/*<info serverAlias="DBLOG-bodb_CustomerLog,DBTXN-bodb_CustomerLog" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[WriteLog_UserLog_Settle]
    @UserID         INT, 
    @MatchID        INT, 
    @ActionID       INT             = 0, 
    @finalhomescore INT             = NULL,
    @finalawayscore INT             = NULL,  
    @hthomescore    INT             = NULL,
    @htawayscore    INT             = NULL,
    @GoalRecord     VARCHAR(50)     = NULL,
    @betstatus      NVARCHAR(50)    = NULL,
    @Remark         VARCHAR(MAX)    = '',   
    @IP             VARCHAR(15)     = '',
    @LogDate        DATETIME        = NULL,
	@BroadcastSessionId VARCHAR(50) = NULL
AS
/*
    Creator: Daniel
    Date: 2009-12-25
    DB: bodb_CustomerLog
    Task: Insert LOGS for settlement function

    Revision:
        - 20110110@Jamie: Change size of Remark to 500
        - 20160507@Patrick: Add more param @LogDate & change size of Remark to 3000
        - 20170314@Kathy: Add default value [Redmine:#73218]
		- 20230817@Kathy: Write log [Redmine:#192311]

*/
BEGIN
    SET NOCOUNT ON;

	DECLARE	@xmlRemark	XML
			,@isxml		BIT = 0

	BEGIN TRY
		SET @xmlRemark = CAST(@Remark AS XML)
		SET @isxml = 1

	END TRY
	BEGIN CATCH
		SET @isxml = 0
	END CATCH

	-- update
	IF EXISTS (SELECT TOP 1 1 FROM dbo.UserLog_Settle WITH(NOLOCK) WHERE matchId = @MatchId AND BroadcastSessionId = @BroadcastSessionId)
	BEGIN
		IF @isxml = 0
		BEGIN
			UPDATE dbo.UserLog_Settle
				SET Remark = Remark + @Remark
			WHERE	MatchID = @MatchId
					AND BroadcastSessionId = @BroadcastSessionId
					AND ActionId = @ActionID
		END
		ELSE IF @isxml = 1
		BEGIN
			SET @xmlRemark.modify('delete /distinct'); -- remove root <distinct>
			SET @xmlRemark.modify('delete /bettypes'); -- remove root <bettypes>
			SET @xmlRemark.modify('delete /eventcounters'); -- remove root <eventcounters>

			UPDATE dbo.UserLog_Settle
				SET Remark = Remark + CAST(@xmlRemark AS VARCHAR(MAX))
			WHERE	MatchID = @MatchId
					AND BroadcastSessionId = @BroadcastSessionId
					AND ActionId = @ActionID
		END
	END
	ELSE -- insert
	BEGIN
		INSERT INTO dbo.UserLog_Settle (UserID,
			MatchID,
			ActionID,
			[finalhomescore],
			[finalawayscore],  
			[hthomescore],
			[htawayscore],
			[GoalRecord],
			[betstatus],
			[Remark],
			[IP],
			LogDate,
			BroadcastSessionId
		)
		SELECT @UserID, @MatchId, @ActionID, @finalhomescore, @finalawayscore, @hthomescore, @htawayscore, @GoalRecord, @betstatus
			,@Remark
			,@IP
			,GETDATE()
			,@BroadcastSessionId

	END
END
GO