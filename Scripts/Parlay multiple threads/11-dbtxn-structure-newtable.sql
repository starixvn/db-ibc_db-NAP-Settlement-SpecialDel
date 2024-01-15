/*<info serverAlias="DBTXN-bodb02" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: 20240215@Kathy
	Task	  : create new table
	DB		  : DBTXN/bodb02
*/

USE [bodb02]
GO

IF OBJECT_ID('ParlaySettlementProcessing') IS NOT NULL
	DROP TABLE dbo.ParlaySettlementProcessing

CREATE TABLE [dbo].[ParlaySettlementProcessing](
	[Id] [bigint] IDENTITY(1,1),
	[SessionId] [bigint] NULL,
	[MatchId] [int] NULL,
	[MessageType] [varchar](200) NULL,
	[Action] [varchar](20) NULL,
	[ActionId] [int] NULL,
	[SubTransIds] [varchar](max) NULL,
	[MainTransIds] [varchar](max) NULL,
	[RefnoMainTransIds] [varchar](max) NULL,
	[EventDate] [smalldatetime] NULL,
	[strSetting] [varchar](max) NULL,
	[IsReSettledTickets] [bit] NULL,
	[StatusId] [tinyint] NULL,
	[MainParlayMaxPO] [varchar](max) NULL,
	[BroadcastSessionId] [varchar](50) NULL,
	CONSTRAINT [PK_ParlaySettlementProcessing] PRIMARY KEY NONCLUSTERED 
	(
		[Id] ASC
	) ON [DATA]
) ON [DATA] 
GO

ALTER TABLE [dbo].[ParlaySettlementProcessing] ADD CONSTRAINT DF_ParlaySettlementProcessing_IsReSettledTickets  DEFAULT ((0)) FOR [IsReSettledTickets]
GO
ALTER TABLE [dbo].[ParlaySettlementProcessing] ADD CONSTRAINT DF_ParlaySettlementProcessing_StatusId DEFAULT ((0)) FOR [StatusId]
GO


CREATE CLUSTERED INDEX [CIX_ParlaySettlementProcessing] ON [dbo].[ParlaySettlementProcessing]
(
	[SessionId] ASC,
	[MessageType] ASC,
	[StatusId] ASC
)ON [DATA]
GO


