/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: 20250804@Hughie
	Task: SOP Outright  [Redmine:#221187]
	DB: DBPRO/bodb02
*/

USE bodb02
GO

CREATE TABLE [dbo].[ResultDetailOutright](
	[orid] [int] NOT NULL
	,[ResultStatusID] [TINYINT] NULL
	,[KeyResultUserId] [INT] NULL
	,[ConfirmUserId] [INT] NULL
	,[CreateDate] [datetime] NULL
	,[LastModifyDate] [datetime] NULL
	,[OtherInfo] [varchar](50) NULL
	,[ResultSetting] [tinyint] NULL
    CONSTRAINT [PK_ResultDetailOutright_orid] PRIMARY KEY NONCLUSTERED 
    (
	    [orid] ASC
    )
) 
GO