/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created: 20201009@Helen
	Task: Correct Data for bettype 228, match test 
	DB: DBPRO/bodb02
*/
USE bodb02
GO
UPDATE ResultDetail
	SET homevalue ='00000000000000000000000000000000000000000000000000'
		, awayvalue='00000000000000000000000000000000000000000000000000'
WHERE  ResourceId IN ('22800','22801')
		AND matchid IN (39021543,38951218,38956640,38972654,38991674,39032050,39030300,39033555)
GO		

