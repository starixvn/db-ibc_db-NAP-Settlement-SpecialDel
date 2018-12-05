/*
	Created: 20181203@Helen
	Task: apply service broker for othersports, first one will be Number Game - https://nexdev.net/issues/101611
	DB: bodb02 @ DBLICAPI02/DBTP/DB05/DB052/DB053/DB054/DB06/DBLICAPI/DB042
	
*/
-- create message types / contracts / queues / services
USE bodb02
GO
IF EXISTS (SELECT TOP 1 1
		   FROM sys.services
		   WHERE name = 'Service_Settlement_OtherSports')
	DROP SERVICE Service_Settlement_OtherSports
GO

IF EXISTS (SELECT TOP 1 1
	   FROM sys.service_contracts
	   WHERE name = 'Contract_Settlement_OtherSports')
DROP CONTRACT Contract_Settlement_OtherSports
GO

IF EXISTS (SELECT TOP 1 1
		   FROM sys.service_queues
		   WHERE name = 'Queue_Settlement_OtherSports')
	DROP QUEUE Queue_Settlement_OtherSports	
GO

IF EXISTS (SELECT TOP 1 1
		   FROM sys.service_message_types
		   WHERE name = 'MessageType_Settlement_OtherSports')
	DROP MESSAGE TYPE MessageType_Settlement_OtherSports
GO
CREATE MESSAGE TYPE [MessageType_Settlement_OtherSports] AUTHORIZATION [dbo] VALIDATION = NONE

--CREATE MESSAGE TYPE [//Message/EndOfStream] AUTHORIZATION [dbo] VALIDATION = NONE
GO
CREATE CONTRACT [Contract_Settlement_OtherSports] AUTHORIZATION [dbo] (
	[MessageType_Settlement_OtherSports] SENT BY ANY,
	[//Message/EndOfStream] SENT BY ANY
)
GO
CREATE QUEUE [dbo].[Queue_Settlement_OtherSports] WITH STATUS = ON , RETENTION = OFF , ACTIVATION (  STATUS = ON , PROCEDURE_NAME = [sb].[SBQueue_Settlement_OtherSports] , MAX_QUEUE_READERS = 1 , EXECUTE AS N'dbo'  ), POISON_MESSAGE_HANDLING (STATUS = ON) 
 ON [ServiceBroker] 
GO

CREATE SERVICE [Service_Settlement_OtherSports]  AUTHORIZATION [dbo]  ON QUEUE [dbo].[Queue_Settlement_OtherSports] (Contract_Settlement_OtherSports)
GO

/*
-- Verification

-- Begin Dialog using service on contract
DECLARE @SBDialog uniqueidentifier
DECLARE @Message NVARCHAR(128)


BEGIN DIALOG CONVERSATION @SBDialog
FROM SERVICE Service_Settlement_OtherSports
TO SERVICE 'Service_Settlement_OtherSports'
ON CONTRACT Contract_Settlement_OtherSports
WITH ENCRYPTION = OFF

-- Send messages on Dialog
SELECT @SBDialog

SET @Message = N'Very First Message 1111';
SEND ON CONVERSATION @SBDialog
MESSAGE TYPE MessageType_Settlement_OtherSports (@Message)

SET @Message = N'Second Message 2222';
SEND ON CONVERSATION @SBDialog
MESSAGE TYPE MessageType_Settlement_OtherSports (@Message)


SELECT * FROM sys.transmission_queue (nolock)

-- View messages from Receive Queue
SELECT CONVERT(NVARCHAR(MAX), message_body) AS Message,*
FROM Queue_Settlement_OtherSports

select conversation_handle,* from sys.conversation_endpoints e WITH(NOLOCK) 
where far_service = 'Service_Settlement_OtherSports' and is_initiator = 1


SET @sMessage = 'SELECT TOP 1 * FROM sb.Logs WHERE creationTime = ''' + CONVERT(nvarchar(max),CURRENT_TIMESTAMP) + ''''


END CONVERSATION 'FA48EEAB-CEE0-E811-8DD0-782BCB4F7604' WITH CLEANUP


DECLARE @sMessage nvarchar(max)
SET @sMessage = 'SELECT TOP 1 ''helentest2'' as From_,* FROM  sb.CalculationLogs WITH (NOLOCK) WHERE creationTime = ''' + CONVERT(nvarchar(max),CURRENT_TIMESTAMP) + ''''

EXEC [sb].[SBInputMessage]  
			@fromService = N'Service_Settlement_OtherSports',
			@toService = N'Service_Settlement_OtherSports',
			@onContract = N'Contract_Settlement_OtherSports',
			@messageType = N'MessageType_Settlement_OtherSports',
			@messageBody = @sMessage

SELECT @sMessage
WAITFOR DELAY '00:00:00.280' -- wait 280ms to make sure service broker got time to do its job.
SELECT top 1 message_body,* from  sb.CalculationLogs WITH(NOLOCK) ORDER BY creationtime DESC

*/