-----------STEP 1: ALTER SP EXCREP ------------------
/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[ExecRep_NAP_Admin_08]
(
	@transidlist VARCHAR(MAX) = ''
)

/*	
	Creator: Helen
	Date: 20230330
	DB: DBCTG/bodb02

	Revisions:
		- 20230330@Helen: Resettle ticket for parlay  [Redmine:#186125]

*/	
AS
BEGIN
	SET NOCOUNT ON

	IF OBJECT_ID (N'BetParlayResult', N'U') IS NULL 
		RETURN
	
	IF @@SERVERNAME IN ('DB054','DB054C2\DB054','DB042', 'SITDB042', 'DB055', 'SITDB055','DB04','DB043','DB044', 'DB04ADMIN1','DB04ADMIN2')
        RETURN

	DECLARE @transIDs AS TABLE (transid BIGINT)

	INSERT INTO @transIDs (transid)
	SELECT CAST(value AS BIGINT) transid
	FROM STRING_SPLIT(@transidlist, ',')

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
			
	END		
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
			,SUM(CASE WHEN pd.statuswinlost = 4	AND pd.statusID NOT IN (102, 0) THEN 1 ELSE 0 END) as loseCnt
			,SUM(CASE WHEN pd.statusID IN (0, 1) THEN 1 ELSE 0 END) as runningCnt
			,MAX(pd.winlostdate) as matchdate_max
			,CAST(dbo.PRODUCT(pd.odds) AS MONEY) AS odds
			,CAST(dbo.PRODUCT(
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
		--,winlostdate = CASE
		--		WHEN @statusId = 0 THEN p.eventdate
		--		WHEN @statusID IN (103, 111, 112) THEN p.matchdate_max
		--		WHEN @statusID = 113                 THEN @matchdate
		--		ELSE @matchdate
		--	END
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

END
GO
-----------STEP 2: UPDATE BETPARLAYRESULT VIA SP EXCREP ------------------
/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
--should define primary key for the temporary tables
CREATE TABLE #Result (transid BIGINT PRIMARY KEY, id INT IDENTITY (1,1))
CREATE TABLE #Result_batch (transid BIGINT PRIMARY KEY)
DECLARE @transidlist VARCHAR(MAX) = ''

INSERT INTO #Result (transid)
SELECT DISTINCT TransId
FROM bettrans WITH (NOLOCK) 
WHERE transid IN (
101059717186453524,101059742956257305,101059850330439703,101059940524752910,101060146683183145,101060271237234700,101060309891940358,101060339956711427,101060370021482508,101060516050370576,101060546115141636,101060636309454871,101060666374225929,101060696438997009,101060799518212169,101060881122590731,101060932662198303,101060936957165588,101061065806184457,101061259079712771,101061276259581963,101062006404022292
,101062719368593423
-- add all list licensee still on dbtrans and filter sitedbgroupid = 0
,101059639881236539,101059644176203787,101059652770332676,101059665651040282,101059764439482374,101059803089993733,101059807384961069,101059850334634019,101059919058305029,101059919058305042,101059957708816423,101059974892879886,101059983482814468,101059987773587509,101059992072749094,101060009248423959,101060035018227712,101060035022422051,101060039317389337,101060095143575565,101060112331833416,101060138097442829,101060215411048487,101060219706015748,101060223996788782,101060232586723330,101060236885884933,101060241180852253,101060258360721430,101060297011232807,101060322781036567,101060327080198167,101060339960905766,101060339960905789,101060370029871132,101060408684576778,101060464519151625,101060511763791912,101060533238628359,101060589073203213,101060593363976219,101060601953910799,101060636313649162,101060666378420227,101060674972549141,101060717918027798,101060717922222083,101060735097896988,101060756572733463,101060756572733486,101060765166862350,101060803817373710,101060851066208270,101060863946915885,101060872541044738,101060894011686929,101060919781490718,101060979915227147,101060988500967464,101061031450640396,101061048630509592,101061065810378766,101061082994442256,101061091580182541,101061095879344161,101061113059213335,101061121640759310,101061151713918982,101061164590432285,101061168893788198,101061220425007120,101061237609070603,101061267678036001,101061289144483862,101061302033580049,101061314918481968,101061349278220307,101061353573187593,101061366453895188,101061370753056776,101061392227893258,101061396522860567,101061400813633553,101061443763306523,101061448058273798,101061555436650536,101061555440844813,101061602685485056,101061619856965658,101061705760505884,101061783069917208,101061791664046101,101061795959013418,101061813134688260,101061813134688302,101061847494426630,101061864674295821,101061873260036143,101061881858359337,101061894739066894,101061907619774501,101061907628163110,101061916213903383,101061920504676356,101061929102999570,101061941983707145,101062105196658734,101062113786593304,101062143847170050,101062161027039240,101062212570841136,101062229746515968,101062251221352466,101062350009794591,101062388664500239,101062418720882715,101062427315011612,101062465973911553,101062483145392148,101062504624422923,101062521804292126,101062594818736128,101062676427309058,101062723667755023,101062779498135554
,101062788096458761,101059639881236539,101059644176203787,101059652770332676,101059665651040282,101059764439482374,101059803089993733,101059807384961069,101059850334634019,101059919058305029,101059919058305042,101059957708816423,101059974892879886,101059983482814468,101059987773587509,101059992072749094,101060009248423959,101060035018227712,101060035022422051,101060039317389337,101060095143575565,101060112331833416,101060138097442829,101060215411048487,101060219706015748,101060223996788782,101060232586723330,101060236885884933,101060241180852253,101060258360721430,101060297011232807,101060322781036567,101060327080198167,101060339960905766,101060339960905789,101060370029871132,101060408684576778,101060464519151625,101060511763791912,101060533238628359,101060589073203213,101060593363976219,101060601953910799,101060636313649162,101060666378420227,101060674972549141,101060717918027798,101060717922222083,101060735097896988,101060756572733463,101060756572733486,101060765166862350,101060803817373710,101060851066208270,101060863946915885,101060872541044738,101060894011686929,101060919781490718,101060979915227147,101060988500967464,101061031450640396,101061048630509592,101061065810378766,101061082994442256,101061091580182541,101061095879344161,101061113059213335,101061121640759310,101061151713918982,101061164590432285,101061168893788198,101061220425007120,101061237609070603,101061267678036001,101061289144483862,101061302033580049,101061314918481968,101061349278220307,101061353573187593,101061366453895188,101061370753056776,101061392227893258,101061396522860567,101061400813633553,101061443763306523,101061448058273798,101061555436650536,101061555440844813,101061602685485056,101061619856965658,101061705760505884,101061783069917208,101061791664046101,101061795959013418,101061813134688260,101061813134688302,101061847494426630,101061864674295821,101061873260036143,101061881858359337,101061894739066894,101061907619774501,101061907628163110,101061916213903383,101061920504676356,101061929102999570,101061941983707145,101062105196658734,101062113786593304,101062143847170050,101062161027039240,101062212570841136,101062229746515968,101062251221352466,101062350009794591,101062388664500239,101062418720882715,101062427315011612,101062465973911553,101062483145392148,101062504624422923,101062521804292126,101062594818736128,101062676427309058,101062723667755023,101062779498135554
,101062788096458761

)
AND statusid NOT IN (101) AND SiteDBGroupID = 0

------ info for deployer
DECLARE @StartRow INT = 1
		, @StopRow INT 
		, @MaxRow INT = 1 -- Keep the total row of your data
		, @Threshold INT = 2000 -- the number of each batch
		
DECLARE @debug_message VARCHAR(500)
SET @MaxRow = (SELECT MAX(ID) FROM #Result)

IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow

-- SET for first batch
SET @StopRow = @Threshold

WHILE (1 = 1)
BEGIN
	
		PRINT @StartRow
		PRINT @StopRow
		
		DELETE R
		OUTPUT DELETED.transid
		INTO #Result_batch (transid)		
		FROM #Result R
		WHERE ID BETWEEN @StartRow AND @StopRow

		SET @transidlist =STUFF((SELECT ',' + CONVERT(VARCHAR(50),transid)
					  FROM #Result_batch
					  FOR XML PATH ('')),1,1,'')
		
		SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

		EXEC ExecRep_NAP_Admin_08 @transidlist = @transidlist
		
		IF @StopRow > @MaxRow 
			BREAK

		WAITFOR DELAY '00:00:00.050' --optional
		TRUNCATE TABLE #Result_batch

		SET @StartRow = @StopRow + 1
		SET @StopRow = @StopRow + @Threshold

END

DROP TABLE #Result
DROP TABLE #Result_batch
