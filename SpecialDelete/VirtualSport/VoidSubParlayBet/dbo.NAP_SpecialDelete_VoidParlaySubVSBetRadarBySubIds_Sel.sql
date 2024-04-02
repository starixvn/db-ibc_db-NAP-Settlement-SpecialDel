/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_VoidParlaySubVSBetRadarBySubIds_Sel]
	@SubTransIds	 VARCHAR(MAX)
AS
/*  
	Created by: 20170831@Kent
	DB: DBTXN/bodb02   
	Original:     

	Revisions:  				
		- 20170831@Kent: VS BetRadar Change on Void Parlay Sub Bets [Redmine:#82405]		
		- 20180305@Helen: Betradar VS2 - [Redmine:90153]
		- 20210712@July: TVS - Modify the way to get move bet date [Redmine: #154974]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220910@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20240220@July: Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]
		- 20240327@July: [TVS] Show Half Won - Half Lost on the bet list [Redmine: #202267]

	Param's Explanation:		
		- @SubTransIds : TransIds of sub parlay tickets
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @SubTickets_Count	INT = 0
		   ,@Movebetdate		DATETIME
		   ,@InvalidTransIds	VARCHAR(MAX) = '' 
		   ,@SiteDBGroupID		SMALLINT = 0
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	CREATE TABLE #tblSubTransIds (SubTransId BIGINT PRIMARY KEY)
	
	CREATE TABLE #tmpBettransm
	(
		Status NVARCHAR(10),
		TransId BIGINT,
		BetCheck NVARCHAR(50),
		BetTeam NVARCHAR(10),
		BetType SMALLINT,
		Hdp1 SMALLMONEY,
		Hdp2 SMALLMONEY,
		Odds SMALLMONEY,
		transdesc NVARCHAR(1000),
		refno BIGINT,
		custid INT,
		matchid INT
	)
	
	CREATE TABLE #tmpResult
	(
		Stake MONEY,
		BetCheck NVARCHAR(50),
		BetId BIGINT,
		BetTeam NVARCHAR(10),
		BetType SMALLINT,
		CurrencyCode NVARCHAR(50),
		Hdp1 SMALLMONEY,
		Hdp2 SMALLMONEY,
		IsLiveIndicator BIT,
		LiveAwayScore SMALLINT,
		LiveHomeScore SMALLINT,
		Odds SMALLMONEY,
		RefNo BIGINT,
		Status NVARCHAR(10),
		TransDate DATETIME,
		TransDesc NVARCHAR(1000),
		TransId BIGINT,
		UserName NVARCHAR(50),
		WinLost MONEY,
		modds SMALLMONEY,
		custid INT,
		recommend INT,
		mrecommend INT,
		srecommend INT,
		SubStatus NVARCHAR(10),
		SubTransId BIGINT,
		SubBetCheck NVARCHAR(50),
		SubBetTeam NVARCHAR(10),
		SubBetType SMALLINT,
		SubHdp1 SMALLMONEY,
		SubHdp2 SMALLMONEY,
		SubOdds SMALLMONEY,
		SubTransdesc NVARCHAR(1000),
		matchid INT,
		Winlostdate SMALLDATETIME
	) 

	EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @MovebetDate OUTPUT

	--> parse @SubTransIds
	INSERT INTO #tblSubTransIds(SubTransId)
	SELECT  DISTINCT value
	FROM	STRING_SPLIT(@SubTransIds, ',')		
	
	-- get sub tickets
	INSERT INTO #tmpBettransm(
			Status
           ,TransId
           ,BetCheck
           ,BetTeam
           ,BetType
           ,Hdp1
           ,Hdp2
           ,Odds
           ,transdesc
           ,refno
           ,custid
           ,matchid)
	SELECT bm.Status
		  ,bm.TransId
		  ,bm.BetCheck
		  ,bm.BetTeam
		  ,bm.BetType
		  ,bm.Hdp1
		  ,bm.Hdp2
		  ,bm.Odds	
		  ,bm.transdesc
		  ,bm.refno
		  ,bm.custid
		  ,bm.matchid			
	FROM #tblSubTransIds t
		 INNER JOIN dbo.bettransm bm WITH (NOLOCK) ON t.SubTransId = bm.transid
	WHERE bm.statusID NOT IN (101, 102) -- reject, void	
		AND bm.SiteDBGroupID = @SiteDBGroupID

	SET @SubTickets_Count = @@ROWCOUNT				
	
	-- get main info for all searched sub tickets
	INSERT INTO #tmpResult(
			Stake
           ,BetCheck
           ,BetId
           ,BetTeam
           ,BetType
           ,CurrencyCode
           ,Hdp1
           ,Hdp2
           ,IsLiveIndicator
           ,LiveAwayScore
           ,LiveHomeScore
           ,Odds
           ,RefNo
           ,Status
           ,TransDate
           ,TransDesc
           ,TransId
           ,UserName
           ,WinLost
           ,modds
           ,custid
           ,recommend
           ,mrecommend
           ,srecommend
           ,SubStatus
           ,SubTransId
           ,SubBetCheck
           ,SubBetTeam
           ,SubBetType
           ,SubHdp1
           ,SubHdp2
           ,SubOdds
           ,SubTransdesc
           ,matchid
		   ,Winlostdate
		  )
	SELECT b.Stake		  
		  ,b.BetCheck
		  ,b.BetId
		  ,b.BetTeam
		  ,b.BetType
		  ,b.CurrencyName AS CurrencyCode
		  ,b.Hdp1
		  ,b.Hdp2		  
		  ,b.LiveIndicator AS IsLiveIndicator
		  ,b.LiveAwayScore
		  ,b.LiveHomeScore
		  ,b.Odds		   
		  ,b.RefNo		  
		  ,b.Status
		  ,b.TransDate
		  ,b.TransDesc
		  ,b.TransId
		  ,b.UserName
		  ,(b.winlost - b.actual_stake) AS WinLost		  
		  ,b.modds
		  ,b.custid		  
		  ,b.recommend
		  ,b.mrecommend
		  ,b.srecommend		  
		  ,bm.Status AS SubStatus
		  ,bm.TransId AS SubTransId
		  ,bm.BetCheck AS SubBetCheck
		  ,bm.BetTeam AS SubBetTeam
		  ,bm.BetType AS SubBetType
		  ,bm.Hdp1 AS SubHdp1
		  ,bm.Hdp2 AS SubHdp2
		  ,bm.Odds AS SubOdds	
		  ,bm.transdesc AS SubTransdesc
		  ,bm.matchid
		  ,b.winlostdate			
	FROM (SELECT TOP (@SubTickets_Count) * 
		  FROM #tmpBettransm) bm
		 INNER JOIN bettrans b WITH (NOLOCK) 
				 ON b.refno = bm.refno 
					AND b.custid = bm.custid
	WHERE b.matchid IN (2799, 10449)
	  AND b.bettype IN (2799, 10449)
	  AND b.statusID NOT IN (101, 102) -- reject, void	
	  AND b.SiteDBGroupID = @SiteDBGroupID
	OPTION(OPTIMIZE FOR (@SubTickets_Count = 1))			    	  								 	
	
	IF EXISTS (SELECT TOP 1 1 FROM #tmpResult WHERE Winlostdate <= @MovebetDate)
	BEGIN
		DELETE FROM #tmpResult WHERE Winlostdate <= @MovebetDate
	END

	------------------------------------------------------------------------------
	--1. Table invald transid
	SELECT @InvalidTransIds = @InvalidTransIds + CASE WHEN @InvalidTransIds <> '' THEN ',' ELSE '' END + CAST(SubTransId AS VARCHAR(50))
	FROM #tblSubTransIds
	WHERE SubTransId NOT IN (SELECT SubTransId FROM #tmpResult)			

	SELECT @InvalidTransIds AS InvalidTransIds

	--2. Table get tickets
	SELECT  t.Stake
		   ,m.AwayId
		   ,t.BetCheck
		   ,t.BetId
		   ,t.BetTeam
		   ,t.BetType
		   ,t.CurrencyCode
		   ,t.Hdp1
		   ,t.Hdp2
		   ,m.HomeId
		   ,t.IsLiveIndicator
		   ,t.LiveAwayScore
		   ,t.LiveHomeScore
		   ,t.Odds		   
		   ,t.RefNo
		   ,m.SportType
		   ,t.Status
		   ,t.TransDate
		   ,t.TransDesc
		   ,t.TransId
		   ,t.UserName
		   ,t.WinLost
		   ,T2.GroupName
		   ,ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral
		   ,ISNULL(CONVERT(NVARCHAR(20), m.kickofftime, 113), '') AS showtime
		   ,m.leagueid
		   ,t.modds AS MasterOdds
		   ,t.SubStatus
		   ,t.SubTransId
		   ,t.SubBetCheck
		   ,t.SubBetTeam
		   ,t.SubBetType
		   ,t.SubHdp1
		   ,t.SubHdp2
		   ,t.SubOdds	
		   ,t.SubTransdesc	
		   ,m.matchcode   
		   ,@SiteDBGroupID AS SiteDBGroupID
	FROM #tmpResult t					
		 INNER JOIN match m WITH (NOLOCK)
				 ON t.matchid = m.matchid		
		 OUTER APPLY (SELECT CAST(CASE 
									WHEN t.srecommend IN (SELECT custid from custDB.dbo.Dep_CustSuper with(NOLOCK)) 
											THEN 1
									ELSE 0
								  END AS BIT) as IsDeposit) AS T1
		 OUTER APPLY (SELECT CASE 
								WHEN T1.IsDeposit = 0  
									 AND t.custid NOT IN (SELECT CustID FROM [f_GetBetDaqCustomer] (1))    
									 AND t.username <> '12EU'  
									 AND t.mrecommend NOT IN (105181, 118473, 105183)  
									 AND t.recommend NOT IN (11196380, 13423967) -- Foobet, 1E
											THEN 'Credit'
								WHEN T1.IsDeposit = 1  
									 AND t.custid NOT IN (SELECT CustID FROM [f_GetBetDaqCustomer] (1))    
									 AND t.username <> '12EU'  
									 AND t.mrecommend NOT IN (105181, 118473, 105183) 
									 AND t.recommend NOT IN (11196380, 13423967) -- Foobet, 1E
											THEN 'Deposit'																			
								ELSE ''							
							 END AS GroupName) AS T2		  
	ORDER BY CASE
				WHEN T2.GroupName = 'Credit'  THEN 0
				WHEN T2.GroupName = 'Deposit' THEN 1				
				ELSE 2				
			 END ASC 
	
	DROP TABLE #tblSubTransIds
	DROP TABLE #tmpBettransm
	DROP TABLE #tmpResult
	SET NOCOUNT OFF		
END
GO