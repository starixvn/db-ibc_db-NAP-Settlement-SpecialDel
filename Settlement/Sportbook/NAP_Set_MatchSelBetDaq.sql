/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_MatchSelBetDaq
	@matchid INT
AS
/*	
	Creator: Louisa
	Date: 20210930
	Task: Move ticket
	DB: DBPRO/bodb02
     
	 Revisions:    
		- 20210930@Louisa: Get old event [Redmine:#159271]
		   
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @NewMatchCode  NVARCHAR(100)
		 , @leagueId INT
		 , @sporttype SMALLINT

	SELECT @NewMatchCode = 'betdaq' + matchcode, @leagueId = m.leagueid
	FROM	dbo.match m WITH (NOLOCK)
	WHERE m.matchid = @matchid
		AND m.sporttype = 43

	SELECT m.matchid, m.matchcode
	FROM dbo.match m WITH (NOLOCK)
	WHERE m.sporttype = 43
		AND m.leagueid = @leagueId
		AND m.matchcode = @NewMatchCode
		AND ISNULL(m.IsDeleted,0) = 0

END
GO