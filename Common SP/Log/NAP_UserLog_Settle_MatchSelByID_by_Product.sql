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
		- 20190517@Kathy: archive a part of old log records to new database [Redmine: #106903]
		- 20190806@Sol: Enhance Log Settlement - Filter log by log type [Redmine:#118072]

	Param's Explanation:
		@ProductTypeList:  list of product, separated by ","
		
	Example: 
		@ProductTypeList = 'BBD' -- BetBuilder
		@ProductTypeList = 'FMK' -- FastMarket
		@ProductTypeList = 'OTH' -- All - excluded MetricGaming, FastMarket, BetBuilder, Number Game, Happy 5
		@ProductTypeList = 'ALL' -- All - excluded MetricGaming, BetBuilder, Number Game, Happy 5
		@ProductTypeList = 'NBG' -- Number game
		@ProductTypeList = 'HPF' -- Happy 5
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @__archiveDate DATETIME 		 
	SELECT @__archiveDate = DATEADD(DAY, 1, dbo.f_CustomerLog_GetArchiveDate())

	DECLARE @tblActionID TABLE (ActionID INT)
	----------------------------------------------------------------------------
	
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
		LEFT JOIN LogAction la WITH (NOLOCK) ON l.ActionID = la.ActionID
		LEFT JOIN bodb02.dbo.CustInfo o WITH(NOLOCK) ON o.custid = l.userid
	WHERE	l.matchid = @matchid
			AND l.ActionID NOT IN (152, 153, 154) --exclude MetricGaming
			AND 1 = CASE WHEN @ProductTypeList = 'BBD' AND l.ActionID IN (81007, 81009, 81010, 81012, 81013, 81014) THEN 1 
						WHEN @ProductTypeList = 'FMK' AND l.ActionID IN (143, 144, 165, 166, 167, 183, 184) THEN 1
						WHEN @ProductTypeList = 'NBG' AND l.ActionID IN (115, 116, 117, 118, 119) THEN 1
						WHEN @ProductTypeList = 'HPF' AND l.ActionID IN (81000, 81001) THEN 1
						WHEN @ProductTypeList = 'OTH' AND l.ActionID NOT IN (143, 144, 165, 166, 167, 183, 184, --exclude FastMarket
																				115, 116, 117, 118, 119, -- exclude NumberGame
																				81000, 81001, -- exclude Happy 5
																				81007, 81009, 81010, 81012, 81013, 81014 -- exclude BetBuilder
																				) THEN 1 
						WHEN @ProductTypeList = 'ALL' AND l.ActionID NOT IN (115, 116, 117, 118, 119, 81000, 81001, 81007, 81009, 81010, 81012, 81013, 81014) THEN 1 --exclude NumberGame, Happy5, BetBuilder
						ELSE 0
					END
			AND LogDate >= @__archiveDate
	UNION ALL
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
	FROM bodb_CustomerLog_Archive.dbo.Userlog_Settle l WITH(NOLOCK)
		LEFT JOIN LogAction la WITH (NOLOCK) ON l.ActionID = la.ActionID
		LEFT JOIN bodb02.dbo.CustInfo o WITH(NOLOCK) ON o.custid = l.userid
	WHERE	l.matchid = @matchid
			AND l.ActionID NOT IN (152, 153, 154) --exclude MetricGaming
			AND 1 = CASE WHEN @ProductTypeList = 'BBD' AND l.ActionID IN (81007, 81009, 81010, 81012, 81013, 81014) THEN 1 
						WHEN @ProductTypeList = 'FMK' AND l.ActionID IN (143, 144, 165, 166, 167, 183, 184) THEN 1
						WHEN @ProductTypeList = 'NBG' AND l.ActionID IN (115, 116, 117, 118, 119) THEN 1
						WHEN @ProductTypeList = 'HPF' AND l.ActionID IN (81000, 81001) THEN 1
						WHEN @ProductTypeList = 'OTH' AND l.ActionID NOT IN (143, 144, 165, 166, 167, 183, 184, --exclude FastMarket
																				115, 116, 117, 118, 119, -- exclude NumberGame
																				81000, 81001, -- exclude Happy 5
																				81007, 81009, 81010, 81012, 81013, 81014 -- exclude BetBuilder
																				) THEN 1 
						WHEN @ProductTypeList = 'ALL' AND l.ActionID NOT IN (115, 116, 117, 118, 119, 81000, 81001, 81007, 81009, 81010, 81012, 81013, 81014) THEN 1 --exclude NumberGame, Happy5, BetBuilder
						ELSE 0
					END
			AND LogDate >= @__archiveDate
	ORDER BY logdate ASC

END
GO