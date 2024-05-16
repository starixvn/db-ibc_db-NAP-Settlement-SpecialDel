/*<info serverAlias="DBAGE-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created: 20240401@Aries
    Task: EC 2024-Correct Score Sharing and Lucky Draw-(Pool prize) [Redmine:#202309]
	DB: DBAGE-bodb02

*/

USE bodb02
GO

UPDATE RepInfo
SET active = 0
WHERE [group] = 7
	AND [name] = 'LuckyDrawList'