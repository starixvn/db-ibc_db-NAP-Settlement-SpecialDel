USE [bodb_CustomerLog]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_UserLog_Settle_MatchSelByID]
	@matchid INT
AS
/*
Created: Dan
Date: 2012-10-03
Task : View match Log for settlement.	
DB: DB052.bodb_CustomerLog
Original: Acc_UserLog_Settle_MatchSelByID

Revisions: 
	- 20160428@Patrick: Fast market integration [Redmine: #56367]
*/
BEGIN
	SET NOCOUNT ON

	SELECT 
		l.logid,
		l.logdate,	
		o.username,
		la.ActionNameEN,
		l.finalhomescore,
		l.finalawayscore,  
		l.hthomescore AS HalfTimeHomeScore,
		l.htawayscore AS HalfTimeAwayScore,
		l.GoalRecord,
		l.betstatus,
		l.Remark,
		l.IP,
		l.ActionID
	FROM Userlog_Settle l WITH(NOLOCK)	
		LEFT JOIN LogAction la WITH (NOLOCK) ON l.ActionID = la.ActionID
		LEFT JOIN bodb02.dbo.CustInfo o WITH(NOLOCK) ON o.custid = l.userid
	WHERE l.matchid = @matchid
	ORDER BY logdate ASC

END
GO
GRANT EXECUTE ON [dbo].[NAP_UserLog_Settle_MatchSelByID] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_UserLog_Settle_MatchSelByID] TO [vnteam] AS [dbo]