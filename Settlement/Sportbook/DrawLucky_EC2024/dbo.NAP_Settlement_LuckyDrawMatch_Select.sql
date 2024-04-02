/*<info serverAlias="DBCTG-bodb02,DBSIG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
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
		
	DECLARE  @WaitingSecond		INT = 900 -- 15min
			,@WaitingTime		DATETIME 
			,@CurrTime			DATETIME

	SET @CurrTime = CAST(GETDATE() AS DATE)
	SET @WaitingTime = DATEADD(SECOND, - @WaitingSecond, @CurrTime)

	SELECT TOP 1
		   m.MatchId
		  ,m.leagueid
		  ,50 AS MinBet --ls.MinBet
	FROM match AS m WITH(NOLOCK)
		OUTER APPLY (SELECT MAX(l.StatusID) AS MaxStatusID, MIN(l.StatusID) AS MinStatusID
					 FROM dbo.LuckyDrawList AS l WITH(NOLOCK) 
					 WHERE l.MatchId = m.matchid 
				) AS ld
		--OUTER APPLY (SELECT s.MinBet
		--			 FROM dbo.LuckyDrawSetting AS s WITH(NOLOCK) 
		--			 WHERE s.MatchId = m.matchid 
		--				AND s.BetType = 413
		--		) AS ls
	WHERE m.eventstatus = 'completed'  
		AND m.matchid IN (83149876,83149907)
		AND ISNULL(ld.MaxStatusID,3) = 3 
		AND ISNULL(ld.MinStatusID,3) = 3 
		AND m.settleTime <= @WaitingTime

END