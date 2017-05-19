USE [bodb02]
GO
/****** Object:  StoredProcedure [sb].[SBQueue_receive]    Script Date: 5/19/2017 3:55:52 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [sb].[SBQueue_receive]
AS
/*  Created: Viet @ 20140210
	Task : queue receive
	DB: bodb02 @ DB052/DB053/DB054/DB06
	Revisions:  
		- 20140619@Viet: send email to DBA once transaction is doomed.
			
*/
BEGIN
	----return 
	SET NOCOUNT ON;
	DECLARE @conversation_handle UNIQUEIDENTIFIER
	DECLARE @message_type SYSNAME
	DECLARE @message_body NVARCHAR(MAX)

	-- Error variables.
	DECLARE @error_number INT
	DECLARE @error_message VARCHAR(4000)
	DECLARE @error_severity INT
	DECLARE @error_state INT
	DECLARE @error_procedure SYSNAME
	DECLARE @error_line INT
	DECLARE @error_dialog VARCHAR(50)
	DECLARE @doomed_transaction BIT
	DECLARE @body VARCHAR(MAX)
	DECLARE @profile_name SYSNAME
	DECLARE @subject VARCHAR(100)


	BEGIN TRANSACTION		
		WAITFOR (
			RECEIVE TOP (1)		   
				@conversation_handle = [conversation_handle],
				@message_type = [message_type_name],
				@message_body = CONVERT(nvarchar(max),[message_body])
			FROM [dbo].[//Queue/Calculation_receive]	
			), TIMEOUT 100 -- if the queue is empty for 100 miliseconds, give up and go away
					
		IF @@ROWCOUNT > 0
		BEGIN
			BEGIN TRY
				IF @message_type IN ('//Message/Calculation')
				BEGIN					
					DECLARE @starttime datetime, @duration int
					SET @starttime = CURRENT_TIMESTAMP
					-- put your code here	
													
					EXEC sp_executesql @message_body
						
					-- viet test: will remove this later	
					SET @duration = datediff(second, @starttime, CURRENT_TIMESTAMP)
					INSERT INTO sb.Logs(message_type, message_body, duration) 
					VALUES(@message_type, @message_body, @duration)		
					-- / viet test: will remove this later					
									
				END
				ELSE IF @message_type = '//Message/EndOfStream'
				BEGIN
					-- initiator is signaling end of message stream: end the dialog
					END CONVERSATION @conversation_handle
				END
				ELSE IF @message_type = 'http://schemas.microsoft.com/SQL/ServiceBroker/Error'
				BEGIN
					-- If the message_type indicates that the message is an error,
					-- raise the error and end the conversation.
					WITH XMLNAMESPACES ('http://schemas.microsoft.com/SQL/ServiceBroker/Error' AS sb)
					SELECT
						@error_number = CAST(@message_body AS XML).value('(//sb:Error/sb:Code)[1]', 'INT'),
						@error_message = CAST(@message_body AS XML).value('(//sb:Error/sb:Description)[1]', 'VARCHAR(4000)')
						
					SET @error_dialog = CAST(@conversation_handle AS VARCHAR(50))
					RAISERROR('Error in dialog %s: %s (%i)', 16, 1, @error_dialog, @error_message, @error_number)
					
					END CONVERSATION @conversation_handle
				END
			END TRY
			BEGIN CATCH
				SET @error_number = ERROR_NUMBER()
				SET @error_message = ERROR_MESSAGE()
				SET @error_severity = ERROR_SEVERITY()
				SET @error_state = ERROR_STATE()
				SET @error_procedure = ERROR_PROCEDURE()
				SET @error_line = ERROR_LINE()

				IF XACT_STATE() = -1
				BEGIN
					-- The transaction is doomed. Only rollback possible.
					-- This could disable the queue if done 5 times consecutively!
					ROLLBACK TRANSACTION
						
					SET @doomed_transaction = 1
						
					-- 20150921@viet: handle deadlock case, put some delay then retry. in case queue is disable, enable it again
					DECLARE @isQueueEnabled bit
					SELECT @isQueueEnabled = is_enqueue_enabled
					FROM sys.service_queues WIHT(NOLOCK)
					WHERE name = '//Queue/Calculation_receive'	
						
					IF @error_number = 1205 --deadlock
					BEGIN
						-- put some delay before retry
						WAITFOR DELAY '00:00:00.100' -- Wait for 100 ms
							
						-- if queue got disabled, enable it again
						IF @isQueueEnabled = 0 ALTER QUEUE [//Queue/Calculation_receive] WITH STATUS = ON;
					END
					---------------
			
					-- SEND warning email to DBA
					BEGIN TRANSACTION sendMail
						SELECT TOP (1) @profile_name = name FROM MSDB.dbo.sysmail_profile where name = 'DB06Profile'				
						SET @subject = 'WARNING: ' + @@SERVERNAME + ' - Service broker problem notification'
							
						SET @body = 'Hi There,
									Queue status: ' + CASE @isQueueEnabled WHEN 1 THEN 'enabled' ELSE 'disabled!!!' END + '
									ERROR: ' + @error_message + ' 
										
									The transaction is doomed. This could disable the queue-receive if done 5 times consecutively!
									-- SELECT TOP(5) * FROM sb.ProcessingErrors WITH(NOLOCK) ORDER BY updatedtime DESC 									
								'
						IF @isQueueEnabled = 0 --- in case of @error_number not 1205 
							set @body = 'The Service Broker queue on ' + @@SERVERNAME + ' is DISABLE now, pls ask DBA for checking & enable back!!!'

						EXEC msdb.dbo.sp_send_dbmail
						@recipients=N'dbaadmin@starixsoft.com',
						@body=@body,
						@sensitivity ='Personal',
						@importance ='High',
						@copy_recipients ='dbaadmin@starixsoft.com',
						@subject =@subject,
						@profile_name =@profile_name;							
					COMMIT TRANSACTION sendMail
				END
				ELSE
				BEGIN					
					COMMIT TRANSACTION
						
					SET @doomed_transaction = 0
				END
					
				-- write log
				INSERT INTO [sb].[ProcessingErrors] (error_conversation, error_number, error_message, error_severity, error_state, error_procedure, error_line, doomed_transaction, [message])
				VALUES(NULL, @error_number, @error_message, @error_severity, @error_state, @error_procedure, @error_line, @doomed_transaction, @message_body)																					
			END CATCH
		END				
		COMMIT TRANSACTION
END






