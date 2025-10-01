/*<info serverAlias="DBTP-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: 20250930@Hughie
	Task: Apply SOP Outright Phase 2  [Redmine:#233004]
	DB: DBTP/bodb02

	Revisions:
        - 20250930@Hughie: Create [Redmine:#233004]
*/

USE bodb02
GO

ALTER TRIGGER [dbo].[ResultDetailOutright_Upd] ON [dbo].[ResultDetailOutright] 
AFTER UPDATE
AS
	SET NOCOUNT ON

	INSERT INTO dbo.SettlementResultDetailOutrightHistory (	
		TableName			
		,Orid				
		,OldResult		
		,NewResult	
		,OldIsdeadHeat
		,NewIsdeadHeat
		,OldModifiedBy		
		,NewModfiedBy		
		,OldModifiedDate	
		,NewModifiedDate	
		,UpdateTime	
		,OldSumWon
		,NewSumWon
		,OldSettledBy 
		,NewSettledBy 
		,OldResultStatusID 
		,NewResultStatusID 
		,OldSettlementStatusID
		,NewSettlementStatusID 		
	)
	SELECT 'ResultDetailOutright'
			, i.Orid
			, d.Result AS OldResult
			, i.Result AS NewResult
			, d.IsDeadHeat AS OldIsdeadHeat
			, i.IsDeadHeat AS NewIsdeadHeat
			, d.ModifiedBy AS OldModifiedBy
			, i.ModifiedBy AS NewModfiedBy
			, d.ModifiedDate OldModifiedDate
			, i.ModifiedDate NewModifiedDate
			, GETDATE() AS UpdateTime
			, d.SumWon AS OldSumWon
			, i.SumWon AS NewSumWon
			, d.SettledBy  AS OldSettledBy 
			, i.SettledBy  AS NewSettledBy 
			, d.ResultStatusID   AS OldResultStatusID 
			, i.ResultStatusID   AS NewResultStatusID 
			, d.SettlementStatusID  AS OldSettlementStatusID
			, i.SettlementStatusID  AS NewSettlementStatusID
	FROM INSERTED i
		INNER JOIN  DELETED d ON i.Orid = d.Orid

GO