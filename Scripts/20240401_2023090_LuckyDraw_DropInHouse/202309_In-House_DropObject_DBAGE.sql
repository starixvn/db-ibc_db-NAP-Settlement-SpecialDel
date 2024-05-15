/*<info serverAlias="DBAGE-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created: 20240401@Aries
    Task: EC 2024-Correct Score Sharing and Lucky Draw-(Pool prize) [Redmine:#202309]
	DB: DBAGE-bodb02

*/

USE bodb02
GO

DELETE
FROM RepInfo
WHERE [group] = 7
	AND [name] = 'LuckyDrawList'
GO

DROP PROCEDURE IF EXISTS dbo.Repl_PutLuckyDrawList
GO

DROP TYPE IF EXISTS dbo.TVP_ReplLuckyDrawList
GO

DROP TABLE IF EXISTS dbo.LuckyDrawList
GO