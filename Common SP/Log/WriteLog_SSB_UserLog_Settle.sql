/*<info serverAlias="DBTXN-bodb_CustomerLog" executers="bodbAdminNet,Dot_Admin,Dot_CoreAPI,Dot_Casino,Dot_Intg" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[WriteLog_SSB_UserLog_Settle]
	@UserID			INT, 
	@MatchID		INT, 
	@ActionID		INT				= 0, 
	@finalhomescore INT				= NULL,
    @finalawayscore INT				= NULL,  
    @hthomescore	INT				= NULL,
    @htawayscore	INT				= NULL,
    @GoalRecord		VARCHAR(50)		= NULL,
    @betstatus		NVARCHAR(50)	= NULL,
    @Remark			VARCHAR(MAX)	= '',	
	@IP				VARCHAR(15)		= '',
	@LogDate		DATETIME		= NULL,
	@BroadcastSessionId VARCHAR(50) = NULL
AS
/*	
	Created: 20230421@Aries
	Task: Use Service Broker to Write Log to DB Log
	DB: DBTXN-bodb_CustomerLog

	Revisions: 
        - 20230214@Aries: Created [Redmine: #187252]
		- 20230817@Kathy: Write log [Redmine:#192311]
		
	Param's Explanation:

*/
	SET NOCOUNT ON;
	DECLARE   @xmlLog		VARCHAR(MAX)
			 ,@SB_error		BIT

	SELECT @xmlLog = CONCAT('<UserLog_Settle>', 
					(SELECT   @UserID				AS '@u'
						     ,@MatchID				AS '@m'
						 	 ,@ActionID				AS '@a'
						 	 ,@finalhomescore		AS '@fth'
						 	 ,@finalawayscore		AS '@fta'
						 	 ,@hthomescore			AS '@hth'
						 	 ,@htawayscore			AS '@hta'
						 	 ,@GoalRecord			AS '@g'
							 ,@betstatus			AS '@b'
						 	 ,@Remark				AS '@r'
						 	 ,@IP					AS '@i'
						 	 ,@LogDate				AS '@l'
							 ,@BroadcastSessionId	AS '@bs'
					  FOR XML PATH),
					  '</UserLog_Settle>')

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @xmlLog, @functionName = 'UserLog', @MessageType = 'MessageType_UserLog', @SB_error = @SB_error OUTPUT;

	IF @SB_error = 1 
	BEGIN
		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle
					 @UserID			= @UserID
					,@MatchID			= @MatchID
					,@actionid			= @ActionID
					,@finalhomescore	= @finalhomescore
					,@finalawayscore	= @finalawayscore
					,@hthomescore		= @hthomescore
					,@htawayscore		= @htawayscore
					,@GoalRecord		= @GoalRecord
					,@betstatus			= @betstatus
					,@Remark			= @Remark
					,@IP				= @ip
					,@LogDate			= @LogDate
					,@BroadcastSessionId = @BroadcastSessionId
	END
GO