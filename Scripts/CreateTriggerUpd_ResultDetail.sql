/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: 20220324@Louisa
	Task: Create new table to store ResultDetail/OS/ES update history  [Redmine:#]
	DB: DBPRO/bodb02
*/

USE bodb02
GO

CREATE TRIGGER [dbo].[ResultDetail_Upd] ON [dbo].[ResultDetail] 
AFTER UPDATE
AS
	SET NOCOUNT ON

	INSERT INTO dbo.SettlementResultDetailHistory (	TableName ,Matchid , ResourceId ,OldHomeValue ,OldAwayValue ,NewHomeValue ,NewAwayValue ,ModifyDate )
	SELECT 'ResultDetail'
			, i.MatchId
			, i.ResourceId
			, d.HomeValue
			, d.AwayValue
			, i.HomeValue
			, i.AwayValue
			, GETDATE()
	FROM INSERTED i
		INNER JOIN  DELETED d ON i.MatchId = d.MatchId
			AND i.ResourceId = d.ResourceId

GO

CREATE TRIGGER [dbo].[ResultDetailOS_Upd] ON [dbo].[ResultDetailOS] 
AFTER UPDATE
AS
	SET NOCOUNT ON

	INSERT INTO dbo.SettlementResultDetailHistory (	TableName ,Matchid , ResourceId ,OldHomeValue ,OldAwayValue ,NewHomeValue ,NewAwayValue ,ModifyDate )
	SELECT 'ResultDetailOS'
			, i.MatchId
			, i.ResourceId
			, d.HomeValue
			, d.AwayValue
			, i.HomeValue
			, i.AwayValue
			, GETDATE()
	FROM INSERTED i
		INNER JOIN  DELETED d ON i.MatchId = d.MatchId
			AND i.ResourceId = d.ResourceId

GO


CREATE TRIGGER [dbo].[ResultDetailES_Upd] ON [dbo].[ResultDetailES] 
AFTER UPDATE
AS
	SET NOCOUNT ON

	INSERT INTO dbo.SettlementResultDetailHistory (	TableName ,Matchid , ResourceId ,OldHomeValue ,OldAwayValue ,NewHomeValue ,NewAwayValue ,ModifyDate )
	SELECT 'ResultDetailES'
			, i.MatchId
			, i.ResourceId
			, d.HomeValue
			, d.AwayValue
			, i.HomeValue
			, i.AwayValue
			, GETDATE()
	FROM INSERTED i
		INNER JOIN  DELETED d ON i.MatchId = d.MatchId
			AND i.ResourceId = d.ResourceId

GO