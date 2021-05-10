/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_VoidTime_Select]
(	
	 @MatchId             INT
	,@FilterFromTransTime DATETIME = NULL
	,@FilterToTransTime	  DATETIME = NULL
	,@FilterBy			  TINYINT = 1
	,@IssueTypeId		  INT = 1
	,@SubIssueTypeId	  INT = NULL
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
		- 20210506@July: TVS - Danger Accept Enhancement - Phase 8 [Redmine: #152051]

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
																				  ELSE @PATime --act.AcceptType = 3
																			 END
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
							WHEN b.checktime IS NULL THEN 1 --Auto Accept
							ELSE CASE 
									  WHEN b.checktime = DATEADD(SECOND,ISNULL(b.LiveBetAcceptTime,0) + ISNULL(b.SecAcceptTime,0), b.transdate) THEN 2 --Second Accept
									  ELSE 3 --Pending Accept
								 END
						END AS AcceptType
					  ,CASE 
							WHEN @FilterBy = 1 THEN b.transdate
							WHEN @FilterBy = 2 AND b.checktime IS NOT NULL THEN b.checktime
							WHEN @FilterBy = 2 AND b.checktime IS NULL THEN b.transdate
					   END AS FromDate
		)act
		INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
		WHERE act.FromDate BETWEEN @VoidFromTime AND @FilterToTransTime
			AND 1 =  CASE WHEN @SubIssueTypeId IN (55,57,60,68,70,83,87,90) AND b.bettype NOT IN (402,404,409,483,485,462,464) THEN 1 --IsCheckedHomeTeam
						  WHEN @SubIssueTypeId IN (56,58,61,69,71,84,88,91) AND b.bettype NOT IN (401,403,407,482,484,461,463) THEN 1 --IsCheckedAwayTeam
						 ELSE 1
					 END

		IF @VoidFromTime IS NULL
		BEGIN
			SELECT @VoidFromTime = NULL ,@VoidToTime = NULL
		END

		SELECT @VoidFromTime AS VoidFromTime
			  ,@VoidToTime AS VoidToTime
	END
END
GO