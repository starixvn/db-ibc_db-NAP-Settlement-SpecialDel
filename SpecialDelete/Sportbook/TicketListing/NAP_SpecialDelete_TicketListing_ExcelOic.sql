/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_TicketListing_ExcelOic]
	@MatchId INT,
	@LicenseeName VARCHAR(1000) = 'ALL',
	@BetTypes VARCHAR(1000) = '',	
	@LiveType SMALLINT = 2,	
	@LiveHomeScore smallint = NULL,
    @LiveAwayScore smallint = NULL,
    @FromTransdate Datetime = NULL,
	@ToTransdate Datetime = NULL,
	@Type SMALLINT = 0,
    @SecondAcceptFlag tinyint = 0,
    @BallSequence VARCHAR(200) = ''
WITH RECOMPILE
AS

/*	Created by: Kent
	Date: 20171106
	Task: Show Tickets Listing Detail and Export to excel for NAP system
	DB: DBACC/bodb02
	Original: 

	Revisions:			
		- 20171106@Kent: Implement Notifications Center [Redmine:#84330] 
		- 20171215@Kent: Number Game Ball Sequence [Redmine:#54346]
		
	Param's Explanation:
	- @Type: sports type
		0: Sportsbook
		1: Number Game
		2: Virtual sports		
		4: MG
		5: Virtual sports betradar
	- @LicenseeName:
		ALL, IBC, 12bet, ...	
	- @BetTypes: String of bettype for Sportsbook, virtual sports and for Dead Ball - Number game, Live casino	
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
     
   Example:    exec NAP_SpecialDelete_TicketListing_ExcelOic @MatchId=4626986,@LicenseeName='IBC',@BetTypes='1101,1102',@BetTypesLive='',@LiveType=0,@LiveHomeScore=default,@LiveAwayScore=default,@FromTransdate=default,@ToTransdate=default,@Type=2,@SecondAcceptFlag=0
	
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @p_bettypes VARCHAR(1000)

	SET @p_bettypes = @BetTypes

	---- If number game then don't care @livetype , so set @LiveType to zero
	IF @Type = 1 or @Type = 2
		SELECT @LiveType = 0

	SELECT CustID 
	INTO #CustIDs
	FROM DBLIC.bodb_Licensee.dbo.LicenseeCust WITH (NOLOCK)

	CREATE TABLE #SpecialDeleteBets 
	(
		username VARCHAR(30),	
		transid BIGINT	
	)

	CREATE TABLE #TmpBallSequence 
	(	
		Seq	TINYINT
	)

	INSERT INTO #TmpBallSequence(Seq)
	SELECT  val
	FROM	dbo.f_SplitString(@BallSequence, ',')
	OPTION (maxrecursion 0)

	----***** bettype <> 9 (because bettype = 9 then matchID = 9)****----
	IF @p_bettypes <> '9' AND @BetTypes <> '29' AND @BetTypes <> '2799' AND @BetTypes <> '9,29,2799'
	BEGIN	
		----Direct Licensee
		IF @LicenseeName <> 'MBC' AND @LicenseeName <> 'ALL' 
		BEGIN
			
			IF @Type = 1 -- Number Game
			BEGIN
				INSERT INTO #SpecialDeleteBets (username, transid)
				SELECT	b.username,									
						b.transid 
				FROM		bettrans b WITH (NOLOCK) 				
					LEFT JOIN dbo.bingoBall bb WITH (NOLOCK) ON bb.matchid = b.matchid AND bb.Number = b.betid AND b.bettype IN (85, 86, 87, 89, 90)
					OUTER APPLY (SELECT BallSequence 
								FROM dbo.f_SD_GetBallSequence (b.bettype,b.betteam,b.betid,bb.Seq)
								WHERE b.bettype IN (85, 86, 87, 88, 89, 90)
								) AS BS_tmp
								
				WHERE		b.srecommend IN ( SELECT custid FROM Dep_CustSuper with(nolock) where site = @LicenseeName)
							AND b.statusID NOT IN (101,102, 121) ---('Void', 'Reject', 'Dummy')
							AND b.matchid = @MatchId 
			 	   			AND
								(   							
									b.bettype IN (SELECT CONVERT(INT,val) FROM dbo.strSplit(@p_bettypes,','))
									 AND CASE WHEN @LiveType <> 2 THEN liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
									 AND b.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE b.livehomescore END
									 AND b.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE b.liveawayscore END
									 AND b.transdate BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE b.transdate END 
													AND	   CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE b.transdate END														 
								) 
							AND ISNULL(SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
							AND EXISTS (SELECT TOP 1 1 
										FROM #TmpBallSequence WITH (NOLOCK)
										WHERE Seq = BS_tmp.BallSequence)
										
							
				OPTION	(RECOMPILE)	
			END
			ELSE
			BEGIN
				INSERT INTO #SpecialDeleteBets (username, transid)
				SELECT	b.username,									
						CASE WHEN b.Bettype IN (801,803,804,805,806) THEN b.refno ELSE b.transid END transid				
				FROM		bettrans b WITH (NOLOCK) 				
				WHERE		b.srecommend IN ( SELECT custid FROM Dep_CustSuper with(nolock) where site = @LicenseeName)
							AND b.statusID NOT IN (101,102, 121) ---('Void', 'Reject', 'Dummy')
							AND b.matchid = @MatchId 
			 	   			AND
								(   							
									b.bettype IN (SELECT CONVERT(INT,val) FROM dbo.strSplit(@p_bettypes,','))
									 AND CASE WHEN @LiveType <> 2 THEN liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
									 AND b.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE b.livehomescore END
									 AND b.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE b.liveawayscore END
									 AND b.transdate BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE b.transdate END 
													AND	   CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE b.transdate END														 
								) 
							AND ISNULL(SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
							
				UNION ALL
				SELECT	b.username,										
						b.translogid transID				
				FROM		translog b WITH (NOLOCK)		 	
				LEFT JOIN bettrans bs WITH(NOLOCK) ON b.translogid = bs.refno AND b.gameid = bs.bettype		
				WHERE		b.srecommend IN ( SELECT custid FROM Dep_CustSuper with(nolock) where site = @LicenseeName)
							AND b.statusID NOT IN (101,102, 121) ---('Void', 'Reject', 'Dummy')
							AND b.gameid IN (801,803,804,805,806) AND bs.refno IS NULL
							AND b.eventid = @MatchId 
			 	   			AND
								(   
									(
										b.gameID IN (SELECT CONVERT(INT,val) FROM dbo.strSplit(@p_bettypes,','))
										AND CASE WHEN @LiveType <> 2 THEN b.liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
										 --AND b.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE b.livehomescore END
										 --AND b.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE b.liveawayscore END
										 --AND b.transdate BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE b.transdate END 
										--			AND	   CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE b.transdate END  
									)
								)
				OPTION (RECOMPILE)				 
			END 
		END

		---IBC 
		IF @LicenseeName = 'MBC'  
		BEGIN
			IF @Type = 1 -- Number Game
			BEGIN
				INSERT INTO #SpecialDeleteBets (username, transid)
				SELECT	b.username,										
						b.transid				
				FROM		bettrans b WITH (NOLOCK) 
					LEFT JOIN dbo.bingoBall bb WITH (NOLOCK) ON bb.matchid = b.matchid AND bb.Number = b.betid AND b.bettype IN (85, 86, 87, 89, 90)
					OUTER APPLY (SELECT BallSequence 
								FROM dbo.f_SD_GetBallSequence (b.bettype,b.betteam,b.betid,bb.Seq)
								WHERE b.bettype IN (85, 86, 87, 88, 89, 90)
								) AS BS_tmp	 	
				WHERE		B.recommend NOT IN (SELECT CustID FROM #CustIDs WITH (NOLOCK) ) 
							AND b.statusID NOT IN (101,102, 121) --- ('Void', 'Reject', 'Dummy')
							AND b.matchid = @MatchId 
							AND (							
									b.bettype IN (SELECT CONVERT(INT,val) FROM dbo.strSplit(@p_bettypes,','))
									 AND CASE WHEN @LiveType <> 2 THEN liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
									 AND b.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE b.livehomescore END
									 AND b.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE b.liveawayscore END
									 AND b.transdate BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE b.transdate END 
													 AND	 CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE b.transdate END													 
								)
								AND ISNULL(SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
								AND EXISTS (SELECT TOP 1 1
											   FROM #TmpBallSequence
											   WHERE Seq = BS_tmp.BallSequence)
				OPTION (RECOMPILE)							   
				
			END
			ELSE
			BEGIN
				INSERT INTO #SpecialDeleteBets (username, transid)
				SELECT	b.username,										
						b.transid				
				FROM		bettrans b WITH (NOLOCK) 		 	
				WHERE		B.recommend NOT IN (SELECT CustID FROM #CustIDs WITH (NOLOCK) ) 
							AND b.statusID NOT IN (101,102, 121) --- ('Void', 'Reject', 'Dummy')
							AND b.matchid = @MatchId 
							AND (							
									b.bettype IN (SELECT CONVERT(INT,val) FROM dbo.strSplit(@p_bettypes,','))
									 AND CASE WHEN @LiveType <> 2 THEN liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
									 AND b.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE b.livehomescore END
									 AND b.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE b.liveawayscore END
									 AND b.transdate BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE b.transdate END 
													 AND	 CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE b.transdate END													 
								)
								AND ISNULL(SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
								
				UNION ALL
				SELECT	b.username,				
						b.TranslogID transid				
				FROM		Translog b WITH (NOLOCK)		 
					LEFT JOIN bettrans bs WITH(NOLOCK) ON b.translogid = bs.refno AND b.gameid = bs.bettype			
				WHERE		B.recommend NOT IN (SELECT CustID FROM #CustIDs WITH (NOLOCK) ) 
							AND b.statusID NOT IN (101,102, 121) --- ('Void', 'Reject', 'Dummy')
							AND b.gameid IN (801,803,804,805,806) AND bs.refno IS NULL
							AND b.EventID = @MatchId 
							AND
								(   
									(
										b.GameID IN (SELECT CONVERT(INT,val) FROM dbo.strSplit(@p_bettypes,','))
										 --AND CASE WHEN @LiveType <> 2 THEN liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
										 --AND b.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE b.livehomescore END
										 --AND b.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE b.liveawayscore END
										 --AND b.transdate BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE b.transdate END 
											--			 AND	 CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE b.transdate END
									)
								)
				OPTION (RECOMPILE)							   				
			END
		END

		---ALL
		IF @LicenseeName= 'ALL' 
		BEGIN 
			IF @Type = 1 -- Number Game
			BEGIN
				INSERT INTO #SpecialDeleteBets (username, transid)
				SELECT	b.username,									
						b.transid				
				FROM		bettrans b WITH (NOLOCK)
					LEFT JOIN dbo.bingoBall bb WITH (NOLOCK) ON bb.matchid = b.matchid AND bb.Number = b.betid AND b.bettype IN (85, 86, 87, 89, 90)
					OUTER APPLY (SELECT BallSequence 
								FROM dbo.f_SD_GetBallSequence (b.bettype,b.betteam,b.betid,bb.Seq)
								WHERE b.bettype IN (85, 86, 87, 88, 89, 90)
								) AS BS_tmp
										 		
				WHERE		b.statusID NOT IN (101,102, 121)--('Void', 'Reject', 'Dummy') 
							AND b.matchid = @MatchId 
							AND	(							
									b.bettype IN (SELECT CONVERT(INT,val) FROM dbo.strSplit(@p_bettypes,','))
									 AND CASE WHEN @LiveType <> 2 THEN liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
									 AND b.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE b.livehomescore END
									 AND b.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE b.liveawayscore END
									 AND b.transdate	BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE b.transdate END 
														AND	    CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE b.transdate END														 
								)
							AND ISNULL(SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
							AND EXISTS (SELECT TOP 1 1 FROM #TmpBallSequence WITH (NOLOCK)
										WHERE Seq = BS_tmp.BallSequence)
			END
			ELSE
			BEGIN
				
				INSERT INTO #SpecialDeleteBets (username, transid)
				SELECT	b.username,									
						b.transid				
				FROM		bettrans b WITH (NOLOCK)		 		
				WHERE		b.statusID NOT IN (101,102, 121)--('Void', 'Reject', 'Dummy') 
							AND b.matchid = @MatchId 
							AND	(							
									b.bettype IN (SELECT CONVERT(INT,val) FROM dbo.strSplit(@p_bettypes,','))
									 AND CASE WHEN @LiveType <> 2 THEN liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
									 AND b.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE b.livehomescore END
									 AND b.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE b.liveawayscore END
									 AND b.transdate	BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE b.transdate END 
														AND	    CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE b.transdate END														 
								)
							AND ISNULL(SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
							
				UNION ALL
				SELECT	b.username,										
						b.translogid AS transid				
				FROM		Translog b WITH (NOLOCK)		 	
					LEFT JOIN bettrans bs WITH(NOLOCK) ON b.translogid = bs.refno	AND b.gameid = bs.bettype	
				WHERE		b.statusID NOT IN (101,102, 121)--('Void', 'Reject', 'Dummy') 
							AND b.gameid IN (801,803,804,805,806) AND bs.refno IS NULL
							AND b.EventID = @MatchId 
							AND	(   
									(
										b.GameID IN (SELECT CONVERT(INT,val) FROM dbo.strSplit(@p_bettypes,','))
										 --AND CASE WHEN @LiveType <> 2 THEN liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
										 --AND b.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE b.livehomescore END
										 --AND b.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE b.liveawayscore END
										 --AND b.transdate	BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE b.transdate END 
											--				AND	    CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE b.transdate END 
									)
								)
			END	
		END			
	END

	----******* If list of bettype include 9 *******
	IF charindex('9', @p_bettypes , 1) <> 0 
	   OR charindex('2799', @p_bettypes , 1) <> 0  
	BEGIN 
		---Licensee
		IF @LicenseeName <> 'MBC' AND @LicenseeName <> 'ALL' 
		BEGIN
			INSERT INTO #SpecialDeleteBets (username, transid)	
			SELECT	b.username,									
					b.transid				
			FROM	bettransm bm WITH (NOLOCK)	
			INNER JOIN  Bettrans b WITH (NOLOCK) ON b.refno = bm.refno 
			INNER JOIN dbo.strSplit(@BetTypes,',') t ON b.bettype = t.val			
			WHERE		b.srecommend IN ( SELECT custid FROM Dep_CustSuper with(NOLOCK) where site = @LicenseeName) 
						AND b.statusID NOT IN (101,102) --- ('Void', 'Reject' )
						AND b.bettype IN(9,29,2799) AND b.matchID IN (9,29,2799)
						AND bm.matchid = @MatchId 
						AND CASE WHEN @LiveType <> 2 THEN bm.liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
						AND bm.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE bm.livehomescore END
						AND bm.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE bm.liveawayscore END
						AND bm.transdate BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE bm.transdate END 
										 AND	  CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE bm.transdate END
						AND ISNULL(SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
						AND (b.betid = 0 OR b.betid IS NULL)
		END
		ELSE 
		
		---IBC
		IF @LicenseeName= 'MBC'  
		BEGIN	
			INSERT INTO #SpecialDeleteBets (username, transid)
			SELECT	b.username,									
					b.transid				
			FROM	Bettrans b WITH (NOLOCK) 
			INNER JOIN  bettransm bm WITH (NOLOCK) ON b.refno = bm.refno 
			INNER JOIN dbo.strSplit(@BetTypes,',') t ON b.bettype = t.val		
			WHERE		b.recommend NOT IN (SELECT CustID FROM #CustIDs WITH (NOLOCK) ) 
						AND b.statusID NOT IN (101,102) --('Void', 'Reject')
						AND b.bettype IN (9,29,2799) AND b.matchID IN (9,29,2799)
						AND bm.matchid = @MatchId 	 
						AND CASE WHEN @LiveType <> 2 THEN bm.liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
						AND bm.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE bm.livehomescore END
						AND bm.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE bm.liveawayscore END
						AND bm.transdate BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE bm.transdate END 
										 AND	 CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE bm.transdate END
						AND ISNULL(SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
						AND (b.betid = 0 OR b.betid IS NULL)
			OPTION (RECOMPILE)				
		END 

		---ALL
		IF @LicenseeName= 'ALL'  
		BEGIN
			INSERT INTO #SpecialDeleteBets (username, transid)	
			SELECT	b.username,									
					b.transid				
			FROM	Bettrans b WITH (NOLOCK)	
			INNER JOIN  bettransm bm WITH (NOLOCK) ON b.refno = bm.refno 
			INNER JOIN dbo.strSplit(@BetTypes,',') t ON b.bettype = t.val		
			WHERE		b.statusID NOT IN (101,102)--('Void', 'Reject')
						AND b.bettype IN (9,29,2799) AND b.matchID IN (9,29,2799) 
						AND bm.matchID = @MatchId
						AND CASE WHEN @LiveType <> 2 THEN bm.liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
						AND bm.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE bm.livehomescore END
						AND bm.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE bm.liveawayscore END
						AND bm.transdate BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE bm.transdate END 
										 AND	 CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE bm.transdate END
						AND ISNULL(SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
						AND (b.betid = 0 OR b.betid IS NULL)
		END 		
	END 

	SELECT  username,			
			transid		
	FROM #SpecialDeleteBets
	ORDER BY transid
	
	DROP TABLE #SpecialDeleteBets
	DROP TABLE #TmpBallSequence
	DROP TABLE #CustIDs
	
END			 
GO
