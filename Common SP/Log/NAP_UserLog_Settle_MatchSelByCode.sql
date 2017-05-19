CREATE PROCEDURE [NAP_UserLog_Settle_MatchSelByCode] 
	@MatchCode varchar(50) = '',
	@FromDate DATETIME = '',
	@ToDate DATETIME = '',
	@BalanceUpDay DATETIME = ''
AS
/*
Created: Dan
Date: 20121003
Task : View match info - settlement log
DB: DBAGE/bodb02
Original: Acc_UserLog_Settle_MatchSelByCode

Revisions: 	
	- 20130121@Dan: change linked server DB06 to DBARC
	
*/
SET NOCOUNT ON
DECLARE @matchId int

BEGIN TRY	
	SET @matchid = CASE WHEN ISNUMERIC(@MatchCode) = 1 THEN CAST(@MatchCode AS INT) ELSE NULL END
END TRY
BEGIN CATCH
	SET @matchid=NULL
END CATCH			

DECLARE  @TMP_ALL_MatchInfo TABLE (
									matchid INT, 
									homeid INT, 
									awayid INT, 
									eventdate DATETIME, 
									leagueid INT, 
									isneutral BIT, 
									sporttype INT,
									showtime nvarchar(50),
									homeid2 INT
								)

IF @Todate >= @BalanceUpDay    
BEGIN
	INSERT INTO @TMP_ALL_MatchInfo
	SELECT matchid , homeid , awayid ,  eventdate , leagueid, isneutral, sporttype, showtime, 
		   ISNULL(homeid2,0) as homeid2  -- contains bettype of Live Casino 
	FROM match WITH (NOLOCK)
	WHERE (matchId = @matchid or matchcode = @MatchCode )
		and eventdate BETWEEN @FromDate and @ToDate

	IF @BalanceUpDay < @FromDate     
		SELECT @BalanceUpDay=@FromDate  

	INSERT INTO @TMP_ALL_MatchInfo
	SELECT matchid , homeid , awayid ,  eventdate , leagueid, isneutral, sporttype, showtime,
		   ISNULL(homeid2,0) as homeid2  -- contains bettype of Live Casino 
	FROM match14 WITH (NOLOCK)
	WHERE (matchId = @matchid or matchcode = @MatchCode )
		and eventdate BETWEEN @BalanceUpDay and @ToDate
END

IF @FromDate < @BalanceUpDay   
BEGIN
	IF @ToDate >= DATEADD(dd, -1, @BalanceUpDay)  
		SELECT @ToDate = DATEADD(dd, -1, @BalanceUpDay)  

	INSERT INTO @TMP_ALL_MatchInfo
	SELECT matchid , homeid , awayid , eventdate , leagueid, isneutral, sporttype, showtime,
		   ISNULL(homeid2,0) as homeid2  -- contains bettype of Live Casino 
	FROM DBARC.bodb_Archive.dbo.match_BK WITH (NOLOCK) 
	WHERE (matchId = @matchid or matchcode = @MatchCode )
		AND eventdate BETWEEN @FromDate and @ToDate
END

SELECT t.matchid , t.homeid , t.awayid , t.eventdate , t.leagueid, isneutral, sporttype, showtime, homeid2 
FROM @TMP_ALL_MatchInfo t


GO

GRANT EXECUTE ON [NAP_UserLog_Settle_MatchSelByCode] TO [bodbAdminNet] AS [dbo]
GO

GRANT VIEW DEFINITION ON [NAP_UserLog_Settle_MatchSelByCode] TO [vnteam] AS [dbo]
GO


