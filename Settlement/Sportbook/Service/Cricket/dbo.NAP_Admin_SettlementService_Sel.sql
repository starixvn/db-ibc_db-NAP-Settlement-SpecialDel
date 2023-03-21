/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_SettlementService_Sel] 
AS
/*  
	Creator: Kathy
    Date: 20160106
    Task: Service - Integrate Cricket into Settlement [Redmine:#49727]
    DB: DBTXN/BODB02

    Revisions:    
		- 20220719@Louisa: get LeagueId [Redmine:#175251]
		- 20230314@Kathy: always return @Session regardless of having match info [Redmine:#184132]
        
    Param's Explanation:
	 
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @session NVARCHAR(50)
				
	SELECT	TOP 1 @session = [Session]
	FROM	dbo.SettlementServicesLogDetail WITH (NOLOCK)
	WHERE	ServiceStatus = 0
	ORDER BY Id
	
	SELECT	@session AS [Session]
			,l.MatchId
			,m.leagueid
			,l.[Action]
			,l.TransId
	FROM	dbo.SettlementServicesLogDetail l WITH (NOLOCK)
		LEFT JOIN dbo.Match m WITH(NOLOCK) on l.MatchId = m.matchid
	WHERE	[Session] = @session
	
END
GO