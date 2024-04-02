/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_VoidParlaySubVSBetRadar_Upd] 
	@SearchBy				VARCHAR(100),
	@MatchId				INT = NULL,	
	@TransIds				VARCHAR(MAX) = '',
	@UserName 				NVARCHAR(50),
    @Password				NVARCHAR(50),
    @UserId					INT,
    @IP						VARCHAR(15),
    @Reason					NVARCHAR(500)	= '',
	@ReasonSC				NVARCHAR(500)	= ''
AS
/*  
	Created by: 20170607@Kent  
	Task: 
	DB: DBTXN/bodb02	    

	Revisions:  		
		- 20170607@Kent: Integrate Betradar Virtual Sports [Redmine:#77177]	
		- 20170831@Kent: VS BetRadar Change on Void Parlay Sub Bets [Redmine:#82405]
		- 20181207@Alan: Support Chinese Email [105976]	
		- 20220727@Max: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20230330@July: Write log into table TVS_UserActionLog [Redmine: #185245]
		- 20230705@July: [SD] Enhance void log to detect more information [Redmine: #190590]
		- 20240220@July: Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]

	Param's Explanation:
		- @SearchBy:		
		'MatchId': Search by @MatchId + @BetTypes
		'SubTransIds': Search by @SubTransIds
		
		- @TransIds : Main transids.
		
		- @SubTransIds : TransIds of sub parlay tickets
*/
BEGIN
	SET NOCOUNT ON	
	
	DECLARE @StartTime			DATETIME
			,@EndTime			DATETIME
			,@LogActionId		INT
			,@LogData			NVARCHAR(MAX)
			,@SB_Error			BIT

	SET @StartTime = GETDATE()
	SET @LogActionId = 90516
	SET @SB_Error = 0

	SET @LogData = CASE WHEN @SearchBy IS NULL THEN '' ELSE '@SearchBy = ''' + CONVERT(NVARCHAR(100), @SearchBy) + '''' END
					+ CASE WHEN @MatchId IS NULL THEN '' ELSE ',@MatchId = ' + CONVERT(NVARCHAR(50), @MatchId) END
					+ CASE WHEN @TransIds IS NULL THEN '' ELSE ',@TransIds = ''' + CONVERT(NVARCHAR(MAX), @TransIds) + '''' END
					+ CASE WHEN @UserName IS NULL THEN '' ELSE ',@UserName = ''' + CONVERT(NVARCHAR(50), @UserName) + '''' END
					+ CASE WHEN @Password IS NULL THEN ''ELSE ',@Password = ''' + CONVERT(NVARCHAR(50), @Password) + '''' END
					+ CASE WHEN @UserId IS NULL THEN '' ELSE ',@UserId = ' + CONVERT(NVARCHAR(50), @UserId) END
					+ CASE WHEN @IP IS NULL THEN '' ELSE ',@IP = ''' + CONVERT(NVARCHAR(50), @IP) + '''' END
					+ CASE WHEN @Reason IS NULL THEN '' ELSE ',@Reason = ''' + CONVERT(NVARCHAR(500), @Reason) + '''' END
					+ CASE WHEN @ReasonSC IS NULL THEN '' ELSE ',@ReasonSC = ''' + CONVERT(NVARCHAR(500), @ReasonSC) + '''' END

	-- Write useraction log 
	DECLARE @sqlCommand NVARCHAR(MAX), @ID UNIQUEIDENTIFIER
			, @SubmittedDate DATETIME = GETDATE()
			, @spName VARCHAR(500) = OBJECT_NAME(@@PROCID)
	SET @ID =  NEWID()
	BEGIN TRY
		IF OBJECT_ID (N'TVS_UserActionLog') IS NOT NULL 
		BEGIN
			SET @sqlCommand = 'EXEC dbo.NAP_SpecialDelete_VoidParlaySubVSBetRadar_Upd '+ @LogData
			
			INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
			VALUES (@ID, @spName, @sqlCommand, @UserId, @MatchId, GETDATE(),@SubmittedDate)
		END	
	END TRY
	BEGIN CATCH
	END CATCH 

	IF @SearchBy = 'MatchId'
	BEGIN
		EXEC [dbo].[NAP_SpecialDelete_VoidParlaySubVSBetRadarByMatchId_Upd]
			@MatchId = @MatchId,
			@TransIds = @TransIds,
			@UserName = @UserName,
			@Password = @Password,
			@UserID	= @UserID,
			@IP	= @IP,
			@Reason	= @Reason,
			@ReasonSC = @ReasonSC
	END
	ELSE IF @SearchBy = 'SubTransIds'
	BEGIN
		EXEC [dbo].[NAP_SpecialDelete_VoidParlaySubVSBetRadarBySubIds_Upd]
			@SubTransIds = @TransIds,
			@UserName = @UserName,
			@Password = @Password,
			@UserID	= @UserID,
			@IP	= @IP,
			@Reason	= @Reason,
			@ReasonSC = @ReasonSC
	END
			
	-- Write useraction log	
	BEGIN TRY
        IF OBJECT_ID (N'TVS_UserActionLog') IS NOT NULL 
		BEGIN     
            INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
            VALUES (@ID, @spName, NULL, @UserId, @MatchId, GETDATE(),@SubmittedDate)
		END      
	END TRY
	BEGIN CATCH
	END CATCH

	-- Write Log
	SET @EndTime = GETDATE()
	SET @LogData = CAST((SELECT	@LogActionId AS '@LogActionId'
							,@UserId AS '@UserId'							
							,@IP AS '@IP'
							,@MatchId AS '@MatchId'
							,'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms.'
								+ @LogData
							AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS NVARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT

	SET NOCOUNT OFF
END
GO