/*<info serverAlias="DBCTG-bodb02" executers="" isFunction="0"></info>*/

/*	
	Created: 20240401@Aries
    Task: EC 2024-Correct Score Sharing and Lucky Draw-(Pool prize)
    [Redmine:#202309,#200194]		
*/

USE bodb02
GO
CREATE NONCLUSTERED INDEX IX_RepUpdateTime ON dbo.LuckyDrawList(RepUpdateTime);
