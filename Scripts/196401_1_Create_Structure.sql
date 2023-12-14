/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20231205@Louisa
	Task:  Result Amendment Redmine:#196401
	DB: DBTXN-bodb02

	Create table
	   +SettlementResultHistory
	   +SettlementResultHistory_TicketDetails
	Add new column(SessionId)
	   +BalanceNegative
	   +BalanceNegativeHistory

*/

USE bodb02
GO

CREATE TABLE dbo.SettlementResultHistory
(
	 SessionID      VARCHAR(50)		NOT NULL
	,MatchID        INT				NOT NULL
	,SeqNo			SMALLINT		NOT NULL
	,ActualResult   VARCHAR(MAX)
	,WrongResult    VARCHAR(MAX)
	,ActionType		TINYINT			NOT NULL
	,ResultType     TINYINT			NOT NULL
	,Sporttype      SMALLINT		NOT NULL
	,CreatedDate    DATETIME		NOT NULL
	,ModifiedDate   DATETIME		NOT NULL
	,StatusID       TINYINT			NOT NULL
	,ExtraInfo      VARCHAR(MAX)
) ON DATA
GO

ALTER TABLE dbo.SettlementResultHistory
ADD CONSTRAINT PK_SettlementResultHistory 
PRIMARY KEY CLUSTERED 
(
	MatchID,SessionID,SeqNo ASC
) ON DATA
GO

CREATE INDEX IDX_SettlementResultHistory_CreatedDate ON dbo.SettlementResultHistory(CreatedDate)
GO
-------------------------------------------------------------------------

CREATE TABLE dbo.SettlementResultHistory_TicketDetails
(
	 SessionID	VARCHAR(50) NOT NULL
	,SeqNo		SMALLINT	NOT NULL
	,Transid	BIGINT	    NOT NULL
) ON DATA
GO

ALTER TABLE dbo.SettlementResultHistory_TicketDetails
ADD CONSTRAINT PK_SettlementResultHistory_TicketDetails
PRIMARY KEY CLUSTERED 
(
	SessionID,Transid ASC
) ON DATA
GO

-------------------------------------------------------------------------

ALTER TABLE BalanceNegative ADD SessionId VARCHAR(50);
GO

ALTER TABLE BalanceNegativeHistory ADD SessionId VARCHAR(50);
GO

