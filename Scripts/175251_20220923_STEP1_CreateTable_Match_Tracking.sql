/*<info serverAlias="DBTP-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: 20220923@Louisa
	Task: Trigger table match to trace issue scaleout [Redmine:#175251]
	DB: DBTP/bodb02
*/

USE bodb02
GO

CREATE TABLE dbo.Match_Tracking
(
		 matchid		int not null
		,eventdate		datetime
		,eventstatus	nvarchar(100)
		,betstatus		nvarchar(100)
		,livehomescore	int
		,liveawayscore	int
		,finalhomescore	int
		,finalawayscore	int
		,creator		int
		,hthomescore	int
		,htawayscore	int
		,GoalRecord		varchar(50)
		,ParentID		int
		,ChildMatchType	tinyint
		,changetime		datetime
		,settletime		datetime
		,IsAutoPayout	bit
		,AutoSetting	tinyint
		,SettlementStatus tinyint
		,UpdateTime		datetime
)
GO

CREATE CLUSTERED INDEX [CIX_Match_Tracking_matchid_UpdateTime] ON [dbo].[Match_Tracking]
(
	[matchid] 
	,UpdateTime
)
GO


