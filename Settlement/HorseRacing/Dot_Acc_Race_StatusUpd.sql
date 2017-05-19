ALTER PROCEDURE [dbo].[Dot_Acc_Race_StatusUpd]
	@programID varchar(10),
	@eventdate smalldatetime,
	@raceNumber int,
	@userid int = 151 ----doing update status userid
AS
/*
	Create:
	Task:
	DB: DB02.BODB02
	
	Revisions: 
		- 20100720@Henry: Change SP Logfile to WriteLog_UserLog
		- 20130524@Elodie: Write settlement log for horse racing
*/
BEGIN
	
	SET NOCOUNT ON;
	
	-- HR event status:
	-- closed: new created or had HR result(only closed status can do settle)
	-- running: running event
	-- completed: settled event
	
	-- uppdate status and reset all result columns
	UPDATE dbo.outright with (rowlock, updlock)
	SET 
		oddsstatus = 'closed',
		odds=0, PlaceOdds=0, 
		Placing=0, IsFavor=0, IsSCR=0 
	WHERE ProgramID = @programID 
		AND eventdate = @eventdate 
		AND groupmatch = CAST(@raceNumber as varchar(20))	
	
	-- WRITE LOG
	DECLARE @Remark VARCHAR(500)
	BEGIN TRY
		SELECT @Remark = 'ProgramID=' + @programID
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_SettleOutright 
			@UserID = @userid, 
			@MatchID = @raceNumber, 
			@ActionID = 129, 
			@LeagueID = 0, 
			@EventDate = @eventdate,
			@Remark = @Remark
			
	END TRY
	BEGIN CATCH		
		SET @Remark = 'Update event oddsstatus to closed and reset result column to zero, for Horse ID:' + @ProgramID 
					+ ' eventdate:' + CAST(@eventdate as nvarchar(20))
					+ ' race:' + CAST(@raceNumber as nvarchar(20))
		EXEC WriteLog_UserLog @UserID = @userid,
							  @Doing = @Remark					
	END CATCH		
END
GO
GRANT VIEW DEFINITION ON [dbo].[Dot_Acc_Race_StatusUpd] TO [vnteam]