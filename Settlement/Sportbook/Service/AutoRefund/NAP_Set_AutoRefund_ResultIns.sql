/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE NAP_Set_AutoRefund_ResultIns
  @ParentId		 INT	 = 0
 ,@TypeId		 TINYINT = 1	  		
 ,@ChildMatchIds VARCHAR(500) = NULL
AS
/*
	Creator: 20201229@Louisa
	Task: Auto refund ET & PEN match [Redmine:#145597]
	DB: DBPRO/bodb02

	Revisions:
		- 20201216@Louisa: Insert ET & PEN match [Redmine:#145597]
		- 20211108@Louisa: In-house Replicator: Deleted Action [Redmine:#164393] 

	Param's explaination:
		@TypeIds: 1 - Refund Single
				  10- Refund Parlay 
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @SourceId  TINYINT
	SET @SourceId = 105

	IF @TypeId = 1
	BEGIN
		INSERT INTO dbo.AutoRefundResult (MatchId, SourceId, TypeId)
		SELECT
			 m.MatchId
			, @SourceId
			, @TypeId
		FROM dbo.match m WITH(NOLOCK)
		WHERE m.ChildMatchType IN (201,202,203)
			AND m.ParentID = @ParentId
			AND ( ISNULL(@ChildMatchIds,'') = '' OR m.matchid IN (SELECT val FROM f_SplitString(@ChildMatchIds, ',') ))
			AND NOT EXISTS (	SELECT TOP 1 1 FROM dbo.AutoRefundResult ar WITH(NOLOCK)
								WHERE ar.MatchId = m.matchid AND ar.SourceId = 105 AND ar.TypeId =  @TypeId
							)
			AND ISNULL(m.IsDeleted,0) = 0
		OPTION (maxrecursion 0)
	END

	ELSE IF @TypeId = 10
	BEGIN
		INSERT INTO dbo.AutoRefundResult (MatchId, SourceId, TypeId)
		SELECT	CAST(@ChildMatchIds AS INT)	, @SourceId	, @TypeId
	END
END

