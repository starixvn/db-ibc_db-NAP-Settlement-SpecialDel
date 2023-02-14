/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/   
/*	
	Created: 20230214@Max
    Task: Reset Turnover - [Redmine: #183838]

	DB: DBCTG/bodb02 
*/
USE [bodb02]
GO

--MBC
UPDATE l SET l.AccumTurnover = total_bettrans.sum_stake						
FROM CustLimitBet_MBC l WITH (ROWLOCK, UPDLOCK)												
	CROSS APPLY (						
			SELECT ISNULL(SUM(stake),0) AS sum_stake 
			FROM bettrans WITH (NOLOCK)				
			WHERE matchid IN (9,29) 
				AND custid = l.custid 
				AND bettype IN (9,29) 
				AND ruben = 0				
				AND oddsid = 1 --soccer				
		) AS total_bettrans			
WHERE EventTypeID = 3 
	AND matchid = 29 
	AND l.AccumTurnover <> total_bettrans.sum_stake	

UPDATE l SET l.AccumTurnover = total_bettrans.sum_stake									
FROM CustLimitBet_MBC l WITH (ROWLOCK, UPDLOCK)													
	CROSS APPLY (							
			SELECT  ISNULL(SUM(stake),0) AS sum_stake 
			FROM bettrans WITH (NOLOCK)					
			WHERE matchid in (9,29) 
				AND custid = l.custid 
				AND bettype IN (9,29) 
				AND ruben = 0					
				AND oddsid = 99 --mix sports					
			) AS total_bettrans				
WHERE EventTypeID = 4 
	AND matchid = 29 
	AND l.AccumTurnover <> total_bettrans.sum_stake						
									
--789y
UPDATE l SET l.AccumTurnover = total_bettrans.sum_stake						
FROM CustLimitBet_789 l WITH (ROWLOCK, UPDLOCK)												
	CROSS APPLY (						
			SELECT ISNULL(SUM(stake),0) AS sum_stake 
			FROM bettrans WITH (NOLOCK)				
			WHERE matchid IN (9,29) 
				AND custid = l.custid 
				AND bettype IN (9,29) 
				AND ruben = 0				
				AND oddsid = 1 --soccer				
		) AS total_bettrans			
WHERE EventTypeID = 3 
	AND matchid = 29 
	AND l.AccumTurnover <> total_bettrans.sum_stake	

UPDATE l SET l.AccumTurnover = total_bettrans.sum_stake									
FROM CustLimitBet_789 l WITH (ROWLOCK, UPDLOCK)													
	CROSS APPLY (							
			SELECT  ISNULL(SUM(stake),0) AS sum_stake 
			FROM bettrans WITH (NOLOCK)					
			WHERE matchid in (9,29) 
				AND custid = l.custid 
				AND bettype IN (9,29) 
				AND ruben = 0					
				AND oddsid = 99 --mix sports					
			) AS total_bettrans				
WHERE EventTypeID = 4 
	AND matchid = 29 
	AND l.AccumTurnover <> total_bettrans.sum_stake
							
--LIC
UPDATE l SET l.AccumTurnover = total_bettrans.sum_stake						
FROM CustLimitBet_LIC l WITH (ROWLOCK, UPDLOCK)												
	CROSS APPLY (						
			SELECT ISNULL(SUM(stake),0) AS sum_stake 
			FROM bettrans WITH (NOLOCK)				
			WHERE matchid IN (9,29) 
				AND custid = l.custid 
				AND bettype IN (9,29) 
				AND ruben = 0				
				AND oddsid = 1 --soccer				
		) AS total_bettrans			
WHERE EventTypeID = 3 
	AND matchid = 29 
	AND l.AccumTurnover <> total_bettrans.sum_stake	

UPDATE l SET l.AccumTurnover = total_bettrans.sum_stake									
FROM CustLimitBet_LIC l WITH (ROWLOCK, UPDLOCK)													
	CROSS APPLY (							
			SELECT  ISNULL(SUM(stake),0) AS sum_stake 
			FROM bettrans WITH (NOLOCK)					
			WHERE matchid in (9,29) 
				AND custid = l.custid 
				AND bettype IN (9,29) 
				AND ruben = 0					
				AND oddsid = 99 --mix sports					
			) AS total_bettrans				
WHERE EventTypeID = 4 
	AND matchid = 29 
	AND l.AccumTurnover <> total_bettrans.sum_stake							
