/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/
/*
	Created: 20240401@Aries
    Task: EC 2024-Correct Score Sharing and Lucky Draw-(Pool prize) [Redmine:#202309]
	DB: DBLOG-bodb_CustomerLog

*/

DECLARE @MatchInfo TABLE(Matchid INT,eventdate DATETIME, HomeName VARCHAR(50), AwayName VARCHAR(50),Total INT, IsDone BIT DEFAULT 0)
DECLARE @MatchIDs VARCHAR(MAX) = '83147814,77103535,77103532,77103539,77103538,77103536,77103531'

INSERT INTO @MatchInfo(Matchid,eventdate,HomeName,AwayName)
SELECT f.value,m.eventdate,th.teamname AS HomeName,ta.teamname AS AwayName
FROM string_split(@MatchIDs,',') AS f
    LEFT JOIN bodb02.dbo.match AS m WITH(NOLOCK) ON m.matchid = f.value
    LEFT JOIN bodb02.dbo.team AS th WITH(NOLOCK) ON m.homeid = th.teamid 
    LEFT JOIN bodb02.dbo.team AS ta WITH(NOLOCK) ON m.awayid = ta.teamid 

DECLARE @MatchID INT, @Count INT = 1
WHILE @Count < 64
BEGIN
    SET @Count = @Count + 1
    IF NOT EXISTS (SELECT 1 FROM @MatchInfo WHERE IsDone = 0)
    BEGIN
        BREAK;
    END

    SELECT TOP 1 @MatchID = Matchid
    FROM @MatchInfo
    WHERE IsDone = 0

    DECLARE @handle INT,@Total INT = 0, @transInfoJson NVARCHAR(MAX) 

    SELECT  TOP 1  @transInfoJson = Remark  
    FROM UserLog_Settle WITH(NOLOCK)
    WHERE ActionID =  81052 
        AND MatchID = @MatchID
        AND Remark NOT LIKE '%MinBet%'
    ORDER BY LogDate DESC

    EXEC sp_xml_preparedocument @handle OUTPUT, @transInfoJson 
    SELECT @Total = COUNT(1) 
    FROM OPENXML(@handle,'root/r',1) WITH(t   BIGINT 

    ) tbl 
    EXEC sp_xml_removedocument @handle 

    UPDATE @MatchInfo
    SET Total = @Total
        ,IsDone = 1
    WHERE Matchid = @MatchID
END

 

 SELECT * FROM @MatchInfo
