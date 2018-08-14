/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_TicketListing_Summary] 
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
	,@Quarter			VARCHAR(5)		= 'All'
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
		- 20180201@Helen: Change way to get Ball Sequence [Redmine:#90434 ]
		- 20170503@Kent: Integrate bonus [Redmine:#72790]
		- 20171127@Kent: Integrate BullFighting [Redmine:#86832]
		- 20180305@Helen: Betradar VS2 - [Redmine:90153]
		- 20180814@Alan: Rename SP - Filter basketball tickets by quarter [99786]
		
	Param's Explanation:
	- @Type: sports type
		0: Sportsbook
		1: Number Game
		2: Virtual sports
		3: Live casino
		4: Metric Gaming Super Live
		5: Virtual sports betradar
		6: Lucky 3
		7: Bull fighting
		
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

	DECLARE @TmpTotal TABLE (
		OrderNo			INT
		,TotalTrans		BIGINT
		,bettype		SMALLINT
		,LiveIndicator	BIT
		,LicenseeName	VARCHAR(50)
		)
	DECLARE @tmpBettypes TABLE ( bettype SMALLINT PRIMARY KEY)
		
	DECLARE @tmpBettransList TABLE (
		transid			BIGINT --PRIMARY KEY
		,srecommend		INT
		,bettype		SMALLINT
		,liveindicator	BIT
		,statusID		TINYINT
		,matchid		INT	
		,custid			INT
		,WalletType		TINYINT
		,RefCode		BIGINT			
	)

	CREATE TABLE #tmpRefCodeSummary (
		 RefCode	BIGINT
		 ,custid	INT
		 ,bettype	SMALLINT
		 ,transid	BIGINT
	)

	CREATE INDEX IX_tmpRefCodeSummary_Refcode ON #tmpRefCodeSummary (RefCode)

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

	INSERT INTO @tmpBettypes (bettype)
	SELECT	CONVERT(smallint, val)
	FROM	dbo.f_SplitString(@BetTypes, ',')
	GROUP BY val
	OPTION (maxrecursion 0)

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
			OUTER APPLY (SELECT BallSequence 
						FROM dbo.f_NG_GetBallSequence (b.bettype, b.betteam , b.betid , b.liveindicator	, b.livehomescore, b.liveawayscore)
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
			AND bettype IN (85, 86, 87, 88, 89, 90) 
			AND EXISTS (SELECT TOP 1 1
						FROM #TmpBallSequence WITH (NOLOCK)
						WHERE Seq = BS_tmp.BallSequence) 
			
		GROUP BY b.srecommend
			,b.matchid
			,b.bettype
			,b.liveindicator
			,b.statusid
		OPTION (RECOMPILE)	
	END
	ELSE -- For Others
	BEGIN
		INSERT INTO @TmpBettransList (transid, srecommend, bettype, liveindicator, statusID, matchid, custid, WalletType, RefCode)
		SELECT transid 
			,srecommend
			,b.bettype
			,liveindicator
			,statusID
			,matchid
			,custid
			,WalletType
			,RefCode					
		FROM bettrans b WITH (NOLOCK)
		WHERE matchid = @MatchId
			AND statusID NOT IN (101, 102, 121) --('Void', 'Reject', 'Dummy')
			AND EXISTS (SELECT TOP 1 1 FROM @tmpBettypes t WHERE t.bettype = b.bettype)
			AND CASE WHEN @LiveType <> 2 THEN liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
			AND livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE livehomescore END
			AND liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE liveawayscore END
			AND transdate BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE transdate END
							AND CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE transdate END					
			AND ISNULL(SecAcceptFlag, 0) = CASE @SecondAcceptFlag
				WHEN 0 THEN ISNULL(SecAcceptFlag, 0)
				WHEN 1 THEN 0
				WHEN 2 THEN 1
				END
			AND (@Quarter = 'All' OR b.betid LIKE CASE WHEN b.bettype BETWEEN 609 AND 617 THEN @Quarter + '%' ELSE CAST(b.betid AS VARCHAR(20)) END)  
		UNION ALL
		SELECT bl.translogid transid 
			,bl.srecommend
			,bl.GameID bettype
			,bl.liveindicator
			,bl.statusID
			,bl.EventID matchid
			,bl.custid
			,b.WalletType
			,b.RefCode					
		FROM translog bl WITH (NOLOCK)
			LEFT JOIN bettrans b WITH(NOLOCK) ON bl.gameid = b.bettype AND b.matchid = bl.eventid AND b.custid = bl.Custid AND bl.translogid = b.refno
		WHERE EventID = @MatchId
			AND GameID IN (801,803,804,805,806,1004) -- MEtric Gaming SUper Live -- MEtric Gaming SUper Live						
			AND bl.statusID NOT IN (101, 102, 121) --('Void', 'Reject', 'Dummy')
			AND EXISTS (SELECT TOP 1 1 FROM @tmpBettypes t WHERE t.bettype = bl.gameID)
			AND b.refno IS NULL
			AND CASE 
					WHEN @LiveType <> 2 THEN bl.liveindicator
					ELSE 0 END = CASE 
					WHEN @LiveType <> 2 THEN @LiveType
					ELSE 0 
				END	

		-- Insert data for Bonus tickets
		INSERT INTO #tmpRefCodeSummary (RefCode, custid, bettype, transid)
		SELECT RefCode, custid, bettype
				, MAX(transid) AS transid
		FROM @tmpBettransList
		WHERE	RefCode IS NOT NULL
		GROUP BY RefCode, custid, bettype
		HAVING COUNT(*) = 1
		
		IF @@ROWCOUNT <> 0
		BEGIN
			INSERT INTO @tmpBettransList (transid, srecommend, bettype, liveindicator, statusID, matchid, custid, WalletType, RefCode)
			SELECT b.transid 
				,b.srecommend
				,b.bettype
				,b.liveindicator
				,b.statusID
				,b.matchid
				,b.custid
				,b.WalletType
				,b.RefCode			
			FROM #tmpRefCodeSummary t
				 INNER JOIN dbo.bettrans b WITH (NOLOCK)
						 ON b.RefCode = t.RefCode
							AND b.transid <> t.transid
							AND b.matchid = @MatchId
							AND b.custid = t.custid
							AND b.bettype = t.bettype
							AND (@Quarter = 'All' OR b.betid LIKE CASE WHEN b.bettype BETWEEN 609 AND 617 THEN @Quarter + '%' ELSE CAST(b.betid AS VARCHAR(20)) END)  
			WHERE b.statusID NOT IN (101,102, 121)--('Void', 'Reject', 'Dummy')	

		END
		
		INSERT INTO #TmpBettrans
		SELECT srecommend
			,bettype
			,liveindicator
			,statusID
			,matchid
			,COUNT(transid) cnt
		FROM @TmpBettransList tmp	
		GROUP BY srecommend
			,matchid
			,bettype
			,liveindicator
			,statusid	
	END

	----## Direct Licensee
	IF @LicenseeID <> 0 AND @LicenseeID <> - 1
	BEGIN
		DECLARE @LicenseeName VARCHAR(100)

		SET @LicenseeName = ''

		SELECT @LicenseeName = site
		FROM site WITH (NOLOCK)
		WHERE isLicensee = 1
			AND isActive = 1
			AND siteID NOT IN (29, 35)
			AND siteID = @LicenseeID

		IF @BetTypes <> '9' AND @BetTypes <> '29' AND @BetTypes <> '2799' AND @BetTypes <> '9,29,2799'
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
		IF charindex('9', @BetTypes, 1) <> 0 OR charindex('2799', @BetTypes, 1) <> 0
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
			WHERE b.srecommend IN ( SELECT custid FROM dbo.Dep_CustSuper WITH (NOLOCK) WHERE site = @LicenseeName )
				AND bm.matchid = @MatchId
				AND b.statusID NOT IN (101, 102) --('Void', 'Reject')
				AND b.bettype IN (9, 29, 2799)
				AND b.matchid IN (9, 29, 2799)
				AND CASE WHEN @LiveType <> 2 THEN bm.liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
				AND bm.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE bm.livehomescore END
				AND bm.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE bm.liveawayscore END
				AND bm.transdate BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE bm.transdate END
								AND CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE bm.transdate END
				AND ISNULL(SecAcceptFlag, 0) = CASE @SecondAcceptFlag
					WHEN 0 THEN ISNULL(SecAcceptFlag, 0)
					WHEN 1 THEN 0
					WHEN 2 THEN 1
					END
				AND (b.betid = 0 OR b.betid IS NULL )
				AND (@Quarter = 'All' OR bm.betcheck LIKE CASE WHEN b.bettype BETWEEN 609 AND 617 THEN @Quarter + '%' ELSE CAST(bm.betcheck AS VARCHAR(20)) END)  
			GROUP BY b.bettype
				,bm.liveIndicator
			HAVING Count(b.Refno) > 0
	END

	----## IBC Group
	IF @LicenseeID = - 1
	BEGIN
		IF @BetTypes <> '9' AND @BetTypes <> '29' AND @BetTypes <> '2799' AND @BetTypes <> '9,29,2799'
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
			FROM #TmpBettrans b WITH (NOLOCK) WHERE b.srecommend NOT IN ( SELECT custid FROM dbo.Dep_CustSuper WITH (NOLOCK) )
			GROUP BY b.bettype
				,b.liveindicator

		---mix parlay
		IF charindex('9', @BetTypes, 1) <> 0 OR charindex('2799', @BetTypes, 1) <> 0
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
			WHERE b.srecommend NOT IN ( SELECT custid FROM dbo.Dep_CustSuper WITH (NOLOCK) )
				AND bm.matchid = @MatchId
				AND b.statusID NOT IN (101, 102) ---('Void', 'Reject')
				AND b.bettype IN (9, 29, 2799)
				AND b.matchid IN (9, 29, 2799)
				AND CASE WHEN @LiveType <> 2 THEN bm.liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
				AND bm.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE bm.livehomescore END
				AND bm.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE bm.liveawayscore END
				AND bm.transdate BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE bm.transdate END
									AND CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE bm.transdate END
				AND ISNULL(SecAcceptFlag, 0) = CASE @SecondAcceptFlag
					WHEN 0 THEN ISNULL(SecAcceptFlag, 0)
					WHEN 1 THEN 0
					WHEN 2 THEN 1
					END
				AND ( b.betid = 0 OR b.betid IS NULL )
				AND (@Quarter = 'All' OR bm.betcheck LIKE CASE WHEN b.bettype BETWEEN 609 AND 617 THEN @Quarter + '%' ELSE CAST(bm.betcheck AS VARCHAR(20)) END)  
			GROUP BY b.bettype
				,bm.liveIndicator
			HAVING Count(B.Refno) > 0
	END

	-----## All 
	IF @LicenseeID = 0
	BEGIN
		IF @BetTypes <> '9' AND @BetTypes <> '29' AND @BetTypes <> '2799' AND @BetTypes <> '9,29,2799'
			INSERT INTO @TmpTotal (
				OrderNo
				,TotalTrans
				,bettype
				,LiveIndicator
				,LicenseeName
				)
			SELECT CASE WHEN s.site IS NULL THEN 0 ELSE 1 END OrderNo
				,sum(cnt) AS TotalTrans
				,bettype
				,CASE WHEN @type = 1 THEN b.liveindicator ELSE 0 END
				,CASE WHEN s.site IS NULL THEN 'MBC' ELSE s.site END AS LicenseeName
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
		IF charindex('9', @BetTypes, 1) <> 0 OR charindex('2799', @BetTypes, 1) <> 0
			INSERT INTO @TmpTotal (
				OrderNo
				,TotalTrans
				,bettype
				,LiveIndicator
				,LicenseeName
				)
			SELECT CASE WHEN s.site IS NULL THEN 0 ELSE 1 END OrderNo
				,Count(DISTINCT b.transid) AS TotalTrans
				,b.bettype
				,0
				,CASE WHEN s.site IS NULL THEN 'MBC' ELSE s.site END AS LicenseeName
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
				AND CASE WHEN @LiveType <> 2 THEN bm.liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
				AND bm.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE bm.livehomescore END
				AND bm.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE bm.liveawayscore END
				AND bm.transdate BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE bm.transdate END
									AND CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE bm.transdate END
				AND ISNULL(SecAcceptFlag, 0) = CASE @SecondAcceptFlag
					WHEN 0 THEN ISNULL(SecAcceptFlag, 0)
					WHEN 1 THEN 0
					WHEN 2 THEN 1
					END
				AND ( b.betid = 0 OR b.betid IS NULL )
				AND (@Quarter = 'All' OR bm.betcheck LIKE CASE WHEN b.bettype BETWEEN 609 AND 617 THEN @Quarter + '%' ELSE CAST(bm.betcheck AS VARCHAR(20)) END)  
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