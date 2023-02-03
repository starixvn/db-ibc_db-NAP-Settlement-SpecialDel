/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Outright_Update]
	 @MatchID		INT
	,@Status		VARCHAR(10)     = ''
	,@Action		VARCHAR(10)		= 'CAL'	
	,@EventDate		DATETIME		= NULL
	,@IsDeadheat	BIT				= 0 
	,@AdminID		INT				= 5838421

	,@ErrCode		INT				= 0  OUTPUT
	,@ErrMsg		NVARCHAR(200)	= '' OUTPUT
AS
/*
	Created by: Jamie
	Date: 2014-08-11
	Task: Settlement Outright 
	DB: DBPRO/bodb02 
	Original: Dot_Admin_SettleOutright_Event 
	
	Revision: 
		- 20211108@Louisa: In-house Replicator: Updated Action [Redmine:#164393] 
		- 20230109@Aries: Migrate Calculate Outright Function to NAP Settlement Site [Redmine:#163971]

	Param's Explanation:
		+ @Action	= CAL | UNDO
		+ @Status	= WON | LOSE | REFUND
		+ @Deadheat = fraction of deadheat to divide (1,2,3  etc)	
*/

BEGIN
	SET NOCOUNT ON 

	DECLARE  @Remark		VARCHAR(500)
			,@ActionID		INT
			,@LeagueID		INT  = 0
	
	SET @ActionID = CASE WHEN @Action = 'CAL' AND @Status IN ('WON','LOSE') THEN 136
						 WHEN @Action = 'CAL' AND @Status IN ('REFUND') THEN 138
						 WHEN @Action = 'UNDO'	THEN 145
					 END

	SET @EventDate =  CONVERT(DATE, ISNULL(@EventDate,GETDATE()))

	SELECT @LeagueID = LeagueID
	FROM Outright WITH (NOLOCK)
	WHERE ORID = @MatchID

	IF @Action = 'CAL' AND @Status = 'WON'
	BEGIN
		UPDATE Outright WITH (UPDLOCK,ROWLOCK)
		SET	 oddsstatus = 'Completed'
			,eventdate = @EventDate
			,status = 'WON'
			,changetime = GETDATE()
			,isDeadheat = @IsDeadheat
		WHERE orid = @MatchID
	END	
	ELSE IF @Action = 'CAL' AND @Status = 'LOSE'
	BEGIN
		UPDATE Outright WITH (UPDLOCK,ROWLOCK)
		SET	 oddsstatus = 'Completed'
			,eventdate = @EventDate
			,status = 'LOSE'
			,changetime = GETDATE()
			,isDeadheat = 0
		WHERE orid = @MatchID
	END
	ELSE IF @Action = 'CAL' AND @Status = 'REFUND'
	BEGIN
		UPDATE outright WITH (UPDLOCK,ROWLOCK)
		SET  oddsstatus = 'Completed'
			,eventdate = @EventDate
			,status= 'Refund'
			,changetime = GETDATE()
			,isDeadheat = @isDeadheat
		WHERE orid = @MatchID
	END
	ELSE IF @Action = 'UNDO'
	BEGIN
		SET @Status = 'UNDO'
		UPDATE Outright WITH (UPDLOCK,ROWLOCK)
		SET	 oddsstatus = 'Running'
			,status = NULL
			,changetime = GETDATE()
			,isDeadheat = 0
		WHERE Orid = @MatchID 
	END
	ELSE 
	BEGIN
		UPDATE Outright WITH (UPDLOCK,ROWLOCK)
		SET  changetime = GETDATE()
			,eventdate = @EventDate
			,isDeadheat = @IsDeadheat
		WHERE orid = @MatchID
	END

	--add log to outright_log to notify for Apollo
	EXEC DBTXN.bodb02.dbo.[Acc_Set_ConfirmedActionOutright]
		@matchid = @Matchid,
		@actionid = 30,
		@status = @Status,
		@deadheat = @IsDeadheat

	-- WRITE LOG
	BEGIN TRY
		SELECT @Remark = CAST(@IsDeadheat AS VARCHAR(5))
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_SettleOutright
			 @UserID = @AdminID
			,@MatchID = @Matchid
			,@ActionID = @ActionID
			,@LeagueID = @LeagueID
			,@EventDate = @EventDate
			,@Result = @Status
			,@Remark = @Remark

	END TRY
	BEGIN CATCH
		SELECT @Remark ='IsDeadheat=' + CAST(@IsDeadheat AS VARCHAR(5)) + ' ErrMsg='+ LEFT(ERROR_MESSAGE(), 400)
		EXEC DBTXN.bodb_CustomerLog.dbo.WriteLog_UserLog_SettleOutright
			 @UserID = @AdminID
			,@MatchID = @Matchid
			,@ActionID = @ActionID
			,@LeagueID = @LeagueID
			,@EventDate = @EventDate
			,@Result = @Status
			,@Remark = @Remark
	END CATCH
END 
