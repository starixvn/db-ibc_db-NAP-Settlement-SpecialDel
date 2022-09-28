/*<info serverAlias="DBTP-bodb02" executers="" viewers="" isFunction="0"></info>*/
USE bodb02
GO
/*
   Created:20220928@Kathy
   Task: create index on match_tracking [Redmine:#175251]

   DB: DBTP/bodb02
	
	Revisions:
		- 20220928@Kathy: create index on match_tracking [Redmine:#175251]
	
	Param's Explanation: 

*/
CREATE INDEX [IX_Match_Tracking_UpdateTime] ON [dbo].[Match_Tracking]
(
	UpdateTime
)
GO
