/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_UserLog_Settle_OutrightSelByCode] 
    @MatchCode  VARCHAR(50) = NULL,
    @MatchID    INT         = NULL,  
    @FromDate   DATETIME    = '',
    @ToDate     DATETIME    = '',
    @BalanceUpDay DATETIME  = ''
AS
/*
    Created: Jamie
    Date: 20100302
    Task : View match info - settlement log
    DB: DBLog/bodb_CustomerLog
    Original:
     
    Revisions:  
        - 20230109@Aries: Migrate Calculate Outright Function to NAP Settlement Site [Redmine:#163971]

    Param Explanation: 
        @MatchID = OrID 

*/
BEGIN
    SET NOCOUNT ON

    DECLARE @tmpOutrightInfo TABLE (
             OrID       INT
            ,LeagueID   INT
            ,MatchCode  VARCHAR(10)
            ,TeamID     INT
            ,EventDate  DATETIME
        )


    IF @Todate >= @BalanceUpDay    
    BEGIN
        INSERT INTO @tmpOutrightInfo(
             OrID
            ,leagueid
            ,matchcode
            ,teamid
            ,eventdate
        )
        SELECT  Orid
                ,leagueid
                ,matchcode
                ,teamid
                ,eventdate
        FROM    bodb02.dbo.outright WITH (NOLOCK)
        WHERE   matchcode = CASE WHEN @MatchCode IS NULL THEN matchcode ELSE @MatchCode END 
                AND orid  = CASE WHEN @MatchID IS NULL THEN orid ELSE @MatchID END 
                AND eventdate BETWEEN @FromDate AND @ToDate


        IF @BalanceUpDay < @FromDate     
            SELECT @BalanceUpDay=@FromDate  
            INSERT INTO @tmpOutrightInfo(
                 OrID
                ,leagueid
                ,matchcode
                ,teamid
                ,eventdate
            )
            SELECT  Orid
                    ,leagueid
                    ,matchcode
                    ,teamid
                    ,eventdate
            FROM    bodb02.dbo.outright14 WITH (NOLOCK)
            WHERE   matchcode = CASE WHEN @MatchCode IS NULL THEN matchcode ELSE @MatchCode END 
                    AND orid  = CASE WHEN @MatchID IS NULL THEN orid ELSE @MatchID END 
                    AND eventdate BETWEEN @FromDate AND @ToDate
    END

    IF @FromDate < @BalanceUpDay   
    BEGIN
        IF @ToDate >= DATEADD(dd, -1, @BalanceUpDay)  
            SELECT @ToDate = DATEADD(dd, -1, @BalanceUpDay)  
            INSERT INTO @tmpOutrightInfo(
                 OrID
                ,leagueid
                ,matchcode
                ,teamid
                ,eventdate
            )
            SELECT  Orid
                    ,leagueid
                    ,matchcode
                    ,teamid
                    ,eventdate
            FROM    DBARC.bodb_Archive.dbo.outright_bk WITH (NOLOCK)
            WHERE   matchcode = CASE WHEN @MatchCode IS NULL THEN matchcode ELSE @MatchCode END 
                    AND orid  = CASE WHEN @MatchID IS NULL THEN orid ELSE @MatchID END 
                    AND eventdate BETWEEN @FromDate AND @ToDate
    END

    SELECT  OrID
            ,leagueid
            ,matchcode
            ,teamid
            ,eventdate
    FROM    @tmpOutrightInfo 
END