/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE NAP_Set_AutoRefundOS_ResultIns
  @MatchId		 INT	
 ,@TypeId		 TINYINT		= 1
 ,@ResourceIds	 VARCHAR(500)
AS
/*
	Creator: 20220511@Louisa
	Task: Auto refund Badminton [Redmine:#171676]
	DB: DBPRO/bodb02

	Revisions:
		- 20220511@Louisa: Initial 

	Param's explaination:
		@TypeIds: 1 - Refund Single
				  10- Refund Parlay

		@ResourceID = '0103,0104,0105'
*/
BEGIN
	SET NOCOUNT ON

	IF ISNULL(@ResourceIds, '') = ''
	RETURN

	DECLARE @tmpResourceId TABLE ( ResourceId VARCHAR(20)	)

	INSERT INTO @tmpResourceId ( ResourceId )
	SELECT f.value FROM STRING_SPLIT(@ResourceIds, ',') f

	MERGE dbo.AutoRefundResultOS WITH (UPDLOCK,ROWLOCK) TARGET
	USING (	SELECT ResourceId FROM @tmpResourceId	) AS SOURCE 
		ON TARGET.MatchId = @MatchId AND TARGET.ResourceId = SOURCE.ResourceId
	WHEN NOT MATCHED THEN 
	INSERT (MatchId, SourceId, TypeId, ResourceID)
	VALUES ( @MatchId, 105	, @TypeId, SOURCE.ResourceId );

END

