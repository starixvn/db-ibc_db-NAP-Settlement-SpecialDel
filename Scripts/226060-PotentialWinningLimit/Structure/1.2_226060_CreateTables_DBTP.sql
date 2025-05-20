/*<info serverAlias="IRS_DBTP-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*	
	Created: 20250416@Louisa
	Task:  Potential Winning Limit/Threshold [Redmine:#226060]
	DB: DBSIC/bodb02
	
	Revisions:
		- 20250416@Louisa:  Potential Winning Limit/Threshold [Redmine:#226060]

*/

---run on DBTP

USE bodb02
GO

drop table if exists CustWinLimitBet
CREATE TABLE CustWinLimitBet (
    CustID			INT			NOT NULL	
	,Sporttype		SMALLINT	NOT NULL	
	,Bettype		INT			NOT NULL	
	,AccumToWin		MONEY		 
	,AccumWinLoss	MONEY		 
	,CreatedDate	DATETIME  
	,RepUpdateTime	DATETIME2	 
	,isDeleted		BIT			NULL
);
GO

ALTER TABLE CustWinLimitBet
ADD CONSTRAINT PK_CustWinLimitBet 
PRIMARY KEY CLUSTERED (	CustID ASC,Sporttype ASC,Bettype ASC) 
GO


ALTER TABLE CustWinLimitBet
ADD CONSTRAINT DF_CustWinLimitBet_AccumToWin DEFAULT 0 FOR AccumToWin;
GO

ALTER TABLE CustWinLimitBet
ADD CONSTRAINT DF_CustWinLimitBet_AccumWinLoss DEFAULT 0 FOR AccumWinLoss;
GO

ALTER TABLE CustWinLimitBet
ADD CONSTRAINT DF_CustWinLimitBet_CreatedDate DEFAULT GETDATE() FOR CreatedDate;
GO

ALTER TABLE CustWinLimitBet
ADD CONSTRAINT DF_CustWinLimitBet_RepUpdateTime DEFAULT SYSDATETIME() FOR RepUpdateTime;
GO

CREATE NONCLUSTERED INDEX IDX_CustWinLimitBet_RepUpdateTime 
ON CustWinLimitBet (RepUpdateTime);
GO

--------------------------------------------------------------------------------------------  
drop table if exists CustWinLimitBet_History
CREATE TABLE CustWinLimitBet_History (
	 ID				BIGINT IDENTITY(1,1)
	,CustID			INT			NOT NULL
	,Sporttype		SMALLINT	 
	,Bettype		INT			 
	,Transid		BIGINT		 
	,AdjToWin		MONEY
	,AdjWinLoss		MONEY
	,ActionType		TINYINT		NOT NULL
	,RepUpdateTime	DATETIME2 
	,isDeleted		BIT			NULL
);
GO 

ALTER TABLE CustWinLimitBet_History
ADD CONSTRAINT PK_CustWinLimitBet_History 
PRIMARY KEY CLUSTERED (	ID ASC) 
GO

ALTER TABLE CustWinLimitBet_History
ADD CONSTRAINT DF_CustWinLimitBet_History_RepUpdateTime DEFAULT SYSDATETIME() FOR RepUpdateTime;
GO

CREATE NONCLUSTERED INDEX IDX_CustWinLimitBet_History_CustID_TransId_Sporttype_Bettype
ON CustWinLimitBet_History (CustID ASC, TransId ASC, Sporttype ASC, Bettype ASC);
GO

CREATE NONCLUSTERED INDEX IDX_CustWinLimitBet_History_RepUpdateTime 
ON CustWinLimitBet_History (RepUpdateTime);
GO
  
