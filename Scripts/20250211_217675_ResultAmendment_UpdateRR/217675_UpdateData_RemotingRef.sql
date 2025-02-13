/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20250211@Aries
	Task:  Can't create result amendment notification due to the resource from the SettlementResultHistory table not being saved like the ref-resource [Redmine: #217675]
	DB: sitdbodds.bodb_odds, SITIHRDISTC1.replDB, DBPRO.bodb02

*/

USE bodb02
GO

UPDATE RefResource
SET ResourceId = 'BOTTOM'
WHERE RefId = 'ResultSettlement'
    AND ResourceId = 'Bottom'

UPDATE RefResource
SET ResourceId = 'NONE'
WHERE RefId = 'ResultSettlement'
    AND ResourceId = 'None'


