/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Admin_Settlement_VS1_Validation
(
	 @matchid		INT = 0
	,@ErrCode		INT		 = 0 OUTPUT
	,@ErrMsg		NVARCHAR(300)  = ''    OUTPUT
)
AS
/*
	Created: 20220719@Louisa
    Task: Scale Out BetTrans [Redmine:#175251]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20220719@Louisa: Validation before settle [Redmine:#175251]

	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @IsWaiting		BIT = 0
			,@WaitingTime	VARCHAR(10)

	-- Check SP is in deployment
	EXEC dbo.NAP_Set_SPDeploymentInfo 
		@SPName = 'NAP_Admin_Settlement_VS_180'
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

	IF EXISTS (	SELECT	1 FROM	dbo.TempVariableNumber
				WHERE	KeyID = 1 
					AND KeyValue = @matchid
				)
	BEGIN
		SELECT @ErrCode = 1000000
			,@ErrMsg = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'
		RETURN
	END	

END
GO