/*<info serverAlias="DBAGE-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [NAP_UserLog_Settle_MatchSelByCode] 
	@MatchCode varchar(50) = '',
	@FromDate DATETIME = '',
	@ToDate DATETIME = '',
	@BalanceUpDay DATETIME = '',
	@ProductType VARCHAR(3) = ''
AS
/*
	Created: Dan
	Date: 20121003
	Task : View match info - settlement log
	DB: DBAGE/bodb02
	Original: Acc_UserLog_Settle_MatchSelByCode

	Revisions: 	
		- 20130121@Dan: change linked server DB06 to DBARC
		- 20190806@Sol: Enhance Log Settlement - Filter log by log type [Redmine:#118072]
		- 20210316@Louisa: Cricket AIO [Redmine:#148870]
		- 20230620@Kathy: view info in archive [Redmine:#186616]
		- 20240718@Kathy: Implement AiO for Baseball - 8 new bettypes [Redmine:#208026]
		- 20240918@Aries: Betradar VS - Integrate 2 new sports Virtual Horse Racing & Virtual Dog Racing  [Redmine:#210875]

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

	IF @Todate >= @BalanceUpDay    
	BEGIN
		IF @MatchId IS NOT NULL
		BEGIN
			INSERT INTO @TMP_ALL_MatchInfo
			SELECT matchid , homeid , awayid ,  eventdate , leagueid, sporttype, showtime, matchcode
			FROM match WITH (NOLOCK)
			WHERE matchId = @matchid
				and eventdate BETWEEN @FromDate and @ToDate
				AND 1 = CASE 
							WHEN @ProductType = 'NBG' AND sporttype = 161 THEN 1 -- NumberGame
							WHEN @ProductType = 'HPF' AND sporttype = 164 THEN 1 -- Happy5
							WHEN @ProductType NOT IN ('NBG', 'HPF') AND sporttype NOT IN (161, 164) THEN 1 -- All SportBook
							ELSE 0
						END
				AND 1 = CASE WHEN sporttype IN (8, 50) AND ISNULL(ChildMatchType,0) = 200 THEN 0
							ELSE 1
						END

			INSERT INTO @TMP_ALL_MatchInfo
			SELECT EventID AS matchid , NULL AS homeid ,NULL AS awayid ,EventTime AS   eventdate , LeagueID, SportType, NULL AS  showtime,  NULL AS  matchcode
			FROM VSRaceInfo WITH (NOLOCK)
			WHERE EventID = @matchid
				and EventTime BETWEEN @FromDate and @ToDate
		END
		ELSE 
		BEGIN
			INSERT INTO @TMP_ALL_MatchInfo
			SELECT matchid , homeid , awayid ,  eventdate , leagueid, sporttype, showtime, matchcode
			FROM match WITH (NOLOCK)
			WHERE matchcode = @MatchCode
				and eventdate BETWEEN @FromDate and @ToDate
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

		IF @BalanceUpDay < @FromDate     
			SELECT @BalanceUpDay=@FromDate  

		IF @MatchId IS NOT NULL
		BEGIN
			INSERT INTO @TMP_ALL_MatchInfo
			SELECT matchid , homeid , awayid ,  eventdate , leagueid, sporttype, showtime, matchcode
			FROM match14 WITH (NOLOCK)
			WHERE matchId = @matchid
				and eventdate BETWEEN @BalanceUpDay and @ToDate
				AND 1 = CASE 
							WHEN @ProductType = 'NBG' AND sporttype = 161 THEN 1 -- NumberGame
							WHEN @ProductType = 'HPF' AND sporttype = 164 THEN 1 -- Happy5
							WHEN @ProductType NOT IN ('NBG', 'HPF') AND sporttype NOT IN (161, 164) THEN 1 -- All SportBook
							ELSE 0
						END
				AND 1 = CASE WHEN sporttype IN (8, 50) AND ISNULL(ChildMatchType,0) = 200 THEN 0
							ELSE 1
						END

			INSERT INTO @TMP_ALL_MatchInfo
			SELECT EventID AS matchid , NULL AS homeid ,NULL AS awayid ,EventTime AS   eventdate , LeagueID, SportType, NULL AS  showtime,  NULL AS  matchcode
			FROM VSRaceInfo14 WITH (NOLOCK)
			WHERE EventID = @matchid
				and EventTime BETWEEN @BalanceUpDay and @ToDate

		END
		ELSE
		BEGIN
			INSERT INTO @TMP_ALL_MatchInfo
			SELECT matchid , homeid , awayid ,  eventdate , leagueid, sporttype, showtime, matchcode
			FROM match14 WITH (NOLOCK)
			WHERE matchcode = @MatchCode
				and eventdate BETWEEN @BalanceUpDay and @ToDate
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