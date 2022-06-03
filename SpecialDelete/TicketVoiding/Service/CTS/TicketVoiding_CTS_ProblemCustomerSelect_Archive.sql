/*<info serverAlias="DBARC-bodb_Archive" executers="bodbSPUNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_CTS_ProblemCustomerSelect_Archive]
	@Datetime		DATETIME = NULL
AS
/*	Created by: July
	Date 20220519
	Task: TVS - Send problem customer in Abnormal Bet request to CTS - Archive process [Redmine:#172634]
	DB: DBARC/bodb_Archive
	
	Revisions: 
		- 20220519@July: Create new SP [Redmine:#172634]
	
	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tmpResult (RequestId INT, ReasonID INT, CustId INT, CreatedBy INT, CreatedDate DATETIME)
	
	INSERT INTO #tmpResult(RequestId, ReasonID, CustId, CreatedBy, CreatedDate)
	SELECT DISTINCT s.RequestId
		 , s.SubIssueTypeId AS ReasonID
		 , s.CustId
		 , r.LastModifiedBy AS CreatedBy
		 , r.LastModifiedDate AS CreatedDate
	FROM dbo.TicketVoiding_RequestDetailTicket_Single_bk s WITH (NOLOCK)  
		INNER JOIN dbo.TicketVoiding_Request_bk r WITH (NOLOCK) ON r.RequestId = s.RequestId
	WHERE r.IssueTypeId = 11 AND r.LastModifiedDate >= @datetime
		AND s.CustId IS NOT NULL

	SELECT CustID, ReasonID, CreatedBy, RequestID, 11 AS IssueTypeID
	FROM #tmpResult

	DROP TABLE #tmpResult
END
GO