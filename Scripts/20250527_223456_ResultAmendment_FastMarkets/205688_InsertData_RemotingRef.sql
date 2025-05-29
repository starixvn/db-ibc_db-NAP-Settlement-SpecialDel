/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20250527@Aries
	Task:  Integrate- Settle- Result Amendment- Fast Markets, Time Machine [Redmine: #223456]
	DB: DBPRO-bodb02

*/

USE bodb02
GO

/*
	select * from RefResource where RefId =  'ResultSettlement' and ResourceId like 'b[0-9]'
*/
INSERT INTO RefResource (
	RefId,
	ResourceId,
	Resource_en,
	Resource_ch,
	Resource_cs,
	Resource_jp,
	RepUpdateTime
)
VALUES
	('ResultSettlement', 'b0', 'None', N'無', N'无', NULL, SYSDATETIME()),
	('ResultSettlement', 'b1', 'Goal', N'入球', N'入球', NULL, SYSDATETIME()),
	('ResultSettlement', 'b2', 'Corner', N'角球', N'角球', NULL, SYSDATETIME()),
	('ResultSettlement', 'b3', 'Free Kick', N'任意球', N'任意球', NULL, SYSDATETIME()),
	('ResultSettlement', 'b4', 'Goal Kick', N'龍門球', N'龙门球', NULL, SYSDATETIME()),
	('ResultSettlement', 'b5', 'Throw In', N'界外球', N'界外球', NULL, SYSDATETIME()),
	('ResultSettlement', 'b6', 'Booking', N'罰牌', N'罚牌', NULL, SYSDATETIME()),
	('ResultSettlement', 'b7', 'Penalty', N'點球', N'点球', NULL, SYSDATETIME());