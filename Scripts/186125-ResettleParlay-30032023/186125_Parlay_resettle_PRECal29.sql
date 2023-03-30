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
/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
--should define primary key for the temporary tables
CREATE TABLE #Result (transid BIGINT PRIMARY KEY, id INT IDENTITY (1,1))
CREATE TABLE #Result_batch (transid BIGINT PRIMARY KEY)
DECLARE @transidlist VARCHAR(MAX) = ''

INSERT INTO #Result (transid)
SELECT DISTINCT TransId
FROM bettrans WITH (NOLOCK) 
WHERE transid IN (xxxxx)

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
