/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
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
	- 20190103@Vicky: Incorporate BetBuilder [Redmine:#106903]
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
		AND l.ActionID NOT IN (81006,81007,81009,81010,81011,81012) --exclude Betbuilder
	ORDER BY logdate ASC

END
GO
