/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_UserActionLog_Update]
(
	@Userid	INT = 0
	,@FunctionName VARCHAR(500) = NULL
	,@LogContent NVARCHAR(MAX) = NULL
	,@IsActionCount BIT = 0
)
AS
/*
	Created by: 20240618@Max
	Task: [TVS] Set logs to check user behavior [Redmine:#204060]  
	DB: DBCTG.bodb02

	Revisions:
		- 20240618@Max: Create new SP - Get all site [Redmine: #204060]

	 Param's Explanation:  
	  - @IsActionCount = 1: Log count function access
					   = 0: Log user edit
*/					    
BEGIN
	SET NOCOUNT ON

	DECLARE @LogDate SMALLDATETIME 

	IF @IsActionCount = 1
	BEGIN
		SET @LogDate = (SELECT CONVERT(DATE,GETDATE()))

		UPDATE t SET t.[ActionCount] = t.[ActionCount] + 1
		FROM [dbo].[TicketVoiding_UserActionLog_Tracking] t WITH (ROWLOCK, UPDLOCK)
		WHERE t.UserId = @Userid AND t.LogDate = @LogDate AND t.FunctionName = @FunctionName

		IF @@ROWCOUNT = 0
		BEGIN
			INSERT INTO dbo.TicketVoiding_UserActionLog_Tracking (UserId, LogDate, FunctionName, ActionCount)
			SELECT @Userid, @LogDate, @FunctionName, 1
		END
	END
	ELSE
	BEGIN
		INSERT INTO dbo.TicketVoiding_UserActionLog_Tracking (UserId, LogDate, FunctionName, ActionCount, LogContent)
		SELECT @Userid, GETDATE(), @FunctionName, 0, @LogContent
	END

	SET NOCOUNT OFF
END
GO

