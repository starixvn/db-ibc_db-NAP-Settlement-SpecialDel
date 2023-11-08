/*<info serverAlias="SBSETTLE-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [sb].[SBQueue_Settlement_OtherSports]
AS
/*  Created: 20181018@Helen
	Task : Queue receive
	DB: bodb02 @ DBLICAPI02/DBTP/DB052/DB053/DB054/DB06/DBLICAPI/DB042
	
	Revisions:  
		- 20181018@Helen: Apply Service Broker for Other Sports - [Redmine:101611]
		- 20181224@Helen: Clean conversation when reach limit (sent 1000) - [Redmine:106881]
		- 20201012@Louisa: Update new email domain starixvn.com [Redmine:#143284]
		- 20210415@Louisa: Fixbug: Body email is empty because check wrong SB name [Redmine:#143442]
		- 20231026@Louisa: Update email domain from starixvn to starixsoft [Redmine:#195197]
		
*/
BEGIN

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
	DECLARE @maxTryCount TINYINT
	DECLARE @TryCount	TINYINT
	DECLARE @isQueueEnabled bit

	SET @maxTryCount = 5	
	SET @TryCount = 0
	SET @doomed_transaction = 0

	WAITFOR (
		RECEIVE TOP (1)		   
			@conversation_handle = [conversation_handle],
			@message_type = [message_type_name],
			@message_body = CONVERT(nvarchar(max),[message_body])
		FROM [dbo].[Queue_Settlement_OtherSports]	
		), TIMEOUT 100 -- if the queue is empty for 100 miliseconds, give up and go away
	
	IF @@ROWCOUNT > 0
	BEGIN
		SET DEADLOCK_PRIORITY HIGH

		WHILE (1 = 1)
		BEGIN
			BEGIN TRY
				IF @message_type IN ('MessageType_Settlement_OtherSports')
				BEGIN	
					DECLARE @starttime datetime
							,@duration int
							,@Id uniqueidentifier

					SET @starttime = CURRENT_TIMESTAMP
					SET @Id = NEWID()
					-- put your code here	
					
					INSERT INTO sb.CalculationLogs (Id, message_type, message_body, duration, message_error)
					VALUES (@Id, @message_type, @message_body, NULL, NULL)								
					
					EXEC sp_executesql @message_body
					
					SET @duration = datediff(second, @starttime, CURRENT_TIMESTAMP)

					INSERT INTO sb.CalculationLogs(Id, message_type, message_body, duration, message_error)
					VALUES (@Id, @message_type, @message_body, @duration, NULL)
									
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
				ELSE IF @message_type = 'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog'
				BEGIN
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
				END

				-- 20150921@viet: handle deadlock case, put some delay then retry. in case queue is disable, enable it again
				SELECT @isQueueEnabled = is_enqueue_enabled
				FROM sys.service_queues WITH(NOLOCK)
				WHERE name = 'Queue_Settlement_OtherSports'
						
				IF @error_number = 1205 --deadlock
				BEGIN
					SET @TryCount = @TryCount + 1
					-- put some delay before retry
					WAITFOR DELAY '00:00:00.100' -- Wait for 100 ms
				END

				-- SEND warning email to DBA
				BEGIN TRANSACTION sendMail
					SELECT TOP (1) @profile_name = name FROM MSDB.dbo.sysmail_profile --where name = 'DB053Profile'				
					SET @subject = 'CRITICAL: ' + @@SERVERNAME + ' - Service broker problem notification'
							
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
					--LOCAL: N'dba_local@starixsoft.com'
					--PRODUCTION: N'dbaadmin@starixsoft.com'
					@body=@body,
					@sensitivity ='Personal',
					@importance ='High',
					@copy_recipients =N'dbaadmin@starixsoft.com',
					@subject =@subject,
					--LOCAL: N'dba_local@starixsoft.com'
					--PRODUCTION: N'dbaadmin@starixsoft.com'
					@profile_name =@profile_name;
												
				COMMIT TRANSACTION sendMail		
			
				-- write log
				INSERT INTO [sb].[ProcessingErrors] (error_conversation, error_number, error_message, error_severity, error_state, error_procedure, error_line, doomed_transaction, [message])
				VALUES(NULL, @error_number, @error_message, @error_severity, @error_state, @error_procedure, @error_line, @doomed_transaction, @message_body)	

				IF @error_number = 1205 AND @TryCount < @maxTryCount
				BEGIN
					INSERT INTO sb.CalculationLogs(Id, message_type, message_body, duration, message_error)
					VALUES (@Id, @message_type, @message_body, NULL, @error_message)

					IF @isQueueEnabled = 0 ALTER QUEUE [Queue_Settlement_OtherSports] WITH STATUS = ON;

					CONTINUE
				END
				ELSE
					ALTER QUEUE [Queue_Settlement_OtherSports] WITH STATUS = OFF;
					
			END CATCH
		
			BREAK		
		END		
		
		SET DEADLOCK_PRIORITY NORMAL															
	END				
END
GO