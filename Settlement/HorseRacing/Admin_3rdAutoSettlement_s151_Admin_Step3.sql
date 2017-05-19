ALTER PROCEDURE [dbo].[Admin_3rdAutoSettlement_s151_Admin_Step3]
	@LeagueID int,
	@raceNumber int,
	@programdate smalldatetime,
	@Action varchar(10) = 'CAL'
AS
BEGIN
	/* @Action input
	CAL: (default) settle
	REFUND: race abandon

	DB: DBPRO/bodb02
	Revisions:
		- 20100916@Jamie: Update changeTime for Outright table 
		- 20110617@Victor: Splitting POC SP , Mark That Part for New Create SP On TranDB works
		- 20120628@Victor: add Log for Harness not settle problem
		- 20120717@Cooper: add try catch 
		- 20130524@Elodie: Write settlement log for horse racing
	*/
BEGIN TRY
	Declare @LogData as nvarchar(200) , @LogDataBegin as nvarchar(200)
	SET @LogDataBegin = 'Begin Calculate Result (' + @Action + ')[Admin_3rdAutoSettlement_s151_Admin_Step3] for Horse League ID:' + CAST(@LeagueID as nvarchar(20)) + ' race:' + CAST(@raceNumber as nvarchar(20)) 
	EXEC dbo.WriteLog_UserLog 151, @LogDataBegin

	-- vivi@2010-4-27
	-- horse racing have two machines calling settlement sp, random delay millisecond to avoid command coming on same time
	DECLARE @Delay char(12)
	DECLARE @Delay1 int, @Delay2 int
	SELECT @Delay1 = RAND()*200000
	SELECT @Delay2 = RAND()*200000
	SELECT @Delay = CONVERT(varchar,DATEADD(ms,(@Delay1+@Delay2)/200,'1970-01-01'),14)
	WAITFOR DELAY @Delay


	UPDATE dbo.Outright with (ROWLOCK, UPDLOCK)
	SET oddsstatus = 'completed',
		[status] = CASE @Action WHEN 'CAL' THEN [status] ELSE 'refund' END,
		changeTime = getdate()
	WHERE
		LeagueID = @LeagueID
		AND groupmatch = CAST(@raceNumber as varchar(20))
		AND ProgramDate = @programdate
		AND CASE
		WHEN @Action = 'CAL' AND oddsstatus = 'closed' THEN 1
		WHEN @Action = 'REFUND' AND oddsstatus IN ('running','suspend','closed') THEN 1 
		ELSE 0 END = 1

	-- Code to Log Message put here
	SET @LogData = 'Calculate Result (' + @Action + ')[Admin_3rdAutoSettlement_s151_Admin_Step3] for Horse League ID:' + CAST(@LeagueID as nvarchar(20)) + ' race:' + CAST(@raceNumber as nvarchar(20)) + ' - ' + right(@Delay,5)
	EXEC dbo.WriteLog_UserLog 151, @LogData
	
	-- WRITE LOG
	DECLARE @Remark varchar(500)
	BEGIN TRY
		SET @Remark = 'Action:' + @Action 
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_SettleOutright 
			@UserID = 151, 
			@MatchID = @raceNumber, 
			@ActionID = 133, 
			@LeagueID = @LeagueID, 
			@EventDate = @programdate,
			@Remark = @Remark
			
	END TRY
	BEGIN CATCH		
		SET @Remark = 'Action:' + @Action + ' Race:' + CAST(@raceNumber as nvarchar(20)) + ' ProgramDate:' + CAST(@programdate as nvarchar(20))
					+ ' LeagueID:' + CAST(@LeagueID as nvarchar(20))
		EXEC dbo.WriteLog_UserLog 151, @Remark
	END CATCH
	
END TRY
BEGIN CATCH 
			SET @LogData = 'Admin_3rdAutoSettlement_s151_Admin_Step3_ErrorNumber:' + cast ( ERROR_NUMBER() as varchar(10) )
			+'.ErrorSeverity:' + cast ( ERROR_SEVERITY() as varchar(10))
			+'.ErrorState:' + cast ( ERROR_STATE() as varchar(10) )
			+'.ErrorProcedure:' + isnull(ERROR_PROCEDURE(),'')
			+'.ErrorLine:' + cast ( ERROR_LINE() as varchar(10) )
			+'.ErrorMessage:' +ERROR_MESSAGE() 
			EXEC dbo.WriteLog_UserLog 151, @LogData
END CATCH
END


GO
GRANT EXECUTE ON [dbo].[Admin_3rdAutoSettlement_s151_Admin_Step3] TO [Dot_3rdparty]
GO
GRANT EXECUTE ON [dbo].[Admin_3rdAutoSettlement_s151_Admin_Step3] TO [Dot_Admin]
GO
GRANT VIEW DEFINITION ON [dbo].[Admin_3rdAutoSettlement_s151_Admin_Step3] TO [vnteam]