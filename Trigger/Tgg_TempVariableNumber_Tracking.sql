/*<info serverAlias="DBTXN-bodb02" executers="" isFunction="0"></info>*/
ALTER TRIGGER [dbo].[Tgg_TempVariableNumber_Tracking] ON [dbo].[TempVariableNumber] 
AFTER INSERT, DELETE
AS
/*
	Created by:20190306@Vicky
	Task: get code from PROD
	DB: DBTXN/bodb02 

	Revision
		- 20190103@Vicky: Incorporate BetBuilder: add column KeyValue2 [Redmine:#106903]
		- 20210531@July: Add column SPName into table TempVariableNumberHistory [Redmine:#155678]
 */
BEGIN
    SET NOCOUNT ON

    IF EXISTS (SELECT TOP 1 1 FROM DELETED)
    BEGIN
	   --DELETE
	   INSERT INTO dbo.TempVariableNumberHistory(KeyId, KeyValue, KeyValue2, Action, CreatedDateTime, SPName)
	   SELECT DELETED.KeyId, DELETED.KeyValue, DELETED.KeyValue2, 'D', GETDATE(), DELETED.SPName
	   FROM DELETED
    END
    ELSE IF EXISTS (SELECT TOP 1 1 FROM INSERTED)
		  AND NOT EXISTS (SELECT TOP 1 1 FROM DELETED)
    BEGIN
	   --INSERT
	   INSERT INTO dbo.TempVariableNumberHistory(KeyId, KeyValue, KeyValue2, Action, CreatedDateTime, SPName)
	   SELECT INSERTED.KeyId, INSERTED.KeyValue, INSERTED.KeyValue2, 'I', GETDATE(), INSERTED.SPName
	   FROM INSERTED
    END

END
GO
