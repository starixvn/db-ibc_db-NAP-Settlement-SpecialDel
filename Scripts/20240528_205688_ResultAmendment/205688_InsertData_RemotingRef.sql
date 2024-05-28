/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20240528@Aries
	Task:  Support new changes on Result Amendment [Redmine: #205688]
	DB: DBPRO-bodb02

*/

USE bodb02
GO

--select * from RefResource where RefId like '%ResultSettlement%'
INSERT INTO RefResource( RefId, ResourceId, Resource_en, Resource_ch, Resource_cs,RepUpdateTime)	
VALUES('ResultSettlement','C',N'Caught',N'接球出局',N'接球出局',SYSDATETIME())
	 ,('ResultSettlement','NC',N'Not Caught',N'非接球出局',N'非接球出局',SYSDATETIME())
	 ,('ResultSettlement','LBW',N'LBW',N'觸身',N'触身',SYSDATETIME())
	 ,('ResultSettlement','RO',N'Run Out',N'追殺',N'追杀',SYSDATETIME())
