/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_MP_Bet14_PreCal_29] 
(
	@matchid	INT
	,@matchdate SMALLDATETIME
	,@TransInfoJson		VARCHAR(MAX) = NULL
	,@strSetting VARCHAR(MAX) = NULL
)
AS
/*
	Created by: 20190715@Helen
	Task: Settlement  
	DB: DBTRANS/BODB02
	
	Revisions:
		- 20190715@Helen: Recover/Void tickets in Bet 14 - [Redmine:115377]
		- 20201126@Louisa: God Of Fortune for Parlay [Redmine:#145774]	
		- 20210121@Kathy: Cricket AIO [Redmine:#148870]
		- 20231227@Max: [TVS] Recover Ticket issue type [Redmine: #196020]
		- 20240416@Max: [TVS] Recover Ticket - Recover full range of archived tickets [Redmine: #203754]
				
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @ExtraValue MONEY
		,@IsSiteDB	BIT = 0
		,@IsReSettledTickets BIT = 0
	
	IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL 
	SET @IsSiteDB = 1

	SET @IsReSettledTickets = ISNULL(@IsReSettledTickets, 0)

	DECLARE @transIDs AS TABLE(transid BIGINT, BetSiteID INT)

	INSERT INTO @transIDs (transid, BetSiteID)
	SELECT t, bet_sid
	FROM STRING_SPLIT(@TransInfoJson, ',') f
		CROSS APPLY (SELECT CAST(DECOMPRESS(CONVERT(VARBINARY(MAX), f.value, 1)) AS NVARCHAR(MAX)) AS Decompress_TransInfoJson) t
		CROSS APPLY (
				SELECT t, bet_sid
				FROM OPENJSON(t.Decompress_TransInfoJson) 
					WITH( t BIGINT, bet_sid INT)
		) tbl
	WHERE f.value <> ''
	
	CREATE TABLE #temp_bettrans (
			transid BIGINT NOT NULL
			,refno BIGINT --PRIMARY KEY CLUSTERED
			,stake MONEY NOT NULL
			,bitmapR INT NOT NULL -- bitmap to identify which parlay set is choosen
			,winlostdate SMALLDATETIME NOT NULL
			,apositiontaking SMALLMONEY
			,mpositiontaking SMALLMONEY
			,spositiontaking SMALLMONEY
			,playerdiscount DECIMAL(9, 8)
			,discount DECIMAL(9, 8)
			,adiscount DECIMAL(9, 8)
			,sdiscount DECIMAL(9, 8)
			,comstatus NVARCHAR(20)
			,inserted_Result BIT -- row has been inserted into betParlayResult
			,inserted_Detail BIT -- row has been inserted into betParlayDetail
			,eventdate SMALLDATETIME -- max(eventdate) - using for set winlostdate of running ticket
			,selection_cnt TINYINT NOT NULL ---- number of selections (bettransM count)
			,oddsspread	money
			,actual_stake	money
			,betteam NVARCHAR(10)
			,BetSiteID INT
			,CustId	INT
		)
	
	DECLARE @tmpSetting AS TABLE (SiteId INT, FromOdds DECIMAL(9,4), ToOdds DECIMAL(9,4), Boost TINYINT, isFirstOdds BIT DEFAULT(0), isLastOdds BIT DEFAULT(0))
	INSERT INTO @tmpSetting(SiteId, FromOdds, ToOdds, Boost, isFirstOdds, isLastOdds)
	SELECT	s.SiteId
			,OverOdds AS FromOdds
			,LEAD(OverOdds) OVER(PARTITION BY SiteID ORDER BY SiteId, OverOdds) AS ToOdds
			,s.Boost
			,CASE WHEN 1 = ROW_NUMBER() OVER (PARTITION BY SiteID ORDER BY SiteId, OverOdds) THEN 1 ELSE 0 END AS isFirstOdds
			,CASE WHEN 1 = ROW_NUMBER() OVER (PARTITION BY SiteID ORDER BY SiteId, OverOdds DESC) THEN 1 ELSE 0 END AS isLastOdds
	FROM	(
		SELECT	s AS SiteId, o AS OverOdds, b AS Boost
		FROM	OPENJSON(@strSetting) WITH (
			s INT '$.s'
			,v NVARCHAR(MAX) '$.v' AS JSON
		) 
		CROSS APPLY OPENJSON(v) WITH (o DECIMAL(9,4) '$.o', b TINYINT '$.b')
	) s

	BEGIN
		INSERT INTO #temp_bettrans (
			transid, refno, stake
			,selection_cnt
			,bitmapR
			,winlostdate, apositiontaking, mpositiontaking, spositiontaking, playerdiscount, discount
			,adiscount, sdiscount, comstatus, inserted_Result, inserted_Detail
			,oddsspread	,actual_stake, betteam, CustId, BetSiteID
		)
		SELECT	b.TransId, [refno], [stake]
				,CASE 
					WHEN betcheck IS NOT NULL THEN CAST(hdp2 AS TINYINT) -- Combo Parlay - New format	
					ELSE CAST(LEN(betteam) AS TINYINT)  -- Old format
					END AS selection_cnt
				,CASE 
					WHEN betcheck IS NOT NULL THEN CAST(betteam AS INT) -- Combo Parlay	- New format	
					ELSE CAST(hdp2/2 AS INT)  -- Old format
					END AS bitmapR
				,winlostdate, apositiontaking, mpositiontaking, spositiontaking, playerdiscount, discount
				,adiscount, sdiscount, comstatus, 0, 0
				,ISNULL(oddsspread, 0), actual_stake, betteam, custid, t.BetSiteID
		FROM	dbo.bettrans b WITH(NOLOCK)	
			INNER JOIN @transIDs t ON t.transid = b.TransId 
		WHERE statusID NOT IN (101, 102) --('VOID','REJECT')	
		UNION ALL
		SELECT	b14.transid, [refno], [stake]
				,CASE 
					WHEN betcheck IS NOT NULL THEN CAST(hdp2 AS TINYINT) -- Combo Parlay - New format	
					ELSE CAST(LEN(betteam) AS TINYINT)  -- Old format
					END AS selection_cnt
				,CASE 
					WHEN betcheck IS NOT NULL THEN CAST(betteam AS INT) -- Combo Parlay	- New format	
					ELSE CAST(hdp2/2 AS INT)  -- Old format
					END AS bitmapR
				,winlostdate, apositiontaking, mpositiontaking, spositiontaking, playerdiscount, discount
				,adiscount, sdiscount, comstatus, 0, 0
				,ISNULL(oddsspread, 0), actual_stake, betteam, custid, t.BetSiteID
		FROM	dbo.bettrans14 b14 WITH(NOLOCK)	
			INNER JOIN @transIDs t ON t.transid = b14.TransId 
		WHERE	statusID NOT IN (101, 102) --('VOID','REJECT')
					
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
			SET inserted_Result = 1
		FROM #temp_bettrans t
			INNER JOIN dbo.BetParlayResult r on t.refno = r.refno			
		
		UPDATE t
			SET inserted_Detail = 1
		FROM #temp_bettrans t
			INNER JOIN dbo.BetParlayDetail r on t.refno = r.refno
			
		;WITH 
			_source AS (
				SELECT bm.refno, bm.transid, bm.winlostdate, bm.statuswinlost, bm.statusid, bm.matchid
					,bm.bettype, bm.odds, bm.betteam, bm.hdp1, bm.hdp2, bm.livehomescore
					,bm.liveawayscore, bm.liveindicator, bm.betcheck, b.selection_cnt, b.bitmapR, bm.stake as SetStake, bm.transdesc
					,b.inserted_Detail, b.inserted_Result
					,RN = ROW_NUMBER() OVER (PARTITION BY bm.refno ORDER BY bm.mainmatch) --RN			
				FROM #temp_bettrans b
					CROSS APPLY
						(
							SELECT	bm.refno, bm.transid, bm.winlostdate, bm.statuswinlost, bm.statusID, bm.matchid
								,bm.bettype, bm.odds, bm.betteam, bm.hdp1, bm.hdp2, bm.livehomescore
								,bm.liveawayscore, bm.liveindicator, bm.betcheck, bm.stake, bm.transdesc
								,CASE WHEN ISNULL(m.ChildMatchType,0) = 200 AND m.ParentID IS NOT NULL AND m.sporttype = 50 THEN m.ParentID ELSE bm.matchid END AS mainmatch
							FROM	dbo.bettransm bm WITH(rowlock)	
								INNER JOIN dbo.match m WITH (NOLOCK)
									ON	bm.matchid = m.matchid
							WHERE	bm.refno = b.refno
									AND m.sporttype BETWEEN 1 AND 99											
							UNION
							SELECT	bm14.refno, bm14.transid, bm14.winlostdate, bm14.statuswinlost, bm14.statusID, bm14.matchid
								,bm14.bettype, bm14.odds, bm14.betteam, bm14.hdp1, bm14.hdp2, bm14.livehomescore
								,bm14.liveawayscore, bm14.liveindicator, bm14.betcheck, bm14.stake, bm14.transdesc
								,CASE WHEN ISNULL(m14.ChildMatchType,0) = 200 AND m14.ParentID IS NOT NULL AND m14.sporttype = 50 THEN m14.ParentID ELSE bm14.matchid END AS mainmatch
							FROM	dbo.bettransm14 bm14 WITH(rowlock)			
								INNER JOIN dbo.match14 m14 WITH(NOLOCK)
									ON bm14.matchid = m14.matchid
							WHERE	bm14.refno = b.refno
									AND m14.sporttype BETWEEN 1 AND 99
							
							UNION
							
							SELECT	bmbk.refno, bmbk.transid, bmbk.winlostdate, bmbk.statuswinlost, bmbk.statusID, bmbk.matchid
								,bmbk.bettype, bmbk.odds, bmbk.betteam, bmbk.hdp1, bmbk.hdp2, bmbk.livehomescore
								,bmbk.liveawayscore, bmbk.liveindicator, bmbk.betcheck, bmbk.stake, bmbk.transdesc
								,CASE WHEN ISNULL(mbk.ChildMatchType,0) = 200 AND mbk.ParentID IS NOT NULL AND mbk.sporttype = 50 THEN mbk.ParentID ELSE bmbk.matchid END AS mainmatch
							FROM	dbarc.bodb_archive.dbo.bettransm bmbk WITH(rowlock)			
								INNER JOIN dbarc.bodb_archive.dbo.match_bk mbk WITH(NOLOCK)
									ON bmbk.matchid = mbk.matchid
							WHERE	bmbk.refno = b.refno
									AND mbk.sporttype BETWEEN 1 AND 99
											
						) bm
				WHERE	b.inserted_Detail = 0 OR b.inserted_Result = 0
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
			INNER JOIN dbo.RefCombinationSet rcs ON p.selection_cnt = rcs.N AND (p.bitmapR & rcs.bitmapR) > 0 -- Pick Set by BitmapR (get R)
			INNER JOIN dbo.RefCombination rc ON rcs.N = rc.N AND rcs.R = rc.R AND p.RN = rc.seq -- Pick subticket details (R & seq)
			INNER JOIN ParlayStake ps ON ps.refno = p.refno AND ps.RN = rc.R
		WHERE p.inserted_Detail = 0
			
		INSERT INTO dbo.BetParlayResult (
			RefNo, Serial, transid, winlostdate, statusid, Stake
			,Odds, mOdds, winlost, awinlost, mwinlost, swinlost
			,playercomm, comm, acomm, scomm
		)
		SELECT DISTINCT b.RefNo, r.Serial, 0, b.winlostdate, 0, r.stake
			,0, 0, 0, 0, 0, 0
			,0, 0, 0, 0
		FROM #temp_bettrans b
			INNER JOIN dbo.BetParlayDetail r ON b.refno = r.refno
		WHERE b.inserted_Result = 0 -- only insert the row not yet insert to that table
		
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
		,@ExtraValue = CASE WHEN b.oddsspread = 2 AND @statusID = 112 THEN CAST(se.Boost AS MONEY)/100 ELSE NULL END
		,ExtraValue = @ExtraValue
		,winlostdate = CASE
				WHEN @statusId = 0 THEN p.eventdate
				WHEN @statusID IN (103, 111, 112) THEN p.matchdate_max
				WHEN @statusID = 113              THEN @matchdate
				ELSE @matchdate
			END
		,odds = p.odds
		,@modds = pr.modds = CASE 
			WHEN p.loseCnt > 0 THEN 0
			WHEN @statusID = 0 THEN 0
			WHEN ISNULL(@ExtraValue,0) > 0 THEN CONVERT(DECIMAL(38,20),(p.modds - 1) * @ExtraValue + p.modds)
			ELSE CONVERT(DECIMAL(38,20),p.modds)
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
														WHEN  b.oddsspread  = 1 THEN b.actual_stake 
																				ELSE PR.stake
																				END * mpositiontaking
			
			WHEN @statusID = 112		         THEN	- PR.stake * (@modds - 1) * mpositiontaking

			WHEN  @statusID = 113				THEN	CASE
														WHEN  b.oddsspread  = 1 THEN - b.actual_stake *(@modds - 1)
																				ELSE - PR.stake * (@modds - 1)
																				END * mpositiontaking
			ELSE 0
			END
		,swinlost = CASE 
			WHEN @statusID = 113 AND loseCnt > 0 THEN  CASE
														WHEN b.oddsspread  = 1 THEN b.actual_stake
														ELSE PR.stake 
														END  * spositiontaking

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
		OUTER APPLY (
			SELECT	TOP 1 s.Boost
			FROM	@tmpSetting s
			WHERE	s.SiteId = b.BetSiteID
					AND b.betteam = '1' -- Mix parlay
					AND b.oddsspread = 2 -- offer parlay boost
					AND 1 =  CASE 
								WHEN s.isFirstOdds = 1 AND CAST(p.mOdds AS MONEY) BETWEEN s.FromOdds AND s.ToOdds THEN 1 --s.Boost
								WHEN s.isLastOdds = 1 AND CAST(p.mOdds AS MONEY) > s.FromOdds THEN 1
								WHEN s.isFirstOdds = 0 AND s.isLastOdds = 0 AND CAST(p.mOdds AS MONEY) > s.FromOdds AND CAST(p.mOdds AS MONEY) <= s.ToOdds THEN 1
								ELSE 0
							END
		)se
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
			ELSE pr.stake *  CAST(CASE 
												WHEN p.loseCnt > 0 THEN 0
												WHEN p.runningCnt > 0 THEN 0
												WHEN CAST(p.modds AS MONEY) > 1 AND ISNULL(CAST(se.Boost AS MONEY)/100,0) > 0 
													THEN CONVERT(DECIMAL(38,20),(p.modds - 1) * ISNULL(CAST(se.Boost AS MONEY)/100,0) + p.modds)
												ELSE CONVERT(DECIMAL(38,20),p.modds)
												END AS MONEY
										)
		END


	IF @IsSiteDB = 1
	BEGIN
		DECLARE @TransInfoJson NVARCHAR(MAX)

		SET @TransInfoJson = (
			SELECT	 @matchdate as 'wld'
					,@strXML as 'strTransId'
					,@IsReSettledTickets AS 'ReSettle'
					,@strSetting AS 'strSetting'
			FOR JSON PATH
		)

		IF @transinfoJson IS NOT NULL
			EXEC dbo.SiteDB_NAP_SettlementService_CalculationLogIns 
				@SystemName = 'Settlement' 
				,@FunctionName = 'PreCal29'
				,@TableName = 'BetParlayResult'
				,@MatchId = @MatchId
				,@TransInfoJson = @transinfoJson
				,@SettlementAction = 'CAL'
				,@TicketType = 'p'
	END
	
	DROP TABLE #temp_bettrans
	
END -- end SP
GO