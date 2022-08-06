/*<info serverAlias="DBACC-bodb02" executers="bodbSPUNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_CTS_ProblemAccountSelect]
	@CustIds	VARCHAR(MAX) = ''
	,@datetime DATETIME = NULL
AS
/*	Created by: Helen
	Date 20200713
	Task: [CTS] Customer Category - Auto tag Problem Customer [Redmine:#136460]
	DB: DBACC/bodb02
	
	Revisions: 
		- 20200713@Helen: Create new SP [Redmine:#136460]
		- 20200921@July: CTS - Cannot categorize for new PA member [Redmine:#142051]
		- 20200903@Max: Enhance Problem Account Category - Multiple Reason - [Redmine: #140211]
		- 20201215@Max: CTS - Missing Category/Class [Redmine: #146822]
		- 20211124@Max: [CTS] Update Category when PA updated [Redmine: #156935]
		- 20220422@Max: CTS Support creator Problem Account [Redmine: #171686]
		- 20220808@July: Change function to STRING_SPLIT [Redmine: #175412]
		
	Param's explanation:
		+ @CustIds = 0: the first run then get all data
		+ @CustIds IS NULL OR '': get all changed data from @datetime
		+ @CustIds IS NOT NULL AND <> '0': get the latest info for inputted customers, latest reason
*/
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #tmpResult (CustId INT, ReasonID TINYINT, CreatedDate DATETIME, Creator INT)
	
	IF @CustIds = '0'
	BEGIN
		INSERT INTO #tmpResult (CustId, ReasonID, CreatedDate, Creator)
		SELECT pa.custid, ISNULL(pa.reasonID, upline.ReasonId), ISNULL(pa.CreatedDate, upline.CreatedDate), ISNULL(pa.Creator, upline.Creator)
		FROM ProblemAccount pa WITH (NOLOCK)
			INNER JOIN customer c (NOLOCK) ON c.custid = pa.CustId
			OUTER APPLY (
						SELECT TOP 1 pma.ReasonId, pma.CreatedDate, pma.Creator
						FROM dbo.ProblemAccount pma WITH (NOLOCK) 
							INNER JOIN customer sma WITH (NOLOCK) ON sma.custid = pma.CustId
						WHERE pma.CustId IN (c.srecommend, c.mrecommend, c.recommend)
							AND pma.ReasonId IS NOT NULL
						ORDER BY CreatedDate DESC, sma.roleid ASC
				) AS upline
		WHERE ISNULL(pa.reasonID, upline.ReasonId) IS NOT NULL

		UNION ALL
		SELECT pa.custid, tmp.reasonID, tmp.CreatedDate, ISNULL(r.UserId, 10278938) AS Creator
		FROM ProblemAccount pa WITH (NOLOCK)
			CROSS APPLY (
						SELECT tv.SubIssueTypeId AS reasonID, MAX(tv.CreatedDate) AS CreatedDate, MIN(MessageId) AS MessageId
						FROM Ticketvoiding_VoidedTransaction tv WITH (NOLOCK) 
						WHERE tv.custid = pa.custid AND tv.IssueTypeId = 11
						GROUP BY tv.SubIssueTypeID
					) AS tmp
			OUTER APPLY (
						SELECT TOP(1) r.UserId
						FROM dbo.TicketVoiding_VoidingHistory vh WITH (NOLOCK) 
							INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = vh.RequestId
						WHERE vh.MessageId = tmp.MessageId
						ORDER BY r.RequestId
					)r
		WHERE tmp.reasonID IS NOT NULL
	END
	ELSE IF ISNULL(@CustIds,'') = '' AND @datetime IS NOT NULL
	BEGIN
		INSERT INTO #tmpResult (CustId, ReasonID, CreatedDate, Creator)
		SELECT pa.custid, ISNULL(pa.reasonID, upline.ReasonId), ISNULL(pa.CreatedDate, upline.CreatedDate), ISNULL(pa.Creator, upline.Creator)
		FROM ProblemAccount pa WITH (NOLOCK)
			INNER JOIN customer c (NOLOCK) ON c.custid = pa.CustId
			OUTER APPLY (
						SELECT TOP 1 pma.ReasonId, pma.CreatedDate, pma.Creator
						FROM dbo.ProblemAccount pma WITH (NOLOCK) 
							INNER JOIN customer sma WITH (NOLOCK) ON sma.custid = pma.CustId
						WHERE pma.CustId IN (c.srecommend, c.mrecommend, c.recommend)
							AND pma.ReasonId IS NOT NULL
						ORDER BY CreatedDate DESC, sma.roleid ASC
				) AS upline
		WHERE ISNULL(pa.reasonID, upline.ReasonId) IS NOT NULL 
			AND ISNULL(pa.CreatedDate, upline.CreatedDate) >= @datetime 

		UNION ALL
		SELECT pa.custid, tmp.reasonID, tmp.CreatedDate, ISNULL(r.UserId, 10278938) AS Creator
		FROM ProblemAccount pa WITH (NOLOCK)
			CROSS APPLY (
						SELECT tv.SubIssueTypeId AS reasonID, MAX(tv.CreatedDate) AS CreatedDate, MIN(MessageId) AS MessageId
						FROM Ticketvoiding_VoidedTransaction tv WITH (NOLOCK) 
						WHERE tv.custid = pa.custid AND tv.IssueTypeId = 11
						GROUP BY tv.SubIssueTypeID
					) AS tmp
			OUTER APPLY (
						SELECT TOP(1) r.UserId
						FROM dbo.TicketVoiding_VoidingHistory vh WITH (NOLOCK) 
							INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = vh.RequestId
						WHERE vh.MessageId = tmp.MessageId
						ORDER BY r.RequestId
					)r
		WHERE tmp.CreatedDate >= @datetime
			AND tmp.reasonID IS NOT NULL
	END
	ELSE IF @CustIds <> ''
	BEGIN
		DECLARE @custid_tbl AS TABLE (custid INT )
		INSERT INTO @custid_tbl (custid)
		SELECT value
		FROM STRING_SPLIT (@CustIds,',')
		
		INSERT INTO #tmpResult (CustId, ReasonID, CreatedDate, Creator)
		SELECT pa.custid, ISNULL(pa.reasonID, upline.ReasonId), ISNULL(pa.CreatedDate, upline.CreatedDate), ISNULL(pa.Creator, upline.Creator)
		FROM ProblemAccount pa WITH (NOLOCK)
			INNER JOIN @custid_tbl ct ON ct.custID = pa.custid
			INNER JOIN customer c (NOLOCK) ON c.custid = ct.CustId
			OUTER APPLY (
						SELECT TOP 1 pma.ReasonId, pma.CreatedDate, pma.Creator
						FROM dbo.ProblemAccount pma WITH (NOLOCK) 
							INNER JOIN customer sma WITH (NOLOCK) ON sma.custid = pma.CustId
						WHERE pma.CustId IN (c.srecommend, c.mrecommend, c.recommend)
							AND pma.ReasonId IS NOT NULL
						ORDER BY CreatedDate DESC, sma.roleid ASC
				) AS upline
		WHERE ISNULL(pa.reasonID, upline.ReasonId) IS NOT NULL
		
		UNION ALL
		SELECT pa.custid, tmp.reasonID, tmp.CreatedDate, ISNULL(r.UserId, 10278938) AS Creator
		FROM ProblemAccount pa WITH (NOLOCK)
			INNER JOIN @custid_tbl ct ON ct.custID = pa.custid			
			CROSS APPLY (
						SELECT tv.SubIssueTypeId AS reasonID, MAX(tv.CreatedDate) AS CreatedDate, MIN(MessageId) AS MessageId
						FROM Ticketvoiding_VoidedTransaction tv WITH (NOLOCK) 
						WHERE tv.custid = pa.custid AND tv.IssueTypeId = 11
						GROUP BY tv.SubIssueTypeID
					) AS tmp
			OUTER APPLY (
						SELECT TOP(1) r.UserId
						FROM dbo.TicketVoiding_VoidingHistory vh WITH (NOLOCK) 
							INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = vh.RequestId
						WHERE vh.MessageId = tmp.MessageId
						ORDER BY r.RequestId
					)r
		WHERE tmp.reasonID IS NOT NULL
	END

	SELECT CustId, ReasonID, CreatedDate, Creator
	FROM #tmpResult
	ORDER BY CustId, CreatedDate

	DROP TABLE #tmpResult
END
GO

