/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_VoidTime_Select]
(	
	 @GetVoidTimeInfo	VARCHAR(MAX) = ''
	 ,@ActionId			INT = 5
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
		- 20210526@Max: [TVS] Danger Accept Enhancement - Phase 9 [Redmine: #153216]
		- 20210628@Max: [TVS] Submit new allowance setting for Main Match [Redmine: #157226]
		- 20210722@Max: [TVS HF] Exclude Cash-Out tickets from Void Time Calculation [Redmine: #158294]

	Param's explanation:
		+ GetVoidTimeInfo:
			<root>
				<r MatchId="0" FilterFromTransTime="1" FilterToTransTime ="" FilterBy="" SubIssueTypeId="" AATime="" PATime="" SATime=""/>
			</root>
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @MinAccept			TINYINT		= 0	
		, @GetVoidTimeInfoXML	XML			= NULL
		, @VoidFromTime			DATETIME	= NULL
		, @VoidToTime			DATETIME	= NULL
		, @MatchId				INT			= 0
		, @FilterFromTransTime	DATETIME	= NULL
		, @FilterToTransTime	DATETIME	= NULL
		, @FilterBy				TINYINT		= 1
		, @SubIssueTypeId		INT			= NULL
		, @AATime				TINYINT		= 0 
		, @PATime				TINYINT		= 0
		, @SATime				TINYINT		= 0

	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)
	DECLARE @Match_VoidTime AS TABLE (MatchId INT, VoidFromTime DATETIME, VoidToTime DATETIME)

	CREATE TABLE #Match_Filter (
		MatchId INT
		, FilterFromTransTime DATETIME
		, FilterToTransTime DATETIME
		, FilterBy TINYINT
		, SubIssueTypeId SMALLINT
		, AATime TINYINT
		, PATime TINYINT
		, SATime TINYINT
		, isFinish BIT
	)

	SET @GetVoidTimeInfoXML = CONVERT(XML, @GetVoidTimeInfo)
	INSERT INTO #Match_Filter(MatchId, FilterFromTransTime, FilterToTransTime, FilterBy, SubIssueTypeId, AATime, PATime, SATime)
	SELECT T.C.value('./@MatchId', 'INT')
		,T.C.value('./@FilterFromTransTime', 'DATETIME')
		,T.C.value('./@FilterToTransTime', 'DATETIME')
		,T.C.value('./@FilterBy', 'TINYINT')
		,T.C.value('./@SubIssueTypeId', 'SMALLINT')
		,T.C.value('./@AATime', 'TINYINT')
		,T.C.value('./@PATime', 'TINYINT')
		,T.C.value('./@SATime', 'TINYINT')
	FROM @GetVoidTimeInfoXML.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@GetVoidTimeInfoXML = NULL ))

	INSERT INTO @bettype_tmp (bettype)
	SELECT DISTINCT pt.bettype
	FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
	WHERE pt.ProductID = 1 -- Sportsbook
		AND pt.bettype NOT IN (10, 9, 29) -- outright, parlay
		AND pt.bettype NOT BETWEEN 221 AND 227 -- Fast Market
		AND pt.SubProduct NOT IN ('Bet Builder', 'MG-SuperLive', 'BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet Builder, Metric Gaming, Bet trade (BT-)

	WHILE (1=1)
	BEGIN
		SELECT @MinAccept				= 0	
			, @VoidFromTime				= NULL
			, @VoidToTime				= NULL
			, @MatchId					= 0
			, @FilterFromTransTime		= NULL
			, @FilterToTransTime		= NULL
			, @FilterBy					= 1
			, @SubIssueTypeId			= NULL
			, @AATime					= 0 
			, @PATime					= 0
			, @SATime					= 0

		UPDATE TOP(1) m SET
			m.isFinish = 1
			,@MatchId = m.MatchId
			,@FilterFromTransTime = m.FilterFromTransTime
			,@FilterToTransTime = m.FilterToTransTime
			,@FilterBy = m.FilterBy
			,@SubIssueTypeId = m.SubIssueTypeId
			,@AATime = m.AATime
			,@PATime = m.PATime
			,@SATime = m.SATime
		FROM #Match_Filter m
		WHERE m.isFinish IS NULL

		IF @@ROWCOUNT = 0 BREAK;
		
		SELECT @MinAccept = @AATime

		IF @MinAccept > @PATime SET @MinAccept = @PATime
		IF @MinAccept > @SATime SET @MinAccept = @SATime

		SELECT @VoidFromTime = DATEADD (SECOND,@MinAccept,@FilterFromTransTime)

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
			SELECT b.transid, NULL AS subtransid, b.bettype, b.transdate, b.checktime, bi.LiveBetAcceptTime, bi.SecAcceptTime, b.statusID
			FROM dbo.bettrans b WITH(NOLOCK) 
				LEFT JOIN dbo.BettransInfo bi WITH(NOLOCK) ON b.transid = bi.transid
			WHERE b.matchid = @MatchId
				AND b.betfrom <> 'P'
				AND ISNULL(b.betdaqid,-1) NOT IN (1)
			UNION ALL
			SELECT NULL AS transid, bm.transid AS subtransid, bm.bettype, bm.transdate, bm.checktime, bm.LiveBetAcceptTime, bm.SecAcceptTime, bm.statusID
			FROM dbo.bettransm bm WITH(NOLOCK)
			WHERE bm.matchid = @MatchId
				AND bm.betfrom <> 'P'
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
			AND 1 =  CASE WHEN @SubIssueTypeId IN (55,57,60,75,79,82) AND b.bettype NOT IN (402,404,409,462,464) THEN 1 
						  WHEN @SubIssueTypeId IN (68,70) AND b.bettype NOT IN (483,485) THEN 1
						  WHEN @SubIssueTypeId IN (56,58,61,76,80,83) AND b.bettype NOT IN (401,403,407,461,463) THEN 1
						  WHEN @SubIssueTypeId IN (69,71) AND b.bettype NOT IN (482,484) THEN 1 
						  WHEN @SubIssueTypeId IN (1,2,3,4,5,26,59,62,63,64,65,66,67,72,73,74,77,78,81,84,85) THEN 1
						  ELSE 0
					 END
			AND 1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
							 WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
							 ELSE 0 END
		
		IF @VoidFromTime IS NULL
		BEGIN
			SELECT @VoidFromTime = NULL ,@VoidToTime = NULL
		END

		INSERT INTO @Match_VoidTime (MatchId, VoidFromTime, VoidToTime)
		SELECT @MatchId, @VoidFromTime, @VoidToTime
	END

	SELECT MatchId, VoidFromTime, VoidToTime
	FROM @Match_VoidTime

	DROP TABLE #Match_Filter
END
GO