USE [bodb02]
GO
ALTER PROCEDURE [dbo].[NAP_Rpt_TicketsListingDetail]
	@MatchId INT,
	@LicenseeName VARCHAR(1000),
	@BetTypes VARCHAR(1000), 
	@BetTypesLive VARCHAR(1000) ,
	@LiveType SMALLINT = 2,	
	@LiveHomeScore smallint = NULL,
    @LiveAwayScore smallint = NULL,
    @FromTransdate Datetime = NULL,
	@ToTransdate Datetime = NULL,
	@Type SMALLINT = 0,
    @SecondAcceptFlag tinyint = 0
WITH RECOMPILE
AS

/*	Created by: Elodie
	Date: 20130606
	Task: Show Tickets Listing Detail and Export to excel for NAP system
	DB: DBACC/bodb02
	Original: Acc_Rpt_TicketsListingDetail

	Revisions:	
		- 20130911@Kathy: Rename parameter @SAFilter to @SecondAcceptFlag
		- 20131203@Kathy: Rename column: liveindicator to IsLiveIndicator.
						Using Dep_CustSuper table instead of f_DepSuper_1() function.		
		- 20140211@Kathy: Get more column for MixParlay	
		- 20150402@Dominic: Add new 60 bettypes [Redmine:#27214]
		- 20150623@Dominic: Add Metric Gaming Super Live [Redmine:##38200]	  
		- 20151023@Patrick: Add more field sporttype to support Muay Thai
		- 20151302@Kathy: add modds column 
		- 20150712@Kathy: Database - Change datatype [Redmine: #48660]
		- 20150119@Kathy: Changes for phase 1.2 of PH All in One: add new column transdesc [Redmine:#50932]
		- 20170104@Kent: Add Column SportType to output tables [Redmine:#69816]	
		- 20170410@Kent: Add columns OriginalBetType, BetdaqId, ExtraInfo [Redmine:#72887]
		- 20170414@Kent: Fix IBC to MBC [Redmine:#75009]  
		- 20170525@Kent: Remove dummy tables and fix bit datatype columns [Redmine:#77040]
		
	Param's Explanation:
	- @Type: sports type
		0: Sportsbook
		1: Number Game
		2: Virtual sports
		3: Live casino
		4: MG
	- @LicenseeName:
		ALL, IBC, 12bet, ...	
	- @BetTypes: String of bettype for Sportsbook, virtual sports and for Dead Ball - Number game, Live casino
	- @BetTypesLive: String of bettype ONLY for Live - Number game 
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
     
   Example:    exec NAP_Rpt_TicketsListingDetail @MatchId=4626986,@LicenseeName='IBC',@BetTypes='1101,1102',@BetTypesLive='',@LiveType=0,@LiveHomeScore=default,@LiveAwayScore=default,@FromTransdate=default,@ToTransdate=default,@Type=2,@SecondAcceptFlag=0
	
*/
SET NOCOUNT ON 

DECLARE @p_bettypes VARCHAR(1000) 
DECLARE @p_bettypesLive VARCHAR(1000) 

SET @p_bettypes = @BetTypes 
SET @p_bettypesLive = @BetTypesLive

---- If number game then don't care @livetype , so set @LiveType to zero
IF @Type = 1 or @Type = 2 or @Type = 3
	SELECT @LiveType = 0

SELECT CustID 
INTO #CustIDs
FROM DBLIC.bodb_Licensee.dbo.LicenseeCust WITH (NOLOCK)

