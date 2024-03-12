/*<info serverAlias="DBTP-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20240312@Aries
	Task:  Result Amendment [Redmine:#196401]
	DB: DBTP-bodb02

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
	,CreatedDate    DATETIME		DEFAULT GETDATE()
	,ModifiedDate   DATETIME		DEFAULT GETDATE()
	,StatusID       TINYINT			
	,ExtraInfo      VARCHAR(MAX)
	,RepUpdateTime  DATETIME2(7)	DEFAULT SYSDATETIME()
	,IsDeleted		BIT				DEFAULT 0
) ON DATA
GO

ALTER TABLE dbo.SettlementResultHistory
ADD CONSTRAINT PK_SettlementResultHistory 
PRIMARY KEY CLUSTERED 
(
	MatchID,SessionID,SeqNo ASC
) ON DATA
GO
-------------------------------------------------------------------------

CREATE TABLE dbo.SettlementResultHistory_TicketDetails
(
	 SessionID			VARCHAR(50) NOT NULL
	,SeqNo				SMALLINT	NOT NULL
	,Transid			BIGINT	    NOT NULL
	,ExtraInfo_Before	VARCHAR(MAX)
	,ExtraInfo_After	VARCHAR(MAX)
	,RepUpdateTime		DATETIME2(7)	DEFAULT SYSDATETIME()
	,IsDeleted			BIT				DEFAULT 0
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
CREATE TYPE [dbo].[TVP_ReplSettlementResultHistory] AS TABLE(
	 SessionID      VARCHAR(50)		
	,MatchID        INT				
	,SeqNo			SMALLINT		
	,ActualResult   VARCHAR(MAX)
	,WrongResult    VARCHAR(MAX)
	,ActionType		TINYINT			
	,ResultType     TINYINT			
	,Sporttype      SMALLINT		
	,CreatedDate    DATETIME		
	,ModifiedDate   DATETIME		
	,StatusID       TINYINT			
	,ExtraInfo      VARCHAR(MAX)
	,RepUpdateTime  DATETIME2(7)	
	,IsDeleted		BIT			
	,_FetchedTime   DATETIME2(7)	
)
GO

-------------------------------------------------------------------------

CREATE TYPE [dbo].[TVP_ReplSettlementResultHistory_TicketDetails] AS TABLE(
	 SessionID			VARCHAR(50) 
	,SeqNo				SMALLINT	
	,Transid			BIGINT	    
	,ExtraInfo_Before	VARCHAR(MAX)
	,ExtraInfo_After	VARCHAR(MAX)
	,RepUpdateTime		DATETIME2(7)	
	,IsDeleted			BIT		
	,_FetchedTime		DATETIME2(7)	
)
GO

GRANT EXECUTE ON TYPE::[dbo].[TVP_ReplSettlementResultHistory_TicketDetails] TO [repl_ap] AS [dbo]
GO
GRANT EXECUTE ON TYPE::[dbo].[TVP_ReplSettlementResultHistory] TO [repl_ap] AS [dbo]
GO