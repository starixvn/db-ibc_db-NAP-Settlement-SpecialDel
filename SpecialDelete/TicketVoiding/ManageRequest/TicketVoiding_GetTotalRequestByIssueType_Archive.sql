/*<info serverAlias="DBARC-bodb_Archive" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_GetTotalRequestByIssueType_Archive]
(
    @IssueTypeIds	VARCHAR(MAX)= NULL
   ,@FromDate		DATETIME = NULL
   ,@ToDate			DATETIME = NULL
)
AS
/*	Created by: 20250731@July
	Task: TVS - Separate issue types of TVS into independent pages  [Redmine:#227835]
	DB: DBARC-bodb_Archive
	
	Revisions: 
		- 20250731@July: Create new SP - Support show RequestIds count follow IssueTypeId  [Redmine:#227835]
		
	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @tmpIssueTypeId TABLE (IssueTypeId INT)
	
	INSERT INTO @tmpIssueTypeId (IssueTypeId)
	SELECT value AS IssueTypeId
	FROM STRING_SPLIT(@IssueTypeIds, ',')
	WHERE value <> ''

	SELECT IssueTypeId, COUNT(1) AS TotalRequest 
	FROM dbo.TicketVoiding_Request_bk WITH (NOLOCK)
	WHERE IssueTypeId IN (SELECT IssueTypeId FROM @tmpIssueTypeId)
		AND CreatedDate BETWEEN @FromDate AND @ToDate
	GROUP BY IssueTypeId

END

GO
