/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="bodbAdminNet" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[WriteLog_UserLog_Settle_Remark_Update]
	@MatchID		INT, 
    @Remark			VARCHAR(MAX),	
	@LogDate		DATETIME,
	@ActionID		INT,
	@LogIDOutput	BIGINT OUTPUT
AS
/*
	Creator: 20190212@Vicky
	DB: DBLOG-bodb_CustomerLog
	Task: Insert LOGS for BetBuilder
	
	Revision:
		- 20190103@Vicky: Incorporate BetBuilder [Redmine:#106903]
*/
BEGIN
	SET NOCOUNT ON;
	--------------------------------------------------------------------------------
	
	SELECT @LogIDOutput = LogID
	FROM dbo.UserLog_Settle WITH(NOLOCK) 
	WHERE MatchID = @MatchID AND LogDate = @LogDate AND ActionID = @ActionID
	
	IF @LogIDOutput IS NOT NULL
	BEGIN
		UPDATE UserLog_Settle WITH (ROWLOCK, UPDLOCK) 
		SET Remark = CASE WHEN Remark IS NOT NULL THEN Remark + ',' ELSE '' END  + @Remark
		WHERE LogID = @LogIDOutput
	END
END

GO
