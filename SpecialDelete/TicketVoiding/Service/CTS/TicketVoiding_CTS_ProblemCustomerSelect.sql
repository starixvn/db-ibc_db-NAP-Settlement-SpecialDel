/*<info serverAlias="DBTP-bodb02" executers="bodbSPUNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_CTS_ProblemCustomerSelect]
	@Datetime				DATETIME = NULL
   ,@IsArchive				BIT = 0			OUTPUT
   ,@MaxTimeRequestActive	DATETIME = NULL OUTPUT
AS
/*	Created by: 20220606@July
	Task: TVS - Send problem customer in Abnormal Bet request to CTS  [Redmine:#172634]
	DB: DBTP/bodb02
	
	Revisions: 
		- 20220606@July: Create new SP [Redmine:#172634]
		- 20220614@July: Remove '=' support CTS [Redmine:#172634]
		- 20220330@July: [TVS] Send problem customer in Abnormal Account request to CTS [Redmine:#185238]

	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @MinTimeRequestActive DATETIME = NULL

	SELECT @MinTimeRequestActive = MIN(LastModifiedDate) FROM dbo.TicketVoiding_Request WITH (NOLOCK) WHERE IssueTypeId = 11

	CREATE TABLE #tmpResult (RequestId INT, ReasonID INT, CustId INT, CreatedBy INT, CreatedDate DATETIME, IsParlay BIT, Sporttype SMALLINT, IssueTypeId TINYINT)
	
	-- Get TVS - add/edit request
	INSERT INTO #tmpResult(RequestId, ReasonID, CustId, CreatedBy, CreatedDate, IsParlay, Sporttype, IssueTypeId)
	SELECT DISTINCT s.RequestId
		 , s.SubIssueTypeId AS ReasonID
		 , s.CustId
		 , r.LastModifiedBy AS CreatedBy
		 , r.LastModifiedDate AS CreatedDate
		 , CASE WHEN r.IssueTypeId = 11 AND s.MatchId = 29 THEN 1 ELSE NULL END AS IsParlay
		 , CASE WHEN r.IssueTypeId = 11 THEN r.Sporttype ELSE NULL END AS Sporttype
		 , r.IssueTypeId
	FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)  
		INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = s.RequestId
	WHERE r.IssueTypeId IN (11,13) AND r.LastModifiedDate > @Datetime
		AND s.CustId IS NOT NULL

	-- Get Function - Void by betid
	INSERT INTO #tmpResult(RequestId, ReasonID, CustId, CreatedBy, CreatedDate, IsParlay, Sporttype, IssueTypeId)
	SELECT NULL AS RequestId
		 , tv.SubIssueTypeId AS ReasonID
		 , tv.CustID
		 , 10278938 AS CreatedBy 
		 , MAX(tv.CreatedDate) AS CreatedDate
		 , NULL AS IsParlay
		 , m.sporttype
		 , 11 AS IssueTypeId
	FROM dbo.Ticketvoiding_VoidedTransaction tv WITH (NOLOCK)  
		OUTER APPLY (
					SELECT TOP(1) vh.RequestId
					FROM dbo.TicketVoiding_VoidingHistory vh WITH (NOLOCK) 
					WHERE vh.MessageId = tv.MessageId
			)r
		CROSS APPLY (
					SELECT	 m.sporttype
					FROM	dbo.match m WITH(NOLOCK)
					WHERE	m.matchid = tv.MatchId
					UNION
					SELECT	 m14.sporttype
					FROM	dbo.match14 m14 WITH(NOLOCK)
					WHERE	m14.matchid = tv.matchid
			)m
	WHERE tv.IssueTypeId = 11 AND tv.CreatedDate > @Datetime AND r.RequestId IS NULL 
	GROUP BY tv.SubIssueTypeId, tv.CustID, m.sporttype

	SELECT CustID, ReasonID, CreatedBy, RequestID, IsParlay, Sporttype, IssueTypeId
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
