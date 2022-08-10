/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Admin_Settlement_3rdValidation_Ticket
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
			'175' : Bitcoint
			'pingoal'
			'outright'
			'VS1' : virtual soccer /tennis

		@SelectedResources: 

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @IsWaiting BIT = 0
			,@WaitingTime VARCHAR(10)
	
	-- Check SP is in deployment
	IF @Mode IN ( '164' , '175' , '193', 'outright' , 'VS1')
	BEGIN
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

	--Lock TempVariableNumber
	IF @Mode = 'outright'
	BEGIN
		IF EXISTS (	SELECT 1
					FROM dbo.TempVariableNumber
					WHERE KeyID = 2
						AND KeyValue = @MatchID
					)
		BEGIN
			SELECT	 @ErrCode = 101
					,@ErrMsg = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'
			RETURN
		END
	END

	IF @Mode = '193'
	BEGIN
		IF EXISTS (
            SELECT	1
            FROM	dbo.Single_Calculate_Queue_VS WITH (NOLOCK)
            WHERE	matchid = @matchid
					AND IsCalculating IN (0, 1)
            )
        OR EXISTS (
            SELECT	1
            FROM	dbo.Parlay_Calculate_Queue_VS WITH (NOLOCK)
            WHERE	matchid = @matchid
					AND IsCalculating IN (0, 1)
            )
		BEGIN
			SELECT	@ErrCode = 1001004
					,@ErrMsg    = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'
			RETURN
		END

	END


	IF @Mode = 'VS1'
	BEGIN
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

END
GO