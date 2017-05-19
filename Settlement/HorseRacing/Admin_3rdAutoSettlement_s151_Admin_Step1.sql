ALTER PROCEDURE [dbo].[Admin_3rdAutoSettlement_s151_Admin_Step1]
	@LeagueID int,
	@raceNumber int,
	@programdate smalldatetime,
	@Action varchar(10) = 'CAL' ,
	@Result int = 0 output
AS
BEGIN
	/* @Action input
	CAL: (default) settle
	REFUND: race abandon
	DB: DBPRO/BODB02

	Revisions:
	 - 20100916@Jamie: Update changeTime for Outright table 
	 - 20110617@Victor: Splitting POC SP , Mark That Part for New Create SP On TranDB works 
	 - 20120717@Cooper: add try catch 
	 - 20130524@Elodie: Write settlement log for horse racing
	*/
 Declare @LogData as nvarchar(200)

BEGIN TRY
 -- vivi@2010-4-27
 -- horse racing have two machines calling settlement sp, random delay millisecond to avoid command coming on same time
 DECLARE @Delay char(12)
 DECLARE @Delay1 int, @Delay2 int
 SELECT @Delay1 = RAND()*200000
 SELECT @Delay2 = RAND()*200000
 SELECT @Delay = CONVERT(varchar,DATEADD(ms,(@Delay1+@Delay2)/200,'1970-01-01'),14)
 WAITFOR DELAY @Delay

 -- check settlement or not
 DECLARE @Calculate bit
 SET @Calculate = 0
 SET @Result =0

 SELECT @Calculate = Calculate 
 FROM dbo.RaceInfo
 WHERE LeagueID = @LeagueID 
  AND RaceNumber = @raceNumber 
  AND ProgramDate = @programdate

 IF @Calculate = 1 and @Action <> 'REFUND'
 BEGIN
  -- Code to Log Message put here  
  SET @LogData = 'Calculate Result (' + @Action + ') for Horse League ID:' + CAST(@LeagueID as nvarchar(20)) + ' race:' + CAST(@raceNumber as nvarchar(20)) + ' Fail b/c this race number already settlement - '+ right(@Delay,5)
  EXEC dbo.WriteLog_UserLog 151, @LogData
  
  set @Result = 1
  RETURN
 END
 ELSE
 BEGIN
  -- mark to settlement
  UPDATE dbo.RaceInfo with (UPDLOCK, ROWLOCK)
  SET Calculate = 1
  WHERE LeagueID = @LeagueID
   AND RaceNumber = @raceNumber
   AND ProgramDate = @programdate
 END
    set @Result = 0
    
    -- WRITE LOG
	DECLARE @Remark varchar(500)
	BEGIN TRY
		SET @Remark = 'Action:' + @Action + ' Result:' + CAST(@Result as nvarchar(5))			
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_SettleOutright 
			@UserID = 151, 
			@MatchID = @raceNumber, 
			@ActionID = 131, 
			@LeagueID = @LeagueID, 
			@EventDate = @programdate,
			@Remark = @Remark
			
	END TRY
	BEGIN CATCH		
		SET @Remark = 'Action:' + @Action + ' Result:' + CAST(@Result as nvarchar(5)) + ' Race:' + CAST(@raceNumber as nvarchar(20)) + ' ProgramDate:' + CAST(@programdate as nvarchar(20))
					+ ' LeagueID:' + CAST(@LeagueID as nvarchar(20))
		EXEC dbo.WriteLog_UserLog 151, @Remark
	END CATCH	
	
END TRY
BEGIN CATCH
   SET @LogData = 'Admin_3rdAutoSettlement_s151_Admin_Step1_ErrorNumber:' + cast ( ERROR_NUMBER() as varchar(10) )
   +'.ErrorSeverity:' + cast ( ERROR_SEVERITY() as varchar(10))
   +'.ErrorState:' + cast ( ERROR_STATE() as varchar(10) )
   +'.ErrorProcedure:' + isnull(ERROR_PROCEDURE(),'')
   +'.ErrorLine:' + cast ( ERROR_LINE() as varchar(10) )
   +'.ErrorMessage:' +ERROR_MESSAGE()  
   EXEC dbo.WriteLog_UserLog 151, @LogData
END CATCH
 
END

GO
GRANT EXECUTE ON [dbo].[Admin_3rdAutoSettlement_s151_Admin_Step1] TO [Dot_3rdparty]
GO
GRANT EXECUTE ON [dbo].[Admin_3rdAutoSettlement_s151_Admin_Step1] TO [Dot_Admin]
GO
GRANT VIEW DEFINITION ON [dbo].[Admin_3rdAutoSettlement_s151_Admin_Step1] TO [vnteam]