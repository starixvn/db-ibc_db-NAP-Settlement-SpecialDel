/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_AutoRefund_ResourceStatusInfo_Sel] 
	@ResourceInfo	VARCHAR(MAX)
AS
/*	Creator: 20241223@Aries
	Task: Support Auto Refund for Soccer's Early Results
	DB: DBPRO/BODB02
	
	Revisions:
		- 20241223@Aries: Support Auto Refund for Soccer's Early Results [Redmine:#214410]

	Param's Explanation:
        - @ResourceInfo = '[{"matchId":1,"sportType":"376","resourceId":'00'}]'
 
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @Resource TABLE (MatchId INT, Sporttype SMALLINT, ResultTable TINYINT,  ResourceID VARCHAR(20))
	DECLARE @MacthResource TABLE (MatchId INT,Sporttype SMALLINT, ResultTable TINYINT,  ResourceID VARCHAR(20), ResultStatusID TINYINT, SettlementStatusID TINYINT, ResultSetting TINYINT)

	INSERT INTO @Resource (MatchId, Sporttype,ResourceID,ResultTable)
	SELECT tbl.MatchId
          ,tbl.sportType
		  ,tbl.ResourceID
		  ,st.ResultTable
	FROM OPENJSON(@ResourceInfo) WITH (
            matchId		            INT
		   ,sportType		        SMALLINT
		   ,resourceId				VARCHAR(20)	
	) AS tbl
		INNER JOIN SettlementResultTableSetting  AS st WITH(NOLOCK) ON st.sporttype = tbl.sporttype
	
	IF EXISTS (SELECT TOP 1 1 FROM @Resource WHERE ResultTable = 1)
	BEGIN
		INSERT INTO @MacthResource(MatchId, Sporttype,ResultTable,ResourceID,ResultStatusID,SettlementStatusID,ResultSetting)
		SELECT	r.MatchId, r.Sporttype,r.ResultTable,r.ResourceID,rd.ResultStatusID,rd.SettlementStatusID,rd.ResultSetting
		FROM @Resource AS r
			INNER JOIN ResultDetail AS rd WITH(NOLOCK) ON r.MatchId = rd.MatchId AND r.resourceId = rd.resourceId 
		WHERE  r.ResultTable = 1
	END

	IF EXISTS (SELECT TOP 1 1 FROM @Resource WHERE ResultTable = 2)
	BEGIN
		INSERT INTO @MacthResource(MatchId, Sporttype,ResultTable,ResourceID,ResultStatusID,SettlementStatusID,ResultSetting)
		SELECT	r.MatchId, r.Sporttype,r.ResultTable,r.ResourceID,rd.ResultStatusID,rd.SettlementStatusID,rd.ResultSetting
		FROM @Resource AS r
			INNER JOIN ResultDetailOS AS rd WITH(NOLOCK) ON r.MatchId = rd.MatchId AND r.resourceId = rd.resourceId 
		WHERE  r.ResultTable = 2
	END

	IF EXISTS (SELECT TOP 1 1 FROM @Resource WHERE ResultTable = 3)
	BEGIN
		INSERT INTO @MacthResource(MatchId, Sporttype,ResultTable,ResourceID,ResultStatusID,SettlementStatusID,ResultSetting)
		SELECT	r.MatchId, r.Sporttype,r.ResultTable,r.ResourceID,rd.ResultStatusID,rd.SettlementStatusID,rd.ResultSetting
		FROM @Resource AS r
			INNER JOIN ResultDetailES AS rd WITH(NOLOCK) ON r.MatchId = rd.MatchId AND r.resourceId = rd.resourceId 
		WHERE  r.ResultTable = 3
	END

	SELECT * 
	FROM @MacthResource
END
GO
