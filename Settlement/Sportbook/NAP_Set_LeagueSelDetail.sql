/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_LeagueSelDetail] 
	@leagueID 			   INT

AS
/*
    Created by: 20180802@Vicky
    Task: Info of match
    DB: DBPRO/BODB02 
    
    Revisions:            
		- 20190103@Vicky: Incorporate BetBuilder [Redmine:#106903]
		
*/
BEGIN
	SET NOCOUNT ON
    
	SELECT l.leaguename, l.AutoSetting
    FROM dbo.League l WITH (NOLOCK)
    WHERE l.leagueID = @leagueID

END
GO

