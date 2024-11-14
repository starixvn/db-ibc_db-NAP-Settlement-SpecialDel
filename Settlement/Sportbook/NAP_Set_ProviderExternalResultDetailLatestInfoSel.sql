/*<info serverAlias="DBPRO-bodb02 " executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_ProviderExternalResultDetailLatestInfoSel]
	@MatchId	INT
	,@SettleType	VARCHAR(10) = 'MNL'
AS
/*
    Created by: 20201202@Louisa
    Task: Integrate with SBO [Redmine:#146239]
    DB: DBPRO/BODB02 
    
    Revisions:            
		- 20201202@Louisa: SBO Result for 8 sports:3,4,6,8,9,18,24,25  [Redmine:#146239]
		- 20210305@Louisa: SOP for Tennis [Readmine:#150425]
		- 20210506@Louisa: SOP for Cricket [Redmine:#153915]
		- 20210524@Louisa: SOP for Badminton, Basketball [Redmine:#155360,#155361]
		- 20210819@Louisa: Show Provider Results for remain sports [Redmine:#160192]
		- 20220629@Louisa: Volleyball AIO [Redmineid:#173862]
		- 20240604@Aries: Support calculate interval child-matches for Table Tennis (SOP) [Redmine:#202100] 
		- 20240718@Kathy: Implement AiO for Baseball [Redmine:#206154]
		- 20241114@Aries: Support to add a new Live columns for Provider Tables [Redmine:#213217]

	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @SportType SMALLINT = 0
		  ,@ExternalResultTable TINYINT = 0
		  ,@IsAppliedSOP	BIT = 0

	DECLARE @tmpProviderExternalResult AS TABLE 
		(SourceId SMALLINT,SourceName VARCHAR(50) ,Remark NVARCHAR(1000), ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50), OrderNo INT)

	SELECT @SportType = m.SportType 
	FROM dbo.Match m WITH(NOLOCK)
	WHERE m.MatchID = @MatchId

	SELECT @ExternalResultTable = r.ExternalResultTable
		 , @IsAppliedSOP		= r.IsAppliedSOP
	FROM dbo.SettlementResultTableSetting r WITH(NOLOCK) 
	WHERE r.Sporttype = @SportType
	
	IF @SportType = 8
		SELECT @ExternalResultTable =2
				,@IsAppliedSOP = 1

	IF @IsAppliedSOP = 1
	BEGIN
		INSERT INTO @tmpProviderExternalResult (SourceId, SourceName, Remark, ResourceId, HomeValue, AwayValue, OrderNo)
		EXEC [dbo].[NAP_Set_ProviderExternalResultDetailOSLatestInfoSel]
			 @MatchId		= @MatchId
			,@SettleType	= @SettleType

	END

	ELSE 
	BEGIN
		;WITH  cteLatestSports AS
			(
				SELECT	ROW_NUMBER() OVER (PARTITION BY ex.ResourceId ORDER BY ex.SourceId, ex.CreateDate DESC) AS rn
						,DENSE_RANK() OVER (ORDER BY ex.SourceId ) AS TopSourceId
						,ex.SourceId
						,ex.ResourceId
						,ex.HomeValue
						,ex.AwayValue
				FROM	dbo.ProviderExternalResultDetail ex WITH(NOLOCK)
				WHERE @ExternalResultTable = 1
					AND ex.MatchID = @MatchId
					AND ex.SourceId < 1001
					AND ex.SourceId <> 100
					AND ISNULL(ex.IsLive,0) = 0

				UNION ALL
				SELECT	ROW_NUMBER() OVER (PARTITION BY ex.ResourceId ORDER BY ex.SourceId, ex.CreateDate DESC) AS rn
						,DENSE_RANK() OVER (ORDER BY ex.SourceId ) AS TopSourceId
						,ex.SourceId
						,ex.ResourceId
						,ex.HomeValue
						,ex.AwayValue
				FROM	dbo.ProviderExternalResultDetailOS ex WITH(NOLOCK)
				WHERE @ExternalResultTable = 2
					AND ex.MatchID = @MatchId
					AND ex.SourceId < 1001
					AND ex.SourceId <> 100
					AND ISNULL(ex.IsLive,0) = 0
			)
		INSERT INTO @tmpProviderExternalResult (SourceId, ResourceId, HomeValue, AwayValue)	
		SELECT	SourceId
				,ResourceId 
				,HomeValue 
				,AwayValue 
		FROM	cteLatestSports
		WHERE	rn = 1
			AND TopSourceId = 1
	END

	SELECT	r.SourceId 
			,p.SourceName
			,r.Remark
			,r.ResourceId 
			,r.HomeValue
			,r.AwayValue
			,r.OrderNo
	FROM @tmpProviderExternalResult r
	INNER JOIN dbo.ProviderInfo p WITH(NOLOCK)
			ON r.SourceId = p.SourceId
	

END