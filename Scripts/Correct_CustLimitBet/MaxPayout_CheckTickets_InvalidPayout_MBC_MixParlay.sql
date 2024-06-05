-------------------Step 1: Get affected custid ----------------------------------------------------
/*
create table #temp (custid INT)
;with cte1
as 
(
SELECT matchid, custid,eventtypeid, PayoutAdjust, COUNT(1) as p1
FROM CustLimitBetHistory_MBC WITH (NOLOCK)
WHERE EventTypeID = 4 AND matchid = 29
	AND PayoutAdjust < 0
group by matchid, custid,eventtypeid, PayoutAdjust
)
,cte2
as
(
SELECT matchid, custid,eventtypeid, PayoutAdjust, COUNT(1) as p1
FROM CustLimitBetHistory_MBC WITH (NOLOCK)
WHERE EventTypeID = 4 AND matchid = 29
	AND PayoutAdjust > 0
group by matchid, custid,eventtypeid, PayoutAdjust
)

insert into #temp (custid)
select distinct t1.CustID
from cte1 t1
	inner join cte2 t2 on t1.Matchid = t2.Matchid and t1.CustID = t2.CustID and t1. EventTypeID = t2.EventTypeID
where t1.p1 <> t2.p1

select * from #temp
*/
-------------------Step 2: after having affected custid from step 1 -------------------------------
/*
USE DBTP/bodb02
GO
*/
CREATE TABLE #Temp_CustID(
	ID INT IDENTITY (1,1) PRIMARY KEY,
	CustID INT
)
create table #temp1 (matchid INT, custid INT, transid BIGINT,TurnoverAdjust MONEY, PayoutAdjust money,EventTypeID tinyint, CreatedDate datetime )
create table #temp2 (matchid INT, custid INT, transid BIGINT,TurnoverAdjust MONEY, PayoutAdjust money,EventTypeID tinyint, CreatedDate datetime, SumAccum_PayoutAdjust MONEY )
create table #Result (matchid INT, custid INT, transid BIGINT,TurnoverAdjust MONEY, PayoutAdjust money,EventTypeID tinyint, CreatedDate datetime, SumAccum_PayoutAdjust MONEY, settingValue_Payout MONEY, IsInValid_Payout BIT )

--paste custid here
INSERT INTO #Temp_CustID (CustID)
values (82440986)

------ info for deployer
DECLARE @StartRow INT 
		, @MaxRow INT  
		, @CustID	INT
		,@debug_message VARCHAR(500)

SET @MaxRow = (SELECT MAX(ID) FROM #Temp_CustID)
SELECT @StartRow = 1

WHILE (@MaxRow IS NOT NULL)
BEGIN
	
		SELECT @CustID = CustID 
		FROM #Temp_CustID
		WHERE ID = @StartRow

		TRUNCATE TABLE #temp1
		TRUNCATE TABLE #temp2

		INSERT INTO #temp1 (matchid, custid, transid, TurnoverAdjust,PayoutAdjust, EventTypeID, CreatedDate)
		SELECT MatchId
			  ,CustId
			  ,Transid
			  ,TurnoverAdjust
			  ,PayoutAdjust
			  ,EventTypeID
			  ,MIN(CreatedDate) CreatedDate
		FROM bodb_xxx.dbo.CustLimitBetHistory_MBC WITH (NOLOCK)
			--dbgrp03l.bodb02.dbo.CustLimitBetHistory_MBC WITH (NOLOCK)
		WHERE custid = @CustID AND EventTypeID = 4 AND matchid = 29
		GROUP BY matchid, custid, transid, TurnoverAdjust, PayoutAdjust, eventtypeid

		INSERT INTO #temp2 (matchid, custid, transid, TurnoverAdjust, PayoutAdjust, EventTypeID, CreatedDate, SumAccum_PayoutAdjust)
		SELECT MatchId
			  ,CustId
			  ,Transid
			  ,TurnoverAdjust
			  ,PayoutAdjust
			  ,EventTypeID
			  ,CreatedDate
			  ,SUM(PayoutAdjust) OVER(PARTITION BY MatchId, CustId ORDER BY CreatedDate ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS SumAccum_PayoutAdjust
		from #temp1 
		ORDER BY CreatedDate

		INSERT INTO #Result (matchid, custid, transid, TurnoverAdjust, PayoutAdjust, EventTypeID, CreatedDate, SumAccum_PayoutAdjust, settingValue_Payout, IsInValid_Payout )
		SELECT MatchId
			  ,CustId
			  ,Transid
			  ,PayoutAdjust
			  ,TurnoverAdjust
			  ,EventTypeID
			  ,CreatedDate
			  --payout value
			  , SumAccum_PayoutAdjust
			  , ISNULL(t2.MaxPayoutPerMatch, t3.MaxPayoutPerMatch) as settingValue_Payout
			  , case when t.TurnoverAdjust > 0 and SumAccum_PayoutAdjust > isnull(t2.MaxPayoutPerMatch, t3.MaxPayoutPerMatch) then 1 
					else 0 end as InValid_Payout
		from #temp2 t
			OUTER APPLY (SELECT TOP 1 h.MaxPayoutPerMatch
					FROM bodb_CustHistory.dbo.CustBetSetting_Member_history h WITH (NOLOCK)
					WHERE CustID=@CustID
					AND UpdateTime between DATEADD (S, -60, t.CreatedDate) and t.CreatedDate
					AND h.SportType = 99 and bettype = 9 --IN (1,99) AND BetType=9 --Soccer Parlay / Mix Sports Parlay
					order by UpdateTime desc
					) t2
			CROSS APPLY (SELECT  h.MaxPayoutPerMatch
					FROM bodb02.dbo.CustBetSetting_Member h WITH (NOLOCK)
					WHERE CustID=@CustID
					AND h.SportType = 99 and bettype = 9 --IN (1,99) AND BetType=9 --Soccer Parlay / Mix Sports Parlay
					) t3
		WHERE t.TurnoverAdjust > 0 and SumAccum_PayoutAdjust  > ISNULL(t2.MaxPayoutPerMatch, t3.MaxPayoutPerMatch)

		SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121) +' | CustId:' + CAST(@custid AS VARCHAR(20) )			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

		IF @StartRow = @MaxRow BREAK

		WAITFOR DELAY '00:00:00.005' --optional

		SET @StartRow = @StartRow + 1

END

SELECT * FROM #Result
