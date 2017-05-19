USE [bodb02]
GO
/****** Object:  StoredProcedure [sb].[SBQueue_send]    Script Date: 5/19/2017 3:56:45 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [sb].[SBQueue_send]
AS
/*  Created: Viet @ 20140210
	Task : queue send
	DB: bodb02 @ DB052/DB053/DB054/DB06
	Revisions:  
			
*/
BEGIN
	SET NOCOUNT ON;
     DECLARE @handle UNIQUEIDENTIFIER;
     DECLARE @message_type SYSNAME;
 
     BEGIN TRANSACTION;
		WAITFOR (
			RECEIVE TOP(1) @handle = [conversation_handle],
				@message_type = [message_type_name]
			FROM [dbo].[//Queue/Calculation_send]
		), TIMEOUT 10

		IF @@ROWCOUNT = 1
		BEGIN
			-- Expect target response to EndOfStream message.
			IF @message_type = 'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog'
			BEGIN
				END CONVERSATION @handle
			END
		END
     COMMIT
END
