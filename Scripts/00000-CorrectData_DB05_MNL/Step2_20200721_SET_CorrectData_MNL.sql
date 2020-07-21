/*<info serverAlias="MNL_DBTRANS-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created:20200721@Louisa
    Task: Correct data on DBMNL
    DB: MNL_DBTRANS/bodb02
	
	Revisions:
		- 20200721@Louisa: Correct data on MNL
*/

USE [bodb02]
GO

CREATE TABLE #transid_tmp
(	
	transid			 BIGINT 
	, modds			 SMALLMONEY 
	, statuswinlost	 TINYINT 
	, SettlementTime DATETIME 
	, WinLost		 MONEY 
	, aWinLost		 MONEY 
	, mWinLost		 MONEY 
	, sWinLost		 MONEY 
	, PlayerComm	 MONEY 	 
	, Comm			 MONEY 
	, aComm			 MONEY 
	, sComm			 MONEY  
	, [Status]		 NVARCHAR(10)
	, StatusID		 TINYINT 
	, ruben			 TINYINT
)

INSERT INTO #transid_tmp 
( 	
	transid
	, modds  
	, statuswinlost  
	, SettlementTime  
	, WinLost  
	, aWinLost 
	, mWinLost  
	, sWinLost  
	, PlayerComm  
	, Comm  
	, aComm  
	, sComm  
	, [Status]  
	, StatusID  
	, ruben 
)
SELECT
	transid
	, modds				
	, statuswinlost		
	, SettlementTime	
	, WinLost			
	, aWinLost			
	, mWinLost			
	, sWinLost			
	, PlayerComm		
	, Comm				
	, aComm				
	, sComm				
	, [Status]			
	, StatusID			
	, ruben						 
FROM DB061.bodb02.dbo.bettrans14 WITH (NOLOCK)
WHERE transid IN (109435035024,109434991001,109435001050,109435035172,109434990952)
		
UPDATE	b 
SET
	modds				= t.modds
	, statuswinlost		= t.statuswinlost
	, SettlementTime	= t.SettlementTime
	, WinLost			= t.WinLost
	, aWinLost			= t.aWinLost
	, mWinLost			= t.mWinLost
	, sWinLost			= t.sWinLost
	, PlayerComm		= t.PlayerComm
	, Comm				= t.Comm
	, aComm				= t.aComm
	, sComm				= t.sComm
	, [Status]			= t.[Status]
	, StatusID			= t.StatusID
	, ruben				= t.ruben
FROM dbo.bettrans14 b WITH (ROWLOCK, UPDLOCK)
	INNER JOIN #transid_tmp t ON b.transid = t.transid

DROP TABLE #transid_tmp
					

