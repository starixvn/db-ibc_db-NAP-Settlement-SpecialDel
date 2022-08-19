/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Admin_Settlement_Outright_Validation
(
	 @IsAuto	BIT = 0
	,@ErrCode	INT	= 0 OUTPUT
	,@ErrMsg	NVARCHAR(300)  = '' OUTPUT
)
AS
/*
	Created: 20220719@Louisa
    Task: Scale Out BetTrans [Redmine:#175251]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20220719@Louisa: Validation event before settle 3rd [Redmine:#175251]

	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @IsWaiting		BIT = 0
			,@WaitingTime	VARCHAR(10)
			,@SPName		VARCHAR(255)

	SELECT @SPName = CASE WHEN @IsAuto = 1 
								THEN 'Dot_Admin_SettleOutright_Trans'
								ELSE 'NAP_Admin_Settlement_Outright'
							END

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


END
GO