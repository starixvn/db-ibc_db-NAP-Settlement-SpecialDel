/*<info serverAlias="DBTXN-bodb_CustomerLog" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROC [sb].[CustomerLog_SendMessage] 
(	
	@xml xml = null
	, @functionName VARCHAR(100) = 'Login'
	, @MessageType VARCHAR (200) = ''
	, @SB_error BIT = 0 OUTPUT
)
AS
/*
	Create By: Kathy
	Created Date: 20181212
	Task: Apply Service Broker for Writing Log - [Redmine: 90155]
	DB: DBTXN/bodb_CustomerLog
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]

	Param's explanation:
*/

BEGIN
	
	SET NOCOUNT ON
	DECLARE @handle UNIQUEIDENTIFIER,@contractName VARCHAR(200)
	DECLARE @errorCode INT = 0, @errorMessage VARCHAR(MAX) = ''
	
	SET @contractName = (SELECT TOP 1 ContractName FROM sb.ConfigurationReferenceDetail WITH (NOLOCK) WHERE FunctionName=@functionName AND MessageType = @MessageType)
	
	EXEC [Sb].[ConversationPick] @functionName = @functionName,@contractName=@contractName,@handle = @handle  out
	SELECT @handle
	IF @handle IS NULL
	BEGIN
		SET @SB_error = 1
		RETURN
	END
	ELSE 
	BEGIN
		EXEC [sb].MsgSent @handle = @handle, @xml = @xml,@MessageType = @MessageType, @errorCode = @errorCode OUT, @errorMessage =  @errorMessage OUT
		
		IF @errorCode <> 0
			SET @SB_error = 1
		ELSE 
			SET @SB_error = 0	
	END
	
	SET NOCOUNT OFF
	
END

GO


