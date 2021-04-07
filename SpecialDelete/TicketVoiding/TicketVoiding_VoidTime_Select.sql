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
	
	DECLARE @MinAccept			TINYINT = 0	
	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)

	SELECT 	@VoidFromTime = NULL, @VoidToTime = NULL

	IF @IssueTypeId = 1 -- Danger Accept
	BEGIN
		SELECT @MinAccept = @AATime

		IF @MinAccept > @PATime SET @MinAccept = @PATime
		IF @MinAccept > @SATime SET @MinAccept = @SATime

		SELECT @VoidFromTime = DATEADD (SECOND,@MinAccept,@FilterFromTransTime)
			   
		INSERT INTO @bettype_tmp (bettype)
		SELECT DISTINCT pt.bettype
		FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
		WHERE pt.ProductID = 1 -- Sportsbook
			AND pt.bettype NOT IN (10, 9, 29) -- outright, parlay
			AND pt.bettype NOT BETWEEN 221 AND 227 -- Fast Market
			AND pt.SubProduct NOT IN ('Bet Builder', 'MG-SuperLive', 'BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet Builder, Metric Gaming, Bet trade (BT-)

		SELECT @VoidFromTime = MIN(CASE WHEN act.FromDate >= DATEADD (SECOND,CASE WHEN act.AcceptType = 1 THEN @AATime
																				 WHEN act.AcceptType = 2 THEN @SATime
																				 WHEN act.AcceptType = 3 THEN @PATime
																				 ELSE NULL END
																			,@FilterFromTransTime
																		  )
			
											 THEN act.FromDate ELSE NULL END
										)
			  ,@VoidToTime = MAX(act.FromDate)
		FROM (
			SELECT b.transid, NULL AS subtransid, b.bettype, b.transdate, b.checktime, bi.LiveBetAcceptTime, bi.SecAcceptTime
			FROM dbo.bettrans b WITH(NOLOCK) 
				LEFT JOIN dbo.BettransInfo bi WITH(NOLOCK) ON b.transid = bi.transid
			WHERE b.matchid = @MatchId
			UNION ALL
			SELECT NULL AS transid, bm.transid AS subtransid, bm.bettype, bm.transdate, bm.checktime, bm.LiveBetAcceptTime, bm.SecAcceptTime
			FROM dbo.bettransm bm WITH(NOLOCK)
			WHERE bm.matchid = @MatchId
		)b
		CROSS APPLY (
				SELECT CASE 
							WHEN b.transdate = b.checktime THEN 1 --Auto Accept
							WHEN ISNULL(b.checktime,0) = DATEADD(SECOND,ISNULL(b.LiveBetAcceptTime,0),DATEADD( SECOND,ISNULL(b.SecAcceptTime,0),b.transdate)) THEN 2 --Second Accept
							WHEN ISNULL(b.checktime,0) != DATEADD(SECOND,ISNULL(b.LiveBetAcceptTime,0),DATEADD( SECOND,ISNULL(b.SecAcceptTime,0),b.transdate)) THEN 3 --Pending Accept
						END AS AcceptType
					  ,CASE 
							WHEN @FilterBy = 1 THEN b.transdate
							WHEN @FilterBy = 2 AND b.checktime IS NOT NULL THEN b.checktime
							WHEN @FilterBy = 2 AND b.checktime IS NULL THEN b.transdate
					   END AS FromDate
		)act
		INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
		WHERE act.FromDate BETWEEN @VoidFromTime AND @FilterToTransTime
			AND (1 = CASE WHEN @SubIssueTypeId NOT IN (1,2) THEN 1
						ELSE CASE WHEN (@IsCheckedHomeTeam = 0 AND @IsCheckedAwayTeam = 0) OR (@IsCheckedHomeTeam = 1 AND @IsCheckedAwayTeam = 1) THEN 1
										WHEN @IsCheckedAwayTeam = 1 AND b.bettype NOT IN (401,403,407,482,484,461,463) THEN 1 
										WHEN @IsCheckedHomeTeam = 1 AND b.bettype NOT IN (402,404,409,483,485,462,464) THEN 1
										ELSE 0 END
						END
			  )

		IF @VoidFromTime IS NULL
		BEGIN
			SELECT @VoidFromTime = NULL ,@VoidToTime = NULL
		END

		SELECT @VoidFromTime AS VoidFromTime
			  ,@VoidToTime AS VoidToTime
	END
END
GO