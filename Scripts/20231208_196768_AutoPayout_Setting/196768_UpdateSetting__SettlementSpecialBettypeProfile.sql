/*<info serverAlias="DBTXN-bodb02,DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20230711@Aries
	Task: Apply Settle Determined for Basketball [Redmine: #184124]
	DB: DBTXN/bodb02, DBPRO/bodb02
*/
 
USE bodb02
GO
/************************Add setting Cal SDT**************************/
IF NOT EXISTS (SELECT * FROM   sys.columns  WHERE  object_id = OBJECT_ID(N'[dbo].[SettlementSpecialBettypeProfile]') AND name = 'HasAwayValue')
BEGIN
	ALTER TABLE dbo.SettlementSpecialBettypeProfile ADD HasAwayValue BIT
END

GO
UPDATE SettlementSpecialBettypeProfile
SET HasAwayValue = 1
WHERE SportType = 50
    AND ResourceID in ('00','9446','9447','9449','96151','94511')








