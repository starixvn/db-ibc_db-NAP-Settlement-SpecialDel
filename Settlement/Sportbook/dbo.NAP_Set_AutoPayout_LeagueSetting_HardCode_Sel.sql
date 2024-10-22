/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_AutoPayout_LeagueSetting_HardCode_Sel
	 @LeagueId					INT				= NULL
	,@AutoType					TINYINT			= NULL
AS
/*	Creator: 20241002@Aries
	Task: Support a tool to add leagues for Direct Payout
	DB: DBPRO/BODB02
	
	Revisions:
		- 20241002@Aries: Support a tool to add leagues for Direct Payout [Redmine:#211265]
		
	Param's Explanation:
		- @AutoType: TINYINT 
			+ 1: Auto Payout
			+ 2: Inst Calculation
			+ 3: Fast Market
			+ 5: Direct Payout
			+ 6: Auto Payout Model 2
			+ 7: Auto Refund
			+ 8: HardCode Direct Soccer
			+ 9. HardCode Fantasy Soccer
			+ 10. HardCode Fantasy Basketball
 
*/
BEGIN
	SET NOCOUNT ON
	
	IF @LeagueId IS NOT NULL
	BEGIN
		SELECT l.LeagueId
			  ,s.AutoType 
			  ,l.sporttype
		FROM League AS l WITH(NOLOCK) 
			OUTER APPLY (
				SELECT ss.AutoType
				FROM SettlementSetting AS ss WITH(NOLOCK) 
				WHERE l.LeagueId = ss.LeagueId
					AND ss.AutoType IN (8,9,10)
			) AS s
		WHERE l.LeagueId = @LeagueId
	END
	ELSE IF @LeagueId IS NULL AND @AutoType IS NULL 
	BEGIN
		SELECT ss.LeagueId
			  ,ss.AutoType 
			  ,l.sporttype
		FROM SettlementSetting AS ss WITH(NOLOCK)
			INNER JOIN League AS l WITH(NOLOCK) ON l.LeagueId = ss.LeagueId
		WHERE ss.AutoType IN (8,9,10)

	END
	ELSE IF @LeagueId IS NULL AND @AutoType IS NOT  NULL 
	BEGIN
		SELECT ss.LeagueId
			  ,ss.AutoType 
			  ,l.sporttype
		FROM SettlementSetting AS ss WITH(NOLOCK)
			INNER JOIN League AS l WITH(NOLOCK) ON l.LeagueId = ss.LeagueId
		WHERE ss.AutoType = @AutoType
	END
	

	
END
GO