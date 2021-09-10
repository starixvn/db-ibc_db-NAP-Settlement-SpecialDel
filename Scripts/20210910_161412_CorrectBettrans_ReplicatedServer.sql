
/* 
	Created:20210910@Louisa
    Task: Correct ticket on replicated servers [RedmineId:#161412]
	
	Revisions:
		- 20210910@Louisa: Correct ticket on replicated servers
*/


---- NOTE: PLEASE DO NOT RUN THIS SCRIPT ON DB054, DB055

USE [bodb02]
GO


	CREATE TABLE #transid_tmp
	(	
		transid			 BIGINT  
		, [Status]		 NVARCHAR(10)
		, SettlementTime DATETIME
		, StatusID		 TINYINT
		, WinLost		 MONEY 
		, aWinLost		 MONEY 
		, mWinLost		 MONEY 
		, sWinLost		 MONEY 
		, PlayerComm	 MONEY 	 
		, Comm			 MONEY 
		, aComm			 MONEY 
		, sComm			 MONEY 
		, ruben			 TINYINT 
		, statuswinlost	 TINYINT
		, odds			 SMALLMONEY   
	)

	INSERT INTO #transid_tmp 
	(
		transid			 
		, [Status]		 
		, SettlementTime 
		, StatusID		 
		, WinLost		 
		, aWinLost		 
		, mWinLost		 
		, sWinLost		 
		, PlayerComm	 
		, Comm			 
		, aComm			 
		, sComm			 
		, ruben			 
		, statuswinlost	 
		, odds			 
	)
	SELECT	
		transid			 
		, [Status]		 
		, SettlementTime 
		, StatusID		 
		, WinLost		 
		, aWinLost		 
		, mWinLost		 
		, sWinLost		 
		, PlayerComm	 
		, Comm			 
		, aComm			 
		, sComm			 
		, ruben			 
		, statuswinlost	 
		, odds
	FROM DBTXN.bodb02.dbo.bettrans WITH (NOLOCK)
	WHERE transid IN ( --10 transIds
		113174915252,
		113174916102,
		113175017341,
		113175018023,
		113175027363,
		113175027738,
		113175075714,
		113175076123,
		113175109209,
		113175111153
	)

	UPDATE	b
	SET				
		[status]		=	tmp.[status]		 				
		,SettlementTime = 	tmp.SettlementTime 
		,statusID		= 	tmp.statusID		
		,winlost		= 	tmp.winlost		
		,awinlost		= 	tmp.awinlost		
		,mwinlost		= 	tmp.mwinlost		
		,swinlost		= 	tmp.swinlost		
		,playercomm		= 	tmp.playercomm		
		,comm			= 	tmp.comm			
		,acomm			= 	tmp.acomm			
		,scomm			= 	tmp.scomm			
		,ruben			= 	tmp.ruben			
		,statuswinlost  = 	tmp.statuswinlost  
		,odds		    = 	tmp.odds		    
	FROM #transid_tmp tmp
		INNER JOIN dbo.bettrans b  WITH (ROWLOCK, UPDLOCK) 
			ON  tmp.transid = b.transid


DROP TABLE #transid_tmp