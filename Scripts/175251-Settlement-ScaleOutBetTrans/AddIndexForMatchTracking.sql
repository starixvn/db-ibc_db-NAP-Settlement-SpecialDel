/*<info serverAlias="DBTP-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20220928@Kathy
	Task: add index for match_tracking [Redmine:#175251]
	DB: DBTP/bodb02
*/

USE bodb02
GO

CREATE INDEX [IX_Match_Tracking_UpdateTime] ON [dbo].[Match_Tracking]
(
	UpdateTime
)
GO



    
