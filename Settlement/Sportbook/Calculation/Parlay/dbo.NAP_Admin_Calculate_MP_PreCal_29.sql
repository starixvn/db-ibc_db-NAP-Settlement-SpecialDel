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
		- 20200304@Helen: Mix Parlay Boost Odds for Licensee [Redmine:127730]
				
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
		)
		
	BEGIN
		INSERT INTO #temp_bettrans (
			transid, refno, stake
			,selection_cnt
			,bitmapR
			,winlostdate, apositiontaking, mpositiontaking, spositiontaking, playerdiscount, discount
			,adiscount, sdiscount, comstatus, inserted
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
		FROM	dbo.bettrans WITH(NOLOCK)		
		WHERE	transid IN (SELECT transid FROM @transIDs)
				AND statusID NOT IN (101, 102) --('VOID','REJECT')	
			
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
			INNER JOIN dbo.BetParlayResult r on t.refno = r.refno			
		
		;WITH 
			_source AS (
				SELECT bm.refno, bm.transid, bm.winlostdate, bm.statuswinlost, bm.statusid, bm.matchid
					,bm.bettype, bm.odds, bm.betteam, bm.hdp1, bm.hdp2, bm.livehomescore
					,bm.liveawayscore, bm.liveindicator, bm.betcheck, b.selection_cnt, b.bitmapR, bm.stake as SetStake, bm.transdesc
					,RN = ROW_NUMBER() OVER (PARTITION BY bm.refno ORDER BY bm.matchid) --RN
					,bm.PriceMultiplier
				FROM #temp_bettrans b
					CROSS APPLY
						(
							SELECT	bm.refno, bm.transid, bm.winlostdate, bm.statuswinlost, bm.statusID, bm.matchid
								,bm.bettype, bm.odds, bm.betteam, bm.hdp1, bm.hdp2, bm.livehomescore
								,bm.liveawayscore, bm.liveindicator, bm.betcheck, bm.stake, bm.transdesc
								,bm.PriceMultiplier
							FROM	dbo.bettransm bm WITH(rowlock)	
								INNER JOIN dbo.match m WITH (NOLOCK)
									ON	bm.matchid = m.matchid
							WHERE	bm.refno = b.refno
									AND m.sporttype BETWEEN 1 AND 99											
							UNION
							SELECT	bm14.refno, bm14.transid, bm14.winlostdate, bm14.statuswinlost, bm14.statusID, bm14.matchid
								,bm14.bettype, bm14.odds, bm14.betteam, bm14.hdp1, bm14.hdp2, bm14.livehomescore
								,bm14.liveawayscore, bm14.liveindicator, bm14.betcheck, bm14.stake, bm14.transdesc
								,bm14.PriceMultiplier
							FROM	dbo.bettransm14 bm14 WITH(rowlock)			
								INNER JOIN dbo.match14 m14 WITH(NOLOCK)
									ON bm14.matchid = m14.matchid
							WHERE	bm14.refno = b.refno
									AND m14.sporttype BETWEEN 1 AND 99
						) bm
				WHERE	b.inserted = 0 
			),
			ParlayStake AS (SELECT refno, RN, SetStake, PriceMultiplier FROM _source)
		--	
		INSERT INTO dbo.BetParlayDetail (
			RefNo, Serial, transid, winlostdate, statuswinlost, statusid
			,matchid, bettype, stake, odds, betteam, hdp1
			,hdp2, livehomescore, liveawayscore, liveindicator, betcheck, transdesc
			,PriceMultiplier
		)
		SELECT p.RefNo, rc.Serial, transid, winlostdate, statuswinlost, statusid
			,matchid, bettype, ps.SetStake, odds, betteam, hdp1
			,hdp2, livehomescore, liveawayscore, liveindicator, betcheck, transdesc
			,ps.PriceMultiplier
		FROM _source p
			INNER JOIN dbo.RefCombinationSet rcs ON p.selection_cnt = rcs.N AND (p.bitmapR & rcs.bitmapR) > 0 -- Pick Set by BitmapR (get R)
			INNER JOIN dbo.RefCombination rc ON rcs.N = rc.N AND rcs.R = rc.R AND p.RN = rc.seq -- Pick subticket details (R & seq)
			INNER JOIN ParlayStake ps ON ps.refno = p.refno AND ps.RN = rc.R
			
		INSERT INTO dbo.BetParlayResult (
			RefNo, Serial, transid, winlostdate, statusid, Stake
			,Odds, mOdds, winlost, awinlost, mwinlost, swinlost
			,playercomm, comm, acomm, scomm
			,PriceMultiplier
		)
		SELECT DISTINCT b.RefNo, r.Serial, 0, b.winlostdate, 0, r.stake
			,0, 0, 0, 0, 0, 0
			,0, 0, 0, 0
			,r.PriceMultiplier
		FROM #temp_bettrans b
			INNER JOIN dbo.BetParlayDetail r ON b.refno = r.refno
		WHERE b.inserted = 0 -- only insert the row not yet insert to that table
		
	END
	-----------------------
	-----------------------
	
	-- eventdate = max(match.eventdate) - using for set winlostdate of running ticket	
	;WITH s AS (
		SELECT pd.refno, MAX(m.eventdate) AS EventDate
		FROM dbo.BetParlayDetail pd WITH (ROWLOCK)			
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
	
	;WITH preResult AS (
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
			
		FROM dbo.BetParlayDetail pd 
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
			ELSE ISNULL(PR.stake * @modds,0)
			END
		,awinlost = CASE 
			WHEN @statusID = 113 AND loseCnt > 0 THEN   PR.stake * apositiontaking
			WHEN @statusID IN (112, 113)         THEN - PR.stake * apositiontaking * (@modds - 1)
			ELSE 0
			END
		,mwinlost = CASE 
			WHEN @statusID = 113 AND loseCnt > 0 THEN   PR.stake * mpositiontaking
			WHEN @statusID IN (112, 113)         THEN - PR.stake * mpositiontaking * (@modds - 1)
			ELSE 0
			END
		,swinlost = CASE 
			WHEN @statusID = 113 AND loseCnt > 0 THEN   PR.stake * spositiontaking
			WHEN @statusID IN (112, 113)         THEN - PR.stake * spositiontaking * (@modds - 1)
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
		CROSS APPLY (SELECT loseCnt, runningCnt, NoRefund, odds, eventdate, matchdate_max
							,p_tmp.modds * pr.PriceMultiplier AS modds
					 FROM preResult AS p_tmp
					 WHERE  p_tmp.refno = pr.refno
							AND p_tmp.serial = pr.serial
					) AS p
	WHERE
		pr.statusID <>
		CASE
			WHEN p.loseCnt > 0    THEN 113 -- Lose
			WHEN p.runningCnt > 0 THEN 0   -- running
			WHEN p.NoRefund = 0   THEN 103 -- Refund
			WHEN p.modds < 1 THEN 113 -- Lose
			WHEN p.modds = 1 THEN 111 -- Draw
			ELSE 112 -- Won
		END
		OR pr.winlost <>
		CASE 
			WHEN p.loseCnt > 0 OR p.runningCnt > 0 THEN 0 
			ELSE pr.stake * p.modds 
		END

END -- end SP
GO