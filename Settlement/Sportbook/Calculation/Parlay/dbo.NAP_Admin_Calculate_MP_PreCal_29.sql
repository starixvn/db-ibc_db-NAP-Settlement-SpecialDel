/*<info serverAlias="DBCTG-bodb02,DBSID-bodb02,DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_MP_PreCal_29] 
	@matchid	INT
	,@matchdate SMALLDATETIME
	,@strXML	VARCHAR(MAX) = NULL
	,@IsReSettledTickets BIT = 0
	,@strSetting VARCHAR(MAX) = NULL
	,@SessionId	BIGINT = NULL
	,@IsParallel BIT = 0
	,@ParlaySettlementProcessingId BIGINT = NULL
	,@ServerName SYSNAME = ''
	,@AffectedTicket INT = NULL OUTPUT
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
		- 20210601@louisa: Performance Tuning for EC 2021 [Redmine:#151143]
		- 20210514@Kathy: settle parlay ticket [Redmine:#154737]
		- 20220205@Kathy: performance tunning [Redmine:#169814]
		- 20220531@Kathy: performance tunning [Redmine:#173456]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
		- 20221004@Kathy: Prevent duplicate data if re-run SP in case of deadlock [Redmine:#178542]
		- 20221026@Helen: resolve deadlock [Redmine:#179541]
		- 20221031@Helen: resolve deadlock - VERSION 2[Redmine:#179541]
		- 20221011@Kathy: Using Json [Redmine:#178694]
		- 20230316@Kathy: Using index hint [Redmine:#185088]
		- 20230405@Louisa: Support resettle Parlay tickets [Redmine:#186276]
		- 20230816@Kathy: parlay boost [Redmine:#191873]
		- 20231017@Kathy: Cast all modds values return from CASE WHEN expression to DECIMAL(38,20) to avoid CONVERT_IMPLICIT with wrong datatype  [Redmine:#191873]
		- 20231213@Kathy:  Update wrong winlostdate when Re-calculate change score for case LOSE [Redmine:#198190]
		- 20231229@Kathy: insert duplicate betparlayresult - force index [Redmine:#198835]
		- 20230131@Kathy: Support generate BetParlayDetail/BetParlayResult for voiding ticket [Redmine:#200440]
		- 20240215@Kathy: support multiple threads to settle parlay [Redmine:#199518]
		- 20240425@Kathy: enhance parlay [Redmine:#199518]


	Param's Explanation:
		+ @matchid: matchid of match to be settled
		+ @matchdate eventdate of the match
		+ @strSetting: 
			[{"s":"40","v":[{"o":4,"b":0.0300},{...},{"o":250,"b":0.3000}]},{"s":"41","v":[{"o":4,"b":0.0300},{...},{"o":250,"b":0.3000}]}]
				s: SiteId
				v: o: OverOdds
				   b: Boost
		
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
	DECLARE @AllowExec	BIT
			,@IsSiteDB	BIT = 0	

	SET @IsReSettledTickets = ISNULL(@IsReSettledTickets, 0)

	IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL 
	SET @IsSiteDB = 1

	SET @ServerName = CASE WHEN ISNULL(@ServerName,'') = '' THEN @@SERVERNAME ELSE @ServerName END
	
	IF @ServerName <> @@SERVERNAME
        RETURN

	IF OBJECT_ID('NAP_Set_ServerAction', 'P') IS NOT NULL
	BEGIN
		EXEC [dbo].[NAP_Set_ServerAction]
			@ServerName	= @ServerName
			,@AllowExec	= @AllowExec OUTPUT

		IF @AllowExec = 0
			RETURN
	END
	-- END CHECK

	DECLARE @xml			XML
			,@ExtraValue	MONEY
			,@totalRow		INT = 0
			,@thresHold		INT = 4000
			,@batchNo		INT = 0
			,@isInsertedBetParlayDetail BIT = 0
			
	DECLARE @transIDs AS TABLE(transid BIGINT primary key)
	DECLARE @tmpSetting AS TABLE (SiteId INT, FromOdds DECIMAL(9,4), ToOdds DECIMAL(9,4), Boost TINYINT, isFirstOdds BIT DEFAULT(0), isLastOdds BIT DEFAULT(0))

	INSERT INTO @transIDs (transid)
	SELECT value
	FROM STRING_SPLIT(@strXML, ',')
	
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

	DECLARE @temp_bettrans AS TABLE (
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
		,insertedDetail bit default(0) -- row has been inserted into betParlayDetail
		,eventdate SMALLDATETIME -- max(eventdate) - using for set winlostdate of running ticket
		,selection_cnt tinyint NOT NULL ---- number of selections (bettransM count)
		,oddsspread	money
		,betteam NVARCHAR(10)
		,actual_stake	money
		,BetSiteID INT
	)
		
	CREATE TABLE #tmpSource (refno BIGINT, transid BIGINT, winlostdate SMALLDATETIME, mainwinlostdate SMALLDATETIME, statuswinlost TINYINT, statusId TINYINT, matchid INT
		, bettype SMALLINT, odds SMALLMONEY, betteam NVARCHAR(10)
		,hdp1 SMALLMONEY, hdp2 SMALLMONEY, livehomescore SMALLINT, liveawayscore SMALLINT
		,liveindicator BIT, betcheck NVARCHAR(50), selection_cnt TINYINT , bitmapR INT, SetStake MONEY, transdesc NVARCHAR(1000)
		,RN INT
	)
	
	CREATE TABLE #tmpSetStake (Refno BIGINT, RN INT, SetStake MONEY)
	CREATE CLUSTERED INDEX CIX_tmpSetStake_refno ON #tmpSetStake (refno)

	CREATE TABLE #BetParlayDetail_pre(
		[RefNo] [bigint] NULL,
		[Serial] [int] NULL,
		[transid] [bigint] NULL,
		[winlostdate] [smalldatetime] NULL,
		[mainwinlostdate] [smalldatetime] NULL,
		[statuswinlost] [tinyint] NULL,
		[statusid] [tinyint] NULL,
		[matchid] [int] NULL,
		[bettype] [smallint] NULL,
		[stake] [money] NULL,
		[odds] [smallmoney] NULL,
		[betteam] [nvarchar](10) NULL,
		[hdp1] [smallmoney] NULL,
		[hdp2] [smallmoney] NULL,
		[livehomescore] [smallint] NULL,
		[liveawayscore] [smallint] NULL,
		[liveindicator] [bit] NULL,
		[betcheck] [nvarchar](50) NULL,
		[transdesc] [nvarchar](2000) NULL
	) 
	CREATE TABLE #tmpBeingGeneratedRefno (refno BIGINT, mainwinlostdate SMALLDATETIME, cntRow INT, runningTotal INT, batchNo INT)
	DECLARE @tmpbatchRefno TABLE (refno BIGINT, mainwinlostdate SMALLDATETIME)
	
	BEGIN
		INSERT INTO @temp_bettrans (
			transid, refno, stake
			,selection_cnt
			,bitmapR
			,winlostdate, apositiontaking, mpositiontaking, spositiontaking, playerdiscount, discount
			,adiscount, sdiscount, comstatus
			,oddsspread, actual_stake, betteam, BetSiteID, eventdate
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
				,adiscount, sdiscount, comstatus
				,ISNULL(oddsspread, 0), actual_stake, betteam, BetSiteID, winlostdate as eventdate
		FROM	dbo.bettrans WITH(NOLOCK, INDEX = PK_bettrans)
		WHERE	transid IN (SELECT transid FROM @transIDs)
				AND statusID <> 101 --('REJECT')	
		
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
			FROM	@temp_bettrans
		)
		DELETE 
		FROM	cteDuplicateTransId
		WHERE	rn > 1

		UPDATE t
			SET insertedDetail = 1
		FROM @temp_bettrans t
		WHERE EXISTS (SELECT TOP 1 1 FROM dbo.BetParlayDetail r WITH (NOLOCK) WHERE t.refno = r.refno)			

		-- generate BetParlayDetail
		INSERT INTO #tmpSource(refno, transid, winlostdate, mainwinlostdate, statuswinlost, statusId, matchid
			,bettype, odds, betteam, hdp1, hdp2, livehomescore
			,liveawayscore, liveindicator, betcheck, selection_cnt, bitmapR, SetStake, transdesc
			,RN
		)
		SELECT bm.refno, bm.transid, bm.winlostdate, b.winlostdate AS mainwinlostdate, bm.statuswinlost, bm.statusid, bm.matchid
			,bm.bettype, bm.odds, bm.betteam, bm.hdp1, bm.hdp2, bm.livehomescore
			,bm.liveawayscore, bm.liveindicator, bm.betcheck, b.selection_cnt, b.bitmapR, bm.stake as SetStake, bm.transdesc
			,RN = ROW_NUMBER() OVER (PARTITION BY bm.refno ORDER BY m.mainmatch) --RN			
		FROM @temp_bettrans b
			INNER LOOP JOIN dbo.bettransm bm WITH(ROWLOCK)
				ON b.refno = bm.refno
			CROSS APPLY
				(
					SELECT	TOP 1 CASE 
									WHEN ISNULL(m.ChildMatchType,0) = 200 AND m.ParentID IS NOT NULL AND m.sporttype = 50 THEN m.ParentID 
									ELSE bm.matchid 
								END AS mainmatch
					FROM dbo.match m WITH (NOLOCK)									
					WHERE	bm.matchid = m.matchid
							AND m.sporttype BETWEEN 1 AND 99											
				) m
		WHERE	b.insertedDetail = 0 

		IF @@ROWCOUNT > 0
		BEGIN			
			INSERT INTO #tmpSetStake (Refno, RN, SetStake)
			SELECT	refno, RN, SetStake
			FROM	#tmpSource
			WHERE	SetStake > 0

			INSERT INTO #BetParlayDetail_pre (RefNo, Serial, transid, winlostdate, mainwinlostdate, statuswinlost, statusid
				,matchid, bettype, stake, odds, betteam, hdp1
				,hdp2, livehomescore, liveawayscore, liveindicator, betcheck, transdesc)
			SELECT p.RefNo, rc.Serial, p.transid, p.winlostdate, p.mainwinlostdate, p.statuswinlost, p.statusid
				,p.matchid, p.bettype, ps.SetStake, p.odds, p.betteam, p.hdp1
				,p.hdp2, p.livehomescore, p.liveawayscore, p.liveindicator, p.betcheck, p.transdesc
			FROM	#tmpSource p
				INNER JOIN dbo.RefCombinationSet rcs WITH (NOLOCK) ON p.selection_cnt = rcs.N AND (p.bitmapR & rcs.bitmapR) > 0 -- Pick Set by BitmapR (get R)
				INNER JOIN dbo.RefCombination rc WITH (NOLOCK) ON rcs.N = rc.N AND rcs.R = rc.R AND p.RN = rc.seq -- Pick subticket details (R & seq)
				INNER JOIN #tmpSetStake ps ON ps.refno = p.refno AND ps.RN = rc.R
			
			CREATE CLUSTERED INDEX CIX_BetParlayDetail_pre_refno ON #BetParlayDetail_pre (refno)

			INSERT INTO #tmpBeingGeneratedRefno(Refno, mainwinlostdate, cntRow)
			SELECT	refno, mainwinlostdate, COUNT(1)
			FROM	#BetParlayDetail_pre
			GROUP BY refno,mainwinlostdate
			ORDER BY refno

			UPDATE #tmpBeingGeneratedRefno
				SET runningTotal = @totalRow
					,@totalRow = CASE WHEN @totalRow + cntRow >= @thresHold THEN cntRow ELSE @totalRow + cntRow END
					,batchNo = @batchNo
					,@batchNo = CASE WHEN @totalRow = cntRow THEN @batchNo + 1 ELSE @batchNo END
			OPTION (MAXDOP 1)

			SET @batchNo = 1

			WHILE (1=1)
			BEGIN
				DELETE @tmpbatchRefno

				INSERT INTO @tmpbatchRefno(refno, mainwinlostdate) 
				SELECT refno, mainwinlostdate FROM #tmpBeingGeneratedRefno WHERE batchno = @batchNo

				IF @@ROWCOUNT = 0
					BREAK

				BEGIN TRY
					SET @isInsertedBetParlayDetail = 0
					
					INSERT INTO dbo.BetParlayDetail WITH (ROWLOCK)
						(
							RefNo, Serial, transid, winlostdate, statuswinlost, statusid
							,matchid, bettype, stake, odds, betteam, hdp1
							,hdp2, livehomescore, liveawayscore, liveindicator, betcheck, transdesc
						)
					SELECT	p.RefNo, Serial, transid, p.winlostdate, statuswinlost, statusid
							,matchid, bettype, stake, odds, betteam, hdp1
							,hdp2, livehomescore, liveawayscore, liveindicator, betcheck, transdesc
					FROM	@tmpbatchRefno t
						INNER JOIN #BetParlayDetail_pre p
							ON	p.RefNo = t.refno
					
					SET @isInsertedBetParlayDetail = 1

					INSERT INTO dbo.BetParlayResult (
						RefNo, Serial, transid, winlostdate, statusid, Stake
						,Odds, mOdds, winlost, awinlost, mwinlost, swinlost
						,playercomm, comm, acomm, scomm
					)
					SELECT	DISTINCT b.RefNo, r.Serial, 0, b.mainwinlostdate, 0, r.stake
							,0, 0, 0, 0, 0, 0
							,0, 0, 0, 0
					FROM	@tmpbatchRefno b
						INNER JOIN #BetParlayDetail_pre r
							ON	b.refno = r.refno
				END TRY
				BEGIN CATCH
					IF @isInsertedBetParlayDetail = 1
					BEGIN
						DELETE	p  WITH(ROWLOCK, UPDLOCK)
						FROM	dbo.BetParlayDetail p
							INNER JOIN @tmpbatchRefno t
								ON t.refno = p.refno
					END

					;THROW -- raise error and return
				END CATCH

				SET @batchNo = @batchNo + 1
			END
		END		
	END
	-----------------------
	-----------------------
	-- eventdate = max(match.eventdate) - using for set winlostdate of running ticket	
	DECLARE @tmpRefnoMaxEventDate TABLE (refno BIGINT, EventDate DATETIME)

	INSERT INTO @tmpRefnoMaxEventDate(refno, EventDate)
	SELECT t.refno, MAX(m.eventdate) AS EventDate
	FROM @temp_bettrans t		
		INNER LOOP JOIN dbo.bettransm bm WITH (NOLOCK)	 
			ON bm.refno = t.refno
		INNER LOOP JOIN dbo.match m WITH (NOLOCK)
			ON m.matchid = bm.matchid
	WHERE	m.eventdate > t.winlostdate
	GROUP BY t.refno
	
	IF @@ROWCOUNT > 0
		UPDATE t 
			SET eventdate = s.eventdate
		FROM @temp_bettrans t
			INNER JOIN @tmpRefnoMaxEventDate s
				ON t.refno = s.refno 

	DECLARE @statusID TINYINT, @modds MONEY
	DECLARE @commWinRate MONEY, @commLostRate MONEY

	;WITH p AS (
		SELECT pd.refno as refno
			,pd.serial
			,b.eventdate
			,SUM(CASE WHEN pd.statusID IN (121, 103) THEN 0 ELSE 1 END) as NoRefund
			,SUM(CASE WHEN pd.statuswinlost = 4	AND pd.statusID NOT IN (102, 0) THEN 1 ELSE 0 END) as loseCnt
			,SUM(CASE WHEN pd.statusID IN (0, 1) THEN 1 ELSE 0 END) as runningCnt
			,MAX(pd.winlostdate) as matchdate_max
			,CAST(dbo.PRODUCT(pd.odds) AS MONEY) AS odds
			,dbo.PRODUCT(
				CASE WHEN pd.statusid = 102 THEN 1
					WHEN pd.statusid = 0 THEN 1
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
				) AS modds
				,SUM(CASE WHEN pd.matchid = @matchid THEN 1 ELSE 0 END) AS relatedSerial
		FROM dbo.BetParlayDetail pd WITH (NOLOCK)
			INNER JOIN @temp_bettrans b ON pd.refno = b.refno
		GROUP BY pd.refno, pd.serial, b.eventdate
		)
	UPDATE pr			
	SET @statusID = statusID = CASE
					WHEN p.loseCnt > 0    THEN 113 -- Lose
					WHEN p.runningCnt > 0 THEN 0   -- running
					WHEN p.NoRefund = 0   THEN 103 -- Refund
					WHEN CAST(p.modds AS MONEY) < 1 THEN 113 -- Lose
					WHEN CAST(p.modds AS MONEY) = 1      THEN 111 -- Draw
					ELSE 112 -- Won
				END
		,@ExtraValue = CASE WHEN b.oddsspread = 2 AND @statusID = 112 THEN CAST(se.Boost AS MONEY)/100 ELSE NULL END
		,ExtraValue = @ExtraValue
		,winlostdate = CASE
				WHEN @statusId = 0 THEN p.eventdate
				WHEN @statusID IN (103, 111, 112) THEN p.matchdate_max
				WHEN @statusID = 113 THEN CASE WHEN pr.statusid = 113 THEN pr.winlostdate ELSE @matchdate END
				ELSE @matchdate
			END
		,odds = p.odds
		,@modds = pr.modds = CAST(CASE 
			WHEN p.loseCnt > 0 THEN 0
			WHEN @statusID = 0 THEN 0
			WHEN ISNULL(@ExtraValue,0) > 0 THEN CONVERT(DECIMAL(38,20),(p.modds - 1) * @ExtraValue + p.modds)
			ELSE CONVERT(DECIMAL(38,20),p.modds)
			END AS MONEY)
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
		INNER JOIN @temp_bettrans b ON pr.refno = b.refno 
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
	WHERE (@IsReSettledTickets = 1 AND p.relatedSerial = 1)
		OR ( @IsReSettledTickets = 0 
				AND (	pr.statusID <>
						CASE
							WHEN p.loseCnt > 0    THEN 113 -- Lose
							WHEN p.runningCnt > 0 THEN 0   -- running
							WHEN p.NoRefund = 0   THEN 103 -- Refund
							WHEN CAST(p.modds AS MONEY) < 1      THEN 113 -- Lose
							WHEN CAST(p.modds AS MONEY) = 1      THEN 111 -- Draw
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
				)
			)
	
	SET @AffectedTicket = @@ROWCOUNT 
	
	IF @IsSiteDB = 1
	BEGIN
		DECLARE @TransInfoJson NVARCHAR(MAX)

		SET @TransInfoJson = (
			SELECT	 @matchdate as 'wld'
					,@strXML as 'strTransIds'
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
				,@SessionId     = @SessionId
                ,@IsParallel    = @IsParallel
				,@ParlaySettlementProcessingId = @ParlaySettlementProcessingId

	END

END -- end SP
GO
