/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: 20250804@Hughie
	Task: SOP Outright  [Redmine:#232955]
	DB: DBPRO/bodb02
*/

USE bodb02
GO

CREATE TABLE [dbo].[ResultDetailOutright](
	[Orid] [int] NOT NULL
	,[Teamid] [int] NULL
	,[ConfirmStatus][VARCHAR](10)NULL
	,[ResultStatusID] [TINYINT] NULL
	,[SettlementStatusID] [TINYINT] NULL
	,[KeyResultUserId] [INT] NULL
	,[ConfirmUserId] [INT] NULL
	,[CreateDate] [datetime] NULL
	,[LastModifyDate] [datetime] NULL
	,[isDelete][bit] NULL
	,[RepUpdateTime] [DATETIME2] NULL
    CONSTRAINT [PK_ResultDetailOutright_Orid] PRIMARY KEY CLUSTERED 
    (
	    [Orid] ASC
    )
) 
GO