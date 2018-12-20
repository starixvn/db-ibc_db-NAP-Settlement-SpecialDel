/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_MatchSelDetail_s164
	@MatchId		INT
AS
/*
	Created by: Vicky
	Date: 20181016
	Task: Incorporate Happy 5
	DB: DBPRO.BODB02
	
	Revisions:
		- 20181016@Vicky: Incorporate Happy 5  [Redmine:#102844]
		
	Param's Explanation:
				
*/
BEGIN
	SET NOCOUNT ON
	
	SELECT	m.matchid
			,m.leagueid
			,m.kickofftime
			,m.matchcode
	FROM	dbo.[match] m WITH (NOLOCK)
	WHERE	m.Matchid = @MatchId
END

GO