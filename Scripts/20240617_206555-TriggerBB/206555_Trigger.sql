/*<info serverAlias="DBTP-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/*
	Created by: 20240617@Aries
	Task: Trigger to capture data for Betbuider  [Redmine:#206555]
	DB: DBTP/bodb02
*/
USE  bodb02
GO

CREATE TRIGGER [dbo].[SMP_Market_History_Ins] ON [dbo].[SMP_Market] 
AFTER INSERT
AS
	SET NOCOUNT ON
	INSERT INTO dbo.SMP_Market_History (	
		[MatchId] ,
		[MarketId],
		[VendorId] ,
		[OldPrice] ,
		[NewPrice] ,
		[OldTradeStatus] ,
		[NewTradeStatus] ,
		[OldResult] ,
		[NewResult] ,
		[OldResultStatusId] ,
		[NewResultStatusId] ,
		[OldSelectionCounts] ,
		[NewSelectionCounts] ,
		[OldCreateTime] ,
		[NewCreateTime] ,
		[OldUpdateTime] ,
		[NewUpdateTime] ,
		[LogDate]
	)
	SELECT   i.[MatchId],
			 i.[MarketId],
			 i.[VendorId] ,
			 NULL	AS [OldPrice],
			 i.Price AS [NewPrice],
			 NULL AS [OldTradeStatus],
			 i.TradeStatus AS [NewTradeStatus],
			 NULL AS [OldResult],
			 i.Result AS [NewResult],
			 NULL AS [OldResultStatusId],
			 i.ResultStatusId AS [NewResultStatusId],
			 NULL AS [OldSelectionCounts],
			 i.SelectionCounts AS [NewSelectionCounts],
			 NULL AS [OldCreateTime] ,
			 i.CreateTime AS [NewCreateTime] ,
			 NULL AS [OldUpdateTime] ,
			 i.UpdateTime AS [NewUpdateTime] ,
			 GETDATE() AS [LogDate]
	FROM INSERTED i
GO

CREATE TRIGGER [dbo].[SMP_Market_History_Upd] ON [dbo].[SMP_Market] 
AFTER UPDATE
AS
	SET NOCOUNT ON
	INSERT INTO dbo.SMP_Market_History (	
		[MatchId] ,
		[MarketId],
		[VendorId] ,
		[OldPrice] ,
		[NewPrice] ,
		[OldTradeStatus] ,
		[NewTradeStatus] ,
		[OldResult] ,
		[NewResult] ,
		[OldResultStatusId] ,
		[NewResultStatusId] ,
		[OldSelectionCounts] ,
		[NewSelectionCounts] ,
		[OldCreateTime] ,
		[NewCreateTime] ,
		[OldUpdateTime] ,
		[NewUpdateTime] ,
		[LogDate]
	)
	SELECT   i.[MatchId],
			 i.[MarketId],
			 i.[VendorId] ,
			 d.Price AS [OldPrice],
			 i.Price AS [NewPrice],
			 d.TradeStatus AS [OldTradeStatus],
			 i.TradeStatus AS [NewTradeStatus],
			 d.Result AS [OldResult],
			 i.Result AS [NewResult],
			 d.ResultStatusId AS [OldResultStatusId],
			 i.ResultStatusId AS [NewResultStatusId],
			 d.SelectionCounts AS [OldSelectionCounts],
			 i.SelectionCounts AS [NewSelectionCounts],
			 d.CreateTime AS [OldCreateTime] ,
			 i.CreateTime AS [NewCreateTime] ,
			 d.UpdateTime AS [OldUpdateTime] ,
			 i.UpdateTime AS [NewUpdateTime] ,
			 GETDATE() AS [LogDate]
	FROM INSERTED i
		INNER JOIN  DELETED d ON i.MatchId = d.MatchId	 AND i.MarketId = d.MarketId AND i.VendorId = d.VendorId

GO


CREATE TRIGGER [dbo].[SMP_MarketSelection_History_Ins] ON [dbo].[SMP_MarketSelection] 
AFTER INSERT
AS
	SET NOCOUNT ON
	INSERT INTO dbo.SMP_MarketSelection_History (	
		[MarketSelectionId],
		[MatchId],
		[MarketId],
		[SelectionType],
		[OldResult],
		[NewResult],
		[OldResultStatusId],
		[NewResultStatusId],
		[LogDate]
	)
	SELECT   i.[MarketSelectionId],
			 i.[MatchId],
			 i.[MarketId],
			 i.[SelectionType],
			 NULL AS [OldResult],
			 i.Result AS [NewResult],
			 NULL AS [OldResultStatusId],
			 i.ResultStatusId AS [NewResultStatusId],
			 GETDATE() AS [LogDate]
	FROM INSERTED i

GO

CREATE TRIGGER [dbo].[SMP_MarketSelection_History_Upd] ON [dbo].[SMP_MarketSelection] 
AFTER UPDATE
AS
	SET NOCOUNT ON
	INSERT INTO dbo.SMP_MarketSelection_History (	
		[MarketSelectionId],
		[MatchId],
		[MarketId],
		[SelectionType],
		[OldResult],
		[NewResult],
		[OldResultStatusId],
		[NewResultStatusId],
		[LogDate]
	)
	SELECT   i.[MarketSelectionId],
			 i.[MatchId],
			 i.[MarketId],
			 i.[SelectionType],
			 d.Result AS [OldResult],
			 i.Result AS [NewResult],
			 d.ResultStatusId AS [OldResultStatusId],
			 i.ResultStatusId AS [NewResultStatusId],
			 GETDATE() AS [LogDate]
	FROM INSERTED i
		INNER JOIN  DELETED d ON i.MarketSelectionId = d.MarketSelectionId

GO