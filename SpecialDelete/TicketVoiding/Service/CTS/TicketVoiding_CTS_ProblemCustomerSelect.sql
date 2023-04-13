/*<info serverAlias="DBTP-bodb02" executers="bodbSPUNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_CTS_ProblemCustomerSelect]
	@Datetime				DATETIME = NULL
   ,@IsArchive				BIT = 0			OUTPUT
   ,@MaxTimeRequestActive	DATETIME = NULL OUTPUT
AS
/*	Created by: July
	Date 20220606
	Task: TVS - Send problem customer in Abnormal Bet request to CTS  [Redmine:#172634]
	DB: DBTP/bodb02
	
	Revisions: 
		- 20220606@July: Create new SP [Redmine:#172634]
		- 20220614@July: Remove '=' support CTS [Redmine:#172634]

	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @MinTimeRequestActive DATETIME = NULL

	SELECT @MinTimeRequestActive = MIN(LastModifiedDate) FROM dbo.TicketVoiding_Request WITH (NOLOCK) WHERE IssueTypeId = 11

	CREATE TABLE #tmpResult (RequestId INT, ReasonID INT, CustId INT, CreatedBy INT, CreatedDate DATETIME)
	
	-- Get TVS - add/edit request
	INSERT INTO #tmpResult(RequestId, ReasonID, CustId, CreatedBy, CreatedDate)
	SELECT DISTINCT s.RequestId
		 , s.SubIssueTypeId AS ReasonID
		 , s.CustId
		 , r.LastModifiedBy AS CreatedBy
		 , r.LastModifiedDate AS CreatedDate
	FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)  
		INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = s.RequestId
	WHERE r.IssueTypeId = 11 AND r.LastModifiedDate > @Datetime
		AND s.CustId IS NOT NULL

	-- Get Function - Void by betid
	INSERT INTO #tmpResult(RequestId, ReasonID, CustId, CreatedBy, CreatedDate)
	SELECT NULL AS RequestId
		 , tv.SubIssueTypeId AS ReasonID
		 , tv.CustID
		 , 10278938 AS CreatedBy 
		 , MAX(tv.CreatedDate) AS CreatedDate
	FROM dbo.Ticketvoiding_VoidedTransaction tv WITH (NOLOCK)  
		OUTER APPLY (
						SELECT TOP(1) vh.RequestId
						FROM dbo.TicketVoiding_VoidingHistory vh WITH (NOLOCK) 
						WHERE vh.MessageId = tv.MessageId
					)r
	WHERE tv.IssueTypeId = 11 AND tv.CreatedDate > @Datetime AND r.RequestId IS NULL 
	GROUP BY tv.SubIssueTypeId, tv.CustID

	SELECT CustID, ReasonID, CreatedBy, RequestID, 11 AS IssueTypeID
	FROM #tmpResult

	SELECT @MaxTimeRequestActive = MAX(CreatedDate) 
	FROM #tmpResult

	IF @Datetime < @MinTimeRequestActive
	BEGIN
		SET @IsArchive = 1
	END

	DROP TABLE #tmpResult
END

GO
