/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_MatchSel_BingoBall
	@matchIds	VARCHAR(MAX)
AS
/*
	Created by: Vicky
	Date: 20181016
	Task: Incorporate Happy 5
	DB: DBPRO.BODB02
	
	Revisions:
		- 20181016@Vicky: Incorporate Happy 5  [Redmine:#102844]
		
		
	Param's Explanation:	
		@matchidList: '27175708, 27175707'
				
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @tblMatch TABLE (matchid INT)
	
	INSERT INTO @tblMatch(matchid)
	SELECT Val 
	FROM dbo.f_SplitString(@matchIds, ',')
	OPTION (maxrecursion 0)
			
	SELECT	b.matchid
			,b.Seq
			,b.Number
	FROM	dbo.[BingoBall] b WITH (NOLOCK)
		INNER JOIN @tblMatch m ON m.matchid = b.matchid
	ORDER BY b.Seq
	
END
GO