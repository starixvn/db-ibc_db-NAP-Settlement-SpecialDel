/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Admin_Settlement_NumberGame_Validation
(
	 @matchid		INT = 0
	,@IsAuto		BIT = 0
	,@ErrCode				INT		 = 0 OUTPUT
	,@ErrMsg				NVARCHAR(300)  = ''    OUTPUT
)
AS
/*
	Created: 20220719@Louisa
    Task: Scale Out BetTrans [Redmine:#175251]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20220719@Louisa: Initial [Redmine:#175251]

*/
BEGIN
	SET NOCOUNT ON


	DECLARE @sporttype		SMALLINT
			,@IsWaiting		BIT = 0
			,@WaitingTime	VARCHAR(10)
			,@xml			XML
			,@IsCentral		BIT = 0
			,@SPName		VARCHAR(255)

	SELECT @SPName = CASE WHEN @IsAuto = 1 
								THEN 'NAP_Admin_Settlement_s161'
							ELSE 'NAP_Admin_Settlement_s161_Manual'
							END
							
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT
 
	-- Check SP is in deployment
	EXEC dbo.NAP_Set_SPDeploymentInfo 
		@SPName = @SPName
		,@WaitingTime = @WaitingTime OUTPUT
		,@IsWaiting = @IsWaiting OUTPUT
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT

	IF @IsWaiting = 1
	BEGIN
		WAITFOR DELAY @WaitingTime -- NAP_Admin_Settlement_s164
			
		SELECT	@ErrCode = @ErrCode
				,@ErrMsg = @ErrMsg
		RETURN
	END

	IF EXISTS(SELECT 1 FROM SystemSettings WITH (NOLOCK) WHERE VValue = 1 AND VName = 'isCalculatingNGManual')
	BEGIN
		SELECT @ErrCode = 102
			, @ErrMsg = 'Another number game re-calculation is in progress, please wait a few seconds until the ongoing process has finished and try again.'
		WHERE @IsAuto = 0

		RETURN
	END

	IF EXISTS (SELECT 1 FROM dbo.TempVariableNumber WHERE KeyID = 1 AND KeyValue = @MatchId)
	BEGIN
		SELECT  @ErrCode =  CASE WHEN @IsAuto = 0 THEN 103 ELSE 101 END
				,@ErrMsg = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'
		RETURN
	END

END
GO