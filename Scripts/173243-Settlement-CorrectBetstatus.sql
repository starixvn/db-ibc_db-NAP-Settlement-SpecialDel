/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created: 20220526@Kathy
	Task: Correct betstatus [Redmine:#173243]
*/
UPDATE dbo.match WITH(ROWLOCK, UPDLOCK) -- 4-1
	SET betstatus = 'Refund FT;0-0,0-1,0-0,3-0,1-0,0-0,0-0,0-0,0-0,0-0'
WHERE matchid = 53880731
GO

UPDATE dbo.match WITH(ROWLOCK, UPDLOCK) -- 9-0
	SET betstatus = 'Refund FT;1-0,0-0,1-0,4-0,3-0,0-0,0-1,0-0,0-0,0-0'
WHERE matchid = 53876862
GO

UPDATE dbo.match WITH(ROWLOCK, UPDLOCK) -- 10-0
	SET betstatus = 'Refund FT;0-0,3-0,0-0,0-0,7-0,0-1,0-0,0-0,0-0,0-0'
WHERE matchid = 53848004
GO

UPDATE dbo.match14 WITH(ROWLOCK, UPDLOCK) -- 1-0
	SET betstatus = 'Refund FT;0-0,0-0,1-0,0-0,0-0,0-0,0-0,0-0,0-0,0-0'
WHERE matchid = 53746185