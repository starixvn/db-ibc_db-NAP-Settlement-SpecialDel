/*<info serverAlias="DBTP-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: 20220923@Louisa
	Task: Trigger table match to trace issue scaleout [Redmine:#175251]
	DB: DBTP/bodb02
*/

USE bodb02
GO
 
CREATE OR ALTER TRIGGER [dbo].[Trg_Match_Tracking] ON [dbo].[match] 
AFTER UPDATE
AS
	SET NOCOUNT ON

	INSERT INTO dbo.Match_Tracking (	
		matchid	 
		,eventdate		 
		,eventstatus	 
		,betstatus		 
		,livehomescore	 
		,liveawayscore	 
		,finalhomescore	 
		,finalawayscore	 
		,creator		 
		,hthomescore	 
		,htawayscore	 
		,GoalRecord		 
		,ParentID		 
		,ChildMatchType	 
		,changetime		 
		,settletime		 
		,IsAutoPayout	 
		,AutoSetting	 
		,SettlementStatus 
		,UpdateTime	 
	)
	SELECT
		d.matchid	 
		,d.eventdate		 
		,d.eventstatus	 
		,d.betstatus		 
		,d.livehomescore	 
		,d.liveawayscore	 
		,d.finalhomescore	 
		,d.finalawayscore	 
		,d.creator		 
		,d.hthomescore	 
		,d.htawayscore	 
		,d.GoalRecord		 
		,d.ParentID		 
		,d.ChildMatchType	 
		,d.changetime		 
		,d.settletime		 
		,d.IsAutoPayout	 
		,d.AutoSetting	 
		,d.SettlementStatus 
		,GETDATE() AS UpdateTime
	FROM INSERTED i
		INNER JOIN  DELETED d ON i.MatchId = d.MatchId

GO