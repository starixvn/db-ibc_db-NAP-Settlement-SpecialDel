/*<info serverAlias="DBARC-bodb_Archive" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [NAP_UserLog_Settle_MatchArchivedSelByCode] 
	@MatchCode varchar(50) = '',
	@FromDate DATETIME = NULL,
	@ToDate DATETIME = NULL,
	@BalanceUpDay DATETIME = NULL,
	@ProductType VARCHAR(3) = ''
AS
/*
	Created: Kathy
	Date: 20230620
	Task : View match info - settlement log
	DB: DBARC/bodb_Archive
	
	Revisions: 	
		- 20230620@Kathy: view info in archive [Redmine:#186616]
		- 20240718@Kathy: Implement AiO for Baseball - 8 new bettypes [Redmine:#208026]

	Example: 
		@ProductType = 'BBD' -- BetBuilder
		@ProductType = 'FMK' -- FastMarket
		@ProductType = 'OTH' -- All - excluded MetricGaming, FastMarket, BetBuilder, Number Game, Happy 5
		@ProductType = 'ALL' -- All - excluded MetricGaming, BetBuilder, Number Game, Happy 5
		@ProductType = 'NBG' -- Number game
		@ProductType = 'HPF' -- Happy 5
	
*/    
BEGIN

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
										sporttype INT,
										showtime nvarchar(50),
										matchcode nvarchar(50)
									)
	IF @FromDate IS NULL -- 185964: Support OST Team Query Resettlement Log
	BEGIN
		INSERT INTO @TMP_ALL_MatchInfo
		SELECT 	matchid , homeid , awayid , eventdate , leagueid, sporttype, showtime, matchcode
		FROM 	dbo.match_BK WITH (NOLOCK) 
		WHERE 	matchId = @matchid 
				AND 1 = CASE 
							WHEN @ProductType = 'NBG' AND sporttype = 161 THEN 1 -- NumberGame
							WHEN @ProductType = 'HPF' AND sporttype = 164 THEN 1 -- Happy5
							WHEN @ProductType NOT IN ('NBG', 'HPF') AND sporttype NOT IN (161, 164) THEN 1 -- All SportBook
							ELSE 0
						END
				AND 1 = CASE WHEN sporttype IN (8, 50) AND ISNULL(ChildMatchType,0) = 200 THEN 0
							ELSE 1
						END
	END
	ELSE IF @FromDate < @BalanceUpDay   
	BEGIN
		IF @ToDate >= DATEADD(dd, -1, @BalanceUpDay)  
			SELECT @ToDate = DATEADD(dd, -1, @BalanceUpDay)  

		IF @MatchId IS NOT NULL
		BEGIN
			INSERT INTO @TMP_ALL_MatchInfo
			SELECT 	matchid , homeid , awayid , eventdate , leagueid, sporttype, showtime, matchcode
			FROM 	dbo.match_BK WITH (NOLOCK) 
			WHERE 	matchId = @matchid
					AND eventdate BETWEEN @FromDate and @ToDate
					AND 1 = CASE 
								WHEN @ProductType = 'NBG' AND sporttype = 161 THEN 1 -- NumberGame
								WHEN @ProductType = 'HPF' AND sporttype = 164 THEN 1 -- Happy5
								WHEN @ProductType NOT IN ('NBG', 'HPF') AND sporttype NOT IN (161, 164) THEN 1 -- All SportBook
								ELSE 0
							END
					AND 1 = CASE WHEN sporttype IN (8, 50) AND ISNULL(ChildMatchType,0) = 200 THEN 0
								ELSE 1
							END
		END
		ELSE 
		BEGIN
			INSERT INTO @TMP_ALL_MatchInfo
			SELECT 	matchid , homeid , awayid , eventdate , leagueid, sporttype, showtime, matchcode
			FROM 	dbo.match_BK WITH (NOLOCK) 
			WHERE 	matchcode = @MatchCode
					AND eventdate BETWEEN @FromDate and @ToDate
					AND 1 = CASE 
								WHEN @ProductType = 'NBG' AND sporttype = 161 THEN 1 -- NumberGame
								WHEN @ProductType = 'HPF' AND sporttype = 164 THEN 1 -- Happy5
								WHEN @ProductType NOT IN ('NBG', 'HPF') AND sporttype NOT IN (161, 164) THEN 1 -- All SportBook
								ELSE 0
							END
					AND 1 = CASE WHEN sporttype IN (8, 50) AND ISNULL(ChildMatchType,0) = 200 THEN 0
								ELSE 1
							END
		END
	END

	SELECT t.matchid , t.homeid , t.awayid , t.eventdate , t.leagueid, sporttype, showtime, matchcode
	FROM @TMP_ALL_MatchInfo t

END
GO