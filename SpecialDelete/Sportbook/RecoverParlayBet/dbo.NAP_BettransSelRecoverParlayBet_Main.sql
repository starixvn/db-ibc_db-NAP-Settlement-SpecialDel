/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BettransSelRecoverParlayBet_Main] 
	@BetType		VARCHAR(20) = 'all'
	,@TransIds		VARCHAR(MAX)	= ''
AS
/*
	Created: Kent
	Date: 20161111
	DB: DBTXN/bodb02

	Revisions: 		
		- 20161011@Kent: Select main voided Parlay tickets [Redmine:#65531]
		- 20170525@Kent: Remove dummy tables and fix bit datatype columns [Redmine:#77040]
		- 20180327@Helen:  Correct Transdesc column size [Redmine: #92810]
		- 20190719@Raymond.Le: Extend days recover ticket unlimited [#115376]
		- 20201126@Charles: God of fortune [Redmine: #146053]
		- 20210712@July: [TVS] Modify the way to get move bet date [Redmine: #154974]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220906@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20240327@July: [TVS] Show Half Won - Half Lost on the bet list [Redmine: #202267]

	Param's Explanation:			
			- @BetType:
			'all': All
			'Mix Parlay': Mix Parlay
			'System Parlay': System Parlay
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @tblRecoverBet TABLE (		
		custid					INT
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
		,livehomescore			SMALLINT 
		,liveawayscore			SMALLINT 
		,Stake					MONEY
		,Odds					SMALLMONEY		
		,modds					SMALLMONEY
		,hdp1					SMALLMONEY
		,hdp2					SMALLMONEY						
		,betcheck				NVARCHAR(50)
		,transdesc				NVARCHAR(1000)
		,ExtraInfo				VARCHAR(1000)
		,ActualStake			MONEY
		,Winlostdate			DATETIME
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
			custid
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
			,livehomescore 
			,liveawayscore 
			,Stake	
			,Odds			
			,modds
			,hdp1
			,hdp2			
			,betcheck
			,transdesc
			,ExtraInfo
			,ActualStake
			,Winlostdate
			)
	SELECT  z.custid AS custid
			,case when EXISTS (select TOP 1 1 from custDB.dbo.Dep_CustSuper with(nolock) WHERE custid = b.srecommend) then 1 else 0 end AS isdeposit
			,b.mrecommend AS mrecommend
			,b.recommend AS recommend
			,z.transid AS transid
			,b.Username AS UserName
			,b.transdate AS TransDate	
			,z.bettype AS BetType	
			,z.refno AS Refno	
			,z.[status] AS [Status]
			,z.winlost-b.actual_stake AS WinLost
			,b.betid AS betid	
			,z.betteam AS BetTeam
			,z.livehomescore AS livehomescore
			,z.liveawayscore AS liveawayscore 
			,z.stake AS Stake	
			,z.odds AS Odds			
			,b.modds
			,z.hdp1 AS hdp1
			,z.hdp2 AS hdp2		
			,z.betcheck AS betcheck
			,b.transdesc AS transdesc
			,b.ExtraInfo
			,b.actual_stake AS ActualStake
			,b.winlostdate
	FROM @tblTransIds t
		 INNER JOIN dbo.bettrans b WITH (NOLOCK)
				ON t.transid = b.transid AND b.SiteDBGroupID = @SiteDBGroupID	
		 INNER JOIN dbo.zzzbettrans z WITH (NOLOCK)
				ON	z.transid = b.transid
				AND z.matchid = b.matchid
				AND z.custid = b.custid	
				AND z.bettype = b.bettype  AND z.SiteDBGroupID = b.SiteDBGroupID	
	WHERE b.bettype = 29	
		AND b.statusid = 102
		AND (b.betfrom IS NULL OR b.betfrom <> 'p')
		AND CASE
				WHEN @BetType = 'all' THEN 1
				WHEN @BetType = 'Mix Parlay' THEN CASE WHEN b.betteam = 1 THEN 1 ELSE 0 END
				WHEN @BetType = 'System Parlay' THEN CASE WHEN b.betteam = 1 THEN 0 ELSE 1 END
				ELSE 0
			END	= 1			
	/*Modify the way to get move bet date*/
	EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @MovebetDate OUTPUT

	IF EXISTS (SELECT TOP 1 1 FROM @tblRecoverBet WHERE Winlostdate <= @MovebetDate)
	BEGIN
		DELETE 
		FROM @tblRecoverBet
			OUTPUT	DELETED.TransId
			INTO @tmpTransIdMoveBet (TransId)
		WHERE Winlostdate <= @MovebetDate
	END	

	SELECT	SUBSTRING(T1.GroupName, 3, 30) AS GroupName			 
			 ,t.transid    
			 ,t.UserName    
			 ,t.TransDate     
			 ,t.BetType    
			 ,t.Refno     
			 ,t.[Status]     
			 ,t.WinLost    
			 ,t.betid     
			 ,t.BetTeam    
			 ,t.livehomescore   
			 ,t.liveawayscore   
			 ,t.Stake     
			 ,t.Odds			    
			 ,t.hdp1     
			 ,t.hdp2			    
			 ,t.betcheck    
			 ,t.transdesc
			 ,t.ExtraInfo
			 ,t.ActualStake   
			 ,@SiteDBGroupID AS SiteDBGroupID
			 ,t.modds AS MasterOdds
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
	SELECT t.transid AS InvalidTrans
		,CASE 
			WHEN t.transid IN (
					SELECT b14.transid
					FROM dbo.bettrans14 b14 WITH (NOLOCK)
					WHERE b14.transid = t.transid AND b14.SiteDBGroupID = @SiteDBGroupID
					) THEN CAST(1 AS BIT)
			WHEN t.transid IN (
					SELECT m.transid
					FROM @tmpTransIdMoveBet m
					WHERE m.transid = t.transid
					) THEN CAST(1 AS BIT)
			ELSE CAST(0 AS BIT)
			END AS isMoved
	FROM @tblTransIds t
	WHERE NOT EXISTS (SELECT TOP 1 1 FROM @tblRecoverBet r WHERE r.transid = t.transid)
END
