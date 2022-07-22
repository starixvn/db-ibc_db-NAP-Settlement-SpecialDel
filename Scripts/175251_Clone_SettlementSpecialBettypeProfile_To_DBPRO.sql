/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created: 20220719@Louisa
    Task: Scale Out BetTrans [Redmine:#175251]
    DB: DBPRO/bodb02
	
	Revisions:
		- 20220719@Louisa: Create table and copy data from DBTRANS to DBPRO  [Redmine:#175251]

	Param's Explanation: 

*/

USE [bodb02]
GO

IF NOT EXISTS (SELECT TOP 1 1 FROM sys.tables WHERE name = 'SettlementSpecialBettypeProfile' )
BEGIN
	CREATE TABLE [dbo].[SettlementSpecialBettypeProfile](
		[pfID]			[smallint]		NOT NULL,
		[BetType]		[smallint]		NOT NULL,
		[SportType]		[tinyint]		NOT NULL,
		[BetID]			[bigint]		NOT NULL,
		[ResourceID]	[varchar](20)	NOT NULL,
		[SettleType]	[char](3)		NOT NULL,
		[GroupType]		[char](2)		NOT NULL,
		[OrdNo]			[smallint]		NULL,
		[RoundID]		[varchar](10)	NULL,
		[OddsType]		[smallint]		NULL,
		[RefResourceId] [varchar](20)	NULL,
		[SDTpfId]		[smallint]		NULL,
		[Is3x30]		[bit]			NULL,
		[SDTResourceId] [smallint]		NULL,
		[IsSDT]			[smallint]		NULL,
		[DeterminedType] [tinyint]		NULL,
		[SpecialType] [tinyint]			NULL
	) ON [DATA]
END
GO

CREATE TABLE #Temp (
		[pfID]			[smallint]		NOT NULL,
		[BetType]		[smallint]		NOT NULL,
		[SportType]		[tinyint]		NOT NULL,
		[BetID]			[bigint]		NOT NULL,
		[ResourceID]	[varchar](20)	NOT NULL,
		[SettleType]	[char](3)		NOT NULL,
		[GroupType]		[char](2)		NOT NULL,
		[OrdNo]			[smallint]		NULL,
		[RoundID]		[varchar](10)	NULL,
		[OddsType]		[smallint]		NULL,
		[RefResourceId] [varchar](20)	NULL,
		[SDTpfId]		[smallint]		NULL,
		[Is3x30]		[bit]			NULL,
		[SDTResourceId] [smallint]		NULL,
		[IsSDT]			[smallint]		NULL,
		[DeterminedType] [tinyint]		NULL,
		[SpecialType] [tinyint]			NULL
	)

--29 068 rows
INSERT INTO #Temp ( pfID, BetType, SportType, BetID, ResourceID, SettleType, GroupType, OrdNo, RoundID, OddsType, RefResourceId, SDTpfId, Is3x30, SDTResourceId, IsSDT, DeterminedType, SpecialType) 
SELECT pfID, BetType, SportType, BetID, ResourceID, SettleType, GroupType, OrdNo, RoundID, OddsType, RefResourceId, SDTpfId, Is3x30, SDTResourceId, IsSDT, DeterminedType, SpecialType
FROM DBTXN.bodb02.dbo.SettlementSpecialBettypeProfile WITH(NOLOCK)

INSERT INTO SettlementSpecialBettypeProfile ( pfID, BetType, SportType, BetID, ResourceID, SettleType, GroupType, OrdNo, RoundID, OddsType, RefResourceId, SDTpfId, Is3x30, SDTResourceId, IsSDT, DeterminedType, SpecialType)
SELECT pfID, BetType, SportType, BetID, ResourceID, SettleType, GroupType, OrdNo, RoundID, OddsType, RefResourceId, SDTpfId, Is3x30, SDTResourceId, IsSDT, DeterminedType, SpecialType
FROM #Temp



	
 
 


