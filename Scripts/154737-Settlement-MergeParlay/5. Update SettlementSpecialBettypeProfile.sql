/*<info serverAlias="DBTXN-bodb02" executers="" isFunction="0"></info>*/

USE [bodb02]
GO
/*  Creator: 20210514@Kathy
	Task: Update data profile
	DB: DBTXN/BODB02

*/
UPDATE dbo.SettlementSpecialBettypeProfile
	SET RefResourceId = '00'
WHERE SportType = 9
		AND bettype BETWEEN 704 AND 706