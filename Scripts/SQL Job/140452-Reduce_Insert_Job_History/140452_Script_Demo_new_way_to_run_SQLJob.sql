/*
	--Step 1 : Capture the latest time deployed Job - SELECT VValue FROM SystemSettings WHERE VName = 'JobDeploymentDate'

	--Step 2: ALTER SP dbo.NAP_Set_JobDeploymentInfo to setup JobName, WaitingTime, IsWaiting = 1

	--Step 3: Compare VValue FROM SystemSettings WHERE VName = 'JobDeploymentDate' 
			  If it newer than value already captured, then Alter SP Job

	--Step 4: ALTER SP dbo.NAP_Set_JobDeploymentInfo to setup JobName, IsWaiting = 0

*/

DECLARE  @startDate		DATETIME, @interval DATETIME
		,@WaitingTime	VARCHAR(10)
		,@IsWaiting		BIT

SET  @startDate  = getdate()
SET  @interval  = @startDate

WHILE (1=1)
BEGIN
	IF DATEDIFF(SECOND, @interval, GETDATE() ) >=  60-- every 1 minutes to check for change SP for JOB
	BEGIN
		EXEC dbo.NAP_Set_JobDeploymentInfo
			@JobName = 'SingleSettlement'
			,@WaitingTime = @WaitingTime OUTPUT
			,@IsWaiting	= @IsWaiting	 OUTPUT
		
		IF @IsWaiting = 1
		BEGIN
			UPDATE SystemSettings (ROWLOCK)
				SET VValue = CONVERT(VARCHAR(50),GETDATE())
			WHERE VName = 'JobDeploymentDate'
			
			WAITFOR DELAY @WaitingTime
			
		END
		SET @interval  =  GETDATE()
	END
	
	EXEC NAP_Admin_Settlement_SB_Job

	IF DATEDIFF(SECOND, @startDate, GETDATE() ) >= 600 -- loop within 10 minutes
		BREAK
	
	WAITFOR DELAY '00:00:00.280'
	
END