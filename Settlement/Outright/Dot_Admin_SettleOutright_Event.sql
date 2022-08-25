/*<info serverAlias="DBPRO-bodb02" executers="Dot_Admin,bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Dot_Admin_SettleOutright_Event]
    @matchid int,
    @status nvarchar(10),
    @isDeadheat bit=0,
    @ErrCode int = 0 OUTPUT,
    @ErrMsg nvarchar(200) = '' OUTPUT,
    @eventdate date = null,
    @adminid int = 5838421
AS
/*
	Created:
	Task : sp for outright settlement

	DB: DBPRO/BODB02
	Original:

	Revisions:
		- 20120307@MartinChen(DBProduct): add isDeadHeat to save db
		- 20120808@Sophia: . Add table TempVariableNumber to check if this match is being calculated then not allow to settle until the on-going process is completed
						   . Add @ErrCode, @ErrMsg to raise error
		- 20130103@Elodie:  Write log for adding a match into TempVariableNumber table or deleting a match from TempVariableNumber table
		- 20130121@Elodie:  Change link server DBTRANS to DBTXN
							Write more log on UserLog table in case of DBLOG server failure
		- 20130712@Dan: add log to outright_log to notify Apollo
		- 20130719@Ava(db02):Add @eventdate when user re-settle
		- 20140219@Elodie: Write settlement log for outright
		- 20150625@Martin: request by Cooper, replace insert statement by sp NAP_UpdateTempVariableNumber
		- 20201211@Louisa: Show Calculate Outright Log, add param @AdminId [Redmine:#146738]
		- 20201216@JackChang(DB02): select @LogFile table

	Param's Explanation:
		- @deadheat = fraction of deadheat to divide (1,2,3  etc)
*/
SET NOCOUNT ON

---- check and not allow attempt to settlement same game while it's still not finish
IF EXISTS (SELECT 1 FROM DBTXN.bodb02.dbo.TempVariableNumber WHERE KeyID = 2 AND KeyValue = @matchid)
BEGIN
    SELECT  @ErrCode = 101,
            @ErrMsg = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'
    RETURN
END

DECLARE @Remark VARCHAR(500), @ActionID INT, @LeagueID  INT
DECLARE @LogData NVARCHAR(4000)
DECLARE @LogFile TABLE (LogKey nvarchar(100), LogData nvarchar(4000), UserID int)

SELECT @ActionID = CASE @status
    WHEN 'Refund' THEN 138
    WHEN 'Won' THEN 136
    WHEN 'Lose' THEN 136
END

SELECT  @LeagueID   = LeagueID
FROM    Outright WITH (NOLOCK)
WHERE   ORID = @MatchID

DECLARE @SPErrCode INT
SET @SPErrCode=0
EXEC DBTXN.bodb02.dbo.NAP_UpdateTempVariableNumber @matchid,1,2,@SPErrCode OUTPUT
IF (@SPErrCode = 0)
    BEGIN TRY
        EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking
            @UserID = @adminid, --dbaAdmin
            @Matchid = @matchid,
            @KeyID = 2,
            @ActionID = @ActionID,
            @Remark = 'ADD SUCCESS'
    END TRY
    BEGIN CATCH
        SELECT @LogData = 'ADD SUCCESS SPName = Dot_Admin_SettleOutright_Event MatchID=' + @matchid + ' KeyID=2 ErrMsg='+ left(error_message(), 70)

        INSERT INTO @LogFile
        Select '', @LogData, @adminid --dbaAdmin
    END CATCH
ELSE
BEGIN
    SELECT @ErrCode = 102, @ErrMsg = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'
    RETURN
END
---------

if(@eventdate is null)
    set @eventdate = convert(char(10),getdate(),111)
else
    set @eventdate = convert(char(10),@eventdate,111)

if (@status='won')
begin
    update outright with (updlock,rowlock)
    set oddsstatus = 'Completed',
        eventdate = @eventdate,
        [status] = 'WON',
        changetime = getdate(),
        isDeadheat = @isDeadheat
    where orid = @matchid
end
else if (@status='lose')
begin
    Update outright with (updlock,rowlock)
    set oddsstatus = 'Completed',
        eventdate = @eventdate,
        [status] = 'LOSE',
        changetime = getdate(),
        isDeadheat = @isDeadheat
    where orid = @matchid
end
ELSE IF @status = 'Refund'
BEGIN
    UPDATE dbo.outright with (updlock,rowlock)
    SET oddsstatus = 'Completed',
        eventdate = @eventdate,
        [status] = 'Refund',
        changetime = getdate(),
        isDeadheat = @isDeadheat
    WHERE orid = @matchid
END
ELSE
BEGIN
    UPDATE dbo.outright with (updlock,rowlock)
    SET changetime = getdate(),
        eventdate = @eventdate,
        isDeadheat = @isDeadheat
    WHERE orid = @matchid
END

----
--add log to outright_log to notify for Apollo
EXEC DBTXN.bodb02.dbo.[Acc_Set_ConfirmedActionOutright]
    @matchid = @matchid,
    @actionid = 30,
    @status = @status,
    @deadheat = @isDeadheat
---

SET @SPErrCode=0
EXEC DBTXN.bodb02.dbo.NAP_UpdateTempVariableNumber @matchid,0,2,@SPErrCode OUTPUT
IF (@SPErrCode = 0)
BEGIN
    BEGIN TRY
        EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking
            @UserID = @adminid, --dbaAdmin
            @Matchid = @matchid,
            @KeyID = 2,
            @ActionID = @ActionID,
            @Remark = 'DEL SUCCESS'
    END TRY
    BEGIN CATCH
        SELECT @LogData = 'DEL SUCCESS SPName = Dot_Admin_SettleOutright_Event MatchID=' + @matchid + ' KeyID=2 ErrMsg='+ left(error_message(), 70)

        INSERT INTO @LogFile
        Select '', @LogData, @adminid --dbaAdmin
    END CATCH
END
ELSE
BEGIN
    BEGIN TRY
        EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking
            @UserID = @adminid, --dbaAdmin
            @Matchid = @matchid,
            @KeyID = 2,
            @ActionID = @ActionID,
            @Remark = 'DEL FAILED'
    END TRY
    BEGIN CATCH
        SELECT @LogData = 'DEL FAILED SPName = Dot_Admin_SettleOutright_Event MatchID=' + @matchid + ' KeyID=2 ErrMsg='+ left(error_message(), 70)

        INSERT INTO @LogFile
        Select '', @LogData, @adminid --dbaAdmin
    END CATCH
END

-- WRITE LOG
BEGIN TRY
    SELECT @Remark = CAST(@isDeadheat AS VARCHAR(5))
    EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_SettleOutright
        @UserID = @adminid,
        @MatchID = @matchid,
        @ActionID = @ActionID,
        @LeagueID = @LeagueID,
        @EventDate = @EventDate,
        @Result = @status,
        @Remark = @Remark

END TRY
BEGIN CATCH
    SELECT @Remark = CAST(@isDeadheat AS VARCHAR(5)) + ' ErrMsg='+ left(error_message(), 400)
    EXEC DBTXN.bodb_CustomerLog.dbo.WriteLog_UserLog_SettleOutright
        @UserID = @adminid,
        @MatchID = @matchid,
        @ActionID = @ActionID,
        @LeagueID = @LeagueID,
        @EventDate = @EventDate,
        @Result = @status,
        @Remark = @Remark
END CATCH

SELECT ISNULL(LogKey, '') LogKey, ISNULL(LogData, '') LogData, ISNULL(UserID, @adminid) AdminID from @LogFile

GO