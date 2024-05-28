/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20240528@Aries
	Task:  Support new changes on Result Amendment [Redmine: #205688]
	DB: DBPRO-bodb02

*/

USE bodb02
GO

--select * from RefResource where RefId like '%ResultSettlement%'

UPDATE RefResource
SET Resource_en = 'Others'
    ,RepUpdateTime = SYSDATETIME()
WHERE RefId = 'ResultSettlement'
    AND ResourceId = 'OT'


UPDATE RefResource
SET Resource_en = 'Home @G Group 1-@X Runs'
    ,RepUpdateTime = SYSDATETIME()
WHERE RefId = 'ResourceCricket'
    AND ResourceId = '9410'

UPDATE RefResource
SET Resource_en = 'Away @G Group 1-@X Runs'
    ,RepUpdateTime = SYSDATETIME()
WHERE RefId = 'ResourceCricket'
    AND ResourceId = '9411'

UPDATE RefResource
SET Resource_ch = N'個人最高得分盤'
    ,Resource_cs= N'个人最高得分盘'
    ,RepUpdateTime = SYSDATETIME()
WHERE RefId = 'ResourceCricket'
    AND ResourceId = '9452'

UPDATE RefResource
SET Resource_ch = N'超級輪獲勝者盤'
    ,Resource_cs= N'超级轮获胜者盘'
    ,RepUpdateTime = SYSDATETIME()
WHERE RefId = 'ResourceCricket'
    AND ResourceId = '9400'

UPDATE RefResource
SET Resource_ch = N'比賽一擊六分盤'
    ,Resource_cs= N'比赛一击六分盘'
    ,RepUpdateTime = SYSDATETIME()
WHERE RefId = 'ResourceCricket'
    AND ResourceId = '9447'

UPDATE RefResource
SET Resource_ch = N'比賽未得分投球數盤'
    ,Resource_cs= N'比赛未得分投球数盘'
    ,RepUpdateTime = SYSDATETIME()
WHERE RefId = 'ResourceCricket'
    AND ResourceId = '9451'