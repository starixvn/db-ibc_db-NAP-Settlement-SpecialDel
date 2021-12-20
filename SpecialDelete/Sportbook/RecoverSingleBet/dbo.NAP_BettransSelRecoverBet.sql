/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BettransSelRecoverBet]
(
	@Option BIT = 0
	,@MatchId		BIGINT			= 0
	,@FromTransId	BIGINT			= 0
	,@ToTransId		BIGINT			= 0
	,@TransIds		VARCHAR(MAX)	= ''
)
AS
/*
	Created: Kathy
	Date: 20131022
	DB: DBTXN/bodb02

	Revisions: 
		- 20140102@Kathy: Add username2 column [Redmine:#10270]
		- 20140210@Kathy: Correct winlost value 
		- 20141017@Kathy: Support recover Sportting Solution bettypes [Redmine:#23129] (1301 -> 1324)
		- 20141125@Kathy: Add betid column [Redmine:#26489]	
		- 20150210@Kathy: allow the recovery of the "voided tickets" which have the winloss date before yesterday [Redmine:#30298]
		- 20150402@Dominic: Add new 60 bettypes [Redmine:#27214]
		- 20150611@Dominic: BetTrade Integration [Redmine:#36964]
		- 20150630@Dominic: Add metric gaming bettype bettypes [Redmine:#38200]
		- 20151021@Patrick: Support Muay Thai [Redmine:#46015]
		- 20151021@Kathy: Do not show ticket 901 if its owner is not BetTrade account(betdaqid = 0)[Redmine:#43233]
		- 20151102@Kathy: Enhance performance [Redmine:#43233]
		- 20150712@Kathy: Database - Change datatype [Redmine: #48660]
		- 20160112@Patrick: Support Cricket [Redmine: #50688]
		- 20160816@Bobby: #62527 - Update BT's info for showing bet list
		- 20161013@Kathy: Exclude phone betting tickets [Redmine:#63211]
		- 20170316@Kent: Integrate cash-out [Redmine:#72059]
		- 20170417@Kent: Tune performance [Redmine:#72059]
		- 20170525@Kent: Remove dummy tables and fix bit datatype columns [Redmine:#77040]
		- 20170503@Kent: Integrate bonus [Redmine:#72790]
		- 20180306@Kathy: get Refcode value [Redmine:#91461]
		- 20180301@Benjamin: Add oddsspread - Fast Markets Phase 2 [Redmine:#90667]
		- 20180327@Helen:  Correct Transdesc column size [Redmine: #92810]
		- 20181004@Alan: Add new column SettlementStatus [102423]
		- 20190812@Charles: Add new column IsMarked [118437]
		- 20190719@Raymond.Le: Extend days recover ticket unlimited [#115376]
		- 20191101@Charles: Remove column IsMarked [122187]
		- 20210712@July: [TVS] Modify the way to get move bet date [Redmine: #154974]
		- 20211213@Max: [TVS] Integrate new Cash Out model [Redmine: #165097]

	Param's Explanation:
			- @Opition: 
			0: By MatchID
			1: By BetID(s)
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @tblRecoverBet TABLE (
		GroupID			BIGINT
		,transid		BIGINT
		,refno			BIGINT
		,custid			INT
		,recommend		INT
		,username		VARCHAR(50)
		,transdate		DATETIME
		,odds			MONEY
		,oddsspread 		MONEY
		,stake			MONEY
		,winlost		MONEY
		,STATUS			NVARCHAR(10)
		,bettype		SMALLINT
		,matchid		INT
		,OddsType		TINYINT
		,betteam		NVARCHAR(10)
		,betcheck		NVARCHAR(50)
		,hdp1			SMALLMONEY
		,hdp2			SMALLMONEY
		,leagueid		INT
		,isdeposit		BIT
		,IsLiveIndicator BIT
		,livehomescore	SMALLINT
		,liveawayscore	SMALLINT
		,betid			BIGINT
		,transdesc		NVARCHAR(1000)
		,betdaqid		BIGINT -- indicate BTrade ticket (main) or not: 0: BT, -1: normal ticket
		,sporttype		SMALLINT
		,homeid			INT
		,awayid			INT
		,ExtraInfo		VARCHAR(1000)
		,zzzBetcheck	NVARCHAR(50)
		,WalletType		TINYINT
		,RefCode		BIGINT
		,BonusID		INT
		,MainTransId	BIGINT
		,EventDate		DATETIME
		,UNIQUE CLUSTERED(RefCode, custid, matchid, bettype, transid)				
	)	
	
	CREATE TABLE #tmpRefCodeSummary (
		 RefCode	BIGINT
		 ,custid	INT
		 ,matchid	INT
		 ,bettype	SMALLINT
		 ,transid	BIGINT
	)
	
	CREATE INDEX IX_tmpRefCodeSummary_Refcode ON #tmpRefCodeSummary (RefCode)
	
	DECLARE @tblTransIds TABLE (transid BIGINT)
	DECLARE @tmpTransIdMoveBet TABLE (Transid BIGINT)
	DECLARE @MovebetDate DATETIME

	IF @Option = 0 -- By MatchID
	BEGIN
		-- Outright
		INSERT INTO @tblRecoverBet(
				GroupID			
				,transid		
				,refno				
				,recommend		
				,username		
				,transdate		
				,odds
				,oddsspread				
				,stake			
				,winlost		
				,STATUS		
				,bettype		
				,matchid		
				,OddsType		
				,betteam		
				,betcheck		
				,hdp1			
				,hdp2			
				,leagueid		
				,isdeposit		
				,IsLiveIndicator
				,livehomescore	
				,liveawayscore	
				,betid			
				,transdesc		
				,betdaqid		
				,sporttype
				,homeid
				,awayid
				,zzzBetcheck
				,custid
				,WalletType
				,RefCode
				,BonusID
				,EventDate
		)
		SELECT	z.transid
				,z.transid
				,z.refno			
				,b.recommend
				,b.Username
				,z.transdate
				,z.odds
				,b.oddsspread
				,z.stake
				,z.winlost - b.actual_stake
				,z.STATUS				
				,b.bettype
				,b.matchid
				,b.oddstype
				,z.betteam
				,z.betcheck
				,z.hdp1
				,z.hdp2
				,o.leagueid
				,CASE WHEN b.srecommend IN (SELECT custid FROM custDB.dbo.Dep_CustSuper WITH (NOLOCK)) THEN 1 ELSE 0 END AS isdeposit
				,z.liveindicator
				,z.livehomescore
				,z.liveawayscore
				,b.betid
				,b.transdesc
				,b.betdaqid
				,NULL AS sporttype
				,o.teamid homeid
				,0 AS awayid
				,z.betcheck AS zzzBetcheck
				,z.custid
				,b.WalletType
				,b.RefCode
				,b.BonusID
				,o.EventDate
		FROM	zzzbettrans z WITH (NOLOCK)
			INNER JOIN bettrans b WITH (NOLOCK) 
				ON	b.transid = z.transid
					AND b.custid = z.custid
					AND b.matchid = z.matchid	
					AND b.bettype = z.bettype				
			INNER JOIN outright o WITH (NOLOCK) 
				ON	z.matchid = o.orid
		WHERE	z.transid BETWEEN @FromTransId AND @ToTransId
				AND z.matchid = @MatchId
				AND z.bettype = 10
				AND b.betfrom <> 'p'
		
		-- match
		INSERT INTO @tblRecoverBet(
				GroupID			
				,transid		
				,refno			
				,username			
				,recommend
				,transdate			
				,odds
				,oddsspread				
				,stake			
				,winlost		
				,STATUS						
				,bettype		
				,matchid
				,OddsType					
				,betteam		
				,betcheck		
				,hdp1			
				,hdp2		
				,isdeposit					
				,IsLiveIndicator
				,livehomescore	
				,liveawayscore						
				,betid
				,transdesc
				,betdaqid
				,leagueid
				,sporttype
				,homeid
				,awayid
				,ExtraInfo
				,zzzBetcheck
				,custid
				,WalletType
				,RefCode
				,BonusID
				,EventDate
		)
		SELECT	z.transid
				,z.transid
				,z.refno
				,b.Username
				,b.recommend
				,b.transdate
				,z.odds
				,b.oddsspread
				,z.stake
				,z.winlost - b.actual_stake
				,z.STATUS				
				,z.bettype
				,z.matchid
				,b.oddstype				
				,z.betteam
				,z.betcheck
				,z.hdp1
				,z.hdp2		
				,case when EXISTS (select TOP 1 1 from custDB.dbo.Dep_CustSuper with(nolock) WHERE custid = b.srecommend) then 1 else 0 end as isdeposit		
				,z.liveindicator
				,z.livehomescore
				,z.liveawayscore				
				,b.betid
				,b.transdesc
				,b.betdaqid
				,m.leagueid
				,m.sporttype
				,m.homeid
				,m.awayid
				,b.ExtraInfo
				,z.betcheck AS zzzBetcheck
				,z.custid
				,b.WalletType
				,b.RefCode
				,b.BonusID
				,m.EventDate
		FROM	dbo.zzzbettrans z WITH (NOLOCK)
			INNER JOIN dbo.bettrans b WITH (NOLOCK)
				ON	z.transid = b.transid
					AND z.custid = b.custid
					AND z.matchid = b.matchid
					AND z.bettype = b.bettype					
			INNER JOIN dbo.match m WITH(NOLOCK)
				ON	m.matchid = b.matchid
		WHERE	b.transid BETWEEN @FromTransId AND @ToTransId
				AND z.matchid = @MatchId
				AND z.Bettype NOT IN (10, 901, 902, 903, 911, 912, 913, 801, 803, 804, 805, 806)
				AND (m.sporttype BETWEEN 1 AND 99 OR m.sporttype = 154)
				AND b.betfrom <> 'p'				
		
		-- MG
		INSERT INTO @tblRecoverBet(
				GroupID			
				,transid		
				,refno			
				,username			
				,recommend
				,transdate			
				,odds
				,oddsspread				
				,stake			
				,winlost		
				,STATUS						
				,bettype		
				,matchid
				,OddsType					
				,betteam		
				,betcheck		
				,hdp1			
				,hdp2		
				,isdeposit					
				,IsLiveIndicator
				,livehomescore	
				,liveawayscore						
				,betid
				,transdesc
				,betdaqid
				,leagueid
				,sporttype
				,homeid
				,awayid
				,zzzBetcheck
				,custid
				,WalletType
				,RefCode
				,BonusID
				,EventDate
		)
		SELECT	z.transid
				,z.transid
				,z.refno
				,b.Username
				,b.recommend
				,b.transdate
				,z.odds
				,b.oddsspread
				,z.stake
				,z.winlost - b.actual_stake
				,z.STATUS				
				,z.bettype
				,z.matchid
				,b.oddstype				
				,z.betteam
				,z.betcheck
				,z.hdp1
				,z.hdp2		
				,case when EXISTS (select TOP 1 1 from custDB.dbo.Dep_CustSuper with(nolock) WHERE custid = b.srecommend) then 1 else 0 end as isdeposit		
				,z.liveindicator
				,z.livehomescore
				,z.liveawayscore				
				,b.betid
				,b.transdesc
				,b.betdaqid
				,m.leagueid
				,m.sporttype
				,m.homeid
				,m.awayid
				,z.betcheck AS zzzBetcheck
				,z.custid
				,b.WalletType
				,b.RefCode
				,b.BonusID
				,m.EventDate
		FROM	dbo.zzzbettrans z WITH (NOLOCK)
			INNER JOIN dbo.bettrans b WITH (NOLOCK)
				ON	z.transid = b.transid
					AND z.custid = b.custid
					AND z.matchid = b.matchid
					AND z.bettype = b.bettype					
			INNER JOIN dbo.match m WITH(NOLOCK)
				ON	m.matchid = b.matchid
		WHERE	z.refno BETWEEN @FromTransId AND @ToTransId
				AND z.matchid = @MatchId
				AND z.Bettype IN (801, 803, 804, 805, 806)
				AND (m.sporttype BETWEEN 1 AND 99 OR m.sporttype = 154)	
	END
	ELSE IF @Option = 1
	BEGIN
		INSERT INTO @tblTransIds
		SELECT ss.val
		FROM dbo.f_SplitString(@TransIds, ',') ss
		OPTION (maxrecursion 0)

		-- Outright
		INSERT INTO @tblRecoverBet(
				GroupID			
				,transid		
				,refno							
				,recommend		
				,username		
				,transdate		
				,odds
				,oddsspread				
				,stake			
				,winlost		
				,STATUS							
				,bettype		
				,matchid		
				,OddsType		
				,betteam		
				,betcheck		
				,hdp1			
				,hdp2			
				,leagueid		
				,isdeposit		
				,IsLiveIndicator
				,livehomescore	
				,liveawayscore	
				,betid			
				,transdesc		
				,betdaqid		
				,sporttype		
				,homeid
				,awayid
				,zzzBetcheck
				,custid
				,WalletType
				,RefCode
				,BonusID
				,EventDate
		)
		SELECT	z.transid
				,z.transid
				,z.refno			
				,b.recommend
				,b.Username
				,z.transdate
				,z.odds
				,b.oddsspread
				,z.stake
				,z.winlost - b.actual_stake
				,z.STATUS				
				,b.bettype
				,b.matchid
				,b.oddstype
				,z.betteam
				,z.betcheck
				,z.hdp1
				,z.hdp2
				,o.leagueid
				,CASE WHEN b.srecommend IN (SELECT custid FROM custDB.dbo.Dep_CustSuper WITH (NOLOCK)) THEN 1 ELSE 0 END AS isdeposit
				,z.liveindicator
				,z.livehomescore
				,z.liveawayscore
				,b.betid
				,b.transdesc
				,b.betdaqid
				,NULL AS SportType
				,o.teamid homeid
				,0 AS awayid
				,z.betcheck AS zzzBetcheck
				,z.custid
				,b.WalletType
				,b.RefCode
				,b.BonusID
				,o.EventDate
		FROM zzzbettrans z WITH (NOLOCK)
			INNER JOIN bettrans b WITH (NOLOCK) 
					ON b.transid = z.transid
					   AND b.custid = z.custid
					   AND b.matchid = z.matchid
					   AND b.bettype = z.bettype
			INNER JOIN outright o WITH (NOLOCK) 
					ON o.orid = z.matchid
		WHERE z.transid IN (
				SELECT s.transid
				FROM @tblTransIds s
				)
			AND z.bettype = 10
			AND b.betfrom <> 'p'
			
		-- Match
		INSERT INTO @tblRecoverBet(
				GroupID			
				,transid		
				,refno	
				,username						
				,recommend
				,transdate			
				,odds
				,oddsspread				
				,stake			
				,winlost		
				,STATUS						
				,bettype		
				,matchid
				,OddsType					
				,betteam		
				,betcheck		
				,hdp1			
				,hdp2		
				,isdeposit					
				,IsLiveIndicator
				,livehomescore	
				,liveawayscore						
				,betid
				,transdesc
				,betdaqid
				,leagueid
				,sporttype
				,homeid
				,awayid
				,ExtraInfo
				,zzzBetcheck
				,custid
				,WalletType
				,RefCode
				,BonusID
				,EventDate
		)
		SELECT	z.transid
				,z.transid
				,z.refno	
				,b.Username			
				,b.recommend
				,b.transdate
				,z.odds
				,b.oddsspread
				,z.stake
				,z.winlost - b.actual_stake
				,z.STATUS				
				,z.bettype
				,z.matchid
				,b.oddstype				
				,z.betteam
				,z.betcheck
				,z.hdp1
				,z.hdp2
				,case when EXISTS (select TOP 1 1 from custDB.dbo.Dep_CustSuper with(nolock) WHERE custid = b.srecommend) then 1 else 0 end as isdeposit						
				,z.liveindicator
				,z.livehomescore
				,z.liveawayscore				
				,b.betid
				,b.transdesc
				,b.betdaqid
				,m.leagueid
				,m.sporttype
				,m.homeid
				,m.awayid
				,b.ExtraInfo
				,z.betcheck AS zzzBetcheck
				,z.custid
				,b.WalletType
				,b.RefCode
				,b.BonusID
				,m.EventDate
		FROM	dbo.zzzbettrans z WITH (NOLOCK)
			INNER JOIN dbo.bettrans b WITH (NOLOCK)
				ON	z.transid = b.transid
					AND z.custid = b.custid
					AND z.matchid = b.matchid					
					AND z.bettype = b.bettype
			INNER JOIN dbo.match m WITH(NOLOCK)
				ON m.matchid = b.matchid
		WHERE b.transid IN (SELECT s.transid FROM @tblTransIds s)		
			AND z.bettype NOT IN (10, 901, 902, 903, 911, 912, 913, 801, 803, 804, 805, 806)
			AND (m.sporttype BETWEEN 1 AND 99 OR m.sporttype = 154)	
			AND b.betfrom <> 'p'			
			
		-- MG
		INSERT INTO @tblRecoverBet(
				GroupID			
				,transid		
				,refno	
				,username						
				,recommend
				,transdate			
				,odds
				,oddsspread				
				,stake			
				,winlost		
				,STATUS						
				,bettype		
				,matchid
				,OddsType					
				,betteam		
				,betcheck		
				,hdp1			
				,hdp2		
				,isdeposit					
				,IsLiveIndicator
				,livehomescore	
				,liveawayscore						
				,betid
				,transdesc
				,betdaqid
				,leagueid
				,sporttype
				,homeid
				,awayid
				,zzzBetcheck
				,custid
				,WalletType
				,RefCode
				,BonusID
				,EventDate
		)
		SELECT	z.transid
				,z.transid
				,z.refno	
				,b.Username			
				,b.recommend
				,b.transdate
				,z.odds
				,b.oddsspread
				,z.stake
				,z.winlost - b.actual_stake
				,z.STATUS				
				,z.bettype
				,z.matchid
				,b.oddstype				
				,z.betteam
				,z.betcheck
				,z.hdp1
				,z.hdp2
				,case when EXISTS (select TOP 1 1 from custDB.dbo.Dep_CustSuper with(nolock) WHERE custid = b.srecommend) then 1 else 0 end as isdeposit						
				,z.liveindicator
				,z.livehomescore
				,z.liveawayscore				
				,b.betid
				,b.transdesc
				,b.betdaqid
				,m.leagueid
				,m.sporttype
				,m.homeid
				,m.awayid
				,z.betcheck AS zzzBetcheck
				,z.custid
				,b.WalletType
				,b.RefCode
				,b.BonusID
				,m.EventDate
		FROM	dbo.zzzbettrans z WITH (NOLOCK)
			INNER JOIN dbo.bettrans b WITH (NOLOCK)
				ON	z.transid = b.transid
					AND z.custid = b.custid
					AND z.matchid = b.matchid					
					AND z.bettype = b.bettype
			INNER JOIN dbo.match m WITH(NOLOCK)
				ON m.matchid = b.matchid	
		WHERE	z.refno IN (SELECT s.transid FROM @tblTransIds s)		
			AND z.bettype IN (801, 803, 804, 805, 806)	
			AND (m.sporttype BETWEEN 1 AND 99 OR m.sporttype = 154)	
	END				
	    					
	-- update MainTransId
	UPDATE sub
	SET MainTransId = main.transid
	FROM @tblRecoverBet main
		 INNER JOIN @tblRecoverBet sub
				 ON main.RefCode = sub.RefCode
					AND main.transid <> sub.transid	
					AND main.custid = sub.custid
					AND main.matchid = sub.matchid
					AND main.bettype = sub.bettype
	WHERE main.WalletType = 1
	
	/*Modify the way to get move bet date*/
	EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @MovebetDate OUTPUT

	IF @Option = 1 AND EXISTS (SELECT TOP 1 1 FROM @tblRecoverBet WHERE EventDate <= @MovebetDate)
	BEGIN
		DELETE 
		FROM @tblRecoverBet
			OUTPUT	DELETED.TransId
			INTO @tmpTransIdMoveBet (TransId)
		WHERE EventDate <= @MovebetDate
	END
  
	-- Insert more bonus or cash ticket in case only one ticket appears in @tblRecoverBet 	
	INSERT INTO #tmpRefCodeSummary (refcode, custid, matchid, bettype, transid)
	SELECT RefCode, custid, matchid, bettype
		 , MAX(transid) AS transid
	FROM @tblRecoverBet
	WHERE	refcode IS NOT NULL
	GROUP BY RefCode, custid, matchid, bettype
	HAVING COUNT(*) = 1
	
	IF @@ROWCOUNT > 0
	BEGIN
		SELECT	 b.transid
				,b.matchid
				,b.custid
				,b.bettype
				,b.Username			
				,b.recommend
				,b.transdate			
				,b.actual_stake			
				,b.oddstype							
				,case when EXISTS (select TOP 1 1 from custDB.dbo.Dep_CustSuper with(nolock) WHERE custid = b.srecommend) then 1 else 0 end as isdeposit							
				,b.betid
				,b.transdesc
				,b.betdaqid							
				,b.ExtraInfo									
				,b.WalletType
				,b.RefCode
				,b.BonusID
				,t.transid AS MainTransId
					INTO #CTE_bettrans	
		FROM #tmpRefCodeSummary t
			 INNER JOIN dbo.bettrans b WITH (NOLOCK)
					 ON b.RefCode = t.RefCode
						AND b.transid <> t.transid
						AND b.matchid = t.matchid
						AND b.custid = t.custid
						AND b.bettype = t.bettype		 
		
		INSERT INTO @tblRecoverBet(
					 GroupID			
					,transid		
					,refno	
					,username						
					,recommend
					,transdate			
					,odds
					,oddsspread					
					,stake			
					,winlost		
					,STATUS						
					,bettype		
					,matchid
					,OddsType					
					,betteam		
					,betcheck		
					,hdp1			
					,hdp2		
					,isdeposit					
					,IsLiveIndicator
					,livehomescore	
					,liveawayscore						
					,betid
					,transdesc
					,betdaqid
					,leagueid
					,sporttype
					,homeid
					,awayid				
					,ExtraInfo
					,zzzBetcheck
					,custid				
					,WalletType
					,RefCode
					,BonusID
					,MainTransId
			)
			SELECT	 z.transid
					,z.transid
					,z.refno	
					,b.Username			
					,b.recommend
					,b.transdate
					,z.odds
					,0 AS oddsspread
					,z.stake
					,z.winlost - b.actual_stake
					,z.STATUS				
					,z.bettype
					,z.matchid
					,b.oddstype				
					,z.betteam
					,z.betcheck
					,z.hdp1
					,z.hdp2
					,b.isdeposit						
					,z.liveindicator
					,z.livehomescore
					,z.liveawayscore				
					,b.betid
					,b.transdesc
					,b.betdaqid
					,m.leagueid
					,m.sporttype
					,m.homeid
					,m.awayid				
					,b.ExtraInfo
					,z.betcheck AS zzzBetcheck
					,z.custid				
					,b.WalletType
					,b.RefCode
					,b.BonusID
					,b.MainTransId
		FROM #CTE_bettrans b
			 INNER JOIN dbo.zzzbettrans z WITH (NOLOCK)
					 ON	z.transid = b.transid
						AND z.custid = b.custid
						AND z.matchid = b.matchid					
						AND z.bettype = b.bettype		 					
			 INNER JOIN dbo.match m WITH(NOLOCK)
					 ON m.matchid = b.matchid		  			    				    						    
	END														
	
	SELECT	ag.site
			,t.transid
			,t.refno
			,t.username
			,t.transdate
			,t.odds
			,t.oddsspread
			,t.stake
			,t.winlost
			,t.STATUS
			,t.bettype
			,t.matchid
			,t.OddsType
			,t.betteam
			,t.betcheck
			,t.hdp1
			,t.hdp2
			,t.leagueid
			,t.IsLiveIndicator
			,t.livehomescore
			,t.liveawayscore
			,t.betid
			,t.transdesc
			,t.sporttype
			,t.homeid
			,t.awayid
			,CASE WHEN t.isdeposit = 0 AND bettype = 501 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsCricket
			,t.betdaqid
			,t.ExtraInfo
			,t.WalletType
			,t.MainTransId
			,t.RefCode
			,m.SettlementStatus
			,m.GlobalShowTime
	FROM	@tblRecoverBet t
		INNER JOIN custDB.dbo.Customer ag WITH (NOLOCK) ON	t.recommend = ag.custid
		LEFT JOIN dbo.match m WITH(NOLOCK) ON m.matchid = t.matchid
	WHERE t.bettype <> 500
	ORDER BY [site]
		, CASE 
			WHEN t.bettype IN (801, 803, 804, 805, 806) THEN t.refno 
			ELSE ISNULL(t.MainTransId, t.transid)
		  END
		, CASE 
			WHEN t.bettype IN (801, 803, 804, 805, 806) THEN t.refno 
			ELSE CASE 
					WHEN t.BonusID IS NOT NULL
							THEN CASE 
									WHEN t.MainTransId IS NULL THEN 1
									ELSE 2 
								 END
					ELSE t.transid
				 END 
		  END


	--- invalid trans info
	;WITH validTransId
	AS
	(
		SELECT  CASE WHEN bettype IN (801, 803, 804, 805, 806) THEN refno ELSE transid END transid
		FROM	@tblRecoverBet 
	)
	SELECT t.transid AS InvalidTrans
		,CASE 
			WHEN t.transid IN (
					SELECT b14.transid
					FROM dbo.bettrans14 b14 WITH (NOLOCK)
					WHERE b14.transid = t.transid
					UNION ALL
					SELECT m.TransId
					FROM @tmpTransIdMoveBet m  
					WHERE m.TransId = t.transid
					) THEN CAST(1 AS BIT)
			ELSE CAST(0 AS BIT)
			END AS isMoved
	FROM @tblTransIds t
	WHERE t.transid NOT IN (SELECT * FROM validTransId)
END