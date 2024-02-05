/*<info serverAlias="SBSETTLE-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [sb].[SBInputMessage]  
	@fromService SYSNAME,   
	@toService SYSNAME,
	@onContract SYSNAME,
	@messageType SYSNAME,       
    @messageBody NVARCHAR(MAX)
AS
/*  Created: Viet @ 20140210
	Task : send a message to queue
	DB: bodb02 @ DB052/DB053/DB054/DB06
	
	Revisions:  
		20240205@Helen: Get code from DB053 and change to increase send count (3 billion) to reset for the issue Release match flow for Sitedb don't run sequentially - [200832]
*/
BEGIN
	SET NOCOUNT ON		

	DECLARE @dialogHandle UNIQUEIDENTIFIER
	DECLARE @sendCount BIGINT     
	DECLARE @counter INT
	DECLARE @error INT

	SELECT @counter = 1
	BEGIN TRANSACTION
	
	-- Will need a loop to retry in case the dialog is
	-- in a state that does not allow transmission
		WHILE (1=1)
		BEGIN
			-- Claim a dialog from the dialog pool (A new one will be created if none are available)
			EXEC [sb].[GetDialogInfo] @fromService, @toService, @onContract, @dialogHandle OUTPUT, @sendCount OUTPUT

			IF (@messageBody IS NOT NULL)
			BEGIN
				-- If the @messageBody is not null it must be sent explicitly
				SEND ON CONVERSATION @dialogHandle MESSAGE TYPE @messageType (@messageBody)
			END
			ELSE
			BEGIN
				-- Messages with no body must *not* specify the body,
				-- cannot send a NULL value argument
				SEND ON CONVERSATION @dialogHandle MESSAGE TYPE @messageType
			END
			     
			SELECT @error = @@ERROR
			IF @error = 0
			BEGIN
				-- Successful send, increment count and exit the loop
				--
				SET @sendCount = @sendCount + 1
				BREAK
			END

			SELECT @counter = @counter+1
			IF @counter > 10
			BEGIN
				-- We failed 10 times in a  row, something must be broken				
				RAISERROR('Failed to SEND on a conversation for more than 10 times. Error %i.', 16, 1, @error) WITH LOG
				--RAISERROR('Failed to SEND on a conversation for more than 10 times. Error %i.', 16, 1, @error)
			BREAK
			END

			-- Delete the associated dialog from the table and try again			
			EXEC [sb].[DeleteDialog] @dialogHandle
			SELECT @dialogHandle = NULL
		END

		-- "Criterion" for dialog pool removal is send count > 1000.
		-- Modify to suit application.
		-- When deleting also inform the target to end the dialog.
		IF @sendCount > 3000000000
		BEGIN
			EXEC [sb].[DeleteDialog] @dialogHandle;
			
			SEND ON CONVERSATION @dialogHandle MESSAGE TYPE [//Message/EndOfStream]
		END
		ELSE
		BEGIN
			-- release the dialog.
			EXEC [sb].[ReleaseDialog] @dialogHandle, @sendCount
		END
	COMMIT
END