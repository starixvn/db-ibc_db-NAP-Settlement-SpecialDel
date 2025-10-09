/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created by: 20250924@July
	Task : [TVS] Manage Void Service - Correct summary ticket 19999 [Redmine: #238091]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02

*/
USE bodb02
GO
IF EXISTS(SELECT 1 FROM sys.tables WHERE Object_ID = Object_ID(N'TVS_BetTicket14'))
BEGIN
	DROP TABLE TVS_BetTicket14
END

CREATE TABLE dbo.TVS_BetTicket14 (
		 TransId			BIGINT PRIMARY KEY
		,CustId				INT			
		,Winlostdate		SMALLDATETIME
		,statusID			TINYINT
		,status				NVARCHAR(10)	
		,SettlementTime		DATETIME	
		,stake				MONEY	
		,actual_stake		MONEY	
		,winlost			MONEY
		,awinlost			MONEY
		,mwinlost			MONEY
		,swinlost			MONEY
		,playercomm			MONEY	
		,comm				MONEY
		,acomm				MONEY
		,scomm				MONEY
		,betdaqid			VARCHAR(1000)
) ON [DATA]
GO