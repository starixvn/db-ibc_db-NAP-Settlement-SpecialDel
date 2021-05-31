ALTER TRIGGER [dbo].[Tgg_TempVariableNumber_Tracking] ON [dbo].[TempVariableNumber] 
AFTER INSERT, DELETE
AS
/*
	Created by:20190306@Vicky
	Task: get code from PROD
	DB: DBTXN/bodb02 

	Revision
		- 20190103@Vicky: Incorporate BetBuilder: add column KeyValue2 [Redmine:#106903]
 */
BEGIN
    SET NOCOUNT ON

    IF EXISTS (SELECT TOP 1 1 FROM DELETED)
    BEGIN
	   --DELETE
	   INSERT INTO dbo.TempVariableNumberHistory(KeyId, KeyValue, KeyValue2, Action, CreatedDateTime)
	   SELECT DELETED.KeyId, DELETED.KeyValue, DELETED.KeyValue2, 'D', GETDATE()
	   FROM DELETED
    END
    ELSE IF EXISTS (SELECT TOP 1 1 FROM INSERTED)
		  AND NOT EXISTS (SELECT TOP 1 1 FROM DELETED)
    BEGIN
	   --INSERT
	   INSERT INTO dbo.TempVariableNumberHistory(KeyId, KeyValue, KeyValue2, Action, CreatedDateTime)
	   SELECT INSERTED.KeyId, INSERTED.KeyValue, INSERTED.KeyValue2, 'I', GETDATE()
	   FROM INSERTED
    END

END
GO
