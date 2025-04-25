/*<info serverAlias="DBCTG-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20250416@Louisa
	Task:Enhance settlement flow when sitedb have down time [Redmine:#217722]
	DB: DBCTG/bodb02
*/
 
USE bodb02
GO

---drop table  SiteDB_PendingCommand
CREATE TABLE SiteDB_PendingCommand (
    pID				INT IDENTITY(1,1),
    MatchId			INT				NOT NULL,
    Sporttype		INT				NOT NULL,
	SPName			VARCHAR(100)	NOT NULL,
	Parameter		VARCHAR (MAX)	NOT NULL,
    Action			VARCHAR(20)		NULL,   ---NAP_Admin_Settlement_s161_Manual does not have action
    IP				NVARCHAR(15)	NOT NULL,
    AdminID			INT				NOT NULL,
    SystemName		VARCHAR(50)		NULL,
    SiteDBGroupID	TINYINT			NOT NULL,
    StatusID		TINYINT			NOT NULL,
	CreateDate		DATETIME		NOT NULL,
	RepUpdateTime	DATETIME2		NOT NULL
);
GO

ALTER TABLE [dbo].[SiteDB_PendingCommand] ADD CONSTRAINT [DF_SiteDB_PendingCommand_CreateDate] DEFAULT(GETDATE()) FOR [CreateDate]
GO

ALTER TABLE [dbo].[SiteDB_PendingCommand] ADD CONSTRAINT [DF_SiteDB_PendingCommand_RepUpdateTime] DEFAULT(SYSDATETIME()) FOR [RepUpdateTime]
GO

ALTER TABLE [dbo].SiteDB_PendingCommand 
ADD CONSTRAINT PK_SiteDB_PendingCommand
PRIMARY KEY CLUSTERED 
(
	pID ASC
)
GO

CREATE NONCLUSTERED INDEX CIX_SiteDB_PendingCommand_matchid ON [dbo].[SiteDB_PendingCommand]
(
	matchid
)
GO

CREATE NONCLUSTERED INDEX CIX_SiteDB_PendingCommand_CreateDate ON [dbo].[SiteDB_PendingCommand]
(
	CreateDate
)
GO







 


