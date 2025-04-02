/*<info serverAlias="DBTP-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: 20250324@Aries
	Task: Enhance data history when updating events and results  [Redmine:#221187]
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
		,OldModifiedBy		
		,NewModfiedBy		
		,OldLastModifiedDate	
		,NewLastModifiedDate	
		,UpdateTime	
		,OldOtherInfo
		,NewOtherInfo
		,OldResultSetting 
		,NewResultSetting 
	)
	SELECT 'ResultDetail'
			, i.MatchId
			, i.ResourceId
			, d.HomeValue AS OldHomeValue
			, d.AwayValue AS OldAwayValue
			, i.HomeValue AS NewHomeValue
			, i.AwayValue AS NewAwayValue
			, d.LastModifyBy AS OldModifiedBy
			, i.LastModifyBy AS NewModfiedBy
			, d.LastModifyDate OldLastModifiedDate
			, i.LastModifyDate NewLastModifiedDate
			, GETDATE() AS UpdateTime
			, d.OtherInfo AS OldOtherInfo
			, i.OtherInfo AS NewOtherInfo
			, d.ResultSetting  AS OldResultSetting 
			, i.ResultSetting  AS NewResultSetting 
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
		,OldModifiedBy		
		,NewModfiedBy		
		,OldLastModifiedDate	
		,NewLastModifiedDate	
		,UpdateTime	
		,OldOtherInfo
		,NewOtherInfo
		,OldResultSetting 
		,NewResultSetting 
	)
	SELECT 'ResultDetailOS'
			, i.MatchId
			, i.ResourceId
			, d.HomeValue AS OldHomeValue
			, d.AwayValue AS OldAwayValue
			, i.HomeValue AS NewHomeValue
			, i.AwayValue AS NewAwayValue
			, d.LastModifyBy AS OldModifiedBy
			, i.LastModifyBy AS NewModfiedBy
			, d.LastModifyDate OldLastModifiedDate
			, i.LastModifyDate NewLastModifiedDate
			, GETDATE() AS UpdateTime
			, d.OtherInfo AS OldOtherInfo
			, i.OtherInfo AS NewOtherInfo
			, d.ResultSetting  AS OldResultSetting 
			, i.ResultSetting  AS NewResultSetting 
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
		,OldModifiedBy		
		,NewModfiedBy		
		,OldLastModifiedDate	
		,NewLastModifiedDate	
		,UpdateTime
		,OldOtherInfo
		,NewOtherInfo
		,OldResultSetting 
		,NewResultSetting 
	)
	SELECT 'ResultDetailES'
			, i.MatchId
			, i.ResourceId
			, d.HomeValue AS OldHomeValue
			, d.AwayValue AS OldAwayValue
			, i.HomeValue AS NewHomeValue
			, i.AwayValue AS NewAwayValue
			, d.LastModifyBy AS OldModifiedBy
			, i.LastModifyBy AS NewModfiedBy
			, d.LastModifyDate OldLastModifiedDate
			, i.LastModifyDate NewLastModifiedDate
			, GETDATE() AS UpdateTime
			, d.OtherInfo AS OldOtherInfo
			, i.OtherInfo AS NewOtherInfo
			, d.ResultSetting  AS OldResultSetting 
			, i.ResultSetting  AS NewResultSetting 
	FROM INSERTED i
		INNER JOIN  DELETED d ON i.MatchId = d.MatchId
			AND i.ResourceId = d.ResourceId

GO