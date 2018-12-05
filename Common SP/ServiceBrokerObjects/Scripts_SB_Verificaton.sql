/*
	Created: 20181203@Helen
	Task: apply service broker for othersports, first one will be Number Game - https://nexdev.net/issues/101611
	DB: bodb02 @ DBLICAPI02/DBTP/DB05/DB052/DB053/DB054/DB06/DBLICAPI/DB042
	
*/
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

SELECT TOP(10) * FROM [sb].[ProcessingErrors] WITH(NOLOCK) ORDER BY updatedtime DESC

GO