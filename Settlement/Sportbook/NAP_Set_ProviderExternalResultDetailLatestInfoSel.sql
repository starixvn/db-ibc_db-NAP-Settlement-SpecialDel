/*<info serverAlias="DBPRO-bodb02 " executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
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

	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @SportType SMALLINT = 0

	SELECT @SportType = m.SportType FROM dbo.Match m WITH(NOLOCK) WHERE m.MatchID = @MatchId
	DECLARE @tmpProviderExternalResult AS TABLE (SourceId SMALLINT,SourceName VARCHAR(50) ,Remark NVARCHAR(1000), ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50), OrderNo INT)

	IF @SportType IN ( 2, 5, 9, 50 ) ---Applied SOP
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
				WHERE ex.MatchID = @MatchId
					AND ex.SourceId < 1001
					AND ex.SourceId <> 100
					AND @SportType IN (1,3,4,6,8,18,19,24,25)

				UNION ALL
				SELECT	ROW_NUMBER() OVER (PARTITION BY ex.ResourceId ORDER BY ex.SourceId, ex.CreateDate DESC) AS rn
						,DENSE_RANK() OVER (ORDER BY ex.SourceId ) AS TopSourceId
						,ex.SourceId
						,ex.ResourceId
						,ex.HomeValue
						,ex.AwayValue
				FROM	dbo.ProviderExternalResultDetailOS ex WITH(NOLOCK)
				WHERE ex.MatchID = @MatchId
					AND ex.SourceId < 1001
					AND ex.SourceId <> 100
					AND @SportType NOT IN (1,3,4,6,8,18,19,24,25)
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