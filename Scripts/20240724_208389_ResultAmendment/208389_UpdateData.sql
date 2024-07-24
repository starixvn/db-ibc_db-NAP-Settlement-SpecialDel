/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20240724@Aries
	Task:  Integration - Support to update name of bet type for the Result Amendment project [Redmine: #208389]
	DB: DBPRO-bodb02

*/

USE bodb02
GO


UPDATE RefResource
SET  Resource_en = N'Home @G Wicket @X Method of Dismissal (6 Way)'
    ,Resource_ch = N'主隊@G第 @X 三柱門出局方式盤(6式)'
    ,Resource_cs= N'主队@G第 @X 三柱门出局方式盘(6式)'
    ,RepUpdateTime = SYSDATETIME()
WHERE RefId = 'ResourceCricket'
    AND ResourceId = '9636'


UPDATE RefResource
SET  Resource_en = N'Away @G Wicket @X Method of Dismissal (6 Way)'
    ,Resource_ch = N'客隊@G第 @X 三柱門出局方式盤(6式)'
    ,Resource_cs= N'客队@G第 @X 三柱门出局方式盘(6式)'
    ,RepUpdateTime = SYSDATETIME()
WHERE RefId = 'ResourceCricket'
    AND ResourceId = '9637'