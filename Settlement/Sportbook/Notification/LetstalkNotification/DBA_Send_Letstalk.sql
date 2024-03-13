/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE DBA_Send_Letstalk
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
				@ServerName			= @@ServerName
			,	@JobName			= 'vndba:Check slowly running or failed processes'
			,	@Message			= @Message
			,	@CaseId = 1
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR
				,@ErrMsg = ERROR_MESSAGE()

	END CATCH
END