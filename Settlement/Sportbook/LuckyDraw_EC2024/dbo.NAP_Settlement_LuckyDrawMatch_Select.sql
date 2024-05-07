/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Settlement_LuckyDrawMatch_Select]
AS
/*
	Created by: 20240401@Aries
	Task: Settlement  
	DB: DBCTG-bodb02
	
	Revisions:
		- 20240401@Aries: EC 2024-Correct Score Sharing and Lucky Draw-(Pool prize) [Redmine:#202309]

	Param's Explanation:  	   
*/
BEGIN	
	SET NOCOUNT ON
		
	DECLARE  @To15Time			DATETIME 
			,@To30Time			DATETIME 
			,@To45Time			DATETIME 
			,@CurrTime			DATETIME

	SET @CurrTime	= GETDATE()
	SET @To15Time	= DATEADD(SECOND, - 900, @CurrTime) --15 min
	SET @To30Time	= DATEADD(SECOND, - 1800, @CurrTime) --30 min
	SET @To45Time	= DATEADD(SECOND, - 2700, @CurrTime) --45 min
	
	SELECT m.MatchId
		  ,m.leagueid
		  ,ls.MinBet
		  ,ls.MinPool
		  ,ls.MaxPool
		  ,pr.TotalPool
		  ,5 AS TotalWinner
		  ,l.IsTest
	FROM match AS m WITH(NOLOCK)
		INNER JOIN dbo.League l WITH(NOLOCK) ON m.leagueid = l.leagueid
		CROSS APPLY (SELECT TOP 1 q.execTime AS SettleTime
					 FROM dbo.Single_Calculate_Queue AS q WITH(NOLOCK) 
					 WHERE q.MatchId = m.matchid 
						AND q.Action IN ('CAL', 'CAL-FT')
					 ORDER BY q.execTime DESC
				) AS qt
		CROSS APPLY (SELECT TOP 1 s.MinBet,s.MinPool,s.MaxPool
					 FROM ActivityDB.dbo.LuckyDrawSetting AS s WITH(NOLOCK) 
					 WHERE s.MatchId = m.matchid 
						AND s.BetType = 413
						AND s.SiteId = 4100
				) AS ls
		CROSS APPLY (SELECT TOP 1 p.TotalPool
					 FROM ActivityDB.dbo.LuckyDrawPoolPrize AS p WITH(NOLOCK) 
					 WHERE p.MatchId = m.matchid 
						AND p.BetType = 413
						AND p.SiteId = 4100
						AND p.BetTeam = 'TotalPool'
				) AS pr
		OUTER APPLY (SELECT MAX(l.StatusID) AS MaxStatusID, MIN(l.StatusID) AS MinStatusID
					 FROM dbo.LuckyDrawList AS l WITH(NOLOCK) 
					 WHERE l.MatchId = m.matchid 
				) AS ld
	WHERE m.eventstatus = 'completed'  
		AND m.betstatus NOT LIKE '%Refund%' 
		AND ISNULL(ld.MaxStatusID,3) = 3 
		AND ISNULL(ld.MinStatusID,3) = 3 
		AND 1 = CASE WHEN qt.SettleTime BETWEEN @To30Time  AND @To15Time  AND ISNULL(m.SettlementStatus,0) & 87 = 0 THEN 1
		             WHEN qt.SettleTime BETWEEN @To45Time  AND @To30Time THEN 1
					 ELSE 0
				END


END