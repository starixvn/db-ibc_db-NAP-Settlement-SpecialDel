/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet,wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_VoidParlaySubVSBetRadarByMatchId_Sel]
	@MatchId		 INT,
	@BetTypes		 VARCHAR(MAX)		
AS
/*  
	Created by: Kent
	Date: 20170831
	Task: 
	DB: DBTXN/bodb02	    

	Revisions:  				
		- 20170831@Kent: VS BetRadar Change on Void Parlay Sub Bets [Redmine:#82405]		
		- 20180305@Helen: Betradar VS2 - [Redmine:90153]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220910@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20240220@July: Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]

	Param's Explanation:		
		
*/
BEGIN
	SET NOCOUNT ON	
	DECLARE @SiteDBGroupID	SMALLINT = 0
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	CREATE TABLE #tblBettype (bettype SMALLINT PRIMARY KEY) 
	INSERT INTO #tblBettype(bettype)
	SELECT  value
	FROM	STRING_SPLIT(@BetTypes, ',')
	
	------------------------------------------------------------------------------
	--1. Table invald transid
	SELECT '' AS InvalidTransIds

	--2. Table get tickets
	SELECT  b.Stake
		   ,m.AwayId
		   ,b.BetCheck
		   ,b.BetId
		   ,b.BetTeam
		   ,b.BetType
		   ,b.CurrencyName AS CurrencyCode
		   ,b.Hdp1
		   ,b.Hdp2
		   ,m.HomeId
		   ,b.LiveIndicator AS IsLiveIndicator
		   ,b.LiveAwayScore
		   ,b.LiveHomeScore
		   ,b.Odds		   
		   ,b.RefNo
		   ,m.SportType
		   ,b.Status
		   ,b.TransDate
		   ,b.TransDesc
		   ,b.TransId
		   ,b.UserName
		   ,(b.winlost - b.actual_stake) AS WinLost
		   ,T2.GroupName
		   ,ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral
		   ,ISNULL(CONVERT(NVARCHAR(20), m.kickofftime, 113), '') AS showtime
		   ,m.leagueid
		   ,b.modds
		   ,bm.Status AS SubStatus
		   ,bm.TransId AS SubTransId
		   ,bm.BetCheck AS SubBetCheck
		   ,bm.BetTeam AS SubBetTeam
		   ,bm.BetType AS SubBetType
		   ,bm.Hdp1 AS SubHdp1
		   ,bm.Hdp2 AS SubHdp2
		   ,bm.Odds AS SubOdds	
		   ,bm.transdesc AS SubTransdesc
		   ,m.matchcode	   
		   ,@SiteDBGroupID AS SiteDBGroupID
	FROM bettrans b WITH (NOLOCK) 
		 INNER JOIN dbo.bettransm bm WITH (NOLOCK)
				 ON b.refno = bm.refno 
		 INNER JOIN match m WITH (NOLOCK)
				 ON bm.matchid = m.matchid
		 INNER JOIN #tblBettype bt
				 ON bm.bettype = bt.bettype
		 OUTER APPLY (SELECT CAST(CASE 
									WHEN b.srecommend IN (SELECT custid from custDB.dbo.Dep_CustSuper with(NOLOCK)) 
											THEN 1
									ELSE 0
								  END AS BIT) as IsDeposit) AS T1
		 OUTER APPLY (SELECT CASE 
								WHEN T1.IsDeposit = 0  
									 AND b.custid NOT IN (SELECT CustID FROM [f_GetBetDaqCustomer] (1))    
									 AND b.username <> '12EU'  
									 AND b.mrecommend NOT IN (105181, 118473, 105183)  
									 AND b.recommend NOT IN (11196380, 13423967) -- Foobet, 1E
											THEN 'Credit'
								WHEN T1.IsDeposit = 1  
									 AND b.custid NOT IN (SELECT CustID FROM [f_GetBetDaqCustomer] (1))    
									 AND b.username <> '12EU'  
									 AND b.mrecommend NOT IN (105181, 118473, 105183) 
									 AND b.recommend NOT IN (11196380, 13423967) -- Foobet, 1E
											THEN 'Deposit'																			
								ELSE ''							
							 END AS GroupName) AS T2
	WHERE b.matchid IN (2799, 10449)
	  AND b.bettype IN (2799, 10449)
	  AND bm.matchid = @MatchId
	  AND b.statusID NOT IN (101, 102) -- reject, void	
	  AND bm.statusID NOT IN (101, 102) -- reject, void	
	  AND b.SiteDBGroupID = @SiteDBGroupID AND bm.SiteDBGroupID = b.SiteDBGroupID
	ORDER BY CASE
				WHEN T2.GroupName = 'Credit'  THEN 0
				WHEN T2.GroupName = 'Deposit' THEN 1				
				ELSE 2				
			 END ASC		  
	
	SET NOCOUNT OFF		
END
GO