/*<info serverAlias="DBCTG-bodb02,SBSETTLE-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_SiteDB_SettlementProcessingDetailSel
	@SessionId	BIGINT
	,@SiteDBGroupId	SMALLINT
	,@Mode VARCHAR(20) = 'single'
AS
/*
	Created by: 20221122@Louisa
	Task: Tool support after release Scaleout [RedmineId:#180746]
	DB: DBCTG-bodb02,SBSETTLE-bodb02
	
	Revisions:
		- 20221122@Louisa: Tool support after release Scaleout [RedmineId:#180746]
		- 20230208@Louisa: support queue 3rd [RedmineId:#179505]
		- 20240514@Kathy: parlay settlement [RedmineId:#204985]

	Param's Explanation:
		@Mode = 'single', 'parlay'

*/
BEGIN
	SET NOCOUNT ON
	
	IF @Mode = 'single'
		SELECT	 p.Id
				,ISNULL(  (LEN(t.TransIds) - LEN(REPLACE(t.TransIds,',','')) + 1 ) ,0) AS TicketCount
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
	ELSE IF @Mode = 'parlay'
		SELECT t.Id
			,ISNULL(  (LEN(t.TransIds) - LEN(REPLACE(t.TransIds,',','')) + 1 ) ,0) AS TicketCount
			, t.TransIds
		FROM (
		SELECT	 p.Id
				--,ISNULL(  (LEN(t.TransIds) - LEN(REPLACE(t.TransIds,',','')) + 1 ) ,0) AS TicketCount
				,COALESCE(bm.BettransmTransIds, re.BetParlayResult, b.BettransTransIds) AS TransIds
		FROM dbo.SiteDB_ParlaySettlementProcessing p WITH(NOLOCK)
			OUTER APPLY (
					SELECT	p.StatusId
							, STUFF (
								( SELECT  ',' + t   
								  FROM OPENJSON (CAST(DECOMPRESS(TransInfoBettransM) AS NVARCHAR(MAX) ) ) WITH( t  VARCHAR(20) ) 
								  FOR XML PATH('') 
								)  
								, 1, 1, '' 
							)  AS BettransmTransIds
					WHERE p.StatusId IN (1,3)
				) bm
			OUTER APPLY (
					SELECT	p.StatusId
							,( SELECT  strTransIds
								  FROM OPENJSON (CAST(DECOMPRESS(TransInfoBetParlayResult) AS NVARCHAR(MAX) ) ) WITH( strTransIds  VARCHAR(max) ) 
								)  AS BetParlayResult
					WHERE p.StatusId IN (11,13)
				) re
			OUTER APPLY (
					SELECT	p.StatusId
							, STUFF (
								( SELECT  ',' + t   
								  FROM OPENJSON (CAST(DECOMPRESS(TransInfoBettrans) AS NVARCHAR(MAX) ) ) WITH( t  VARCHAR(20) ) 
								  FOR XML PATH('') 
								)  
								, 1, 1, '' 
							)  AS BettransTransIds
					WHERE p.StatusId IN (21,23)
				) b
		WHERE	p.SessionId = @SessionId
			AND p.SiteDBGroupId = @SiteDBGroupId
			AND p.StatusId  IN (1,3, 11,13, 21,23)
		) t
END
GO