----***** bettype <> 9 (because bettype = 9 then matchID = 9)****----
IF @p_bettypes <> '9' AND @BetTypes <> '29' AND @BetTypes <> '9,29'
BEGIN
	CREATE TABLE #SpecialDeleteBets 
	(
		username VARCHAR(30),
		bettype SMALLINT,
		transid BIGINT,
		homeid INT,
		awayid INT,
		hdp1 SMALLMONEY, 
		hdp2 SMALLMONEY,
		odds MONEY,
		status NVARCHAR(10),
		stake MONEY,
		transdate DATETIME, 
		betteam NVARCHAR(10),
		betcheck NVARCHAR(50),
		livehomescore SMALLINT, 
		liveawayscore SMALLINT,
		IsLiveIndicator BIT,
		ISNeutral BIT,
		OddsType INT, 
		CurrencyName NVARCHAR(100),
		winlost MONEY,
		betid BIGINT,
		IsMP BIT,
		SecAcceptFlag BIT,		
		refno BIGINT,
		ChoiceTransID BIGINT ,
		ChoiceBetType INT  ,
		ChoiceHomeID INT  ,
        ChoiceAwayID INT   ,
        ChoiceHdp1 SMALLMONEY  , 
        ChoiceHdp2 SMALLMONEY  ,
        ChoiceOdds MONEY   ,
		ChoiceStake MONEY,
        ChoiceBetTeam NVARCHAR(20), 
        ChoiceBetCheck NVARCHAR(50), 
        ChoiceLiveHomeScore SMALLINT  ,
        ChoiceLiveAwayScore SMALLINT  ,
        ChoiceLiveIndicator BIT  ,
		ChoiceLeagueId INT  ,
        ChoiceSportType SMALLINT,  
        TransDesc NVARCHAR(300),
        SportType SMALLINT,
		OriginalBetType	SMALLINT,
		ExtraInfo VARCHAR(1000),
		BetdaqId BIGINT
	)
	
	----Direct Licensee
	IF @LicenseeName <> 'MBC' AND @LicenseeName <> 'ALL' 
	BEGIN				 
		INSERT INTO #SpecialDeleteBets
		SELECT	b.username,
				b.bettype,		
				CASE WHEN b.Bettype IN (801,803,804,805,806) THEN b.refno ELSE b.transid END transid,
				m.homeID,
				m.awayID,
				convert(float, b.hdp1) as hdp1, 
				convert(float, b.hdp2) as hdp2, 
				b.odds,
				CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					 ELSE b.status 
					 END  as status,
				b.stake,
				b.transdate,		
				b.betteam,
				b.betcheck,
				b.livehomescore,
				b.liveawayscore,
				b.liveindicator, 
				isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
				b.OddsType,
				b.CurrencyName,
				(winlost-actual_stake )as winlost,
				b.betid,
				0 as isMP,
				ISNULL(SecAcceptFlag,0) SecAcceptFlag,
				b.refno,
				b.transid as ChoiceTransID,
				b.bettype as ChoiceBetType ,
				m.homeid as ChoiceHomeID,
				m.awayid as ChoiceAwayID,
				b.hdp1 as ChoiceHdp1,
				b.hdp2 as ChoiceHdp2,
				b.odds as ChoiceOdds,
				b.stake as ChoiceStake,
				b.betteam as ChoiceBetTeam,
				b.betcheck as ChoiceBetCheck,
				b.livehomescore as ChoiceLiveHomeScore,
				b.liveawayscore as ChoiceLiveAwayScore,
				b.liveindicator as ChoiceLiveIndicator,
				m.leagueid  as ChoiceLeagueId ,
				m.sporttype as ChoiceSportType
				,b.transdesc				
				,m.sporttype AS SportType
				,b.bettype AS OriginalBetType
				,b.ExtraInfo
				,b.BetdaqId
		FROM		Bettrans b WITH (NOLOCK) 
		INNER JOIN  match m WITH (NOLOCK) on b.matchid = m.matchid 		
		WHERE		b.srecommend IN ( SELECT custid FROM Dep_CustSuper with(nolock) where site = @LicenseeName)
					AND b.statusID NOT IN (101,102, 121) ---('Void', 'Reject', 'Dummy')
					AND b.matchid = @MatchId 
			 	   	AND
						(   
							(
								b.bettype IN (SELECT CONVERT(INT,val) FROM dbo.strSplit(@p_bettypes,','))
								 AND CASE WHEN @LiveType <> 2 THEN liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
								 AND b.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE b.livehomescore END
								 AND b.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE b.liveawayscore END
								 AND b.transdate BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE b.transdate END 
												AND	   CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE b.transdate END  
							)
							 OR
							(
								b.bettype IN (SELECT CONVERT(INT,val) FROM dbo.strSplit(@p_bettypesLive,','))
								AND b.liveindicator = 1
							)
						) 
                    AND ISNULL(SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
		UNION ALL
		SELECT	b.username,
				b.gameID,		
				b.translogid transID,
				m.homeID,
				m.awayID,
				0 AS hdp1, 
				0 as hdp2, 
				b.odds,
				b.status,
				b.stake,
				b.transdate,		
				NULL betteam,
				NULL betcheck,
				NULL livehomescore,
				NULL liveawayscore,
				b.liveindicator liveindicator, 
				isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
				b.custom1 AS OddsType,
				b.CurrencyName,
				- b.actual_stake as winlost,
				NULL AS betid,
				0 isMP,
				NULL SecAcceptFlag,
				b.translogid refno,
				b.translogid as ChoiceTransID,
				b.gameID as ChoiceBetType ,
				m.homeid as ChoiceHomeID,
				m.awayid as ChoiceAwayID,
				0 as ChoiceHdp1,
				0 as ChoiceHdp2,
				b.odds as ChoiceOdds,
				b.stake as ChoiceStake,
				NULL as ChoiceBetTeam,
				NULL as ChoiceBetCheck,
				NULL as ChoiceLiveHomeScore,
				NULL as ChoiceLiveAwayScore,
				b.liveindicator as ChoiceLiveIndicator,
				m.leagueid  as ChoiceLeagueId ,
				m.sporttype as ChoiceSportType		
				,b.transdesc		
				,m.sporttype AS SportType
				,b.gameID AS OriginalBetType
				,NULL AS ExtraInfo
				,NULL AS BetdaqId
		FROM		translog b WITH (NOLOCK) 
		INNER JOIN  match m WITH (NOLOCK) on b.eventid = m.matchid 	
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
		ORDER BY transID
 
	END

	---IBC 
	IF @LicenseeName = 'MBC'  
	BEGIN	
		INSERT INTO #SpecialDeleteBets
		SELECT	b.username,
				b.bettype,		
				b.transid,
				m.homeID,
				m.awayID,
				convert(float, b.hdp1) as hdp1, 
				convert(float, b.hdp2) as hdp2, 
				b.odds,
				CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					 ELSE b.status 
					 END as status,
				b.stake,
				b.transdate,		
				b.betteam,
				b.betcheck,
				b.livehomescore,
				b.liveawayscore,
				b.liveindicator, 
				isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
				b.OddsType,
				b.CurrencyName,
				(winlost-actual_stake )as winlost,
				b.betid,
				0 as isMP,
				ISNULL(SecAcceptFlag,0) SecAcceptFlag,
				b.refno,
				b.transid as ChoiceTransID,
				b.bettype as ChoiceBetType ,
				m.homeid as ChoiceHomeID,
				m.awayid as ChoiceAwayID,
				b.hdp1 as ChoiceHdp1,
				b.hdp2 as ChoiceHdp2,
				b.odds as ChoiceOdds,
				b.stake as ChoiceStake,
				b.betteam as ChoiceBetTeam,
				b.betcheck as ChoiceBetCheck,
				b.livehomescore as ChoiceLiveHomeScore,
				b.liveawayscore as ChoiceLiveAwayScore,
				b.liveindicator as ChoiceLiveIndicator,
				m.leagueid  as ChoiceLeagueId ,
				m.sporttype as ChoiceSportType
				,b.transdesc
				,m.sporttype AS SportType
				,b.bettype AS OriginalBetType
				,b.ExtraInfo
				,b.BetdaqId
		FROM		Bettrans b WITH (NOLOCK) 
		INNER JOIN  match m WITH (NOLOCK) on b.matchid = m.matchid 	
		WHERE		B.recommend NOT IN (SELECT CustID FROM #CustIDs WITH (NOLOCK) ) 
					AND b.statusID NOT IN (101,102, 121) --- ('Void', 'Reject', 'Dummy')
					AND b.matchid = @MatchId 
					AND
						(   
							(
								b.bettype IN (SELECT CONVERT(INT,val) FROM dbo.strSplit(@p_bettypes,','))
								 AND CASE WHEN @LiveType <> 2 THEN liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
								 AND b.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE b.livehomescore END
								 AND b.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE b.liveawayscore END
								 AND b.transdate BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE b.transdate END 
												 AND	 CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE b.transdate END
							)
							 OR
							(
								b.bettype IN (SELECT CONVERT(INT,val) FROM dbo.strSplit(@p_bettypesLive,','))
								AND b.liveindicator = 1
							)
						)
						AND ISNULL(SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
		UNION ALL
		SELECT	b.username,
				b.GameID,		
				b.TranslogID transid,
				m.homeID,
				m.awayID,
				0 as hdp1, 
				0 as hdp2, 
				b.odds,
				b.status,
				b.stake,
				b.transdate,		
				NULL betteam,
				NULL betcheck,
				NULL livehomescore,
				NULL liveawayscore,
				b.liveindicator liveindicator, 
				isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
				b.custom1 AS OddsType,
				b.CurrencyName,
				- b.actual_stake as winlost,
				NULL AS betid,
				0 as isMP,
				NULL SecAcceptFlag,
				b.translogid refno,
				b.translogid as ChoiceTransID,
				b.gameID as ChoiceBetType ,
				m.homeid as ChoiceHomeID,
				m.awayid as ChoiceAwayID,
				0 as ChoiceHdp1,
				0 as ChoiceHdp2,
				b.odds as ChoiceOdds,
				b.stake as ChoiceStake,
				NULL as ChoiceBetTeam,
				NULL as ChoiceBetCheck,
				NULL as ChoiceLiveHomeScore,
				NULL as ChoiceLiveAwayScore,
				b.liveindicator as ChoiceLiveIndicator,
				m.leagueid  as ChoiceLeagueId ,
				m.sporttype as ChoiceSportType
				,b.transdesc
				,m.sporttype AS SportType
				,b.gameID AS OriginalBetType
				,NULL AS ExtraInfo
				,NULL AS BetdaqId
		FROM		Translog b WITH (NOLOCK) 
		INNER JOIN  match m WITH (NOLOCK) on b.EventID = m.matchid 
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
		ORDER BY transID

	END

	---ALL
	IF @LicenseeName= 'ALL' 
	BEGIN 	
		INSERT INTO #SpecialDeleteBets
		SELECT	b.username,
				b.bettype,		
				b.transid,
				m.homeID,
				m.awayID,
				convert(float, b.hdp1) as hdp1, 
				convert(float, b.hdp2) as hdp2, 
				b.odds,
				CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					 ELSE b.status 
					 END  as status,
				b.stake,
				b.transdate,		
				b.betteam,
				b.betcheck,
				b.livehomescore,
				b.liveawayscore,
				b.liveindicator, 
				isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
				b.OddsType,
				b.CurrencyName,
				(winlost-actual_stake )as winlost,
				b.betid,
				0 as isMP,
				ISNULL(SecAcceptFlag,0) SecAcceptFlag,
				b.refno		,
				b.transid as ChoiceTransID,
				b.bettype as ChoiceBetType ,
				m.homeid as ChoiceHomeID,
				m.awayid as ChoiceAwayID,
				b.hdp1 as ChoiceHdp1,
				b.hdp2 as ChoiceHdp2,
				b.odds as ChoiceOdds,
				b.stake as ChoiceStake,
				b.betteam as ChoiceBetTeam,
				b.betcheck as ChoiceBetCheck,
				b.livehomescore as ChoiceLiveHomeScore,
				b.liveawayscore as ChoiceLiveAwayScore,
				b.liveindicator as ChoiceLiveIndicator	,
				m.leagueid  as ChoiceLeagueId ,
				m.sporttype as ChoiceSportType	
				,b.transdesc
				,m.sporttype AS SportType
				,b.bettype AS OriginalBetType
				,b.ExtraInfo
				,b.BetdaqId
		FROM		Bettrans b WITH (NOLOCK)
		INNER JOIN  match m WITH (NOLOCK) on b.matchid = m.matchid 		
		WHERE		b.statusID NOT IN (101,102, 121)--('Void', 'Reject', 'Dummy') 
					AND b.matchid = @MatchId 
					AND	(   
							(
								b.bettype IN (SELECT CONVERT(INT,val) FROM dbo.strSplit(@p_bettypes,','))
								 AND CASE WHEN @LiveType <> 2 THEN liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
								 AND b.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE b.livehomescore END
								 AND b.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE b.liveawayscore END
								 AND b.transdate	BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE b.transdate END 
													AND	    CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE b.transdate END 
							)
							 OR
							(
								b.bettype IN (SELECT CONVERT(INT,val) FROM dbo.strSplit(@p_bettypesLive,','))
								AND b.liveindicator = 1
							)
						)
					AND ISNULL(SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
		UNION ALL
		SELECT	b.username,
				b.GameID,		
				b.translogid AS transid,
				m.homeID,
				m.awayID,
				0 as hdp1, 
				0as hdp2, 
				b.odds,
				b.status,
				b.stake,
				b.transdate,		
				NULL betteam,
				NULL betcheck,
				NULL livehomescore,
				NULL liveawayscore,
				b.liveindicator liveindicator, 
				isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
				b.custom1 AS OddsType,
				b.CurrencyName,
				- b.actual_stake as winlost,
				NULL AS betid,
				0 as isMP,
				NULL SecAcceptFlag,
				b.translogid refno,
				b.translogid as ChoiceTransID,
				b.GameID as ChoiceBetType ,
				m.homeid as ChoiceHomeID,
				m.awayid as ChoiceAwayID,
				0 as ChoiceHdp1,
				0 as ChoiceHdp2,
				b.odds as ChoiceOdds,
				b.stake as ChoiceStake,
				NULL as ChoiceBetTeam,
				NULL as ChoiceBetCheck,
				NULL as ChoiceLiveHomeScore,
				NULL as ChoiceLiveAwayScore,
				b.liveindicator as ChoiceLiveIndicator,
				m.leagueid  as ChoiceLeagueId ,
				m.sporttype as ChoiceSportType	
				,b.transdesc
				,m.sporttype AS SportType
				,b.gameID AS OriginalBetType
				,NULL AS ExtraInfo
				,NULL AS BetdaqId
		FROM		Translog b WITH (NOLOCK)
		INNER JOIN  match m WITH (NOLOCK) on b.EventID = m.matchid 	
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
		ORDER BY transID
	END
		
	SELECT * FROM #SpecialDeleteBets
	
	IF @Type = 3				
		SELECT bg.refno, bg.odds, bg.stake, bg.status, bg.bettype, bg.betteam
		FROM #SpecialDeleteBets b
			INNER JOIN bettransG bg WITH(NOLOCK) ON b.refno = bg.refno
			
END 
ELSE
BEGIN 
	SELECT	username ,
			bettype ,				
			transid ,
			0 as homeID ,
			0 as awayID ,
			hdp1 , 
			hdp2 , 
			odds ,	
			status,
			stake ,
			transdate ,		
			betteam ,
			betcheck,
			livehomescore ,
			liveawayscore ,
			liveindicator as IsLiveIndicator, 
			CAST(0 AS BIT) as IsNeutral ,
			OddsType ,
			CurrencyName ,
			winlost ,
			betid,	
			CAST(0 AS BIT) as isMP,
			CAST(0 AS BIT) AS SecAcceptFlag,
			refno,
			transid as ChoiceTransID,
			bettype as ChoiceBetType ,
			0 as ChoiceHomeID,
			0 as ChoiceAwayID,
			hdp1 as ChoiceHdp1,
			hdp2 as ChoiceHdp2,
			odds as ChoiceOdds,
			stake as ChoiceStake,
			betteam as ChoiceBetTeam,
			betcheck as ChoiceBetCheck,
			livehomescore as ChoiceLiveHomeScore,
			liveawayscore as ChoiceLiveAwayScore,
			liveindicator as ChoiceLiveIndicator,
			CAST(0 AS INT)  as ChoiceLeagueId ,
			CAST(0 AS SMALLINT) as ChoiceSportType
			,CAST('' AS NVARCHAR(300)) AS transdesc
			,CAST(1 AS SMALLINT) AS Sporttype			
			,bettype AS OriginalBetType
			,ExtraInfo
			,BetdaqId
	FROM bettrans WITH (NOLOCK)
	WHERE 0 = 1
END 

----******* If list of bettype include 9 *******
IF charindex('9', @p_bettypes , 1) <> 0  
BEGIN 
	---Licensee
	IF @LicenseeName <> 'MBC' AND @LicenseeName <> 'ALL' 
	BEGIN		
		SELECT
				b.username,
				b.bettype,	
				b.transid,	
				m.homeID,
				m.awayID,
				b.hdp1,
				b.hdp2,
				b.odds,
				CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					 ELSE b.status 
					 END  as status,
				b.stake,
				b.transdate,
				b.betteam,
				b.betcheck,
				b.livehomescore,
				b.liveawayscore,
				b.liveindicator as IsLiveIndicator,
				isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
				0 as OddsType,
				b.CurrencyName,
				(b.winlost-b.actual_stake )as winlost,
				b.betid,
				CAST(1 AS BIT) as isMP,
				CAST(0 AS BIT) SecAcceptFlag,
				b.refno,
				bm.transid ChoiceTransID,
				bm.bettype ChoiceBetType,
				m.homeid ChoiceHomeID,
				m.awayid ChoiceAwayID,
				convert(float, bm.hdp1) as ChoiceHdp1, 
				convert(float, bm.hdp2) as ChoiceHdp2, 				  
				bm.odds as ChoiceOdds, 				
				bm.stake ChoiceStake,						
				bm.betteam ChoiceBetTeam,
				bm.betcheck as ChoiceBetCheck,
				bm.livehomescore ChoiceLiveHomeScore,
				bm.liveawayscore ChoiceLiveAwayScore,
				bm.liveindicator ChoiceLiveIndicator	,
				m.leagueid  as ChoiceLeagueId ,
				m.sporttype as ChoiceSportType,
				m.sporttype AS sporttype,
				b.modds,
				bm.transdesc ChoiceTransDesc
		FROM	bettransm bm WITH (NOLOCK)	
		INNER JOIN  Bettrans b WITH (NOLOCK) ON b.refno = bm.refno 
		INNER JOIN dbo.strSplit(@BetTypes,',') t ON b.bettype = t.val
		INNER JOIN  match m WITH (NOLOCK) ON m.matchid = bm.MatchID	
		WHERE		b.srecommend IN ( SELECT custid FROM Dep_CustSuper with(NOLOCK) where site = @LicenseeName) 
					AND b.statusID NOT IN (101,102) --- ('Void', 'Reject' )
					AND b.bettype IN(9,29) AND b.matchID IN (9,29)
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
		SELECT	b.username,
				b.bettype,	
				b.transid,	
				m.homeID,
				m.awayID,
				b.hdp1,
				b.hdp2,
				b.odds,
				CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					 ELSE b.status 
					 END  as status,
				b.stake,
				b.transdate,
				b.betteam,
				b.betcheck,
				b.livehomescore,
				b.liveawayscore,
				b.liveindicator as IsLiveIndicator,
				isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
				0 as OddsType,
				b.CurrencyName,
				(b.winlost-b.actual_stake )as winlost,
				b.betid,
				CAST(1 AS BIT) as isMP,
				CAST(0 AS BIT) SecAcceptFlag,
				b.refno,
				bm.transid ChoiceTransID,
				bm.bettype ChoiceBetType,
				m.homeid ChoiceHomeID,
				m.awayid ChoiceAwayID,
				convert(float, bm.hdp1) as ChoiceHdp1, 
				convert(float, bm.hdp2) as ChoiceHdp2, 				  
				bm.odds as ChoiceOdds, 				
				bm.stake ChoiceStake,						
				bm.betteam ChoiceBetTeam,
				bm.betcheck ChoiceBetCheck,
				bm.livehomescore ChoiceLiveHomeScore,
				bm.liveawayscore ChoiceLiveAwayScore,
				bm.liveindicator ChoiceLiveIndicator,
				m.leagueid  as ChoiceLeagueId ,
				m.sporttype as ChoiceSportType		,
				m.sporttype AS sporttype,
				b.modds,
				bm.transdesc ChoiceTransDesc
		FROM	Bettrans b WITH (NOLOCK) 
		INNER JOIN  bettransm bm WITH (NOLOCK) ON b.refno = bm.refno 
		INNER JOIN dbo.strSplit(@BetTypes,',') t ON b.bettype = t.val
		INNER JOIN  match m WITH (NOLOCK) ON m.matchid = bm.matchID
		WHERE		b.recommend NOT IN (SELECT CustID FROM #CustIDs WITH (NOLOCK) ) 
					AND b.statusID NOT IN (101,102) --('Void', 'Reject')
					AND b.bettype IN (9,29) AND b.matchID IN (9,29)
					AND bm.matchid = @MatchId 	 
					AND CASE WHEN @LiveType <> 2 THEN bm.liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
					AND bm.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE bm.livehomescore END
					AND bm.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE bm.liveawayscore END
					AND bm.transdate BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE bm.transdate END 
									 AND	 CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE bm.transdate END
					AND ISNULL(SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
					AND (b.betid = 0 OR b.betid IS NULL)
	END 

	---ALL
	IF @LicenseeName= 'ALL'  
	BEGIN		
		SELECT	b.username,
				b.bettype,	
				b.transid,	
				m.homeID,
				m.awayID,
				b.hdp1,
				b.hdp2,
				b.odds,
				CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					 ELSE b.status 
					 END  as status,
				b.stake,
				b.transdate,
				b.betteam,
				b.betcheck,
				b.livehomescore,
				b.liveawayscore,
				b.liveindicator as IsLiveIndicator,
				isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
				0 as OddsType,
				b.CurrencyName,
				(b.winlost-b.actual_stake )as winlost,
				b.betid,
				CAST(1 AS BIT) as isMP,
				CAST(0 AS BIT) SecAcceptFlag,
				b.refno,
				bm.transid ChoiceTransID,
				bm.bettype ChoiceBetType,
				m.homeid ChoiceHomeID,
				m.awayid ChoiceAwayID,
				convert(float, bm.hdp1) as ChoiceHdp1, 
				convert(float, bm.hdp2) as ChoiceHdp2, 				  
				bm.odds as ChoiceOdds, 				
				bm.stake ChoiceStake,						
				bm.betteam ChoiceBetTeam,
				bm.betcheck ChoiceBetCheck,
				bm.livehomescore ChoiceLiveHomeScore,
				bm.liveawayscore ChoiceLiveAwayScore,
				bm.liveindicator ChoiceLiveIndicator	,
				m.leagueid  as ChoiceLeagueId ,
				m.sporttype as ChoiceSportType,
				m.sporttype AS sporttype				,
				b.modds,
				bm.transdesc ChoiceTransDesc
		FROM	Bettrans b WITH (NOLOCK)	
		INNER JOIN  bettransm bm WITH (NOLOCK) ON b.refno = bm.refno 
		INNER JOIN dbo.strSplit(@BetTypes,',') t ON b.bettype = t.val
		INNER JOIN  match m WITH (NOLOCK) ON m.matchid = bm.matchID
		WHERE		b.statusID NOT IN (101,102)--('Void', 'Reject')
					AND b.bettype IN (9,29) AND b.matchID IN (9,29) 
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
ELSE 
BEGIN
		SELECT	username ,
				bettype ,	
				transid,
				0 as homeID ,
				0 as awayID ,
				hdp1 , 
				hdp2 , 
				odds ,
				status,
				transdate ,		
				betteam	,
				betcheck,
				livehomescore ,
				liveawayscore ,
				liveindicator as IsLiveIndicator , 
				CAST(0 AS BIT) as IsNeutral ,
				OddsType ,
				CurrencyName ,
				winlost - actual_stake as winlost,
				betid,
				CAST(0 AS BIT) as isMP,
				CAST(0 AS BIT) SecAcceptFlag,
				refno,
				transid as ChoiceTransID,
				bettype ChoiceBetType,
				0 ChoiceHomeID,
				0 ChoiceAwayID,
				convert(float, hdp1) ChoiceHdp1,
				convert(float, hdp2) ChoiceHdp2,
				odds AS ChoiceOdds,
				stake AS ChoiceStake,
				betteam AS ChoiceBetTeam,
				betcheck AS ChoiceBetCheck,
				livehomescore AS ChoiceLiveHomeScore,
				liveawayscore AS ChoiceLiveAwayScore,
				liveindicator AS ChoiceLiveIndicator,
				CAST(0 AS INT)  as ChoiceLeagueId ,
				CAST(0 AS TINYINT) as ChoiceSportType,
				CAST(0 AS TINYINT) AS sporttype,
				modds,
				transdesc
		FROM bettrans WITH (NOLOCK) 
		WHERE 0 = 1
END




GO
GRANT EXECUTE ON [dbo].[NAP_Rpt_TicketsListingDetail] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Rpt_TicketsListingDetail] TO [vnteam] AS [dbo]