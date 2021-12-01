/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_UserLog_Settle_by_ActionId
	@ActionId	INT
	,@FromDate	DATETIME
	,@ToDate	DATETIME
AS
/*

	Created By : 20211125@Louisa
	Task: Delete Match no ticket
	DB: DBLOG/bodb_CustomerLog

	Revisions:
			- 20211125@Louisa: Get Log for match.IsDeleted = 1 [Redmine:#163469]

*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @__archiveDate DATETIME		 
	SELECT @__archiveDate = DATEADD(DAY, 1, dbo.f_CustomerLog_GetArchiveDate())

	SELECT 
		l.logid
		,l.logdate
		,c.username
		,l.ActionID
		,la.ActionNameEN
		,l.Remark
		,l.IP
	FROM dbo.Userlog_Settle l WITH(NOLOCK)
		INNER JOIN dbo.LogAction la WITH (NOLOCK) ON l.ActionID = la.ActionID
		LEFT JOIN bodb02.dbo.CustInfo c WITH(NOLOCK) ON c.custid = l.userid
	WHERE l.ActionID = @ActionId
		AND l.LogDate BETWEEN @FromDate AND @ToDate
		AND l.LogDate >= @__archiveDate
	
	UNION ALL
	SELECT 
		l.logid
		,l.logdate
		,c.username
		,l.ActionID
		,la.ActionNameEN
		,l.Remark
		,l.IP
	FROM bodb_CustomerLog_Archive.dbo.Userlog_Settle l WITH(NOLOCK)
		INNER JOIN dbo.LogAction la WITH (NOLOCK) ON l.ActionID = la.ActionID
		LEFT JOIN bodb02.dbo.CustInfo c WITH(NOLOCK) ON c.custid = l.userid
	WHERE l.ActionID = @ActionId
		AND l.LogDate BETWEEN @FromDate AND @ToDate
		AND l.LogDate < @__archiveDate

END
GO