/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BettransSelRecoverParlayBet_Sub] 
	@BetType		VARCHAR(20) = 'all'
	,@MatchId		INT			= 0	
	,@TransIds		VARCHAR(MAX)	= ''
AS
/*
	Created: Kent
	Date: 20161111
	DB: DBTXN/bodb02

	Revisions: 		
		- 20161011@Kent: Select sub voided Parlay tickets [Redmine:#65531]
		- 20170525@Kent: Remove dummy tables and fix bit datatype columns [Redmine:#77040]
		- 20190719@Raymond.Le: Extend days recover ticket unlimited [#115376]
		- 20201126@Charles: God of fortune [Redmine: #146053]
		- 20210712@July: [TVS] Modify the way to get move bet date [Redmine: #154974]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220906@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]

	Param's Explanation:			
			- @BetType:
			'all': All
			'Mix Parlay': Mix Parlay
			'System Parlay': System Parlay
*/
BEGIN
	SET NOCOUNT ON
		
	DECLARE @tblRecoverBet TABLE (
		SubTransID				BIGINT		 
		,SubBetCheck			NVARCHAR(50)
		,SubOdds				MONEY   
		,SubBetTeam				NVARCHAR(20)  
		,SubBetType				INT  
		,SubHdp1				SMALLMONEY   
		,SubHdp2				SMALLMONEY	
		,SubTransDesc			NVARCHAR(200)	
		,SubLivehomescore		SMALLINT 
		,SubLiveawayscore		SMALLINT 
		,SubLiveindicator		BIT	
		,SubHomeID				INT 
		,SubAwayID				INT 
		,SubSportType			SMALLINT 
		,SubLeagueID			INT	
		,EventDate				DATETIME		
		,custid					INT
		,isdeposit				BIT
		,mrecommend				INT
		,recommend				INT
		,transid				BIGINT
		,UserName				VARCHAR(30)
		,TransDate				DATETIME 
		,BetType				SMALLINT
		,Refno					BIGINT
		,Status					NVARCHAR(10)
		,WinLost				MONEY
		,betid					BIGINT 
		,BetTeam				NVARCHAR(20)		
		,Stake					MONEY
		,Odds					MONEY		
		,hdp1					SMALLMONEY
		,hdp2					SMALLMONEY		 
		,betcheck				NVARCHAR(50)
		,ExtraInfo				VARCHAR(1000)
		,ActualStake			MONEY
	)		
	DECLARE @tblTransIds TABLE (transid BIGINT)
	DECLARE @tmpTransIdMoveBet TABLE (Transid BIGINT)
	DECLARE @MovebetDate		DATETIME
		   ,@SiteDBGroupID		SMALLINT = 0
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	INSERT INTO @tblTransIds(transid)
	SELECT ss.value
	FROM STRING_SPLIT(@TransIds, ',') ss				
	
	INSERT INTO @tblRecoverBet(
			 SubTransID			 
			,SubBetCheck	
			,SubOdds
			,SubBetTeam	
			,SubBetType
			,SubHdp1		
			,SubHdp2
			,SubTransDesc
			,SubLivehomescore 
			,SubLiveawayscore 
			,SubLiveindicator
			,SubHomeID
			,SubAwayID
			,SubSportType 
			,SubLeagueID
			,EventDate			
			,custid
			,isdeposit
			,mrecommend				
			,recommend				
			,transid
			,UserName
			,TransDate	
			,BetType	
			,Refno	
			,Status
			,WinLost
			,betid	
			,BetTeam			
			,Stake	
			,Odds			
			,hdp1
			,hdp2			 
			,betcheck
			,ExtraInfo
			,ActualStake)
	SELECT  bm.transid AS SubTransID			 
			,bm.betcheck AS SubBetCheck	
			,bm.odds AS SubOdds
			,bm.betteam AS SubBetTeam	
			,bm.bettype AS SubBetType
			,bm.hdp1 AS SubHdp1		
			,bm.hdp2 AS SubHdp2	
			,bm.transdesc AS SubTransDesc	
			,bm.livehomescore AS SubLivehomescore 
			,bm.liveawayscore AS SubLiveawayscore 
			,bm.liveindicator AS SubLiveindicator
			,m.homeid AS SubHomeID
			,m.awayid AS SubAwayID
			,m.sporttype AS SubSportType 
			,m.leagueid AS SubLeagueID				
			,m.eventdate AS EventDate			
			,b.custid AS custid
			,case when EXISTS (select TOP 1 1 from custDB.dbo.Dep_CustSuper with(nolock) WHERE custid = b.srecommend) then 1 else 0 end AS isdeposit
			,b.mrecommend AS mrecommend
			,b.recommend AS recommend
			,b.transid AS transid
			,b.Username AS UserName
			,b.transdate AS TransDate	
			,b.bettype AS BetType	
			,b.refno AS Refno	
			,b.[status] AS [Status]
			,b.winlost-b.actual_stake AS WinLost
			,b.betid AS betid	
			,b.betteam AS BetTeam												
			,b.stake AS Stake	
			,b.odds AS Odds			
			,b.hdp1 AS hdp1
			,b.hdp2 AS hdp2			 
			,b.betcheck AS betcheck
			,b.ExtraInfo
			,b.actual_stake AS ActualStake		
	FROM @tblTransIds t
		INNER JOIN dbo.bettrans b WITH (NOLOCK)
				ON t.transid = b.transid AND b.SiteDBGroupID = @SiteDBGroupID		   
		INNER JOIN bettransm bm WITH (NOLOCK)
				ON b.refno = bm.refno AND bm.SiteDBGroupID = b.SiteDBGroupID				
		INNER JOIN dbo.match m WITH(NOLOCK)
				ON	m.matchid = bm.matchid			   
	WHERE	bm.matchid = @MatchId
			AND b.bettype = 29	
			AND bm.statusid = 102
			AND (b.betfrom IS NULL OR b.betfrom <> 'p')
			AND (m.sporttype BETWEEN 1 AND 99)		
			AND CASE
					WHEN @BetType = 'all' THEN 1
					WHEN @BetType = 'Mix Parlay' THEN CASE WHEN b.betteam = 1 THEN 1 ELSE 0 END
					WHEN @BetType = 'System Parlay' THEN CASE WHEN b.betteam = 1 THEN 0 ELSE 1 END
					ELSE 0
				END	= 1													
	
	/*Modify the way to get move bet date*/
	EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @MovebetDate OUTPUT

	IF EXISTS (SELECT TOP 1 1 FROM @tblRecoverBet WHERE EventDate <= @MovebetDate)
	BEGIN
		DELETE 
		FROM @tblRecoverBet
			OUTPUT	DELETED.TransId
			INTO @tmpTransIdMoveBet (TransId)
		WHERE EventDate <= @MovebetDate
	END
		
	SELECT	t.SubTransID     
			 ,t.SubBetCheck  
			 ,t.SubOdds      
			 ,t.SubBetTeam  
			 ,t.SubBetType     
			 ,t.SubHdp1       
			 ,t.SubHdp2 
			 ,t.SubTransDesc 
			 ,t.SubLivehomescore   
			 ,t.SubLiveawayscore 
			 ,t.SubLiveindicator 
			 ,t.SubHomeID
			 ,t.SubAwayID
			 ,t.SubSportType 
			 ,t.SubLeagueID  			 
			 ,SUBSTRING(T1.GroupName, 3, 30) AS GroupName			 
			 ,t.transid    
			 ,t.UserName    
			 ,t.TransDate     
			 ,t.BetType    
			 ,t.Refno     
			 ,t.[Status]     
			 ,t.WinLost    
			 ,t.betid     
			 ,t.BetTeam    			   
			 ,t.Stake     
			 ,t.Odds     			     
			 ,t.hdp1     
			 ,t.hdp2     			 
			 ,t.betcheck
			 ,t.ExtraInfo
			 ,t.ActualStake
			 ,@SiteDBGroupID AS SiteDBGroupID
	FROM @tblRecoverBet t
		LEFT JOIN dbo.f_GetBetDaqCustomer(1) f
			   ON t.custid = f.CustID
		CROSS APPLY (SELECT CASE
								WHEN f.CustID IS NULL
									AND t.username <> '12EU'
									AND t.IsDeposit = 0
									AND t.mrecommend NOT IN (105181, 118473, 105183) -- MHC
									AND t.recommend NOT IN (11196380, 13423967, 52466) -- Foobet, 1E, 8RM
									AND t.custid NOT IN (1077687,2331,115770,15523642,15042477,16041068,16041058)
										THEN '0-Credit' --1. For Normal bets
								WHEN t.recommend = 52466
										THEN '1-8RM' ----2: For 8RM
								WHEN f.CustID IS NULL -- Betdaq
									AND t.username <> '12EU' 
									AND t.IsDeposit = 1	
									AND t.mrecommend NOT IN (105181, 118473, 105183)
									AND t.recommend NOT IN (11196380, 13423967, 52466) -- Foobet: 11196380, 1E: 13423967, 8RM: 52466
									AND t.custid NOT IN (1077687,2331,115770,15523642,15042477,16041068,16041058) -- Betfair: BFOS, BF, ITibc102, BF3
										THEN '2-Deposit' ----3. For Deposit bets
								WHEN t.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) -- Betfair: BFOS, BF, ITibc102, BF3
										THEN '3-BetFair' ----8: For Betfair
								ELSE NULL
						    END AS GroupName) AS T1								
	WHERE T1.GroupName IS NOT NULL
	ORDER BY T1.GroupName, t.transid				

	--- invalid trans info
	/*
	cases : 
		1/ transid in bettrans AND subtransid in bettransm => isMoved = 0 (not satisfied additional conditions of search)
		
		2/ transid in bettrans14, subtransid in bettransm14 => isMoved = 1
		3/ transid in bettrans14, subtransid in bettransm => isMoved = 1		
		4/ transid in bettrans, subtransid in bettransm14 => isMoved = 1
								
		5/ transid not in bettrans OR subtransid not in bettransm  => isMoved = 0 (not real ticket)
		6/ transid belong to match are going to be moved => isMoved = 1
	*/
	;WITH InvalidTransID AS
	(
		SELECT t.transid		 
		FROM @tblTransIds t
		WHERE NOT EXISTS (SELECT TOP 1 1 
						  FROM @tblRecoverBet 
						  WHERE transid = t.transid)
	)
	SELECT t.transid AS InvalidTrans
		 , CASE
				WHEN m.transid IS NOT NULL
						THEN CAST(1 AS BIT) -- case 6
				WHEN b.transid IS NOT NULL
					 AND bm.transid IS NOT NULL
						THEN CAST(0 AS BIT) -- case 1
				WHEN b14.transid IS NOT NULL
					 OR bm14.transid IS NOT NULL
						THEN CAST(1 AS BIT) -- case 2 + 3 + 4					
				ELSE CAST(0 AS BIT) -- case 5 					
		   END AS isMoved
	FROM InvalidTransID t
		 LEFT JOIN bettrans b WITH(NOLOCK)
				ON t.transid = b.transid
				   AND b.bettype = 29 AND b.SiteDBGroupID = @SiteDBGroupID
		 LEFT JOIN bettransm bm WITH (NOLOCK)
				ON b.refno = bm.refno AND bm.SiteDBGroupID = @SiteDBGroupID
				   AND bm.matchid = @MatchId
		 LEFT JOIN bettrans14 b14 WITH(NOLOCK)
				ON t.transid = b14.transid AND b14.SiteDBGroupID = @SiteDBGroupID
		 LEFT JOIN bettransm14 bm14 WITH(NOLOCK)
				ON ISNULL(b.refno, b14.refno) = bm14.refno
				   AND bm14.matchid = @MatchId AND bm14.SiteDBGroupID = @SiteDBGroupID
		 LEFT JOIN @tmpTransIdMoveBet m
				ON t.transid = m.transid		
END