/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_MP_PreCal_29] @matchid INT
	,@matchdate SMALLDATETIME
	,@strXML VARCHAR(MAX) = NULL
AS
/*
	Created: Viet
	Date: 20151005
	Task : Settle bettrans based on bettransm (for system parlay)
	DB: DBTXN.bodb02
	Original: Admin_Calculate_29_Precal, Admin_Calculate_29, Admin_Calculate_29_Summary

	Revisions:
		- 20160419@Kathy: Support Combo Parlay
		- 20160924@Kathy: Exclude bettype 31,32
		- 20160926@Kathy: Get detail tickets of Sportbook only
		- 20171121@Kathy: Prevent lock escalation on table bettrans [Redmine:#75827]
		- 20180629@Kathy: Wrong winlostdate of main ticket [Redmine:#97384]
		- 20190221@Kathy: Do not settle ticket on DB04x [Redmine:#108362]
		- 20190604@Helen: User-Defined Aggregate SQL Function for Parlay Calculation [Redmine:#114391]
		- 20190715@Helen: Recover/Void tickets in Bet 14 [Redmine:115377]
		- 20201126@Louisa: God Of Fortune for Parlay [Redmine:#145774]
		- 20210305@Kathy: Generate combination of ticket by main match of cricket [Redmine:#148870] 
		- 20210415@Helen: Performance Tuning for EC 2021 [Redmine:#151143] 
		
	Param's Explanation:
		+ @matchid: matchid of match to be settled
		+ @matchdate eventdate of the match
	
	Notes: Below is used to calculate odds before CLR Function used 
			,CAST(EXP(SUM(CAST(LOG(pd.odds) AS DECIMAL(38, 20)))) as MONEY) as odds
			,CAST(EXP(SUM(CAST(LOG(
				case pd.statuswinlost
					when 0 then 1 -- draw
					when 1 then 1+((pd.odds-1)/2) -- half won
					when 2 then pd.odds -- won
					when 3 then 0.5 -- half lose
					when 4 then 0.000000000001 -- lose
					else 1 -- void/reject
				end
				) AS DECIMAL(38, 20)))) as MONEY) as modds	
				
*/
BEGIN
	SET NOCOUNT ON
	
	-- CHECK SERVER BEFORE CALCULATING
	DECLARE @ServerName	SYSNAME 
			,@AllowExec	BIT
			,@rowcnt_input INT = 0
			,@rowcnt_inserted INT = 0

	SET @ServerName = @@SERVERNAME

	IF OBJECT_ID('NAP_Set_ServerAction', 'P') IS NOT NULL
	BEGIN
		EXEC [dbo].[NAP_Set_ServerAction]
			@ServerName	= @ServerName
			,@AllowExec	= @AllowExec OUTPUT

		IF @AllowExec = 0
			RETURN
	END
	-- END CHECK

	DECLARE @xml XML
	DECLARE @transIDs AS TABLE(transid BIGINT)

	SET @XML = N'<root><r>' + REPLACE(@strXML, ',', '</r><r>') + '</r></root>'
	
	INSERT INTO @transIDs (transid)
	SELECT r.value('.','BIGINT')
	FROM @xml.nodes('//root/r') AS RECORDS(r)
	OPTION (OPTIMIZE FOR (@xml = NULL))
	
	CREATE TABLE #temp_bettrans (
			transid bigint NOT NULL
			,refno bigint --PRIMARY KEY CLUSTERED
			,stake money NOT NULL
			,bitmapR INT NOT NULL -- bitmap to identify which parlay set is choosen
			,winlostdate smalldatetime NOT NULL
			,apositiontaking smallmoney
			,mpositiontaking smallmoney
			,spositiontaking smallmoney
			,playerdiscount decimal(9, 8)
			,discount decimal(9, 8)
			,adiscount decimal(9, 8)
			,sdiscount decimal(9, 8)
			,comstatus nvarchar(20)
			,inserted bit -- row has been inserted into betParlayResult/betParlayDetail
			,eventdate SMALLDATETIME -- max(eventdate) - using for set winlostdate of running ticket
			,selection_cnt tinyint NOT NULL ---- number of selections (bettransM count)
			,oddsspread	money
			,actual_stake	money
		)
		
	BEGIN
		INSERT INTO #temp_bettrans (
			transid, refno, stake
			,selection_cnt
			,bitmapR
			,winlostdate, apositiontaking, mpositiontaking, spositiontaking, playerdiscount, discount
			,adiscount, sdiscount, comstatus, inserted
			,oddsspread, actual_stake
		)
		SELECT	[transid], [refno], [stake]
				,CASE 
					WHEN betcheck IS NOT NULL THEN CAST(hdp2 AS TINYINT) -- Combo Parlay - New format	
					ELSE CAST(LEN(betteam) AS TINYINT)  -- Old format
					END AS selection_cnt
				,CASE 
					WHEN betcheck IS NOT NULL THEN CAST(betteam AS INT) -- Combo Parlay	- New format	
					ELSE CAST(hdp2/2 AS INT)  -- Old format
					END AS bitmapR
				,winlostdate, apositiontaking, mpositiontaking, spositiontaking, playerdiscount, discount
				,adiscount, sdiscount, comstatus, 0
				,ISNULL(oddsspread, 0), actual_stake
		FROM	dbo.bettrans WITH(NOLOCK)
		WHERE	transid IN (SELECT transid FROM @transIDs)
				AND statusID NOT IN (101, 102) --('VOID','REJECT')	
		SET @rowcnt_input = @@ROWCOUNT
		
		-- Remove duplicate transid if page split occurs
		;WITH cteDuplicateTransId
		AS(
			SELECT	transid
					,refno
					,stake
					,bitmapR
					,winlostdate
					,selection_cnt
					,ROW_NUMBER() OVER(PARTITION BY transid ORDER BY transid) as rn 
			FROM	#temp_bettrans
		)
		DELETE 
		FROM	cteDuplicateTransId
		WHERE	rn > 1

		-- Create index after remove duplicate rows
		CREATE UNIQUE CLUSTERED INDEX CIX_tempBettrans_refno ON #temp_bettrans (refno)

		UPDATE t
			SET inserted = 1
		FROM #temp_bettrans t
		WHERE EXISTS (SELECT TOP 1 1 FROM dbo.BetParlayResult r WITH (NOLOCK) WHERE t.refno = r.refno)			
		SET @rowcnt_inserted = @@ROWCOUNT
		
		IF @rowcnt_inserted <> @rowcnt_input
		BEGIN
			;WITH 
				_source AS (
					SELECT bm.refno, bm.transid, bm.winlostdate, bm.statuswinlost, bm.statusid, bm.matchid
						,bm.bettype, bm.odds, bm.betteam, bm.hdp1, bm.hdp2, bm.livehomescore
						,bm.liveawayscore, bm.liveindicator, bm.betcheck, b.selection_cnt, b.bitmapR, bm.stake as SetStake, bm.transdesc
						,RN = ROW_NUMBER() OVER (PARTITION BY bm.refno ORDER BY bm.mainmatch) --RN			
					FROM #temp_bettrans b
						CROSS APPLY
							(
								SELECT	bm.refno, bm.transid, bm.winlostdate, bm.statuswinlost, bm.statusID, bm.matchid
									,bm.bettype, bm.odds, bm.betteam, bm.hdp1, bm.hdp2, bm.livehomescore
									,bm.liveawayscore, bm.liveindicator, bm.betcheck, bm.stake, bm.transdesc
									,CASE WHEN ISNULL(m.ChildMatchType,0) = 200 AND m.ParentID IS NOT NULL AND m.sporttype = 50 THEN m.ParentID ELSE bm.matchid END AS mainmatch
								FROM	dbo.bettransm bm WITH(ROWLOCK)	
									INNER JOIN dbo.match m WITH (NOLOCK)
										ON	bm.matchid = m.matchid
								WHERE	bm.refno = b.refno
										AND m.sporttype BETWEEN 1 AND 99											
							) bm
					WHERE	b.inserted = 0 
				),
				ParlayStake AS (SELECT refno, RN, SetStake FROM _source)
			--	
			INSERT INTO dbo.BetParlayDetail (
				RefNo, Serial, transid, winlostdate, statuswinlost, statusid
				,matchid, bettype, stake, odds, betteam, hdp1
				,hdp2, livehomescore, liveawayscore, liveindicator, betcheck, transdesc
			)
			SELECT p.RefNo, rc.Serial, transid, winlostdate, statuswinlost, statusid
				,matchid, bettype, ps.SetStake, odds, betteam, hdp1
				,hdp2, livehomescore, liveawayscore, liveindicator, betcheck, transdesc
			FROM _source p
				INNER JOIN dbo.RefCombinationSet rcs WITH (NOLOCK) ON p.selection_cnt = rcs.N AND (p.bitmapR & rcs.bitmapR) > 0 -- Pick Set by BitmapR (get R)
				INNER JOIN dbo.RefCombination rc WITH (NOLOCK) ON rcs.N = rc.N AND rcs.R = rc.R AND p.RN = rc.seq -- Pick subticket details (R & seq)
				INNER JOIN ParlayStake ps ON ps.refno = p.refno AND ps.RN = rc.R
				
			INSERT INTO dbo.BetParlayResult (
				RefNo, Serial, transid, winlostdate, statusid, Stake
				,Odds, mOdds, winlost, awinlost, mwinlost, swinlost
				,playercomm, comm, acomm, scomm
			)
			SELECT DISTINCT b.RefNo, r.Serial, 0, b.winlostdate, 0, r.stake
				,0, 0, 0, 0, 0, 0
				,0, 0, 0, 0
			FROM #temp_bettrans b
				INNER JOIN dbo.BetParlayDetail r WITH (NOLOCK) ON b.refno = r.refno
			WHERE b.inserted = 0 -- only insert the row not yet insert to that table
		END	
		
	END
	-----------------------
	-----------------------
	-- eventdate = max(match.eventdate) - using for set winlostdate of running ticket	
	;WITH s AS (
		SELECT pd.refno, MAX(m.eventdate) AS EventDate
		FROM dbo.BetParlayDetail pd WITH (NOLOCK)			
			INNER JOIN #temp_bettrans t ON pd.refno = t.refno
			INNER JOIN dbo.match m WITH (NOLOCK)
				ON m.matchid = pd.matchid
		GROUP BY pd.refno
	)
	UPDATE #temp_bettrans
		SET eventdate = s.eventdate
	FROM s
	WHERE #temp_bettrans.refno = s.refno 

	DECLARE @statusID TINYINT, @modds MONEY
	DECLARE @commWinRate MONEY, @commLostRate MONEY
	
	;WITH p AS (
		SELECT pd.refno as refno
			,pd.serial
			,b.eventdate
			,SUM(CASE WHEN pd.statusID IN (121, 103) THEN 0 ELSE 1 END) as NoRefund
			,SUM(CASE WHEN pd.statuswinlost = 4	AND pd.statusID <> 102 THEN 1 ELSE 0 END) as loseCnt
			,SUM(CASE WHEN pd.statusID IN (0, 1) THEN 1 ELSE 0 END) as runningCnt
			,MAX(pd.winlostdate) as matchdate_max
			,CAST(dbo.PRODUCT(pd.odds) AS MONEY) AS odds
			,CAST(dbo.PRODUCT(
				CASE WHEN pd.statusid = 102 THEN 1
					ELSE
						CASE pd.statuswinlost
							WHEN 0 THEN 1 -- draw
							WHEN 1 THEN 1+((pd.odds-1)/2) -- half won
							WHEN 2 THEN pd.odds -- won
							WHEN 3 THEN 0.5 -- half lose
							WHEN 4 THEN 0.000000000001 -- lose
							ELSE 1 -- VOID/REJECT
						END
				END
				) AS MONEY) AS modds
		FROM dbo.BetParlayDetail pd WITH (NOLOCK)
			INNER JOIN #temp_bettrans b ON pd.refno = b.refno
		GROUP BY pd.refno, pd.serial, b.eventdate
	)
	UPDATE pr			
	SET @statusID = statusID = CASE
					WHEN p.loseCnt > 0    THEN 113 -- Lose
					WHEN p.runningCnt > 0 THEN 0   -- running
					WHEN p.NoRefund = 0   THEN 103 -- Refund
					WHEN p.modds < 1      THEN 113 -- Lose
					WHEN p.modds = 1      THEN 111 -- Draw
					ELSE 112 -- Won
				END
		,winlostdate = CASE
				WHEN @statusId = 0 THEN p.eventdate
				WHEN @statusID IN (103, 111, 112) THEN p.matchdate_max
				WHEN @statusID = 113                 THEN @matchdate
				ELSE @matchdate
			END
		,odds = p.odds
		,@modds = pr.modds = CASE 
			WHEN p.loseCnt > 0 THEN 0
			WHEN @statusID = 0 THEN 0
			ELSE p.modds
			END
		,@commWinRate = CASE b.comstatus -- 0 : pay normal, both win/lost -- 1 : pay 'double' ONLY on lost
			WHEN '0' THEN 1
			WHEN '1' THEN 0
			ELSE 1
			END
		,@commLostRate = CASE b.comstatus
			WHEN '0' THEN 1
			WHEN '1' THEN 2
			ELSE 1
			END
		,winlost = CASE 
			WHEN loseCnt > 0   THEN 0
			WHEN @statusID = 0 THEN 0
			WHEN  b.oddsspread = 1	THEN	CASE 
											WHEN @modds > 1 THEN @modds * pr.stake + (b.actual_stake - pr.stake)
											WHEN @modds < 1 THEN @modds * b.actual_stake
											ELSE b.actual_stake
											END
			ELSE ISNULL(PR.stake * @modds,0)
			END
		,awinlost = CASE 
			WHEN @statusID = 113 AND loseCnt > 0 THEN	CASE 
														WHEN b.oddsspread  = 1 THEN b.actual_stake 
																				ELSE PR.stake
																				END	* apositiontaking

			WHEN @statusID = 112		         THEN - PR.stake * (@modds - 1) * apositiontaking

			WHEN  @statusID = 113				THEN	CASE
														WHEN  b.oddsspread  = 1 THEN - b.actual_stake *(@modds - 1)
																				ELSE - PR.stake * (@modds - 1)
																				END * apositiontaking
			ELSE 0
			END
		,mwinlost = CASE 
			WHEN @statusID = 113 AND loseCnt > 0 THEN	CASE 
														WHEN b.oddsspread  = 1 THEN b.actual_stake 
																				ELSE PR.stake
																				END	* mpositiontaking

			WHEN @statusID = 112		         THEN	- PR.stake * (@modds - 1) * mpositiontaking

			WHEN  @statusID = 113				THEN	CASE
														WHEN  b.oddsspread  = 1 THEN - b.actual_stake *(@modds - 1)
																				ELSE - PR.stake * (@modds - 1)
																				END * mpositiontaking
			ELSE 0
			END
		,swinlost = CASE 
			WHEN @statusID = 113 AND loseCnt > 0 THEN	CASE 
														WHEN b.oddsspread  = 1 THEN b.actual_stake 
																				ELSE PR.stake
																				END	* spositiontaking

			WHEN @statusID = 112		         THEN	- PR.stake * (@modds - 1) * spositiontaking

			WHEN  @statusID = 113				THEN	CASE
														WHEN  b.oddsspread  = 1 THEN - b.actual_stake *(@modds - 1)
																				ELSE - PR.stake * (@modds - 1)
																				END * spositiontaking
			ELSE 0
			END
		,playercomm = CASE @statusID
			WHEN 112 THEN @commWinRate  * PR.stake * playerdiscount
			WHEN 113 THEN @commLostRate * PR.stake * playerdiscount
			ELSE 0
			END
		,comm = CASE @statusID
			WHEN 112 THEN @commWinRate  * PR.stake * discount * (1 - apositiontaking)
			WHEN 113 THEN @commLostRate * PR.stake * discount * (1 - apositiontaking)
			ELSE 0
			END
		,acomm = CASE @statusID
			WHEN 112 THEN @commWinRate  * PR.stake * adiscount * (1 - apositiontaking - mpositiontaking)
			WHEN 113 THEN @commLostRate * PR.stake * adiscount * (1 - apositiontaking - mpositiontaking)
			ELSE 0
			END
		,scomm = CASE @statusID
			WHEN 112 THEN @commWinRate  * PR.stake * sdiscount * (1 - apositiontaking - mpositiontaking - spositiontaking)
			WHEN 113 THEN @commLostRate * PR.stake * sdiscount * (1 - apositiontaking - mpositiontaking - spositiontaking)
			ELSE 0
			END
	FROM dbo.BetParlayResult pr
		INNER JOIN #temp_bettrans b ON pr.refno = b.refno 
		INNER JOIN p ON pr.refno = p.refno AND pr.serial = p.serial
	WHERE
		pr.statusID <>
		CASE
			WHEN p.loseCnt > 0    THEN 113 -- Lose
			WHEN p.runningCnt > 0 THEN 0   -- running
			WHEN p.NoRefund = 0   THEN 103 -- Refund
			WHEN p.modds < 1      THEN 113 -- Lose
			WHEN p.modds = 1      THEN 111 -- Draw
			ELSE 112 -- Won
		END
		OR pr.winlost <>
		CASE 
			WHEN p.loseCnt > 0 OR p.runningCnt > 0 THEN 0 
			ELSE pr.stake * p.modds
		END

END -- end SP
GO
