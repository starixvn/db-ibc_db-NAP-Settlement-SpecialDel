/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20240528@Aries
	Task:  Support new changes on Result Amendment [Redmine: #205688]
	DB: sitdbodds.bodb_odds, SITIHRDISTC1.replDB, DBPRO.bodb02

*/

USE bodb02
GO

--select * from RefResource where RefId like '%ResultSettlement%'

UPDATE RefResource
SET ResourceId = 'C'
    ,RepUpdateTime = SYSDATETIME()
WHERE RefId = 'ResultSettlement'
    AND ResourceId = 'c'

UPDATE RefResource
SET ResourceId = 'NC'
    ,RepUpdateTime = SYSDATETIME()
WHERE RefId = 'ResultSettlement'
    AND ResourceId = 'nc'

UPDATE RefResource
SET ResourceId = 'RO'
    ,RepUpdateTime = SYSDATETIME()
WHERE RefId = 'ResultSettlement'
    AND ResourceId = 'ro'

UPDATE RefResource
SET ResourceId = 'LBW'
    ,RepUpdateTime = SYSDATETIME()
WHERE RefId = 'ResultSettlement'
    AND ResourceId = 'lbw'