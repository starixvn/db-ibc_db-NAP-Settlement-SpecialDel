/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_GetTotalRequestByIssueType]
(
    @IssueTypeIds			VARCHAR(MAX) = NULL
   ,@FromDate				DATETIME = NULL
   ,@ToDate					DATETIME = NULL
   ,@IsScanArchiveRange		BIT = 0	OUTPUT
)
AS
/*	Created by: 20250731@July
	Task: TVS - Separate issue types of TVS into independent pages  [Redmine:#227835]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20250731@July: Create new SP - Support show RequestIds count follow IssueTypeId  [Redmine:#227835]
		
	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @MinTimeRequestActive DATETIME = NULL

	SELECT @MinTimeRequestActive = MIN(CreatedDate) FROM dbo.TicketVoiding_Request WITH (NOLOCK)
	
	DECLARE @tmpIssueTypeId TABLE (IssueTypeId INT)
	
	INSERT INTO @tmpIssueTypeId (IssueTypeId)
	SELECT value AS IssueTypeId
	FROM STRING_SPLIT(@IssueTypeIds, ',')
	WHERE value <> ''

	SELECT IssueTypeId, COUNT(1) AS TotalRequest 
	FROM dbo.TicketVoiding_Request WITH (NOLOCK)
	WHERE IssueTypeId IN (SELECT IssueTypeId FROM @tmpIssueTypeId)
		AND CreatedDate BETWEEN @FromDate AND @ToDate
	GROUP BY IssueTypeId

	IF @FromDate < @MinTimeRequestActive
	BEGIN
		SET @IsScanArchiveRange = 1
	END

END

GO
