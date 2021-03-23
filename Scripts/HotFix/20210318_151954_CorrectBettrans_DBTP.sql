/*<info serverAlias="DBTP-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created:20210318@Louisa
    Task: Correct data on table bettrans [Redmine:#151954]
    DB: DBTP/bodb02
	
	Revisions:
		- 20210318@Louisa: Correct data on table bettrans [Redmine:#151954]
*/



USE [bodb02]
GO


SELECT
	b.transid
	, b.modds				
	, b.statuswinlost		
	, b.SettlementTime	
	, b.WinLost			
	, b.aWinLost			
	, b.mWinLost			
	, b.sWinLost			
	, b.PlayerComm		
	, b.Comm				
	, b.aComm				
	, b.sComm				
	, b.[Status]			
	, b.StatusID			
	, b.ruben
INTO #transid_tmp						 
FROM DBTXN.bodb02.dbo.bettrans b WITH (NOLOCK)
WHERE transid IN (	111387546134
					,111387548455
					,111387549490
					,111387544662
					,111387545465
					,111387546136
					,111387548353
				 )

------------------------------------------
---	SELECT * FROM #transid_tmp

----------------------------------------
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
FROM dbo.bettrans b WITH (ROWLOCK, UPDLOCK)
	INNER JOIN #transid_tmp t ON b.transid = t.transid


DROP TABLE #transid_tmp
					