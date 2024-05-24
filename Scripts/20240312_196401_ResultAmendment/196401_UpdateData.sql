/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20240524@Aries
	Task:  Result Amendment [Redmine:#196401]
	DB: DBPRO-bodb02

*/

USE bodb02
GO

--select * from RefResource where RefId like '%ResultSettlement%'

UPDATE RefResource
SET ResourceId = 'C'
WHERE RefId = 'ResultSettlement'
    AND ResourceId = 'c'

UPDATE RefResource
SET ResourceId = 'NC'
WHERE RefId = 'ResultSettlement'
    AND ResourceId = 'nc'

UPDATE RefResource
SET ResourceId = 'RO'
WHERE RefId = 'ResultSettlement'
    AND ResourceId = 'ro'

UPDATE RefResource
SET ResourceId = 'LBW'
WHERE RefId = 'ResultSettlement'
    AND ResourceId = 'lbw'


UPDATE RefResource
SET Resource_en = 'Home @G Group 1-@X Runs'
WHERE RefId = 'ResourceCricket'
    AND ResourceId = '9410'

UPDATE RefResource
SET Resource_en = 'Away @G Group 1-@X Runs'
WHERE RefId = 'ResourceCricket'
    AND ResourceId = '9411'


UPDATE RefResource
SET Resource_en = '@G Highest Individual Score'
   ,Resource_ch = N'@G個人最高得分盤'
   ,Resource_cs = N'@G个人最高得分盘'
WHERE RefId = 'ResourceCricket'
    AND ResourceId = '9708'


UPDATE RefResource
SET Resource_en = '@G Highest Over Score'
   ,Resource_ch = N'@G赛轮最高得分盘'
   ,Resource_cs = N'@G赛轮最高得分盘'
WHERE RefId = 'ResourceCricket'
    AND ResourceId = '9709'