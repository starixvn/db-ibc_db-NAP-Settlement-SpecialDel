/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Rpt_TicketsListing] 
	@MatchId			INT
	,@LicenseeId		INT
	,@BetTypes			VARCHAR(1000)	= ''	
	,@LiveType			SMALLINT 		= 2
	,@LiveHomeScore		SMALLINT 		= NULL
	,@LiveAwayScore		SMALLINT 		= NULL
	,@FromTransdate		DATETIME 		= NULL
	,@ToTransdate		DATETIME 		= NULL
	,@Type				SMALLINT 		= 0
	,@SecondAcceptFlag	TINYINT			= 0
	,@BallSequence		VARCHAR(200)	= ''
	,@ErrCode			INT				= 0 OUTPUT
	,@ErrMsg			VARCHAR(1000)	= '' OUTPUT
WITH RECOMPILE
AS
/*	Created by: Elodie
	Date: 20130606
	Task: Show Tickets Listing for NAP system
	DB: DBACC/bodb02
	Original: Acc_Rpt_TicketListing
	
	Revisions:	
		- 20130910@Kathy: Rename parameter @SAFilter to @SecondAcceptFlag
		- 20131129@Kathy: Add HR Fixed Odds (154) [Redmine:#6505]
		- 20131203@Kathy: Add @showtime column.
						Using Dep_CustSuper table instead of f_DepSuper_1() function.
		- 20141021@Kathy: Consolidate Sportting Solution and IBC bettypes [Redmine:#23129]
		- 20150401@Dominic: Add new parent-child bettypes [Redmine:#27214]
		- 20150623@Dominic: Add Metric Gaming Super Live [Redmine:#38200]
		- 20150401@Kathy: Add new parent-child bettypes for PH [Redmine:#48110]
		- 20150119@Kathy: Changes parent-child for phase 1.2 of PH All in One:  [Redmine:#50932]	  
		- 20160722@Bobby: #61240 - Implement parent-child for PHAIO new 19 bet types
		- 20170414@Kent: Fix IBC to MBC [Redmine:#75009]
		- 20170530@Kent: Integrate Betradar Virtual Sports [Redmine:#77177]
		- 20170718@Paul: Integrate Lucky 3 [Redmine:#77175]
		- 20170918@Kent: Add New Bettypes Decimal Only 461, 462, 463, 464 [Redmine:#83255]
		- 20171009@Kent: PH AIO Phase 3 [Redmine:#83737]
		- 20171215@Kent: Number Game Ball Sequence [Redmine:#54346]
		
	Param's Explanation:
	- @Type: sports type
		0: Sportsbook
		1: Number Game
		2: Virtual sports
		3: Live casino
		4: Metric Gaming Super Live
		5: Virtual sports betradar
		6: Lucky 3
	- @LicenseeID:
	  + =0: No Site filter
	  + >0: Filter by specific Licensee's ID
	  + -1: Filter by IBC sites (Non-Licensee sites)
	- @BetTypes: String of bettype for Sportsbook, Virtual sports and for Dead Ball - Number game, Live casino	 
	- @LiveType: Combo Type, used only for Sportsbook
		0: Dead ball
		1: Live ball
		2: All	
	- Because the interface is separated with sportbook and number game
		==>	SportsBook: Use @BetTypes and @LiveType to indicate Live ball or Dead ball
			Number game: Use @BetTypes and @BetTypesLive to indicate Live ball or Dead ball
			Virtual sports: Use @BetTypes to indicate Dead ball
    - @SecondAcceptFlag: 
      + 0: All tickets
      + 1: Normal tickets only
      + 2: SA tickets only	  
      
    Example:	declare @p12 int
				set @p12=0
				declare @p13 varchar(1000)
				set @p13=''
								exec NAP_Rpt_TicketsListing @MatchId=4626986,@LicenseeID=0,@BetTypes='1101,1102',@BetTypesLive='',@LiveType=2,@LiveHomeScore=default,@LiveAwayScore=default,@FromTransdate=default,@ToTransdate=default,@Type=3,@SecondAcceptFlag=0,@ErrCode=@p12 output,@ErrMsg=@p13 output
				select @p12, @p13		
*/
BEGIN
	SET NOCOUNT ON

	--- Check MatchID
	DECLARE @matchcode	NVARCHAR(100)
		,@homeid 		INT
		,@awayid 		INT
		,@eventdate 	DATETIME
		,@IsNeutral 	BIT
		,@sporttype 	SMALLINT
		,@showtime		NVARCHAR(50)

	SET @sporttype = 0

	---- If not sportbook then don't care @livetype , so set @LiveType to 2 (All)
	IF @Type <> 0
		SELECT @LiveType = 2

	----Show match description
	SELECT @matchcode	= matchcode
		,@homeid 		= homeid
		,@awayid 		= awayid
		,@eventdate 	= eventdate
		,@IsNeutral 	= IsNeutral
		,@sporttype 	= sporttype
		,@showtime		= showtime
	FROM match WITH (NOLOCK)
	WHERE matchid = @MatchId

	IF ISNULL(@sporttype, 0) = 0 
	   OR ( 
			@sporttype > 99 
			AND @sporttype <> 154 
			AND @sporttype <> 161 
			AND @sporttype <> 162 
			AND @sporttype NOT BETWEEN 180 AND 186
			AND @sporttype NOT BETWEEN 190 AND 199
			AND @sporttype <> 160
		  )
	BEGIN
		SET @ErrCode = 1
		SET @ErrMsg = 'Invalid MatchID.'

		RETURN
	END
	ELSE IF @sporttype > 99
		AND @sporttype <> 154
		AND @Type IN (0,4)
	BEGIN
		SET @ErrCode = 2
		SET @ErrMsg = 'This MatchID is not sportsbook.'

		RETURN
	END
	ELSE IF @sporttype <> 161
		AND @Type = 1
	BEGIN
		SET @ErrCode = 3
		SET @ErrMsg = 'This MatchID is not number game.'

		RETURN
	END
	ELSE IF @sporttype NOT BETWEEN 180 AND 186
		AND @Type = 2
	BEGIN
		SET @ErrCode = 4
		SET @ErrMsg = 'This MatchID is not virtual sports.'

		RETURN
	END
	ELSE IF @sporttype NOT BETWEEN 190 AND 199
		AND @Type = 5
	BEGIN
		SET @ErrCode = 5
		SET @ErrMsg = 'This MatchID is not virtual sports betradar.'

		RETURN
	END	
	ELSE IF @sporttype <> 160
		AND @Type = 6
	BEGIN
		SET @ErrCode = 6
		SET @ErrMsg = 'This MatchID is not Lucky 3.'

		RETURN
	END
	ELSE
		SELECT @matchcode	AS matchcode
			,@homeid		AS homeid
			,@awayid		AS awayid
			,convert(VARCHAR(12), @eventdate, 107) AS eventdate
			,@MatchId		AS matchid
			,@IsNeutral		AS IsNeutral
			,@showtime		AS showtime

	---------
	DECLARE @TmpTotal TABLE (
		OrderNo			INT
		,TotalTrans		BIGINT
		,bettype		SMALLINT
		,LiveIndicator	BIT
		,LicenseeName	VARCHAR(50)
		)

	CREATE TABLE #TmpBettrans (
		srecommend		INT
		,bettype		SMALLINT
		,liveindicator	BIT
		,statusID		TINYINT
		,matchid		INT
		,cnt			INT
		)
		
	CREATE TABLE #TmpBallSequence (	
		Seq			TINYINT
	)
	
	
	DECLARE @tmpConsolidatedBettypes TABLE (
		parentid	INT
		,typeid		INT
		)

	INSERT INTO @tmpConsolidatedBettypes
	SELECT f.GroupTypeId AS parentid
		 , f.Bettype AS typeid
    FROM [dbo].[f_GroupBettype] () f
    WHERE f.Bettype NOT IN (187, 179) 		
	
	IF @Type = 1 -- FOR Number Game Only
	BEGIN
		INSERT INTO #TmpBallSequence(Seq)
		SELECT  val
		FROM	dbo.f_SplitString(@BallSequence, ',')
		OPTION (maxrecursion 0)	
	
		INSERT INTO #TmpBettrans (srecommend,bettype,liveindicator,statusID,matchid,cnt)
		SELECT b.srecommend
			,b.bettype
			,b.liveindicator
			,b.statusID
			,b.matchid
			,COUNT(b.transid) cnt
		FROM dbo.bettrans b WITH (NOLOCK)
			LEFT JOIN [dbo].[bingoBall] bb WITH (NOLOCK) ON bb.matchid = b.matchid AND bb.Number = b.betid AND b.bettype IN (85, 86, 87, 89, 90)
			OUTER APPLY (SELECT BallSequence 
						FROM dbo.f_SD_GetBallSequence (b.bettype,b.betteam,b.betid,bb.Seq)
						WHERE b.bettype IN (85, 86, 87, 88, 89, 90)
						) AS BS_tmp
						
		WHERE b.matchid = @MatchId
			AND statusID NOT IN (101, 102, 121) --('Void', 'Reject', 'Dummy')
			AND (			
					bettype IN (
						SELECT CONVERT(INT, val)
						FROM dbo.strSplit(@BetTypes, ',')
						)
					AND CASE 
					WHEN @LiveType <> 2 THEN liveindicator
					ELSE 0 END = CASE 
					WHEN @LiveType <> 2 THEN @LiveType
					ELSE 0 END
					AND livehomescore = CASE 
					WHEN @LiveHomeScore IS NOT NULL
						AND @LiveType = 1 THEN @LiveHomeScore
					ELSE livehomescore END
					AND liveawayscore = CASE 
					WHEN @LiveAwayScore IS NOT NULL
						AND @LiveType = 1 THEN @LiveAwayScore
					ELSE liveawayscore END
					AND transdate BETWEEN CASE 
								WHEN @FromTransdate IS NOT NULL
									AND @LiveType = 1 THEN @FromTransdate
								ELSE transdate
								END
						AND CASE 
								WHEN @ToTransdate IS NOT NULL
									AND @LiveType = 1 THEN @ToTransdate
								ELSE transdate
								END				
				)
			AND ISNULL(SecAcceptFlag, 0) = CASE @SecondAcceptFlag
				WHEN 0 THEN ISNULL(SecAcceptFlag, 0)
				WHEN 1 THEN 0
				WHEN 2 THEN 1
				END
			AND EXISTS (SELECT TOP 1 1
						 FROM #TmpBallSequence WITH (NOLOCK)
						 WHERE Seq = BS_tmp.BallSequence)
			
		GROUP BY b.srecommend
			,b.matchid
			,b.bettype
			,b.liveindicator
			,b.statusid
	END
	ELSE -- For Others
	BEGIN
		INSERT INTO #TmpBettrans (srecommend,bettype,liveindicator,statusID,matchid,cnt)
		SELECT srecommend
			,bettype
			,liveindicator
			,statusID
			,matchid
			,COUNT(transid) cnt
		FROM (
			SELECT b.srecommend
				,b.bettype
				,b.liveindicator
				,b.statusID
				,b.matchid
				,b.transid
			FROM dbo.bettrans b WITH (NOLOCK)
			WHERE b.matchid = @MatchId
				AND statusID NOT IN (101, 102, 121) --('Void', 'Reject', 'Dummy')
				AND (			
						bettype IN (
							SELECT CONVERT(INT, val)
							FROM dbo.strSplit(@BetTypes, ',')
							)
						AND CASE 
						WHEN @LiveType <> 2 THEN liveindicator
						ELSE 0 END = CASE 
						WHEN @LiveType <> 2 THEN @LiveType
						ELSE 0 END
						AND livehomescore = CASE 
						WHEN @LiveHomeScore IS NOT NULL
							AND @LiveType = 1 THEN @LiveHomeScore
						ELSE livehomescore END
						AND liveawayscore = CASE 
						WHEN @LiveAwayScore IS NOT NULL
							AND @LiveType = 1 THEN @LiveAwayScore
						ELSE liveawayscore END
						AND transdate BETWEEN CASE 
									WHEN @FromTransdate IS NOT NULL
										AND @LiveType = 1 THEN @FromTransdate
									ELSE transdate
									END
							AND CASE 
									WHEN @ToTransdate IS NOT NULL
										AND @LiveType = 1 THEN @ToTransdate
									ELSE transdate
									END				
					)
				AND ISNULL(SecAcceptFlag, 0) = CASE @SecondAcceptFlag
					WHEN 0 THEN ISNULL(SecAcceptFlag, 0)
					WHEN 1 THEN 0
					WHEN 2 THEN 1
					END
					
			UNION ALL
			
			SELECT bl.srecommend
				,bl.GameID bettype
				,bl.liveindicator
				,bl.statusID
				,bl.EventID matchid
				,bl.translogid transid
			FROM translog bl WITH (NOLOCK)
				LEFT JOIN bettrans b WITH(NOLOCK) ON bl.gameid = b.bettype AND b.matchid = bl.eventid AND b.custid = bl.Custid AND bl.translogid = b.refno
			WHERE EventID = @MatchId
				AND GameID IN (
							801,803,804,805,806 -- MEtric Gaming SUper Live
							)
				AND bl.statusID NOT IN (101, 102, 121) --('Void', 'Reject', 'Dummy')
				AND GameID IN (
							SELECT CONVERT(INT, val)
							FROM dbo.strSplit(@BetTypes, ',')
							)
				AND b.refno IS NULL
				AND CASE 
						WHEN @LiveType <> 2 THEN bl.liveindicator
						ELSE 0 END = CASE 
						WHEN @LiveType <> 2 THEN @LiveType
						ELSE 0 
					END	
		) tmp	
		GROUP BY srecommend
			,matchid
			,bettype
			,liveindicator
			,statusid
	END

	----## Direct Licensee
	IF @LicenseeID <> 0
		AND @LicenseeID <> - 1
	BEGIN
		DECLARE @LicenseeName VARCHAR(100)

		SET @LicenseeName = ''

		SELECT @LicenseeName = site
		FROM site WITH (NOLOCK)
		WHERE isLicensee = 1
			AND isActive = 1
			AND siteID NOT IN (29, 35)
			AND siteID = @LicenseeID

		IF @BetTypes <> '9'
			AND @BetTypes <> '29'
			AND @BetTypes <> '2799'
			AND @BetTypes <> '9,29,2799'
			INSERT INTO @TmpTotal (
				OrderNo
				,TotalTrans
				,bettype
				,LiveIndicator
				,LicenseeName
				)
			SELECT 1 AS OrderNo
				,sum(cnt) AS TotalTrans
				,bettype
				,CASE 
					WHEN @type = 1 THEN liveindicator
					ELSE 0
					END
				,--- because liveindicator only use for indicate live or dead ball of number game. So the sportsbook don't care.
				@LicenseeName AS LicenseeName
			FROM #TmpBettrans WITH (NOLOCK)
			WHERE srecommend IN (
					SELECT custid
					FROM dbo.Dep_CustSuper WITH (NOLOCK)
					WHERE site = @LicenseeName
					)
			GROUP BY bettype
				,LiveIndicator

		---mix parlay
		IF charindex('9', @BetTypes, 1) <> 0
		   OR charindex('2799', @BetTypes, 1) <> 0
			INSERT INTO @TmpTotal (
				OrderNo
				,TotalTrans
				,bettype
				,LiveIndicator
				,LicenseeName
				)
			SELECT 1 AS OrderNo
				,Count(b.transid) AS TotalTrans
				,b.bettype
				,0
				,@LicenseeName AS LicenseeName
			FROM bettransm bm WITH (NOLOCK)
				INNER JOIN Bettrans b WITH (NOLOCK) ON bm.refno = b.refno
				INNER JOIN dbo.strSplit(@BetTypes, ',') t ON b.bettype = t.val
			WHERE b.srecommend IN (
					SELECT custid
					FROM dbo.Dep_CustSuper WITH (NOLOCK)
					WHERE site = @LicenseeName
					)
				AND bm.matchid = @MatchId
				AND b.statusID NOT IN (101, 102) --('Void', 'Reject')
				AND b.bettype IN (9, 29, 2799)
				AND b.matchid IN (9, 29, 2799)
				AND CASE 
					WHEN @LiveType <> 2 THEN bm.liveindicator
					ELSE 0
					END = CASE 
					WHEN @LiveType <> 2 THEN @LiveType
					ELSE 0
					END
				AND bm.livehomescore = CASE 
					WHEN @LiveHomeScore IS NOT NULL
						AND @LiveType = 1 THEN @LiveHomeScore
					ELSE bm.livehomescore
					END
				AND bm.liveawayscore = CASE 
					WHEN @LiveAwayScore IS NOT NULL
						AND @LiveType = 1 THEN @LiveAwayScore
					ELSE bm.liveawayscore
					END
				AND bm.transdate BETWEEN CASE 
							WHEN @FromTransdate IS NOT NULL
								AND @LiveType = 1 THEN @FromTransdate
							ELSE bm.transdate
							END
					AND CASE 
							WHEN @ToTransdate IS NOT NULL
								AND @LiveType = 1 THEN @ToTransdate
							ELSE bm.transdate
							END
				AND ISNULL(SecAcceptFlag, 0) = CASE @SecondAcceptFlag
					WHEN 0 THEN ISNULL(SecAcceptFlag, 0)
					WHEN 1 THEN 0
					WHEN 2 THEN 1
					END
				AND (
					b.betid = 0
					OR b.betid IS NULL
					)
			GROUP BY b.bettype
				,bm.liveIndicator
			HAVING Count(b.Refno) > 0
	END

	----## IBC Group
	IF @LicenseeID = - 1
	BEGIN
		IF @BetTypes <> '9'
			AND @BetTypes <> '29'
			AND @BetTypes <> '2799'
			AND @BetTypes <> '9,29,2799'
			INSERT INTO @TmpTotal (
				OrderNo
				,TotalTrans
				,bettype
				,LiveIndicator
				,LicenseeName
				)
			SELECT 0 AS OrderNo
				,sum(cnt) AS TotalTrans
				,bettype
				,CASE 
					WHEN @type = 1 THEN b.liveindicator
					ELSE 0
					END
				,'MBC' AS LicenseeName
			FROM #TmpBettrans b WITH (NOLOCK)
			WHERE b.srecommend NOT IN (
					SELECT custid
					FROM dbo.Dep_CustSuper WITH (NOLOCK)
					)
			GROUP BY b.bettype
				,b.liveindicator

		---mix parlay
		IF charindex('9', @BetTypes, 1) <> 0
		   OR charindex('2799', @BetTypes, 1) <> 0
			INSERT INTO @TmpTotal (
				OrderNo
				,TotalTrans
				,bettype
				,LiveIndicator
				,LicenseeName
				)
			SELECT 0 AS OrderNo
				,Count(DISTINCT b.transid) AS TotalTrans
				,b.bettype
				,0
				,'MBC' AS LicenseeName
			FROM bettransm bm WITH (NOLOCK)
				INNER JOIN Bettrans b WITH (NOLOCK) ON bm.refno = b.refno
				INNER JOIN dbo.strSplit(@BetTypes, ',') t ON b.bettype = t.val
			WHERE b.srecommend NOT IN (
					SELECT custid
					FROM dbo.Dep_CustSuper WITH (NOLOCK)
					)
				AND bm.matchid = @MatchId
				AND b.statusID NOT IN (101, 102) ---('Void', 'Reject')
				AND b.bettype IN (9, 29, 2799)
				AND b.matchid IN (9, 29, 2799)
				AND CASE 
					WHEN @LiveType <> 2 THEN bm.liveindicator
					ELSE 0
					END = CASE 
					WHEN @LiveType <> 2 THEN @LiveType
					ELSE 0
					END
				AND bm.livehomescore = CASE 
					WHEN @LiveHomeScore IS NOT NULL
						AND @LiveType = 1 THEN @LiveHomeScore
					ELSE bm.livehomescore
					END
				AND bm.liveawayscore = CASE 
					WHEN @LiveAwayScore IS NOT NULL
						AND @LiveType = 1 THEN @LiveAwayScore
					ELSE bm.liveawayscore
					END
				AND bm.transdate BETWEEN CASE 
							WHEN @FromTransdate IS NOT NULL
								AND @LiveType = 1 THEN @FromTransdate
							ELSE bm.transdate
							END
					AND CASE 
							WHEN @ToTransdate IS NOT NULL
								AND @LiveType = 1 THEN @ToTransdate
							ELSE bm.transdate
							END
				AND ISNULL(SecAcceptFlag, 0) = CASE @SecondAcceptFlag
					WHEN 0 THEN ISNULL(SecAcceptFlag, 0)
					WHEN 1 THEN 0
					WHEN 2 THEN 1
					END
				AND (
					b.betid = 0
					OR b.betid IS NULL
					)
			GROUP BY b.bettype
				,bm.liveIndicator
			HAVING Count(B.Refno) > 0
	END

	-----## All 
	IF @LicenseeID = 0
	BEGIN
		IF @BetTypes <> '9'
			AND @BetTypes <> '29'
			AND @BetTypes <> '2799'
			AND @BetTypes <> '9,29,2799'
			INSERT INTO @TmpTotal (
				OrderNo
				,TotalTrans
				,bettype
				,LiveIndicator
				,LicenseeName
				)
			SELECT CASE 
					WHEN s.site IS NULL THEN 0
					ELSE 1
					END OrderNo
				,sum(cnt) AS TotalTrans
				,bettype
				,CASE 
					WHEN @type = 1 THEN b.liveindicator
					ELSE 0
					END
				,CASE 
					WHEN s.site IS NULL THEN 'MBC'
					ELSE s.site
					END AS LicenseeName
			FROM #TmpBettrans b WITH (NOLOCK)
				LEFT JOIN Customer c WITH (NOLOCK) ON b.srecommend = c.custid
				LEFT JOIN site s WITH (NOLOCK) ON s.site = c.Site
				AND s.isLicensee = 1
				AND s.isActive = 1
				AND s.siteID NOT IN (29, 35)
			WHERE matchid = @MatchId
			GROUP BY b.bettype
				,b.liveindicator
				,s.site

		---mix parlay
		IF charindex('9', @BetTypes, 1) <> 0
		   OR charindex('2799', @BetTypes, 1) <> 0
			INSERT INTO @TmpTotal (
				OrderNo
				,TotalTrans
				,bettype
				,LiveIndicator
				,LicenseeName
				)
			SELECT CASE 
					WHEN s.site IS NULL THEN 0
					ELSE 1
					END OrderNo
				,Count(DISTINCT b.transid) AS TotalTrans
				,b.bettype
				,0
				,CASE 
					WHEN s.site IS NULL THEN 'MBC'
					ELSE s.site
					END AS LicenseeName
			FROM bettransm bm WITH (NOLOCK)
				INNER JOIN Bettrans b WITH (NOLOCK) ON bm.refno = b.refno
				INNER JOIN dbo.strSplit(@BetTypes, ',') t ON b.bettype = t.val
				LEFT JOIN Customer c WITH (NOLOCK) ON b.srecommend = c.custid
				LEFT JOIN site s WITH (NOLOCK) ON s.site = c.Site
				AND s.isLicensee = 1
				AND s.isActive = 1
				AND s.siteID NOT IN (29, 35)
			WHERE bm.matchid = @MatchId
				AND b.bettype IN (9, 29, 2799)
				AND b.matchid IN (9, 29, 2799)
				AND b.statusID NOT IN (101, 102) -- ('Void', 'Reject')
				AND CASE 
					WHEN @LiveType <> 2 THEN bm.liveindicator
					ELSE 0
					END = CASE 
					WHEN @LiveType <> 2 THEN @LiveType
					ELSE 0
					END
				AND bm.livehomescore = CASE 
					WHEN @LiveHomeScore IS NOT NULL
						AND @LiveType = 1 THEN @LiveHomeScore
					ELSE bm.livehomescore
					END
				AND bm.liveawayscore = CASE 
					WHEN @LiveAwayScore IS NOT NULL
						AND @LiveType = 1 THEN @LiveAwayScore
					ELSE bm.liveawayscore
					END
				AND bm.transdate BETWEEN CASE 
							WHEN @FromTransdate IS NOT NULL
								AND @LiveType = 1 THEN @FromTransdate
							ELSE bm.transdate
							END
					AND CASE 
							WHEN @ToTransdate IS NOT NULL
								AND @LiveType = 1 THEN @ToTransdate
							ELSE bm.transdate
							END
				AND ISNULL(SecAcceptFlag, 0) = CASE @SecondAcceptFlag
					WHEN 0 THEN ISNULL(SecAcceptFlag, 0)
					WHEN 1 THEN 0
					WHEN 2 THEN 1
					END
				AND (
					b.betid = 0
					OR b.betid IS NULL
					)
			GROUP BY s.site
				,bm.liveindicator
				,b.bettype
	END

	UPDATE t
	SET t.bettype = c.parentid
	FROM @TmpTotal t
		LEFT JOIN @tmpConsolidatedBettypes c ON c.typeid = t.bettype
	WHERE c.parentid IS NOT NULL

	SELECT SUM(TotalTrans) TotalTrans
		,OrderNo
		,bettype AS 'bettypeId'
		,LiveIndicator
		,LicenseeName
	FROM @TmpTotal
	GROUP BY OrderNo
		,LicenseeName
		,bettype
		,LiveIndicator
	ORDER BY OrderNo
		,LicenseeName
		,bettype
		,LiveIndicator

	DROP TABLE #TmpBettrans
	DROP TABLE #TmpBallSequence
	
END
GO