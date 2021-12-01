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
	
	Param's explanation:
		+ @CustIds = 0: the first run then get all data
		+ @CustIds IS NULL OR '': get all changed data from @datetime
		+ @CustIds IS NOT NULL AND <> '0': get the latest info for inputted customers, latest reason
*/
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #tmpResult (CustId INT, ReasonID TINYINT, CreatedDate DATETIME)
	
	IF @CustIds = '0'
	BEGIN
		INSERT INTO #tmpResult (CustId, ReasonID, CreatedDate)
		SELECT pa.custid, ISNULL(pa.reasonID, upline.ReasonId), ISNULL(pa.CreatedDate, upline.CreatedDate)
		FROM ProblemAccount pa WITH (NOLOCK)
			INNER JOIN customer c (NOLOCK) ON c.custid = pa.CustId
			OUTER APPLY (
						SELECT TOP 1 pma.ReasonId, pma.CreatedDate
						FROM dbo.ProblemAccount pma WITH (NOLOCK) 
							INNER JOIN customer sma WITH (NOLOCK) ON sma.custid = pma.CustId
						WHERE pma.CustId IN (c.srecommend, c.mrecommend, c.recommend)
							AND pma.ReasonId IS NOT NULL
						ORDER BY CreatedDate DESC, sma.roleid ASC
				) AS upline
		WHERE ISNULL(pa.reasonID, upline.ReasonId) IS NOT NULL

		UNION ALL
		SELECT pa.custid, tmp.reasonID, tmp.CreatedDate
		FROM ProblemAccount pa WITH (NOLOCK)
			CROSS APPLY (
						SELECT tv.SubIssueTypeId AS reasonID, MAX(tv.CreatedDate) AS CreatedDate
						FROM Ticketvoiding_VoidedTransaction tv WITH (NOLOCK) 
						WHERE tv.custid = pa.custid AND tv.IssueTypeId = 11
						GROUP BY tv.SubIssueTypeID
					) AS tmp
	END
	ELSE IF ISNULL(@CustIds,'') = '' AND @datetime IS NOT NULL
	BEGIN
		INSERT INTO #tmpResult (CustId, ReasonID, CreatedDate)
		SELECT pa.custid, ISNULL(pa.reasonID, upline.ReasonId), ISNULL(pa.CreatedDate, upline.CreatedDate)
		FROM ProblemAccount pa WITH (NOLOCK)
			INNER JOIN customer c (NOLOCK) ON c.custid = pa.CustId
			OUTER APPLY (
						SELECT TOP 1 pma.ReasonId, pma.CreatedDate
						FROM dbo.ProblemAccount pma WITH (NOLOCK) 
							INNER JOIN customer sma WITH (NOLOCK) ON sma.custid = pma.CustId
						WHERE pma.CustId IN (c.srecommend, c.mrecommend, c.recommend)
							AND pma.ReasonId IS NOT NULL
						ORDER BY CreatedDate DESC, sma.roleid ASC
				) AS upline
		WHERE ISNULL(pa.reasonID, upline.ReasonId) IS NOT NULL 
			AND ISNULL(pa.CreatedDate, upline.CreatedDate) >= @datetime 

		UNION ALL
		SELECT pa.custid, tmp.reasonID, tmp.CreatedDate
		FROM ProblemAccount pa WITH (NOLOCK)
			CROSS APPLY (
						SELECT tv.SubIssueTypeId AS reasonID, MAX(tv.CreatedDate) AS CreatedDate
						FROM Ticketvoiding_VoidedTransaction tv WITH (NOLOCK) 
						WHERE tv.custid = pa.custid AND tv.IssueTypeId = 11
						GROUP BY tv.SubIssueTypeID
					) AS tmp
		WHERE tmp.CreatedDate >= @datetime
	END
	ELSE IF @CustIds <> ''
	BEGIN
		DECLARE @custid_tbl AS TABLE (custid INT )
		INSERT INTO @custid_tbl (custid)
		SELECT t.val
		FROM dbo.f_SplitString (@CustIds,',') AS t
		OPTION (MAXRECURSION 0)
		
		INSERT INTO #tmpResult (CustId, ReasonID, CreatedDate)
		SELECT pa.custid, ISNULL(pa.reasonID, upline.ReasonId), ISNULL(pa.CreatedDate, upline.CreatedDate)
		FROM ProblemAccount pa WITH (NOLOCK)
			INNER JOIN @custid_tbl ct ON ct.custID = pa.custid
			INNER JOIN customer c (NOLOCK) ON c.custid = ct.CustId
			OUTER APPLY (
						SELECT TOP 1 pma.ReasonId, pma.CreatedDate
						FROM dbo.ProblemAccount pma WITH (NOLOCK) 
							INNER JOIN customer sma WITH (NOLOCK) ON sma.custid = pma.CustId
						WHERE pma.CustId IN (c.srecommend, c.mrecommend, c.recommend)
							AND pma.ReasonId IS NOT NULL
						ORDER BY CreatedDate DESC, sma.roleid ASC
				) AS upline
		WHERE ISNULL(pa.reasonID, upline.ReasonId) IS NOT NULL
		
		UNION ALL
		SELECT pa.custid, tmp.reasonID, tmp.CreatedDate
		FROM ProblemAccount pa WITH (NOLOCK)
			INNER JOIN @custid_tbl ct ON ct.custID = pa.custid			
			CROSS APPLY (
						SELECT tv.SubIssueTypeId AS reasonID, MAX(tv.CreatedDate) AS CreatedDate
						FROM Ticketvoiding_VoidedTransaction tv WITH (NOLOCK) 
						WHERE tv.custid = pa.custid AND tv.IssueTypeId = 11
						GROUP BY tv.SubIssueTypeID
					) AS tmp
	END

	SELECT CustId, ReasonID, CreatedDate
	FROM #tmpResult
	ORDER BY CustId, CreatedDate

	DROP TABLE #tmpResult
END
GO

