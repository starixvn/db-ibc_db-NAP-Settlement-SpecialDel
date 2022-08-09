/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE NAP_Admin_Settlement_3rdValidation_Ticket
(
	 @matchid		INT = 0
	,@Action		VARCHAR(10)
	,@Mode			VARCHAR(10)
	,@IsAuto		BIT = 0
	,@SPName		VARCHAR(255)
	,@SelectedResources	VARCHAR(MAX) = NULL
	,@ErrCode				INT		 = 0 OUTPUT
	,@ErrMsg				NVARCHAR(300)  = ''    OUTPUT
)
AS
/*
	Created: 20220719@Louisa
    Task: Scale Out BetTrans [Redmine:#175251]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20220719@Louisa: Validation event before settle 3rd [Redmine:#175251]

	Param's Explanation:
		@Action: CAL, REFUND,			

		@Mode: 
			'164' : Happy5
			'pingoal'

		@SelectedResources: 

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @IsWaiting BIT = 0
			,@WaitingTime VARCHAR(10)
	
	IF @Mode IN ( '164' , 'pingoal' )--happy5
	BEGIN
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



END
GO