/*<info serverAlias="DBACC-bodb02" executers="bodbSPUNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_CTS_ProblemAccountSelect_CN88]
	@CustIds	VARCHAR(MAX) = ''
	,@datetime DATETIME = NULL
AS
/*	
	Created by: Max
	Date 20200819
	Task: [CTS] Customer Category - Auto tag Problem Customer for CN88 [Redmine:#139869]
	DB: DBACC/bodb02
	
	Revisions: 
		- 20200819@Max: Create new SP [Redmine:#139869]
		- 20200921@July: CTS - Cannot categorize for new PA member [Redmine:#142051]
		- 20200903@Max: Enhance Problem Account Category - Multiple Reason - [Redmine: #140211]
		- 20201215@Max: CTS - Missing Category/Class [Redmine: #146822]
		- 20220808@July: Change function to STRING_SPLIT [Redmine: #175412]
		
	Param's explanation:
		+ @CustIds = 0: the first run then get all data
		+ @CustIds IS NULL OR '': get all changed data from @datetime
		+ @CustIds IS NOT NULL AND <> '0': get the latest info for inputted customers, latest reason
*/
BEGIN
	SET NOCOUNT ON
	
	IF @CustIds = '0'
	BEGIN
		SELECT pa.custid, pa.reasonID
		FROM CS_ProblemAccount pa WITH (NOLOCK)
		WHERE pa.ReasonId IS NOT NULL
		UNION ALL
		SELECT pa.custid, ISNULL (tmp.reasonID, upline.ReasonId)
		FROM CS_ProblemAccount pa WITH (NOLOCK)
			INNER JOIN customer c (NOLOCK) ON c.custid = pa.CustId
			OUTER APPLY (SELECT DISTINCT tv.SubIssueTypeId AS reasonID
						FROM Ticketvoiding_VoidedTransaction tv WITH (NOLOCK) 
						WHERE tv.custid = pa.custid AND tv.IssueTypeId = 11
						) AS tmp
			OUTER APPLY (SELECT TOP 1 pma.ReasonId
						FROM CS_ProblemAccount pma WITH (NOLOCK) 
							INNER JOIN customer sma WITH (NOLOCK) ON sma.custid = pma.CustId
						WHERE pma.CustId IN (c.srecommend, c.mrecommend, c.recommend)
							AND pma.ReasonId IS NOT NULL
						ORDER BY CreatedDate DESC, sma.roleid ASC
						) AS upline
		WHERE pa.ReasonId IS NULL AND ISNULL (tmp.reasonID, upline.ReasonId) IS NOT NULL
	
	END
	ELSE IF ISNULL(@CustIds,'') = '' AND @datetime IS NOT NULL
	BEGIN
		SELECT pa.custid, pa.reasonID
		FROM CS_ProblemAccount pa WITH (NOLOCK)
		WHERE pa.CreatedDate >= @datetime 
			AND pa.ReasonId IS NOT NULL
		UNION ALL
		SELECT pa.custid,ISNULL (tmp.reasonID, upline.ReasonId)
		FROM CS_ProblemAccount pa WITH (NOLOCK)
		    INNER JOIN customer c (NOLOCK) ON c.custid = pa.CustId
			OUTER APPLY (SELECT DISTINCT tv.SubIssueTypeId AS reasonID
						FROM Ticketvoiding_VoidedTransaction tv WITH (NOLOCK) 
						WHERE tv.custid = pa.custid AND tv.IssueTypeId = 11
						) AS tmp
		   OUTER APPLY (SELECT TOP 1 pma.ReasonId
						FROM CS_ProblemAccount pma WITH (NOLOCK) 
						    	INNER JOIN customer sma WITH (NOLOCK) ON sma.custid = pma.CustId
						WHERE pma.CustId IN (c.srecommend, c.mrecommend, c.recommend)
							AND pma.ReasonId IS NOT NULL
						ORDER BY CreatedDate DESC, sma.roleid ASC
						) AS upline
		WHERE pa.ReasonId IS NULL AND ISNULL (tmp.reasonID, upline.ReasonId) IS NOT NULL
			AND pa.CreatedDate >= @datetime
		ORDER BY pa.CustId
	END
	ELSE IF @CustIds <> ''
	BEGIN
		DECLARE @custid_tbl AS TABLE (custid INT )
		INSERT INTO @custid_tbl (custid)
		SELECT value
		FROM STRING_SPLIT (@CustIds,',')
		
		SELECT pa.custid, pa.reasonID
		FROM CS_ProblemAccount pa WITH (NOLOCK)
			INNER JOIN @custid_tbl c ON c.custID = pa.custid
		WHERE pa.ReasonId IS NOT NULL
		
		UNION ALL
		
		SELECT pa.custid, ISNULL (tmp.reasonID, upline.ReasonId)
		FROM CS_ProblemAccount pa WITH (NOLOCK)
			INNER JOIN @custid_tbl ct ON ct.custID = pa.custid
			INNER JOIN customer c (NOLOCK) ON c.custid = ct.CustId
			OUTER APPLY (SELECT DISTINCT tv.SubIssueTypeId AS reasonID
						FROM Ticketvoiding_VoidedTransaction tv WITH (NOLOCK) 
						WHERE tv.custid = pa.custid AND tv.IssueTypeId = 11
						) AS tmp
			OUTER APPLY (SELECT TOP 1 pma.ReasonId
						FROM CS_ProblemAccount pma WITH (NOLOCK) 
								INNER JOIN customer sma WITH (NOLOCK) ON sma.custid = pma.CustId
						WHERE pma.CustId IN (c.srecommend, c.mrecommend, c.recommend)
							AND pma.ReasonId IS NOT NULL
						ORDER BY CreatedDate DESC, sma.roleid ASC
						) AS upline
		WHERE pa.ReasonId IS NULL AND ISNULL (tmp.reasonID, upline.ReasonId) IS NOT NULL
		
	END
END
GO

