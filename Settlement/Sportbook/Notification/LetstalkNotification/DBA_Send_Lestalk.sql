/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE DBA_Send_Lestalk
(
	@Message	NVARCHAR(4000)
	,@ErrCode	INT				= 0		OUTPUT 		
	,@ErrMsg	NVARCHAR(MAX)	= ''	OUTPUT 

)
/*
	Created by: 20231205@Louisa
	DB: DBTXN-bodb02
	
	Revisions: 
		- 20231205@Louisa: Initial [Redmine:#196401]

*/
AS
BEGIN
	BEGIN TRY
		EXEC DBNOTI.NotificationDB.dbo.DBA_Letstalk_NewJobMessage
				@ServerName			= 'Pontus'
			,	@JobName			= 'Custom Message'
			,	@Message			= @Message
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR
				,@ErrMsg = ERROR_MESSAGE()

	END CATCH
END