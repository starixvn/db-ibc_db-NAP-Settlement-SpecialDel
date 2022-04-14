/*<info serverAlias="DBTP-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: 20220808@Louisa
	Task: Capture more value  [Redmine:#170548]
	DB: DBTP/bodb02
*/

USE bodb02
GO

ALTER TRIGGER [dbo].[ResultDetail_Upd] ON [dbo].[ResultDetail] 
AFTER UPDATE
AS
	SET NOCOUNT ON

	INSERT INTO dbo.SettlementResultDetailHistory (	
		TableName			
		,MatchId				
		,ResourceId			
		,OldHomeValue		
		,OldAwayValue		
		,NewHomeValue		
		,NewAwayValue
		,OldResultStatusID
		,NewResultStatusID
		,OldSettlementStatusID
		,NewSettlementStatusID
		,OldModifiedBy		
		,NewModfiedBy		
		,OldLastModifiedDate	
		,NewLastModifiedDate	
		,UpdateTime			
	)
	SELECT 'ResultDetail'
			, i.MatchId
			, i.ResourceId
			, d.HomeValue		AS OldHomeValue
			, d.AwayValue		AS OldAwayValue
			, i.HomeValue		AS NewHomeValue
			, i.AwayValue		AS NewAwayValue
			, d.ResultStatusID  AS OldResultStatusID
			, i.ResultStatusID  AS NewResultStatusID
			, d.SettlementStatusID AS OldSettlementStatusID
			, i.SettlementStatusID AS NewSettlementStatusID
			, d.LastModifyBy	AS OldModifiedBy
			, i.LastModifyBy	AS NewModfiedBy
			, d.LastModifyDate OldLastModifiedDate
			, i.LastModifyDate NewLastModifiedDate
			, GETDATE() AS UpdateTime
	FROM INSERTED i
		INNER JOIN  DELETED d ON i.MatchId = d.MatchId
			AND i.ResourceId = d.ResourceId

GO

ALTER TRIGGER [dbo].[ResultDetailOS_Upd] ON [dbo].[ResultDetailOS] 
AFTER UPDATE
AS
	SET NOCOUNT ON

		INSERT INTO dbo.SettlementResultDetailHistory (	
		TableName			
		,MatchId				
		,ResourceId			
		,OldHomeValue		
		,OldAwayValue		
		,NewHomeValue		
		,NewAwayValue
		,OldResultStatusID
		,NewResultStatusID
		,OldSettlementStatusID
		,NewSettlementStatusID
		,OldModifiedBy		
		,NewModfiedBy		
		,OldLastModifiedDate	
		,NewLastModifiedDate	
		,UpdateTime			
	)
	SELECT 'ResultDetailOS'
			, i.MatchId
			, i.ResourceId
			, d.HomeValue		AS OldHomeValue
			, d.AwayValue		AS OldAwayValue
			, i.HomeValue		AS NewHomeValue
			, i.AwayValue		AS NewAwayValue
			, d.ResultStatusID  AS OldResultStatusID
			, i.ResultStatusID  AS NewResultStatusID
			, d.SettlementStatusID AS OldSettlementStatusID
			, i.SettlementStatusID AS NewSettlementStatusID
			, d.LastModifyBy	AS OldModifiedBy
			, i.LastModifyBy	AS NewModfiedBy
			, d.LastModifyDate OldLastModifiedDate
			, i.LastModifyDate NewLastModifiedDate
			, GETDATE() AS UpdateTime
	FROM INSERTED i
		INNER JOIN  DELETED d ON i.MatchId = d.MatchId
			AND i.ResourceId = d.ResourceId

GO


ALTER TRIGGER [dbo].[ResultDetailES_Upd] ON [dbo].[ResultDetailES] 
AFTER UPDATE
AS
	SET NOCOUNT ON

		INSERT INTO dbo.SettlementResultDetailHistory (	
		TableName			
		,MatchId				
		,ResourceId			
		,OldHomeValue		
		,OldAwayValue		
		,NewHomeValue		
		,NewAwayValue
		,OldResultStatusID
		,NewResultStatusID
		,OldSettlementStatusID
		,NewSettlementStatusID
		,OldModifiedBy		
		,NewModfiedBy		
		,OldLastModifiedDate	
		,NewLastModifiedDate	
		,UpdateTime			
	)
	SELECT 'ResultDetailES'
			, i.MatchId
			, i.ResourceId
			, d.HomeValue		AS OldHomeValue
			, d.AwayValue		AS OldAwayValue
			, i.HomeValue		AS NewHomeValue
			, i.AwayValue		AS NewAwayValue
			, d.ResultStatusID  AS OldResultStatusID
			, i.ResultStatusID  AS NewResultStatusID
			, d.SettlementStatusID AS OldSettlementStatusID
			, i.SettlementStatusID AS NewSettlementStatusID
			, d.LastModifyBy	AS OldModifiedBy
			, i.LastModifyBy	AS NewModfiedBy
			, d.LastModifyDate OldLastModifiedDate
			, i.LastModifyDate NewLastModifiedDate
			, GETDATE() AS UpdateTime
	FROM INSERTED i
		INNER JOIN  DELETED d ON i.MatchId = d.MatchId
			AND i.ResourceId = d.ResourceId

GO