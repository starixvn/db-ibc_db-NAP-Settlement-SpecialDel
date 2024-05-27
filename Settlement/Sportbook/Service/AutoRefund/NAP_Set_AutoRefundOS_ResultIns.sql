/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE NAP_Set_AutoRefundOS_ResultIns
  @MatchId		 INT	
 ,@TypeId		 TINYINT		= 1
 ,@ResourceIds	 VARCHAR(500)
 ,@RowCount		 INT = 0 OUTPUT
AS
/*
	Creator: 20220511@Louisa
	Task: Auto refund Badminton [Redmine:#171676]
	DB: DBPRO/bodb02

	Revisions:
		- 20220511@Louisa: Initial 
		- 20221213@Kathy: Upgrade Auto Payout for Badminton & Volleyball [Redmine:#181458]
		- 20230328@Aries: Auto refund tennis incorrect [Redmine: #188857]
		- 20240229@Aries: Auto Payout for e-Sports Main ＆ Early Results  [Redmine: #191875]
		- 20240527@Aries: Cannot insert duplicate key in object dbo.@Resource  [Redmine: #205620]

	Param's explaination:
		@TypeIds: 1 - Refund Single
				  10- Refund Parlay

		@ResourceID = '0103,0104,0105'
*/
BEGIN
	SET NOCOUNT ON

	IF ISNULL(@ResourceIds, '') = ''
	RETURN

	DECLARE  @Sporttype			INT
			,@ResultTable		TINYINT
	DECLARE @tmpResourceId TABLE ( ResourceId VARCHAR(20) PRIMARY KEY(ResourceId) WITH (IGNORE_DUP_KEY = ON))

	SELECT @Sporttype	= m.sportType
  	FROM dbo.match m WITH (NOLOCK)
	WHERE m.matchid = @MatchId

	SELECT @ResultTable =  ResultTable
	FROM SettlementResultTableSetting WITH (NOLOCK)
	WHERE SportType = @Sporttype

	IF @ResultTable = 1
	BEGIN
		;WITH cteResourceId 
		AS (
			SELECT CAST(f.value AS VARCHAR(20)) AS ResourceId
			FROM STRING_SPLIT(@ResourceIds, ',') f
		)
		INSERT INTO @tmpResourceId ( ResourceId )
		SELECT 	c.ResourceId
		FROM 	cteResourceId c 
		WHERE	NOT EXISTS (SELECT r.ResourceId FROM dbo.ResultDetail r WITH(NOLOCK) WHERE r.matchid = @MatchId AND r.ResultStatusID IN (2,5) AND c.ResourceID = r.ResourceId)
	END
	ELSE IF @ResultTable = 2
	BEGIN
		;WITH cteResourceId 
		AS (
			SELECT CAST(f.value AS VARCHAR(20)) AS ResourceId
			FROM STRING_SPLIT(@ResourceIds, ',') f
		)
		INSERT INTO @tmpResourceId ( ResourceId )
		SELECT 	c.ResourceId
		FROM 	cteResourceId c 
		WHERE	NOT EXISTS (SELECT r.ResourceId FROM dbo.ResultDetailOS r WITH(NOLOCK) WHERE r.matchid = @MatchId AND r.ResultStatusID IN (2,5) AND c.ResourceID = r.ResourceId)
	END
	ELSE IF @ResultTable = 3
	BEGIN
		;WITH cteResourceId 
		AS (
			SELECT CAST(f.value AS VARCHAR(20)) AS ResourceId
			FROM STRING_SPLIT(@ResourceIds, ',') f
		)
		INSERT INTO @tmpResourceId ( ResourceId )
		SELECT 	c.ResourceId
		FROM 	cteResourceId c 
		WHERE	NOT EXISTS (SELECT r.ResourceId FROM dbo.ResultDetailES r WITH(NOLOCK) WHERE r.matchid = @MatchId AND r.ResultStatusID IN (2,5) AND c.ResourceID = r.ResourceId)
	END

	MERGE dbo.AutoRefundResultOS WITH (UPDLOCK,ROWLOCK) TARGET
	USING (	SELECT ResourceId FROM @tmpResourceId	) AS SOURCE 
		ON TARGET.MatchId = @MatchId AND TARGET.ResourceId = SOURCE.ResourceId
	WHEN NOT MATCHED THEN 
	INSERT (MatchId, SourceId, TypeId, ResourceID)
	VALUES ( @MatchId, 105	, @TypeId, SOURCE.ResourceId );

	SET @RowCount = @@ROWCOUNT

END

