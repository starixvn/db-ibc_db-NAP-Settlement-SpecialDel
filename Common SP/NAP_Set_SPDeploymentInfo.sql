/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_SPDeploymentInfo
	@SPName			SYSNAME
	,@WaitingTime	VARCHAR(10) 	OUTPUT
	,@IsWaiting		BIT		= 0		OUTPUT
	,@ErrCode		INT		= 0		OUTPUT
	,@ErrMsg		VARCHAR(300) = '' OUTPUT
AS
/*
	Created by: 20210514@Kathy
	Task: Set waiting time for SP [Redmine:#153155]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20210514@Kathy: Set waiting time for SP [Redmine:#153155]
		- 20210810@Kathy: Incorporate Bitcoin  [Redmine:#159714]
		- 20220601@Kathy: Check SP under deployment [Redmine:#172557]
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @tmpSPInfo TABLE (SPName SYSNAME, WaitingTime VARCHAR(10), IsWaiting BIT DEFAULT (0))

	SET @WaitingTime = '00:00:10'
	SET @IsWaiting = 0

	---1.Auto FM Settlement
	INSERT INTO @tmpSPInfo (SPName, WaitingTime, IsWaiting)
	SELECT 'NAP_Admin_Settlement_Fast_Market_Auto_1s_Push', @WaitingTime, 0	
	
	UNION ALL
	SELECT 'NAP_Admin_Settlement_Profile_Push', @WaitingTime, 0	
	
	-- Auto PinGoal
	UNION ALL
	SELECT 'NAP_Admin_Settlement_Profile', @WaitingTime, 0	

	-- Bitcoin
	UNION ALL
	SELECT 'NAP_Admin_Settlement_s175', @WaitingTime, 0

	-- NG
	UNION ALL
	SELECT 'NAP_Admin_Settlement_s161_Manual', @WaitingTime, 0	 --manual
	UNION ALL
	SELECT 'NAP_Admin_Settlement_s161', @WaitingTime, 0	 -- api
	
	-- HP5
	UNION ALL
	SELECT 'NAP_Admin_Settlement_s164', @WaitingTime, 0	

	-- VS
	UNION ALL
	SELECT 'NAP_Admin_Settlement_VS_180', @WaitingTime, 0	
	
	-- outright
	UNION ALL
	SELECT 'NAP_Admin_Settlement_Outright', @WaitingTime, 0	
	UNION ALL
	SELECT 'Dot_Admin_SettleOutright_Trans', @WaitingTime, 0	
	
	
	SELECT @WaitingTime = WaitingTime
			,@IsWaiting = IsWaiting
	FROM	@tmpSPInfo
	WHERE	SPName = @SPName

	IF @IsWaiting = 1
	BEGIN
		SELECT	@ErrCode = 99
				,@ErrMsg = 'Failed due to system is in deployment, please wait a few seconds until the process is completed and try again.'
	END
END
GO