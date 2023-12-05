/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20231205@Louisa
	Task:  Result Amendment [Redmine:#196401]
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

CREATE TABLE [dbo].[SettlementResultHistory]
(
	 [SessionID]      VARCHAR(50)    NOT NULL
	,[MatchID]        INT            NOT NULL
	,[ActualResult]   VARCHAR(MAX)
	,[WrongResult]    VARCHAR(MAX)
	,[Action]         BIGINT
	,[ResultType]     TINYINT
	,[Sporttype]      SMALLINT
	,[CreatedDate]    DATETIME
	,[ModifiedDate]   DATETIME
	,[StatusID]       TINYINT
	,[ExtraInfo]      VARCHAR(MAX)
) ON DATA
GO

CREATE CLUSTERED INDEX [CIX_SettlementResultHistory] ON [dbo].[SettlementResultHistory]
(
	MatchID,SessionID
) ON [DATA]
GO

-------------------------------------------------------------------------

CREATE TABLE [dbo].[SettlementResultHistory_TicketDetails]
(
	 [SessionID]	VARCHAR(50) NOT NULL
	,[Transid]		BIGINT	    NOT NULL
) ON DATA
GO

CREATE CLUSTERED INDEX [SettlementResultHistory_TicketDetails] ON [dbo].[SettlementResultHistory_TicketDetails]
(
	[SessionID],[Transid]
) ON [DATA]
GO

-------------------------------------------------------------------------

ALTER TABLE BalanceNegative ADD SessionId VARCHAR(50);
GO

ALTER TABLE BalanceNegativeHistory ADD SessionId VARCHAR(50);
GO

