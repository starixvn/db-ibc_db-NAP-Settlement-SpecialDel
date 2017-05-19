 alter PROCEDURE [dbo].[NAP_UserLog_Settle3rd_MatchSelByID]
	@matchid INT,
	@ResultID INT
 AS
	/*
		Created: Johnson
		Date: 2015-07-16
		Task: Show log for settlement of Metric Gaming
		DB: DBLOG/bodb_CustomerLog
		
		Revisions:
		
		Parameter's Explanation:
	*/
BEGIN
	SET NOCOUNT ON
	
	SELECT 
		logid,
		logdate,
		o.username,
		la.ActionNameEN,
		l.Detail as Remark,
		l.IP
	FROM Userlog_Settle3rd l WITH(NOLOCK)
		LEFT JOIN LogAction la WITH (NOLOCK) ON l.ActionID = la.ActionID
		LEFT JOIN bodb02.dbo.CustInfo o WITH(NOLOCK) ON o.custid = l.userid
	WHERE matchid = @matchid
		AND ResultID = @ResultID		
	ORDER BY logid
	
END
GO
GRANT EXECUTE ON [dbo].[NAP_UserLog_Settle3rd_MatchSelByID] TO [bodbAdminNet]