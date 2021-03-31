/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_VoidTime_Select]
(	
	 @MatchId             INT
	,@FilterFromTransTime DATETIME = NULL
	,@FilterToTransTime	  DATETIME = NULL
	,@FilterBy			  TINYINT = 1
	,@IssueTypeId		  INT = 1
	,@SubIssueTypeId	  INT = NULL
	,@IsCheckedHomeTeam   BIT = 0
	,@IsCheckedAwayTeam   BIT = 0
	,@AATime			  TINYINT 
	,@PATime			  TINYINT 
	,@SATime			  TINYINT 
	,@VoidFromTime		  DATETIME = NULL OUTPUT
	,@VoidToTime		  DATETIME = NULL OUTPUT	
)
AS 
/*	
	Created by: July
	Date 20210329
	Task: [TVS] Danger Accept/Red Card Enhancement - Phase 7
	DB: DBTXN/bodb02
	
	Revisions:
		- 20210329@July: Create new SP [Redmine: #150459] 

	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @AutoAcceptTime		DATETIME = NULL,
			@PendingAcceptTime	DATETIME = NULL,
			@SecondAcceptTime	DATETIME = NULL,
			@MinFromTime		DATETIME = NULL,
			@MaxFromTime		DATETIME = NULL,
			@MinAccept			TINYINT = 0,
			@MaxAccept			TINYINT = 0,
			@MinTicketFromTime	DATETIME = NULL
			
	
	CREATE TABLE #tblTransIdTemp (
			matchid         INT,
			transid         BIGINT,
			subtransid		BIGINT,
			refno           BIGINT,
			transdate       DATETIME,
			checktime		DATETIME,
			IsMixParlay     BIT DEFAULT(0),
			bettype         SMALLINT,
			statusId		TINYINT,
			typeaccept		TINYINT
	)
	CREATE TABLE #tblGroupTypeAccept (TypeAccept TINYINT, MinTicket DATETIME)
	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)

	IF @IssueTypeId = 1 -- Danger Accept
	BEGIN
		SELECT @MinAccept = @AATime
			 , @MaxAccept = @AATime
			 
		IF @MinAccept > @PATime SET @MinAccept = @PATime
		IF @MinAccept > @SATime SET @MinAccept = @SATime
	
		IF @MaxAccept < @PATime SET @MaxAccept = @PATime
		IF @MaxAccept < @SATime SET @MaxAccept = @SATime

		SELECT @AutoAcceptTime = DATEADD (SECOND,@AATime,@FilterFromTransTime)
			  ,@PendingAcceptTime = DATEADD (SECOND,@PATime,@FilterFromTransTime)
			  ,@SecondAcceptTime = DATEADD (SECOND,@SATime,@FilterFromTransTime)
			  ,@MinFromTime = DATEADD (SECOND,@MinAccept,@FilterFromTransTime)
			  ,@MaxFromTime = DATEADD (SECOND,@MaxAccept,@FilterFromTransTime)

		SELECT @VoidToTime = @FilterToTransTime
			   
		INSERT INTO @bettype_tmp (bettype)
		SELECT DISTINCT pt.bettype
		FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
		WHERE pt.ProductID = 1 -- Sportsbook
			AND pt.bettype NOT IN (10, 9, 29) -- outright, parlay
			AND pt.bettype NOT BETWEEN 221 AND 227 -- Fast Market
			AND pt.SubProduct NOT IN ('Bet Builder', 'MG-SuperLive', 'BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet Builder, Metric Gaming, Bet trade (BT-)

		-- search tickets : not metric gaming tickets, mix parlay tickets
		INSERT INTO #tblTransIdTemp(	
				matchid   	
				,transid 
				,subtransid 		
				,refno     		
				,transdate 		
				,checktime
				,bettype   
				,statusId	
			)
		SELECT 
				@MatchId
				,b.transid
				,b.transid AS subtransid
				,b.refno
				,b.transdate
				,b.checktime
				,b.bettype
				,b.statusId
		FROM	bettrans b WITH (NOLOCK)	
			INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
		WHERE	b.matchid = @matchid
				AND CASE WHEN @FilterBy = 1 THEN b.transdate 
							 WHEN @FilterBy = 2 AND b.checktime IS NOT NULL THEN b.checktime
							 WHEN @FilterBy = 2 AND b.checktime IS NULL THEN b.transdate
							 END BETWEEN @MinFromTime AND @FilterToTransTime
				AND (1 = CASE WHEN @SubIssueTypeId NOT IN (1,2) THEN 1
							ELSE CASE WHEN (@IsCheckedHomeTeam = 0 AND @IsCheckedAwayTeam = 0) OR (@IsCheckedHomeTeam = 1 AND @IsCheckedAwayTeam = 1) THEN 1
									  WHEN @IsCheckedAwayTeam = 1 AND b.bettype NOT IN (401,403,407,482,484,461,463) THEN 1 
									  WHEN @IsCheckedHomeTeam = 1 AND b.bettype NOT IN (402,404,409,483,485,462,464) THEN 1
									  ELSE 0 END
							END)
		
		---get sub ticket of a mix parlay	
		IF EXISTS (
				SELECT 1
				FROM dbo.bettransm AS bm WITH (NOLOCK)
				WHERE bm.matchid = @matchid
				)
		BEGIN		
			INSERT INTO #tblTransIdTemp(
					matchid   	
					,transid
					,subtransid  		
					,refno     		
					,transdate 		
					,checktime
					,IsMixParlay
					,bettype   
					,statusId	
				)
			SELECT 
					@MatchId
					,main.transid AS TransId
					,sub.transid AS subtransid
					,sub.refno
					,sub.transdate
					,sub.checktime
					,1 AS IsMixParlay
					,main.bettype
					,main.statusId
			FROM	dbo.bettransm sub WITH (NOLOCK)				
					INNER HASH JOIN bettrans AS main WITH (NOLOCK) 
						ON	main.refno = sub.refno				
							AND sub.matchid = @matchid
			WHERE   main.matchid = 29
					AND main.bettype = 29
					AND CASE WHEN @FilterBy = 1 THEN sub.transdate
							 WHEN @FilterBy = 2 AND sub.checktime IS NOT NULL THEN sub.checktime
							 WHEN @FilterBy = 2 AND sub.checktime IS NULL THEN sub.transdate
						   END BETWEEN @MinFromTime AND @FilterToTransTime
				    AND (1 = CASE WHEN @SubIssueTypeId NOT IN (1,2) THEN 1
						ELSE CASE WHEN (@IsCheckedHomeTeam = 0 AND @IsCheckedAwayTeam = 0) OR (@IsCheckedHomeTeam = 1 AND @IsCheckedAwayTeam = 1) THEN 1
										WHEN @IsCheckedAwayTeam = 1 AND sub.bettype NOT IN (401,403,407,482,484,461,463) THEN 1 
										WHEN @IsCheckedHomeTeam = 1 AND sub.bettype NOT IN (402,404,409,483,485,462,464) THEN 1
										ELSE 0 END
						END)
		END 
		
		UPDATE b
		SET typeaccept = CASE WHEN b.transdate = b.checktime THEN 1 --Auto Accept
							  WHEN ISNULL(b.checktime,0) = DATEADD(SECOND,ISNULL(bi.LiveBetAcceptTime,0),DATEADD( SECOND,ISNULL(bi.SecAcceptTime,0),b.transdate)) THEN 2 --Second Accept
							  WHEN ISNULL(b.checktime,0) ! = DATEADD(SECOND,ISNULL(bi.LiveBetAcceptTime,0),DATEADD( SECOND,ISNULL(bi.SecAcceptTime,0),b.transdate)) THEN 3 --Pending Accept
						 END
		FROM #tblTransIdTemp b
			LEFT JOIN dbo.BettransInfo bi WITH(NOLOCK) ON b.transid = bi.transid

		INSERT INTO #tblGroupTypeAccept (TypeAccept , MinTicket )
		SELECT typeaccept, MIN(CASE WHEN @FilterBy = 1 THEN transdate 
									WHEN @FilterBy = 2 AND checktime IS NOT NULL THEN checktime 
									WHEN @FilterBy = 2 AND checktime IS NULL THEN transdate 
									END )
		FROM #tblTransIdTemp 
		WHERE CASE WHEN @FilterBy = 1 THEN transdate
				   WHEN @FilterBy = 2 AND checktime IS NOT NULL THEN checktime
				   WHEN @FilterBy = 2 AND checktime IS NULL THEN transdate
				END BETWEEN @MinFromTime AND @MaxFromTime
		GROUP BY typeaccept

		DELETE FROM #tblGroupTypeAccept 
		WHERE 1 = CASE WHEN typeaccept = 1 AND MinTicket < @AutoAcceptTime THEN 1
					   WHEN typeaccept = 2 AND MinTicket < @SecondAcceptTime THEN 1
					   WHEN typeaccept = 3 AND MinTicket < @PendingAcceptTime THEN 1
					   ELSE 0 END

		SELECT @MinTicketFromTime = MIN(MinTicket) 
		FROM #tblGroupTypeAccept

		IF (@MinTicketFromTime IS NOT NULL)
		BEGIN
			DELETE FROM  #tblTransIdTemp 
			WHERE CASE WHEN @FilterBy = 1 THEN transdate
					   WHEN @FilterBy = 2 AND checktime IS NOT NULL THEN checktime
					   WHEN @FilterBy = 2 AND checktime IS NULL THEN transdate
					END < @MinTicketFromTime

			SELECT @VoidFromTime = @MinTicketFromTime
		END
		ELSE
		BEGIN
			SELECT @MinTicketFromTime = MIN(CASE WHEN @FilterBy = 1 THEN transdate 
												 WHEN @FilterBy = 2 AND checktime IS NOT NULL THEN checktime 
												 WHEN @FilterBy = 2 AND checktime IS NULL THEN transdate 
											END)
			FROM #tblTransIdTemp 
			WHERE CASE WHEN @FilterBy = 1 THEN transdate
					   WHEN @FilterBy = 2 AND checktime IS NOT NULL THEN checktime
					   WHEN @FilterBy = 2 AND checktime IS NULL THEN transdate
					END >= @MaxFromTime

			DELETE FROM  #tblTransIdTemp 
			WHERE CASE WHEN @FilterBy = 1 THEN transdate
					   WHEN @FilterBy = 2 AND checktime IS NOT NULL THEN checktime
					   WHEN @FilterBy = 2 AND checktime IS NULL THEN transdate
					END < @MaxFromTime

			SELECT @VoidFromTime = @MinTicketFromTime
		END

	END
	IF NOT EXISTS (SELECT TOP 1 1 FROM #tblTransIdTemp )
	BEGIN
		SELECT  @VoidFromTime = NULL
			   ,@VoidToTime = NULL
	END 

	SELECT @VoidFromTime AS VoidFromTime
		  ,@VoidToTime AS VoidToTime

	DROP TABLE #tblTransIdTemp
	DROP TABLE #tblGroupTypeAccept

END
GO