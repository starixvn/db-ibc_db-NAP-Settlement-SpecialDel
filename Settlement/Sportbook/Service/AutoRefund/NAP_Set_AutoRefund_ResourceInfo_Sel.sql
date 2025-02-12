/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_AutoRefund_ResourceInfo_Sel] 
	@ResourceInfo	VARCHAR(MAX)
AS
/*	Creator: 20241223@Aries
	Task: Support Auto Refund for Soccer's Early Results
	DB: DBPRO/BODB02
	
	Revisions:
		- 20241223@Aries: Support Auto Refund for Soccer's Early Results [Redmine:#214410]

	Param's Explanation:
        - @ResourceInfo = '[{"matchId":1,"sportType":"376","sourceMatchType":2,"sourceChildMatchType":202,"sourceResource":'00'}]'
 
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @Resource TABLE (MatchId INT,ParentId INT, Sporttype SMALLINT, ResultTable TINYINT, ExternalResultTable TINYINT, sourceResource VARCHAR(20), sourceMatchType TINYINT, sourceChildMatchType	TINYINT)
	DECLARE @MacthResource TABLE (MatchId INT,ParentId INT, Sporttype SMALLINT, ResultTable TINYINT, ExternalResultTable TINYINT, sourceResource VARCHAR(20), sourceMatchType TINYINT, sourceChildMatchType	TINYINT,HomeValue VARCHAR(50),AwayValue  VARCHAR(50),CfmHomeValue VARCHAR(50),CfmAwayValue  VARCHAR(50),ResultStatusID TINYINT, SettlementStatusID TINYINT, ResultSetting TINYINT)

	INSERT INTO @Resource (MatchId,ParentId, Sporttype,ResultTable,ExternalResultTable, sourceMatchType, sourceChildMatchType,sourceResource)
	SELECT tbl.MatchId
		  ,m.ParentId
          ,tbl.sportType
		  ,st.ResultTable
		  ,st.ExternalResultTable
		  ,tbl.sourceMatchType
		  ,tbl.sourceChildMatchType
          ,tbl.sourceResource
	FROM OPENJSON(@ResourceInfo) WITH (
            matchId		            INT
		   ,sportType		        SMALLINT
		   ,sourceMatchType		    TINYINT
           ,sourceChildMatchType	TINYINT
           ,sourceResource		    VARCHAR(20)	
	) AS tbl
		INNER JOIN match  AS m WITH(NOLOCK) ON m.MatchId = tbl.MatchId
		INNER JOIN SettlementResultTableSetting  AS st WITH(NOLOCK) ON st.sporttype = tbl.sporttype
	
	IF EXISTS (SELECT TOP 1 1 FROM @Resource WHERE ResultTable = 1)
	BEGIN
		INSERT INTO @MacthResource(MatchId,ParentId, Sporttype,ResultTable,ExternalResultTable, sourceMatchType, sourceChildMatchType,sourceResource,HomeValue,AwayValue,ResultStatusID,SettlementStatusID,ResultSetting)
		SELECT	r.MatchId,r.ParentId, r.Sporttype,r.ResultTable,r.ExternalResultTable, r.sourceMatchType, r.sourceChildMatchType,r.sourceResource
			   ,rd.HomeValue,rd.AwayValue,rd.ResultStatusID,rd.SettlementStatusID,rd.ResultSetting
		FROM @Resource AS r
			INNER JOIN ResultDetail AS rd WITH(NOLOCK) ON r.MatchId = rd.MatchId AND r.sourceResource = rd.resourceId 
		WHERE r.sourceMatchType = 1 --Current
			AND r.ResultTable = 1
		
		INSERT INTO @MacthResource(MatchId,ParentId, Sporttype,ResultTable,ExternalResultTable, sourceMatchType, sourceChildMatchType,sourceResource,HomeValue,AwayValue,ResultStatusID,SettlementStatusID,ResultSetting)
		SELECT	r.MatchId,r.ParentId, r.Sporttype,r.ResultTable,r.ExternalResultTable, r.sourceMatchType, r.sourceChildMatchType,r.sourceResource
			   ,rd.HomeValue,rd.AwayValue,rd.ResultStatusID,rd.SettlementStatusID,rd.ResultSetting
		FROM @Resource AS r
			INNER JOIN ResultDetail AS rd WITH(NOLOCK) ON r.ParentId = rd.MatchId AND r.sourceResource = rd.resourceId 
		WHERE r.sourceMatchType = 2 --Parent
			AND r.ResultTable = 1
		
		INSERT INTO @MacthResource(MatchId,ParentId, Sporttype,ResultTable,ExternalResultTable, sourceMatchType, sourceChildMatchType,sourceResource,HomeValue,AwayValue,ResultStatusID,SettlementStatusID,ResultSetting)
		SELECT	r.MatchId,r.ParentId, r.Sporttype,r.ResultTable,r.ExternalResultTable, r.sourceMatchType, r.sourceChildMatchType,r.sourceResource
			   ,rd.HomeValue,rd.AwayValue,rd.ResultStatusID,rd.SettlementStatusID,rd.ResultSetting
		FROM @Resource AS r
			INNER JOIN match AS cm WITH(NOLOCK) ON cm.ParentId = r.ParentId AND  cm.ChildMatchType  = r.sourceChildMatchType 
			INNER JOIN ResultDetail AS rd WITH(NOLOCK) ON cm.MatchId = rd.MatchId AND r.sourceResource = rd.resourceId 
		WHERE r.sourceMatchType = 3 --Relate
			AND r.ResultTable = 1
	END

	IF EXISTS (SELECT TOP 1 1 FROM @Resource WHERE ResultTable = 2)
	BEGIN
		INSERT INTO @MacthResource(MatchId,ParentId, Sporttype,ResultTable,ExternalResultTable, sourceMatchType, sourceChildMatchType,sourceResource,HomeValue,AwayValue,ResultStatusID,SettlementStatusID,ResultSetting)
		SELECT	r.MatchId,r.ParentId, r.Sporttype,r.ResultTable,r.ExternalResultTable, r.sourceMatchType, r.sourceChildMatchType,r.sourceResource
			   ,rd.HomeValue,rd.AwayValue,rd.ResultStatusID,rd.SettlementStatusID,rd.ResultSetting
		FROM @Resource AS r
			INNER JOIN ResultDetailOS AS rd WITH(NOLOCK) ON r.MatchId = rd.MatchId AND r.sourceResource = rd.resourceId 
		WHERE r.sourceMatchType = 1 --Current
			AND r.ResultTable = 1
		
		INSERT INTO @MacthResource(MatchId,ParentId, Sporttype,ResultTable,ExternalResultTable, sourceMatchType, sourceChildMatchType,sourceResource,HomeValue,AwayValue,ResultStatusID,SettlementStatusID,ResultSetting)
		SELECT	r.MatchId,r.ParentId, r.Sporttype,r.ResultTable,r.ExternalResultTable, r.sourceMatchType, r.sourceChildMatchType,r.sourceResource
			   ,rd.HomeValue,rd.AwayValue,rd.ResultStatusID,rd.SettlementStatusID,rd.ResultSetting
		FROM @Resource AS r
			INNER JOIN ResultDetailOS AS rd WITH(NOLOCK) ON r.ParentId = rd.MatchId AND r.sourceResource = rd.resourceId 
		WHERE r.sourceMatchType = 2 --Parent
			AND r.ResultTable = 1
		
		INSERT INTO @MacthResource(MatchId,ParentId, Sporttype,ResultTable,ExternalResultTable, sourceMatchType, sourceChildMatchType,sourceResource,HomeValue,AwayValue,ResultStatusID,SettlementStatusID,ResultSetting)
		SELECT	r.MatchId,r.ParentId, r.Sporttype,r.ResultTable, r.ExternalResultTable,r.sourceMatchType, r.sourceChildMatchType,r.sourceResource
			   ,rd.HomeValue,rd.AwayValue,rd.ResultStatusID,rd.SettlementStatusID,rd.ResultSetting
		FROM @Resource AS r
			INNER JOIN match AS cm WITH(NOLOCK) ON cm.ParentId = r.ParentId AND  cm.ChildMatchType  = r.sourceChildMatchType 
			INNER JOIN ResultDetailOS AS rd WITH(NOLOCK) ON cm.MatchId = rd.MatchId AND r.sourceResource = rd.resourceId 
		WHERE r.sourceMatchType = 3 --Relate
			AND r.ResultTable = 1
	END

	IF EXISTS (SELECT TOP 1 1 FROM @Resource WHERE ResultTable = 3)
	BEGIN
		INSERT INTO @MacthResource(MatchId,ParentId, Sporttype,ResultTable,ExternalResultTable, sourceMatchType, sourceChildMatchType,sourceResource,HomeValue,AwayValue,ResultStatusID,SettlementStatusID,ResultSetting)
		SELECT	r.MatchId,r.ParentId, r.Sporttype,r.ResultTable,r.ExternalResultTable, r.sourceMatchType, r.sourceChildMatchType,r.sourceResource
			   ,rd.HomeValue,rd.AwayValue,rd.ResultStatusID,rd.SettlementStatusID,rd.ResultSetting
		FROM @Resource AS r
			INNER JOIN ResultDetailES AS rd WITH(NOLOCK) ON r.MatchId = rd.MatchId AND r.sourceResource = rd.resourceId 
		WHERE r.sourceMatchType = 1 --Current
			AND r.ResultTable = 1
		
		INSERT INTO @MacthResource(MatchId,ParentId, Sporttype,ResultTable,ExternalResultTable, sourceMatchType, sourceChildMatchType,sourceResource,HomeValue,AwayValue,ResultStatusID,SettlementStatusID,ResultSetting)
		SELECT	r.MatchId,r.ParentId, r.Sporttype,r.ResultTable,r.ExternalResultTable, r.sourceMatchType, r.sourceChildMatchType,r.sourceResource
			   ,rd.HomeValue,rd.AwayValue,rd.ResultStatusID,rd.SettlementStatusID,rd.ResultSetting
		FROM @Resource AS r
			INNER JOIN ResultDetailES AS rd WITH(NOLOCK) ON r.ParentId = rd.MatchId AND r.sourceResource = rd.resourceId 
		WHERE r.sourceMatchType = 2 --Parent
			AND r.ResultTable = 1
		
		INSERT INTO @MacthResource(MatchId,ParentId, Sporttype,ResultTable,ExternalResultTable, sourceMatchType, sourceChildMatchType,sourceResource,HomeValue,AwayValue,ResultStatusID,SettlementStatusID,ResultSetting)
		SELECT	r.MatchId,r.ParentId, r.Sporttype,r.ResultTable, r.ExternalResultTable,r.sourceMatchType, r.sourceChildMatchType,r.sourceResource
			   ,rd.HomeValue,rd.AwayValue,rd.ResultStatusID,rd.SettlementStatusID,rd.ResultSetting
		FROM @Resource AS r
			INNER JOIN match AS cm WITH(NOLOCK) ON cm.ParentId = r.ParentId AND  cm.ChildMatchType  = r.sourceChildMatchType 
			INNER JOIN ResultDetailES AS rd WITH(NOLOCK) ON cm.MatchId = rd.MatchId AND r.sourceResource = rd.resourceId 
		WHERE r.sourceMatchType = 3 --Relate
			AND r.ResultTable = 1
	END

	IF EXISTS (SELECT TOP 1 1 FROM @MacthResource WHERE ExternalResultTable = 1 AND ResultSetting & 6 > 0)
	BEGIN
		UPDATE mr
		SET  mr.CfmHomeValue = p.HomeValue
			,mr.CfmAwayValue = p.AwayValue
		FROM @MacthResource AS mr
		INNER JOIN ProviderExternalResultDetail AS p ON p.MatchId = mr.MatchId AND p.ResourceId = mr.sourceResource AND p.SourceId = 99
		WHERE mr.ExternalResultTable = 1 
			AND mr.ResultSetting & 6 > 0
	END

	IF EXISTS (SELECT TOP 1 1 FROM @MacthResource WHERE ExternalResultTable = 2 AND ResultSetting & 6 > 0)
	BEGIN
		UPDATE mr
		SET  mr.CfmHomeValue = p.HomeValue
			,mr.CfmAwayValue = p.AwayValue
		FROM @MacthResource AS mr
		INNER JOIN ProviderExternalResultDetailOS AS p ON p.MatchId = mr.MatchId AND p.ResourceId = mr.sourceResource AND p.SourceId = 99
		WHERE mr.ExternalResultTable = 1 
			AND mr.ResultSetting & 6 > 0
	END

	SELECT * 
	FROM @MacthResource
END
GO
