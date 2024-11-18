/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_AutoPayout_ResultStatusSel
	 @MatchId					INT
	,@SportType					SMALLINT
	,@relatedCalResources		VARCHAR(MAX)
	,@relatedSettResources		VARCHAR(MAX)
	
AS
/*
	Creator: 20241028@Aries
	Task: Direct payout for early soccer  [Redmine: #211079]
	DB: DBPRO/bodb02
	Revisions:
		- 20241028@Aries: Direct payout for early soccer [Redmine:#211079]
	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON

	DECLARE  @ResultTable				TINYINT = 0
			
	DECLARE @Resource TABLE (ResourceId	VARCHAR(20), Type VARCHAR(5) PRIMARY KEY (ResourceId))


	SELECT @ResultTable	= r.ResultTable 
	FROM dbo.SettlementResultTableSetting r (NOLOCK)
	WHERE r.Sporttype = @Sporttype

	INSERT INTO @Resource(ResourceId,Type)
	SELECT DISTINCT value, 'Cal'
	FROM STRING_SPLIT(@relatedCalResources,',')
	WHERE value != ''

	INSERT INTO @Resource(ResourceId,Type)
	SELECT DISTINCT value, 'Sett'
	FROM STRING_SPLIT(@relatedSettResources,',')
	WHERE value != ''

	IF @ResultTable = 1
	BEGIN
		SELECT r.ResourceId, rd.ResultStatusID, rd.SettlementStatusID, r.Type
		FROM   @Resource AS r
			LEFT JOIN dbo.ResultDetail AS rd WITH(NOLOCK) ON r.ResourceID = rd.ResourceID AND rd.matchid = @MatchId
	END
	ELSE IF @ResultTable = 2
	BEGIN
		SELECT r.ResourceId, rd.ResultStatusID, rd.SettlementStatusID, r.Type
		FROM   @Resource AS r
			LEFT JOIN dbo.ResultDetailOS AS rd WITH(NOLOCK) ON r.ResourceID = rd.ResourceID AND rd.matchid = @MatchId
	END
	ELSE IF @ResultTable = 3
	BEGIN
		SELECT r.ResourceId, rd.ResultStatusID, rd.SettlementStatusID, r.Type
		FROM   @Resource AS r
			LEFT JOIN dbo.ResultDetailES AS rd WITH(NOLOCK) ON r.ResourceID = rd.ResourceID AND rd.matchid = @MatchId
	END

END
GO




