/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_AutoRefund_MatchInfo_Sel] 
	@MatchInfo	VARCHAR(MAX)
AS
/*	Creator: 20241223@Aries
	Task: Support Auto Refund for Soccer's Early Results
	DB: DBPRO/BODB02
	
	Revisions:
		- 20241223@Aries: Support Auto Refund for Soccer's Early Results [Redmine:#214410]

	Param's Explanation:
        - @ResourceInfo = '[{"matchId":1,"childMatchType":"202","targetChildMatchType":202},{"matchId":1,"childMatchType":"0","targetChildMatchType":202},{"matchId":1,"childMatchType":"201","targetChildMatchType":202}]'
 
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @tmpMatch TABLE (MatchId INT,ParentID INT,ChildMatchType	TINYINT, TargetChildMatchType	TINYINT)
	DECLARE @tmpTargetMatch TABLE (MatchId INT,ChildMatchType	TINYINT, TargetChildMatchType	TINYINT, TargetMatchId	INT)

	INSERT INTO @tmpMatch (MatchId,ParentID,ChildMatchType,TargetChildMatchType)
	SELECT tbl.matchId
		  ,m.ParentID
		  ,tbl.childMatchType
          ,tbl.targetChildMatchType
	FROM OPENJSON(@MatchInfo) WITH (
            matchId		            INT
		   ,childMatchType		    TINYINT
		   ,targetChildMatchType	TINYINT
	) AS tbl
		INNER JOIN match AS m WITH(NOLOCK) ON m.matchId = tbl.matchId

	IF EXISTS (SELECT TOP 1 1 FROM  @tmpMatch WHERE ChildMatchType = TargetChildMatchType) -- Current Match
	BEGIN
		INSERT INTO @tmpTargetMatch(MatchId,ChildMatchType,TargetChildMatchType,TargetMatchId)
		SELECT MatchId
			  ,ChildMatchType
			  ,TargetChildMatchType
			  ,MatchId AS TargetMatchId
		FROM @tmpMatch AS tm
		WHERE tm.ChildMatchType = tm.TargetChildMatchType
	END

	IF EXISTS (SELECT TOP 1 1 FROM  @tmpMatch WHERE ChildMatchType != TargetChildMatchType AND ChildMatchType  = 0) --main to child 
	BEGIN
		INSERT INTO @tmpTargetMatch(MatchId,ChildMatchType,TargetChildMatchType,TargetMatchId)
		SELECT tm.MatchId
			  ,tm.ChildMatchType
			  ,tm.TargetChildMatchType
			  ,m.MatchId AS TargetMatchId
		FROM @tmpMatch AS tm
			INNER JOIN match AS m WITH(NOLOCK) ON m.ParentID  = tm.MatchId AND m.ChildMatchType = tm.TargetChildMatchType
		WHERE tm.ChildMatchType != tm.TargetChildMatchType
			AND tm.ChildMatchType  = 0
	END

	IF EXISTS (SELECT TOP 1 1 FROM  @tmpMatch WHERE ChildMatchType != TargetChildMatchType AND ChildMatchType  != 0) --child to child 
	BEGIN
		INSERT INTO @tmpTargetMatch(MatchId,ChildMatchType,TargetChildMatchType,TargetMatchId)
		SELECT tm.MatchId
			  ,tm.ChildMatchType
			  ,tm.TargetChildMatchType
			  ,m.MatchId AS TargetMatchId
		FROM @tmpMatch AS tm
			INNER JOIN match AS m WITH(NOLOCK) ON m.ParentID = tm.ParentID AND m.ChildMatchType = tm.TargetChildMatchType
		WHERE tm.ChildMatchType != tm.TargetChildMatchType
			AND tm.ChildMatchType  != 0
	END

	SELECT *
	FROM @tmpTargetMatch
END
GO
