/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Rpt_TicketsListingDetail]
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
    @BallSequence VARCHAR(200)	= ''
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
		- 20170530@Kent: Integrate Betradar Virtual Sports [Redmine:#77177]
		- 20170818@Kent: Re-Add columns OriginalBetType, ExtraInfo, BetdaqId And Add new column ActualStake [Redmine:#81868] 
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
     
   Example:    exec NAP_Rpt_TicketsListingDetail @MatchId=4626986,@LicenseeName='IBC',@BetTypes='1101,1102',@BetTypesLive='',@LiveType=0,@LiveHomeScore=default,@LiveAwayScore=default,@FromTransdate=default,@ToTransdate=default,@Type=2,@SecondAcceptFlag=0
	
*/
SET NOCOUNT ON 

DECLARE @p_bettypes VARCHAR(1000)

SET @p_bettypes = @BetTypes

---- If not sportbook then don't care @livetype , so set @LiveType to 2 (All)
IF @Type <> 0
	SELECT @LiveType = 2

SELECT CustID 
INTO #CustIDs
FROM DBLIC.bodb_Licensee.dbo.LicenseeCust WITH (NOLOCK)

CREATE TABLE #TmpBallSequence 
(	
	Seq	TINYINT
)

CREATE TABLE #TmpbingoBall (
	Number TINYINT,
	Seq	   TINYINT
)
CREATE CLUSTERED INDEX CIX_TmpbingoBall_Number ON #TmpbingoBall(Number)

CREATE TABLE #SpecialDeleteBets 
(
	username VARCHAR(30),
	bettype SMALLINT,
	OriginalBetType SMALLINT,
	ExtraInfo VARCHAR(1000),
	BetdaqId BIGINT,
	ActualStake MONEY,
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
	IsParlay BIT,
	SecAcceptFlag BIT,		
	refno BIGINT,
	TransDesc NVARCHAR(300),
	SportType SMALLINT,
	MOdds SMALLMONEY,
	BallSequence TINYINT,	
	
	SubTransID BIGINT ,
	SubBetType INT  ,
	SubHomeID INT  ,
    SubAwayID INT   ,
    SubHdp1 SMALLMONEY  , 
    SubHdp2 SMALLMONEY  ,
    SubOdds MONEY   ,
	SubStake MONEY,
    SubBetTeam NVARCHAR(20), 
    SubBetCheck NVARCHAR(50), 
    SubLiveHomeScore SMALLINT  ,
    SubLiveAwayScore SMALLINT  ,
    SubLiveIndicator BIT  ,
	SubLeagueId INT  ,
    SubSportType SMALLINT,         
	SubTransDesc NVARCHAR(300)
)

INSERT INTO #TmpBallSequence(Seq)
SELECT  val
FROM	dbo.f_SplitString(@BallSequence, ',')
OPTION (maxrecursion 0)

INSERT INTO #TmpbingoBall(Number, Seq)
SELECT Number, Seq
FROM DBTXN.bodb02.[dbo].[bingoBall]
WHERE Matchid = @MatchId

----***** bettype <> 9 (because bettype = 9 then matchID = 9)****----
IF @p_bettypes <> '9' AND @BetTypes <> '29' AND @BetTypes <> '2799' AND @BetTypes <> '9,29,2799'
BEGIN	
	----Direct Licensee
	IF @LicenseeName <> 'MBC' AND @LicenseeName <> 'ALL' 
	BEGIN
		;WITH CTE_CalculateBallSequence_bettrans AS
		(
			SELECT *
				 , CASE
						WHEN b.bettype = 88 
								THEN CASE 
										WHEN b.betteam = 'a' AND b.betid = 0 THEN 2
										WHEN b.betteam = 'h' AND b.betid = 0 THEN 3
										ELSE NULL
									 END
						WHEN b.bettype IN (85, 86, 89, 90) AND b.betid = 0 THEN 1
						WHEN b.bettype IN (85, 86, 87, 89, 90) THEN T_Seq.Seq							
						ELSE NULL
				   END AS BallSequence
				 , CASE
						WHEN b.bettype BETWEEN 85 AND 90 THEN 1
						ELSE 0
				   END AS IsNumberGame
			FROM bettrans b (NOLOCK)
				 OUTER APPLY (SELECT TOP 1 (Seq + 1) AS Seq
							  FROM #TmpbingoBall
							  WHERE Number = b.betid) T_Seq
		)				 
		INSERT INTO #SpecialDeleteBets
		SELECT	b.username,
				b.bettype,				
				b.bettype AS OriginalBetType,
				b.ExtraInfo,
				b.BetdaqId,
				b.actual_stake AS ActualStake,						
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
				0 as IsParlay,
				ISNULL(SecAcceptFlag,0) SecAcceptFlag,
				b.refno,
				b.TransDesc,
				m.sporttype,
				b.MOdds,
				b.BallSequence,				
				
				NULL AS SubTransID,
				NULL AS SubBetType,
				NULL AS SubHomeID,
				NULL AS SubAwayID,
				NULL AS SubHdp1, 
				NULL AS SubHdp2,
				NULL AS SubOdds,
				NULL AS SubStake,
				NULL AS SubBetTeam, 
				NULL AS SubBetCheck, 
				NULL AS SubLiveHomeScore,
				NULL AS SubLiveAwayScore,
				NULL AS SubLiveIndicator,
				NULL AS SubLeagueId,
				NULL AS SubSportType,          
				NULL AS SubTransDesc
		FROM		CTE_CalculateBallSequence_bettrans b WITH (NOLOCK) 
		INNER JOIN  match m WITH (NOLOCK) on b.matchid = m.matchid 		
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
                    AND CASE
							WHEN IsNumberGame = 0 THEN 1
							ELSE CASE
										WHEN EXISTS (SELECT TOP 1 1
													 FROM #TmpBallSequence
													 WHERE Seq = b.BallSequence)
												THEN 1
										ELSE 0
								 END
						END = 1 -- Filter for BallSequence
		UNION ALL
		SELECT	b.username,
				b.gameID AS bettype,				
				b.gameID AS OriginalBetType,
				NULL AS ExtraInfo,
				NULL AS BetdaqId,
				b.actual_stake AS ActualStake,						
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
				0 IsParlay,
				NULL SecAcceptFlag,
				b.translogid refno,
				b.TransDesc,
				m.SportType,
				NULL AS MOdds,
				NULL AS BallSequence,				
				
				NULL AS SubTransID,
				NULL AS SubBetType,
				NULL AS SubHomeID,
				NULL AS SubAwayID,
				NULL AS SubHdp1, 
				NULL AS SubHdp2,
				NULL AS SubOdds,
				NULL AS SubStake,
				NULL AS SubBetTeam, 
				NULL AS SubBetCheck, 
				NULL AS SubLiveHomeScore,
				NULL AS SubLiveAwayScore,
				NULL AS SubLiveIndicator,
				NULL AS SubLeagueId,
				NULL AS SubSportType,          
				NULL AS SubTransDesc
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
		;WITH CTE_CalculateBallSequence_bettrans AS
		(
			SELECT *
				 , CASE
						WHEN b.bettype = 88 
								THEN CASE 
										WHEN b.betteam = 'a' AND b.betid = 0 THEN 2
										WHEN b.betteam = 'h' AND b.betid = 0 THEN 3
										ELSE NULL
									 END
						WHEN b.bettype IN (85, 86, 89, 90) AND b.betid = 0 THEN 1
						WHEN b.bettype IN (85, 86, 87, 89, 90) THEN T_Seq.Seq							
						ELSE NULL
				   END AS BallSequence
				 , CASE
						WHEN b.bettype BETWEEN 85 AND 90 THEN 1
						ELSE 0
				   END AS IsNumberGame
			FROM bettrans b (NOLOCK)
				 OUTER APPLY (SELECT TOP 1 (Seq + 1) AS Seq
							  FROM #TmpbingoBall
							  WHERE Number = b.betid) T_Seq
		)	
		INSERT INTO #SpecialDeleteBets
		SELECT	b.username,
				b.bettype,				
				b.bettype AS OriginalBetType,
				b.ExtraInfo,
				b.BetdaqId,
				b.actual_stake AS ActualStake,						
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
				0 as IsParlay,
				ISNULL(SecAcceptFlag,0) SecAcceptFlag,
				b.refno,
				b.TransDesc,
				m.SportType,
				b.MOdds,
				b.BallSequence,				
				
				NULL AS SubTransID,
				NULL AS SubBetType,
				NULL AS SubHomeID,
				NULL AS SubAwayID,
				NULL AS SubHdp1, 
				NULL AS SubHdp2,
				NULL AS SubOdds,
				NULL AS SubStake,
				NULL AS SubBetTeam, 
				NULL AS SubBetCheck, 
				NULL AS SubLiveHomeScore,
				NULL AS SubLiveAwayScore,
				NULL AS SubLiveIndicator,
				NULL AS SubLeagueId,
				NULL AS SubSportType,          
				NULL AS SubTransDesc
		FROM		CTE_CalculateBallSequence_bettrans b WITH (NOLOCK) 
		INNER JOIN  match m WITH (NOLOCK) on b.matchid = m.matchid 	
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
						AND CASE
								WHEN IsNumberGame = 0 THEN 1
								ELSE CASE
											WHEN EXISTS (SELECT TOP 1 1
														 FROM #TmpBallSequence
														 WHERE Seq = b.BallSequence)
													THEN 1
											ELSE 0
									 END
							END = 1 -- Filter for BallSequence
		UNION ALL
		SELECT	b.username,
				b.GameID AS bettype,					
				b.gameID AS OriginalBetType,
				NULL AS ExtraInfo,
				NULL AS BetdaqId,
				b.actual_stake AS ActualStake,					
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
				0 as IsParlay,
				NULL SecAcceptFlag,
				b.translogid refno,
				b.TransDesc,
				m.SportType,
				NULL AS MOdds,
				NULL AS BallSequence,				
				
				NULL AS SubTransID,
				NULL AS SubBetType,
				NULL AS SubHomeID,
				NULL AS SubAwayID,
				NULL AS SubHdp1, 
				NULL AS SubHdp2,
				NULL AS SubOdds,
				NULL AS SubStake,
				NULL AS SubBetTeam, 
				NULL AS SubBetCheck, 
				NULL AS SubLiveHomeScore,
				NULL AS SubLiveAwayScore,
				NULL AS SubLiveIndicator,
				NULL AS SubLeagueId,
				NULL AS SubSportType,          
				NULL AS SubTransDesc
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
		;WITH CTE_CalculateBallSequence_bettrans AS
		(
			SELECT *
				 , CASE
						WHEN b.bettype = 88 
								THEN CASE 
										WHEN b.betteam = 'a' AND b.betid = 0 THEN 2
										WHEN b.betteam = 'h' AND b.betid = 0 THEN 3
										ELSE NULL
									 END
						WHEN b.bettype IN (85, 86, 89, 90) AND b.betid = 0 THEN 1
						WHEN b.bettype IN (85, 86, 87, 89, 90) THEN T_Seq.Seq							
						ELSE NULL
				   END AS BallSequence
				 , CASE
						WHEN b.bettype BETWEEN 85 AND 90 THEN 1
						ELSE 0
				   END AS IsNumberGame
			FROM bettrans b (NOLOCK)
				 OUTER APPLY (SELECT TOP 1 (Seq + 1) AS Seq
							  FROM #TmpbingoBall
							  WHERE Number = b.betid) T_Seq
		)	
		INSERT INTO #SpecialDeleteBets
		SELECT	b.username,
				b.bettype,					
				b.bettype AS OriginalBetType,
				b.ExtraInfo,
				b.BetdaqId,
				b.actual_stake AS ActualStake,					
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
				0 as IsParlay,
				ISNULL(SecAcceptFlag,0) SecAcceptFlag,
				b.refno,
				b.TransDesc,
				m.SportType,
				b.MOdds,
				b.BallSequence,				
				
				NULL AS SubTransID,
				NULL AS SubBetType,
				NULL AS SubHomeID,
				NULL AS SubAwayID,
				NULL AS SubHdp1, 
				NULL AS SubHdp2,
				NULL AS SubOdds,
				NULL AS SubStake,
				NULL AS SubBetTeam, 
				NULL AS SubBetCheck, 
				NULL AS SubLiveHomeScore,
				NULL AS SubLiveAwayScore,
				NULL AS SubLiveIndicator,
				NULL AS SubLeagueId,
				NULL AS SubSportType,          
				NULL AS SubTransDesc
		FROM		CTE_CalculateBallSequence_bettrans b WITH (NOLOCK)
		INNER JOIN  match m WITH (NOLOCK) on b.matchid = m.matchid 		
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
					AND CASE
							WHEN IsNumberGame = 0 THEN 1
							ELSE CASE
										WHEN EXISTS (SELECT TOP 1 1
													 FROM #TmpBallSequence
													 WHERE Seq = b.BallSequence)
												THEN 1
										ELSE 0
								 END
						END = 1 -- Filter for BallSequence
		UNION ALL
		SELECT	b.username,
				b.GameID AS bettype,				
				b.gameID AS OriginalBetType,
				NULL AS ExtraInfo,
				NULL AS BetdaqId,
				b.actual_stake AS ActualStake,						
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
				0 as IsParlay,
				NULL SecAcceptFlag,
				b.translogid refno,
				b.TransDesc,
				m.SportType,
				NULL AS MOdds,
				NULL AS BallSequence,				
				
				NULL AS SubTransID,
				NULL AS SubBetType,
				NULL AS SubHomeID,
				NULL AS SubAwayID,
				NULL AS SubHdp1, 
				NULL AS SubHdp2,
				NULL AS SubOdds,
				NULL AS SubStake,
				NULL AS SubBetTeam, 
				NULL AS SubBetCheck, 
				NULL AS SubLiveHomeScore,
				NULL AS SubLiveAwayScore,
				NULL AS SubLiveIndicator,
				NULL AS SubLeagueId,
				NULL AS SubSportType,          
				NULL AS SubTransDesc
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
END

----******* If list of bettype include 9 *******
IF charindex('9', @p_bettypes , 1) <> 0 
   OR charindex('2799', @p_bettypes , 1) <> 0  
BEGIN 
	---Licensee
	IF @LicenseeName <> 'MBC' AND @LicenseeName <> 'ALL' 
	BEGIN
		INSERT INTO #SpecialDeleteBets		
		SELECT	b.username,
				b.bettype,				
				b.bettype AS OriginalBetType,
				b.ExtraInfo,
				b.BetdaqId,
				b.actual_stake AS ActualStake,					
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
				1 as IsParlay,
				0 SecAcceptFlag,
				b.refno,
				b.TransDesc,
				m.SportType,
				b.MOdds,
				NULL AS BallSequence,				
				
				bm.transid SubTransID,
				bm.bettype SubBetType,
				m.homeid SubHomeID,
				m.awayid SubAwayID,
				convert(float, bm.hdp1) as SubHdp1, 
				convert(float, bm.hdp2) as SubHdp2, 				  
				bm.odds as SubOdds, 				
				bm.stake SubStake,						
				bm.betteam SubBetTeam,
				bm.betcheck as SubBetCheck,
				bm.livehomescore SubLiveHomeScore,
				bm.liveawayscore SubLiveAwayScore,
				bm.liveindicator SubLiveIndicator,
				m.leagueid  as SubLeagueId ,
				m.sporttype as SubSportType,				
				bm.transdesc SubTransDesc
		FROM	bettransm bm WITH (NOLOCK)	
		INNER JOIN  Bettrans b WITH (NOLOCK) ON b.refno = bm.refno 
		INNER JOIN dbo.strSplit(@BetTypes,',') t ON b.bettype = t.val
		INNER JOIN  match m WITH (NOLOCK) ON m.matchid = bm.MatchID	
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
		INSERT INTO #SpecialDeleteBets	
		SELECT	b.username,
				b.bettype,				
				b.bettype AS OriginalBetType,
				b.ExtraInfo,
				b.BetdaqId,
				b.actual_stake AS ActualStake,					
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
				1 as IsParlay,
				0 SecAcceptFlag,
				b.refno,
				b.TransDesc,
				m.SportType,
				b.MOdds,
				NULL AS BallSequence,				
				
				bm.transid SubTransID,
				bm.bettype SubBetType,
				m.homeid SubHomeID,
				m.awayid SubAwayID,
				convert(float, bm.hdp1) as SubHdp1, 
				convert(float, bm.hdp2) as SubHdp2, 				  
				bm.odds as SubOdds, 				
				bm.stake SubStake,						
				bm.betteam SubBetTeam,
				bm.betcheck SubBetCheck,
				bm.livehomescore SubLiveHomeScore,
				bm.liveawayscore SubLiveAwayScore,
				bm.liveindicator SubLiveIndicator,
				m.leagueid  as SubLeagueId,
				m.sporttype as SubSportType,				
				bm.transdesc SubTransDesc
		FROM	Bettrans b WITH (NOLOCK) 
		INNER JOIN  bettransm bm WITH (NOLOCK) ON b.refno = bm.refno 
		INNER JOIN dbo.strSplit(@BetTypes,',') t ON b.bettype = t.val
		INNER JOIN  match m WITH (NOLOCK) ON m.matchid = bm.matchID
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
	END 

	---ALL
	IF @LicenseeName= 'ALL'  
	BEGIN
		INSERT INTO #SpecialDeleteBets		
		SELECT	b.username,
				b.bettype,				
				b.bettype AS OriginalBetType,
				b.ExtraInfo,
				b.BetdaqId,
				b.actual_stake AS ActualStake,					
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
				1 as IsParlay,
				0 SecAcceptFlag,
				b.refno,
				b.TransDesc,
				m.SportType,
				b.MOdds,
				NULL AS BallSequence,				
				
				bm.transid SubTransID,
				bm.bettype SubBetType,
				m.homeid SubHomeID,
				m.awayid SubAwayID,
				convert(float, bm.hdp1) as SubHdp1, 
				convert(float, bm.hdp2) as SubHdp2, 				  
				bm.odds as SubOdds, 				
				bm.stake SubStake,						
				bm.betteam SubBetTeam,
				bm.betcheck SubBetCheck,
				bm.livehomescore SubLiveHomeScore,
				bm.liveawayscore SubLiveAwayScore,
				bm.liveindicator SubLiveIndicator,
				m.leagueid  as SubLeagueId ,
				m.sporttype as SubSportType,				
				bm.transdesc SubTransDesc
		FROM	Bettrans b WITH (NOLOCK)	
		INNER JOIN  bettransm bm WITH (NOLOCK) ON b.refno = bm.refno 
		INNER JOIN dbo.strSplit(@BetTypes,',') t ON b.bettype = t.val
		INNER JOIN  match m WITH (NOLOCK) ON m.matchid = bm.matchID
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
		bettype,		
		OriginalBetType,
		ExtraInfo,
		BetdaqId,
		ActualStake,		
		transid,
		homeid,
		awayid,
		hdp1, 
		hdp2,
		odds,
		status,
		stake,
		transdate, 
		betteam,
		betcheck,
		livehomescore, 
		liveawayscore,
		IsLiveIndicator,
		ISNeutral,
		OddsType, 
		CurrencyName,
		winlost,
		betid,
		IsParlay,
		SecAcceptFlag,		
		refno,
		TransDesc,
		SportType,
		MOdds,
		BallSequence,			
		
		SubTransID,
		SubBetType,
		SubHomeID,
		SubAwayID,
		SubHdp1, 
		SubHdp2,
		SubOdds,
		SubStake,
		SubBetTeam, 
		SubBetCheck, 
		SubLiveHomeScore,
		SubLiveAwayScore,
		SubLiveIndicator,
		SubLeagueId,
		SubSportType,          
		SubTransDesc 
FROM #SpecialDeleteBets
		 
GO
