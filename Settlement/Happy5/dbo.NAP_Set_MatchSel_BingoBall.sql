/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
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
		- 20211108@Louisa: In-house Replicator: Deleted Action [Redmine:#164393]
		- 20220509@Kathy: Change to use STRING_SPLIT [Redmine:#172461]
		
	Param's Explanation:	
		@matchidList: '27175708, 27175707'
				
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @tblMatch TABLE (matchid INT)
	
	INSERT INTO @tblMatch(matchid)
	SELECT value 
	FROM STRING_SPLIT(@matchIds, ',')
			
	SELECT	b.matchid
			,b.Seq
			,b.Number
	FROM	dbo.[BingoBall] b WITH (NOLOCK)
		INNER JOIN @tblMatch m ON m.matchid = b.matchid
	WHERE ISNULL(b.IsDeleted,0) = 0
	ORDER BY b.Seq
	
END
GO