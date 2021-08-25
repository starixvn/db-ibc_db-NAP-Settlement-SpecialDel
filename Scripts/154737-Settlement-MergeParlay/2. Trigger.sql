/*<info serverAlias="DBTXN-bodb02" executers="" isFunction="0"></info>*/

USE [bodb02]
GO

CREATE TRIGGER [dbo].[Tgg_ParlayLocking_Tracking] ON [dbo].[ParlayLocking] 
AFTER INSERT, DELETE
AS
/*
	Created by:20210629@Kathy
	Task: trigger on ParlayLocking
	DB: DBTXN/bodb02 

 */
BEGIN
    SET NOCOUNT ON

    IF EXISTS (SELECT TOP 1 1 FROM DELETED)
    BEGIN
	   --DELETE
	   INSERT INTO dbo.ParlayLockingHistory(MatchId, RefNo, Session, SPName, CreatedDate, Action)
	   SELECT DELETED.MatchId, DELETED.RefNo, DELETED.Session, DELETED.SPName, GETDATE(), 'D'
	   FROM DELETED
    END
    ELSE IF EXISTS (SELECT TOP 1 1 FROM INSERTED)
		  AND NOT EXISTS (SELECT TOP 1 1 FROM DELETED)
    BEGIN
	   --INSERT
	   INSERT INTO dbo.ParlayLockingHistory(MatchId, RefNo, Session, SPName, CreatedDate, Action)
	   SELECT INSERTED.MatchId, INSERTED.RefNo, INSERTED.Session, INSERTED.SPName, GETDATE(), 'I'
	   FROM INSERTED
    END

END

GO

ALTER TABLE [dbo].[ParlayLocking] ENABLE TRIGGER [Tgg_ParlayLocking_Tracking]
GO


