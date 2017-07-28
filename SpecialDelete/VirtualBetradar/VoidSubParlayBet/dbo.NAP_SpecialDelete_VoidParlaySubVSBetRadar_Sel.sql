/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_VoidParlaySubVSBetRadar_Sel] 
	@MatchId	INT,
	@BetTypes	VARCHAR(MAX)
AS
/*  
	Created by: Kent
	Date: 20170607
	Task: 
	DB: DBTXN/bodb02   
	Original:NAP_SpecialDelete_VoidParlaySubVSBetRadar_Sel     

	Revisions:  		
		- 20170607@Kent: Integrate Betradar Virtual Sports [Redmine:#77177]			

	*/
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #tblBettype (bettype SMALLINT PRIMARY KEY) 
	
	INSERT INTO #tblBettype(bettype)
	SELECT  val
	FROM	dbo.f_SplitString(@BetTypes, ',')
	OPTION (maxrecursion 0)
		
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
	WHERE b.matchid = 2799
	  AND b.bettype = 2799
	  AND bm.matchid = @MatchId
	  AND b.statusID NOT IN (101, 102) -- reject, void	
	  AND bm.statusID NOT IN (101, 102) -- reject, void	
	ORDER BY CASE
				WHEN T2.GroupName = 'Credit'  THEN 0
				WHEN T2.GroupName = 'Deposit' THEN 1				
				ELSE 2				
			 END ASC	  
	
	SET NOCOUNT OFF		
END
GO