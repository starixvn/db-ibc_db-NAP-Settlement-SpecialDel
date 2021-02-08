/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MoveTicket_ReferenceActionByMatchSel] 
	  @MatchIds	 VARCHAR(MAX) 
AS

/*	
	Creator	: 20210205@Louisa
	Task	: Cricket AIO [Redmine:#148870]			
	DB		: DB052/bodb_CustomerLog
	
	Revision:	
		- 20210205@Louisa: Cricket AIO [Redmine:#148870]

	Param's Explanation:
		
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @__archiveDate DATETIME , @ActionId INT			 
	SELECT @__archiveDate = DATEADD(DAY, 1, dbo.f_CustomerLog_GetArchiveDate())

	SELECT @ActionId = 81025 -- Move Cricket ticket

	;WITH MatchTmp AS (
		SELECT CAST(val AS INT) AS MatchId
		FROM bodb02.dbo.Lrf_f_StringSplit(@MatchIds, ',')
	)

	SELECT LogId
		, MatchID
		, ActionID
		, CASE WHEN Remark LIKE 'Failed%' THEN 1 ELSE 0 END AS IsFailed
		, LogDate		
	FROM dbo.UserLog_Settle l WITH(NOLOCK)
	WHERE EXISTS (SELECT TOP 1 1 FROM MatchTmp f WHERE f.MatchId = l.MatchID)
		AND l.ActionID = @ActionId
		AND logdate >= @__archiveDate
	UNION ALL
	SELECT LogId
	, MatchID
	, ActionID
	, CASE WHEN Remark LIKE 'Failed%' THEN 1 ELSE 0 END AS IsFailed	
	, LogDate	
	FROM [bodb_CustomerLog_Archive].dbo.UserLog_Settle l WITH(NOLOCK)
	WHERE EXISTS (SELECT TOP 1 1 FROM MatchTmp f WHERE f.MatchId = l.MatchID)
		AND l.ActionID = @ActionId
		AND logdate < @__archiveDate
	ORDER BY LogId

END
GO
