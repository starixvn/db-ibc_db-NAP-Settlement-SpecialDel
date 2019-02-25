/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_UserLog_Settle_MatchSelByID_by_Product]
		@Matchid 				INT
		,@ProductTypeList		VARCHAR(20)
AS
/*
	Creator: Vicky
	Date: 20181228
	Task: BetBuilder Auto/Manual Settlement
	DB: DBLOG-bodb_CustomerLog

	Revisions: 
		- 20190103@Vicky: Incorporate BetBuilder [Redmine:#106903]
		
	Param's Explanation:
		@ProductTypeList:  list of product, separated by ","
		
	Example: 
		@ProductTypeList = 'BBD'
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @tblActionID TABLE (ActionID INT)
	----------------------------------------------------------------------------
	
	IF @ProductTypeList LIKE '%BBD%'
	BEGIN
		INSERT INTO @tblActionID(ActionID)
		VALUES (81006),(81007),(81009), (81010),(81012)
	END 
	
	SELECT 
		l.logid,
		l.logdate AS SettlementDate,	
		o.username,
		la.ActionNameEN AS Action,
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
		INNER JOIN @tblActionID a ON a.ActionID = l.ActionID
		LEFT JOIN LogAction la WITH (NOLOCK) ON l.ActionID = la.ActionID
		LEFT JOIN bodb02.dbo.CustInfo o WITH(NOLOCK) ON o.custid = l.userid
	WHERE l.matchid = @matchid
	ORDER BY logdate ASC

END
GO
