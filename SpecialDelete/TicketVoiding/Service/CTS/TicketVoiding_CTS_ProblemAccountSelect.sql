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
		FROM ProblemAccount pa WITH (NOLOCK)
		WHERE pa.ReasonId IS NOT NULL
		UNION ALL
		SELECT pa.custid, tmp.reasonID
		FROM ProblemAccount pa WITH (NOLOCK)
			CROSS APPLY (SELECT TOP 1 tv.SubIssueTypeId AS reasonID
						FROM Ticketvoiding_VoidedTransaction tv WITH (NOLOCK) 
						WHERE tv.custid = pa.custid AND tv.IssueTypeId = 11
						ORDER BY ID DESC
						) AS tmp
		WHERE pa.ReasonId IS NULL	
	
	END
	ELSE IF ISNULL(@CustIds,'') = '' AND @datetime IS NOT NULL
	BEGIN
		SELECT pa.custid, pa.reasonID
		FROM ProblemAccount pa WITH (NOLOCK)
		WHERE pa.CreatedDate >= @datetime 
			AND pa.ReasonId IS NOT NULL
		UNION ALL
		SELECT pa.custid, tmp.reasonID
		FROM ProblemAccount pa WITH (NOLOCK)
			CROSS APPLY (SELECT TOP 1 tv.SubIssueTypeId AS reasonID
						FROM Ticketvoiding_VoidedTransaction tv WITH (NOLOCK) 
						WHERE tv.custid = pa.custid AND tv.IssueTypeId = 11
						ORDER BY ID DESC
						) AS tmp
		WHERE pa.ReasonId IS NULL	
			AND pa.CreatedDate >= @datetime
	END
	ELSE IF @CustIds <> ''
	BEGIN
		DECLARE @custid_tbl AS TABLE (custid INT )
		INSERT INTO @custid_tbl (custid)
		SELECT t.val
		FROM dbo.f_SplitString (@CustIds,',') AS t
		OPTION (MAXRECURSION 0)
		
		SELECT pa.custid, pa.reasonID
		FROM ProblemAccount pa WITH (NOLOCK)
			INNER JOIN @custid_tbl c ON c.custID = pa.custid
		WHERE pa.ReasonId IS NOT NULL
		
		UNION ALL
		
		SELECT pa.custid, tmp.reasonID
		FROM ProblemAccount pa WITH (NOLOCK)
			INNER JOIN @custid_tbl c ON c.custID = pa.custid
			CROSS APPLY (SELECT TOP 1 tv.SubIssueTypeId AS reasonID
							FROM Ticketvoiding_VoidedTransaction tv WITH (NOLOCK) 
							WHERE tv.custid = pa.custid AND tv.IssueTypeId = 11
							ORDER BY ID DESC
							) AS tmp
		WHERE pa.ReasonId IS NULL	
		
	END
END
GO

