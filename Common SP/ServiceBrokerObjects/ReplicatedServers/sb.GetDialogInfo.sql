/*<info serverAlias="SBSETTLE-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [sb].[GetDialogInfo]
      @fromService SYSNAME,
      @toService SYSNAME,
      @onContract SYSNAME,
      @dialogHandle UNIQUEIDENTIFIER OUTPUT,
      @sendCount BIGINT OUTPUT
AS
/*  Created: Viet @ 20140210
	Task : Get dialog's information
	DB: bodb02 @ DB052/DB053/DB054/DB06
	Revisions:  
		20240205@Helen: Get code from DB053 and change READPAST to ROWLOCK to fix issue Lock and Release match flow for Sitedb don't run sequentially - [200832]
			
*/
BEGIN
	SET NOCOUNT ON;
	DECLARE @dialog TABLE (
		FromService SYSNAME NOT NULL,
		ToService SYSNAME NOT NULL,
		OnContract SYSNAME NOT NULL,
		Handle UNIQUEIDENTIFIER NOT NULL,
		OwnerSPID INT NOT NULL,
		CreationTime DATETIME NOT NULL,
		SendCount BIGINT NOT NULL
	)

	-- Try to claim an unused dialog in [DialogPool]
	-- READPAST option avoids blocking on locked dialogs.		
	UPDATE TOP(1) [sb].[DialogPool] WITH(ROWLOCK)
		SET OwnerSPID = @@SPID
	OUTPUT INSERTED.* INTO @dialog
	WHERE FromService = @fromService
		AND ToService = @toService
		AND OnContract = @OnContract
		AND OwnerSPID = -1
	
	IF @@ROWCOUNT > 0
	BEGIN
		SET @dialogHandle = (SELECT Handle FROM @dialog)
		SET @sendCount = (SELECT SendCount FROM @dialog)          
	END
	ELSE BEGIN
		-- No free dialogs: need to create a new one
		BEGIN DIALOG CONVERSATION @dialogHandle
			 FROM SERVICE @fromService
			 TO SERVICE @toService
			 ON CONTRACT @onContract
			 WITH ENCRYPTION = OFF
			 
		INSERT INTO [sb].[DialogPool] (FromService, ToService, OnContract, Handle, OwnerSPID, CreationTime, SendCount)
		VALUES (@fromService, @toService, @onContract, @dialogHandle, @@SPID, CURRENT_TIMESTAMP, 0)
		
		SET @sendCount = 0
	END
END
GO


