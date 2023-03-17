/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_UserLog_Settle_OutrightSelByLeagueID]
    @LeagueID   INT = 0 
    ,@MatchID   INT = 0 
    ,@FromDate  DATETIME
    ,@ToDate    DATETIME 
AS
/*
    Created: Jamie
    Date: 20140812
    Task : View Outright LOG 
    DB: DBLog/bodb_CustomerLog
    Original: 

    Revisions: 
        - 20230109@Aries: Migrate Calculate Outright Function to NAP Settlement Site [Redmine:#163971]

    Param's Explanation:
        @FromDate & @ToDate: Event Date 
        @MatchID: = ORID of Outright 
*/
BEGIN
    SET NOCOUNT ON

    SELECT   l.logid
            ,l.logdate
            ,o.username
            ,la.ActionNameEN
            ,l.LeagueID
            ,l.MatchID
            ,l.EventDate
            ,l.Result
            ,l.Remark
    FROM    Userlog_SettleOutright l WITH (NOLOCK)
            LEFT JOIN LogAction la WITH (NOLOCK) ON l.ActionID = la.ActionID
            LEFT JOIN bodb02.dbo.CustInfo o WITH (NOLOCK) ON o.custid = l.userid
    WHERE   l.LeagueID = CASE WHEN @LeagueID = 0 THEN l.LeagueID ELSE @LeagueID END 
            AND l.MatchID = @MatchID
            AND L.EventDate BETWEEN @FromDate AND @ToDate 
            AND l.ActionID NOT IN (136, 138, 140)
    ORDER BY l.LogID ASC

END