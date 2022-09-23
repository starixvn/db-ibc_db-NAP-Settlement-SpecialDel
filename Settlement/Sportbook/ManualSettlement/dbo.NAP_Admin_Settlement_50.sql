/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_50]
	@MatchId			INT
	,@Action			VARCHAR(20)
	,@ServiceType		TINYINT			= 1
	,@ServiceCommand	NVARCHAR(MAX)
	,@ServiceStatus		TINYINT	 
	,@Reason			VARCHAR(300)	= ''
	,@StartTime			DATETIME		= NULL
	,@EndTime			DATETIME		= NULL
	,@IsAuto			BIT				= 0
AS
/*  
	Creator: Kathy
    Date: 20160106
    Task: Integrate Cricket into Settlement [Redmine:#49727]
    DB: DBTXN/BODB02

    Revisions:   
		- 20171115@Kathy: Change datatype of @ServiceCommand to NVARCHAR(MAX) [Redmine:#86735]
		- 20200623@Max: [TVS] Auto Void for remaining sports - [Redmine: #135574]
		- 20210729@Louisa: Auto Settle Cricket [Redmine:#154586]
		- 20220922@Louisa: Scaleout DBTrans [Redmine:#175251]
        
    Param's Explanation:
		@ServiceStatus: - 0: Waiting for calculating NetPosition
						- 1: Finished
						- 2: Failed
        
*/

BEGIN
	
	SET NOCOUNT ON
	
	DECLARE @keyId		INT
			,@AdminId	INT
			,@IP		VARCHAR(15)
			,@execTime	DATETIME
			,@tryCount	TINYINT = 0
			,@IsSettle	BIT 
			,@ErrCode	INT = 0
			,@ErrMsg	NVARCHAR(200) = ''
	
	IF @Action IN ('CAL', 'CAL-FT', 'REFUND-FT', 'REFUND') -- For Caculate & Refund
		SET @IsSettle = 1
	ELSE IF @action = 'UNDO'
		SET @IsSettle = 0
	ELSE
		RETURN

	SELECT	@keyId = keyid
			,@AdminId = AdminId
			,@IP = IP
	FROM	dbo.Single_Calculate_Queue WITH(NOLOCK)
	WHERE	matchid = @matchid
			AND IsCalculating = 1
			AND Action = @Action
	
	IF @@ROWCOUNT = 0
		RETURN
			
	IF (@ServiceStatus = 1 AND @IsSettle = 1) OR (@ServiceStatus = 0 AND @IsSettle = 0)
	BEGIN
		WHILE (@tryCount < 3)
		BEGIN
			BEGIN TRY
				SET @execTime = GETDATE()
				
				EXEC sys.sp_executesql @ServiceCommand
					,N'@ErrMsg VARCHAR(400) OUTPUT, @ErrCode int OUTPUT'
					,@ErrMsg	= @ErrMsg	OUTPUT
					,@ErrCode	= @ErrCode	OUTPUT
			END TRY
			BEGIN CATCH
				SET @ErrMsg = ERROR_MESSAGE()
				SET @ErrCode = ERROR_NUMBER()
			END CATCH	
			
			IF @ErrCode = 0 OR @ErrCode = 1000006 OR @ErrMsg = ''
			BEGIN
				UPDATE	Single_Calculate_Queue WITH (ROWLOCK, UPDLOCK)
					SET IsCalculating = CASE WHEN @IsSettle = 1 THEN 2 ELSE IsCalculating END
						,execTime = @execTime
						,duration = DATEDIFF(ms, @execTime, GETDATE())
				WHERE 	keyid = @keyId

				--Insert TVS AutoVoid Queue
				INSERT INTO dbo.TicketVoiding_AutoVoidRequest_Queue (RequestId,MatchId,sporttype,StatusId,UserId,Ip,starttime,action, BroadcastSessionId)
				SELECT	0,MatchId,SportType,0 StatusID,10278938 AS Userid,'125.227.140.97',GETDATE() AS starttime
						, Action
						,q.BroadcastSessionId
				FROM Single_Calculate_Queue q WITH (NOLOCK)
				WHERE keyid = @keyId 
					AND q.[Action] IN ('CAL-HT','CAL-FT','CAL','CAL-EARLY','CAL_EAR')
						
				IF @ErrCode = 1000006			
					INSERT INTO Settled_Message (
						AdminId
						,MatchId
						,IP
						,Starttime
						,Action
						,Message
						,Warning
						)
					SELECT @AdminId
						,@MatchId
						,@IP
						,GETDATE()
						,@Action
						,@ErrMsg
						,NULL
													
				BREAK
			END		
			ELSE
			BEGIN
				SET @tryCount = @tryCount + 1
				
				UPDATE Single_Calculate_Queue WITH (ROWLOCK, UPDLOCK)
					SET IsCalculating = 3 --CASE WHEN @IsSettle = 1 THEN 3 ELSE IsCalculating END
						,execTime = @execTime
						,duration = DATEDIFF(ms, @execTime, GETDATE())					
						,TryCount = @tryCount
				WHERE 	keyid = @keyId
				
				IF @tryCount = 3
				BEGIN
					INSERT INTO Settled_Message (AdminId, MatchId, IP, Starttime, Action, Message, Warning)
					SELECT @AdminId, @MatchId, @IP, GETDATE(), @Action 
						,CASE 
							WHEN @ErrCode = 1000000 THEN NULL
							ELSE @ErrMsg
							END
						,CASE 
							WHEN @ErrCode = 1000000 THEN @ErrMsg
							ELSE NULL
							END
				END
			END
		END
		
		IF @IsAuto = 1 AND ISNULL(@ErrCode,1000006) <> 1000006
		BEGIN
			EXEC dbo.NAP_Set_SB_ErrorHandling @Action	  = @Action
											, @MatchId	  = @MatchId
											, @sqlCommand = @ServiceCommand	
											, @ErrMsg	  = @ErrMsg
											, @AdminId	  = 0			---Service Auto
											, @IP		  = ''
											, @IsService  = 1
		END		
	END
	
	IF @ServiceStatus = 2 -- For Calculating
	BEGIN
		UPDATE	Single_Calculate_Queue WITH (ROWLOCK, UPDLOCK)
					SET IsCalculating = 3											
				WHERE 	keyid = @keyId
	END
	
	IF (@tryCount < 3 AND (@IsSettle = 0 OR (@IsSettle = 1 AND @ServiceStatus = 2)))
	BEGIN
		SET @StartTime = GETDATE()
		
		EXEC dbo.NAP_Admin_SettlementService_Ins
		@MatchId			= @MatchId
		,@Action			= @Action
		,@ServiceType		= @ServiceType
		,@ServiceStatus		= @ServiceStatus 
		,@AdminId			= @AdminId
		,@StartTime			= @StartTime
		,@EndTime			= @EndTime
		,@Reason			= @Reason
	END
END
GO