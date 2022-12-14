/*<info serverAlias="DBCTG-bodb02,SBSETTLE-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_SiteDB_SettlementProcessingDetailSel
	@SessionId	BIGINT
	,@SiteDBGroupId	SMALLINT
AS
/*
	Created by: 20221122@Louisa
	Task: Tool support after release Scaleout [RedmineId:#180746]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20221122@Louisa: Tool support after release Scaleout [RedmineId:#180746]

	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @checktime DATETIME2

	DECLARE @tmpSSB_SettlementLogs TABLE (MatchId INT, SessionId BIGINT, ErrorMessage VARCHAR(200), CreatedTime DATETIME2, SiteDBGroupId SMALLINT )

	SELECT	  p.Id
			,ISNULL(  (LEN(t.TransIds) - LEN(REPLACE(t.TransIds,',','')) + 1 ) ,0) AS TicketCount
			,p.TicketType
			,p.SettlementAction
			,p.StatusId
			,t.TransIds
	FROM dbo.SiteDB_SettlementProcessing p WITH(NOLOCK)
		CROSS APPLY (
				SELECT	p.StatusId, p.SettlementAction, p.TicketType
						, STUFF (
							( SELECT  ',' + t   
							  FROM OPENJSON (CAST(DECOMPRESS(TransInfo) AS NVARCHAR(MAX) ) ) WITH( t  VARCHAR(20) ) 
							  FOR XML PATH('') 
							)  
							, 1, 1, '' 
						)  AS TransIds
			) t
	
	WHERE	p.SessionId = @SessionId
		AND p.SiteDBGroupId = @SiteDBGroupId
		AND p.StatusId  IN (1,3)
END
GO

--select *   FROM dbo.SiteDB_SettlementProcessing 