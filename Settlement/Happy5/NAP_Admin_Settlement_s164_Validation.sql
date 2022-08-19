/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Admin_Settlement_s164_Validation
(
	 @ErrCode	INT			   = 0  OUTPUT
	,@ErrMsg	NVARCHAR(300)  = '' OUTPUT
)
AS
/*
	Created: 20220719@Louisa
    Task: Scale Out BetTrans [Redmine:#175251]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20220719@Louisa: initial [Redmine:#175251]

	Param's Explanation:
		@Action: CAL, REFUND			

*/
BEGIN
	SET NOCOUNT ON


	DECLARE @IsWaiting		BIT = 0
			,@WaitingTime	VARCHAR(10)

	-- Check SP is in deployment
	EXEC dbo.NAP_Set_SPDeploymentInfo 
		@SPName			= 'NAP_Admin_Settlement_s164'
		,@WaitingTime	= @WaitingTime OUTPUT
		,@IsWaiting		= @IsWaiting OUTPUT
		,@ErrCode		= @ErrCode OUTPUT
		,@ErrMsg		= @ErrMsg OUTPUT

	IF @IsWaiting = 1
	BEGIN
		WAITFOR DELAY @WaitingTime
			
		SELECT	@ErrCode = @ErrCode
				,@ErrMsg = @ErrMsg
		RETURN
	END

END
GO