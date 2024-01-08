/*<info serverAlias="DBTXN-bodb02, DB02-bodb02" executers="" viewers="" isFunction="0"></info>*/
USE bodb02
GO

CREATE TABLE [dbo].[SettlementSpecialBettypeProfile](
	[rId] [int] IDENTITY (1,1) NOT FOR REPLICATION NOT NULL,
	[pfID] [smallint] NOT NULL,
	[BetType] [smallint] NOT NULL,
	[SportType] [tinyint] NOT NULL,
	[BetID] [bigint] NOT NULL,
	[ResourceID] [varchar](20) NOT NULL,
	[SettleType] [char](3) NOT NULL,
	[GroupType] [char](2) NOT NULL,
	[OrdNo] [smallint] NULL,
	[RoundID] [varchar](10) NULL,
	[OddsType] [smallint] NULL,
	[RefResourceId] [varchar](20) NULL,
	[SDTpfId] [smallint] NULL,
	[Is3x30] [bit] NULL,
	[SDTResourceId] [varchar](20) NULL,
	[IsSDT] [bit] NULL,
	[DeterminedType] [tinyint] NULL,
	[SpecialType] [tinyint] NULL,
	[SDTRefund] [tinyint] NULL,
	[SDTInstant] [tinyint] NULL,
	[HasAwayValue] [bit] NULL
 CONSTRAINT [PK_SettlementSpecialBettypeProfile] PRIMARY KEY NONCLUSTERED ( [rId] ASC ) ON [DATA]
) ON [DATA]
GO

CREATE NONCLUSTERED INDEX [IX_SettlementSpecialBettypeProfile_Bettype_BetID] ON [dbo].[SettlementSpecialBettypeProfile]
(
	[BetType] ASC,
	[BetID] ASC
) ON [DATA]
GO


CREATE CLUSTERED INDEX [IX_SettlementSpecialBettypeProfile_resourceid] ON [dbo].[SettlementSpecialBettypeProfile]
(
	[ResourceID] ASC
) ON [DATA]
GO

CREATE NONCLUSTERED INDEX [IX_SettlementSpecialBettypeProfile_SportType] ON [dbo].[SettlementSpecialBettypeProfile]
(
	[SportType] ASC
)
INCLUDE([BetType],[BetID]) ON [DATA]
GO