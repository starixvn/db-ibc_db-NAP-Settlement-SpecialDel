-- Run on DBTP/bodb02
USE bodb02
GO
IF OBJECT_ID('tempdb..#tempBetParlayResultOld') IS NOT NULL
    DROP TABLE #tempBetParlayResult

IF OBJECT_ID('tempdb..#temp_bettrans') IS NOT NULL
    DROP TABLE #temp_bettrans


IF OBJECT_ID('tempdb..#tempBetParlayResultNew') IS NOT NULL
    DROP TABLE #tempBetParlayResultNew

DECLARE @today SMALLDATETIME, @yesterday SMALLDATETIME

SET @today = CAST(GETDATE() AS date)
SET @yesterday = DATEADD(DAY,-1,@today)

SELECT *
into #tempBetParlayResultOld
FROM BetParlayResult WITH(NOLOCK)
WHERE statusid > 0
	AND winlostdate BETWEEN @yesterday AND @today

SELECT *
into #tempBetParlayResultNew
FROM #tempBetParlayResultOld

CREATE UNIQUE CLUSTERED INDEX [CIX_tempBetParlayResultOld] ON #tempBetParlayResultOld
(
	rid 
)

CREATE UNIQUE CLUSTERED INDEX [CIX_tempBetParlayResultNew] ON #tempBetParlayResultNew
(
	rid 
)

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
		,insertedDetail bit default(0) -- row has been inserted into betParlayDetail
		,insertedResult bit default(0)-- row has been inserted into betParlayResult
		,eventdate SMALLDATETIME -- max(eventdate) - using for set winlostdate of running ticket
		,selection_cnt tinyint NOT NULL ---- number of selections (bettransM count)
		,oddsspread	money
		,betteam NVARCHAR(10)
		,actual_stake	money
		,BetSiteID INT
	)

INSERT INTO #temp_bettrans (
			transid, refno, stake
			,selection_cnt
			,bitmapR
			,winlostdate, apositiontaking, mpositiontaking, spositiontaking, playerdiscount, discount
			,adiscount, sdiscount, comstatus
			,oddsspread, actual_stake, betteam, BetSiteID
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
				,ISNULL(oddsspread, 0), actual_stake, betteam, BetSiteID
		FROM	dbo.bettrans WITH(NOLOCK)
		WHERE	refno IN (SELECT refno FROM #tempBetParlayResultOld)
				AND statusID NOT IN (101, 102) --('VOID','REJECT')	
			and matchid = 29


--- old code: without boost
DECLARE @xml XML
,@ExtraValue MONEY
DECLARE @statusID TINYINT, @modds MONEY, @IsReSettledTickets bit = 1

DECLARE @commWinRate MONEY, @commLostRate MONEY

DECLARE @tmpSetting AS TABLE (SiteId INT, FromOdds DECIMAL(9,4), ToOdds DECIMAL(9,4), Boost TINYINT, isFirstOdds BIT DEFAULT(0), isLastOdds BIT DEFAULT(0))
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
	FROM #tempBetParlayResultOld pr
		INNER JOIN #temp_bettrans b ON pr.refno = b.refno 
		INNER JOIN p ON pr.refno = p.refno AND pr.serial = p.serial

--- end old code: without boost
		

select t1.modds as 'old_modds', t2.modds as 'new_modds', t2.refno, t2.serial, t1.statusid, t2.statusid
from #tempBetParlayResultOld t1
	inner join #tempBetParlayResultNew t2 with(nolock)
		on t2.rid = t1.rid					
					
where  t2.ExtraValue is null
	AND (t1.modds <> t2.modds OR t1.statusid <> t2.statusid
		)
	and t1.statusid > 0
				
