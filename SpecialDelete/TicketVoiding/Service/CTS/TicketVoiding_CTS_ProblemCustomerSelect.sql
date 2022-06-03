/*<info serverAlias="DBACC-bodb02" executers="bodbSPUNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_CTS_ProblemCustomerSelect]
	@Datetime				DATETIME = NULL
   ,@IsArchive				BIT = 0			OUTPUT
   ,@MaxTimeRequestActive	DATETIME = NULL OUTPUT
AS
/*	Created by: July
	Date 20220519
	Task: TVS - Send problem customer in Abnormal Bet request to CTS  [Redmine:#172634]
	DB: DBACC/bodb02
	
	Revisions: 
		- 20220519@July: Create new SP [Redmine:#172634]
	
	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @MinTimeRequestActive DATETIME = NULL
	CREATE TABLE #tmpResult (RequestId INT, ReasonID INT, CustId INT, CreatedBy INT, CreatedDate DATETIME)
	
	INSERT INTO #tmpResult(RequestId, ReasonID, CustId, CreatedBy, CreatedDate)
	SELECT DISTINCT s.RequestId
		 , s.SubIssueTypeId AS ReasonID
		 , s.CustId
		 , r.LastModifiedBy AS CreatedBy
		 , r.LastModifiedDate AS CreatedDate
	FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)  
		INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = s.RequestId
	WHERE r.IssueTypeId = 11 AND r.LastModifiedDate >= @datetime
		AND s.CustId IS NOT NULL

	SELECT CustID, ReasonID, CreatedBy, RequestID, 11 AS IssueTypeID
	FROM #tmpResult

	SELECT @MinTimeRequestActive = MIN(CreatedDate)
		  ,@MaxTimeRequestActive = MAX(CreatedDate) 
	FROM #tmpResult

	IF @MinTimeRequestActive > @Datetime
	BEGIN
		SET @IsArchive = 1
	END

	DROP TABLE #tmpResult
END

GO
