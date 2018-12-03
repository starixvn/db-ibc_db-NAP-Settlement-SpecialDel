/*

	Created: 20181203@Helen
	Task: apply service broker for othersports, first one will be Number Game - https://nexdev.net/issues/101611
	DB: bodb02 @ DBLICAPI02/DBTP/DB05/DB052/DB053/DB054/DB06/DBLICAPI
	

*/
DECLARE @fromService SYSNAME
		,@toService SYSNAME
		,@onContract SYSNAME
		,@messageType SYSNAME       
		
		
SELECT @fromService = N'Service_Settlement_OtherSports',
			@toService = N'Service_Settlement_OtherSports',
			@onContract = N'Contract_Settlement_OtherSports'
			
			
-- clean existing conversation 
DECLARE  @handle UNIQUEIDENTIFIER

IF EXISTS (SELECT TOP 1 * FROM sys.conversation_endpoints e WITH(NOLOCK) WHERE far_service = 'Service_Settlement_OtherSports')
BEGIN
	WHILE (1=1)
	BEGIN
		SELECT @handle = (SELECT TOP 1 conversation_handle FROM sys.conversation_endpoints e WITH(NOLOCK) WHERE far_service = 'Service_Settlement_OtherSports')
		IF @handle IS NOT NULL
		BEGIN
			END CONVERSATION @handle WITH CLEANUP
		END
		ELSE 
			BREAK	
	END
END

DELETE [sb].[DialogPool] WHERE FromService ='Service_Settlement_OtherSports'
		
--- CREATE new conversation for other sports
BEGIN DIALOG CONVERSATION @handle
FROM SERVICE  @fromService 
TO SERVICE  @toService 
ON CONTRACT @onContract 
WITH ENCRYPTION = OFF								

IF @handle IS NOT NULL
BEGIN
	INSERT INTO [sb].[DialogPool] (FromService, ToService, OnContract, Handle,OwnerSPID, CreationTime, SendCount)
	VALUES (@fromService, @toService, @onContract, @handle, -1, CURRENT_TIMESTAMP, 0)
END	

 /*CHECKING 

SELECT * FROM [sb].[DialogPool] (NOLOCK) WHERE FromService = 'Service_Settlement_OtherSports'
SELECT * FROM sys.conversation_endpoints e WITH(NOLOCK) WHERE far_service = 'Service_Settlement_OtherSports'


DECLARE @sMessage nvarchar(max)
SET @sMessage = 'SELECT TOP 1 ''helentest6'' as From_,* FROM  sb.CalculationLogs WITH (NOLOCK) WHERE creationTime = ''' + CONVERT(nvarchar(max),CURRENT_TIMESTAMP) + ''''

EXEC [sb].[SBInputMessage]  
			@fromService = N'Service_Settlement_OtherSports',
			@toService = N'Service_Settlement_OtherSports',
			@onContract = N'Contract_Settlement_OtherSports',
			@messageType = N'MessageType_Settlement_OtherSports',
			@messageBody = @sMessage

SELECT @sMessage

WAITFOR DELAY '00:00:00.280' -- wait 280ms to make sure service broker got time to do its job.
SELECT top 1 message_body,* from  sb.CalculationLogs WITH(NOLOCK) ORDER BY creationtime DESC

SELECT * FROM [sb].[DialogPool] (NOLOCK)
SELECT TOP(10) * FROM [sb].[ProcessingErrors] WITH(NOLOCK) ORDER BY updatedtime DESC

SELECT conversation_handle,* FROM sys.conversation_endpoints e WITH(NOLOCK) 
WHERE far_service = 'Service_Settlement_OtherSports' --and is_initiator = 1

*/
GO


