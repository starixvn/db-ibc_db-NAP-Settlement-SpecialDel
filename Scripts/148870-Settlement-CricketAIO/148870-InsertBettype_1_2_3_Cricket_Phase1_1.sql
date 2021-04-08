/*<info serverAlias="DBTXN-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by: 20210408@Louisa
    Task: 20210408@Louisa: Cricket AIO [Redmine:#148870]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20210126@Louisa: Insert SettlementSpecialBettypeProfile for Cricket ( bettype 1,2,3 ) [Redmine:#148870]
*/

USE bodb02
GO


INSERT INTO dbo.SettlementSpecialBettypeProfile
				(pfID,
				BetType,	
				SportType,	
				BetID,	
				ResourceID,	
				SettleType,	
				GroupType,	
				OrdNo,	
				RoundID,	
				OddsType,	
				RefResourceId)
VALUES	 (10,	1,	50,	0,	'00',	'MNL',	'FT',	99,	'0'	,	1,	NULL)
		,(2	,	2,	50,	0,	'00',	'MNL',	'FT',	99,	'0',	1,	NULL)
		,(3	,	3,	50,	0,	'00',	'MNL',	'FT',	99,	'0',	1,	NULL)

GO