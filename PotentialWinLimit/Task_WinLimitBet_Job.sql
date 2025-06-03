/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/  
ALTER PROC [dbo].[Task_WinLimitBet_Job]
(
	 @Jobname VARCHAR(100)
	 ,@Waitfordelay VARCHAR(12) = NULL
)
AS
/*	
	Created: 20250416@Louisa
	Task:  Potential Winning Limit/Threshold [Redmine:#226060]
	DB: DBSIC/bodb02
	
	Revisions:
		- 20250416@Louisa:  Potential Winning Limit/Threshold [Redmine:#226060]
*/

BEGIN

	DECLARE  @startDate		DATETIME, @interval DATETIME
			,@WaitingTime	VARCHAR(10)
			,@IsWaiting		BIT
			---,@Jobname VARCHAR(100) = 'bodb02: Task_BalanceTrigger_WinLimit'
	SET  @startDate  = getdate()
	SET  @interval  = @startDate

	WHILE (1=1)
	BEGIN
		IF DATEDIFF(SECOND, @interval, GETDATE() ) >=  60
		BEGIN
			WHILE (1=1)
			BEGIN
				EXEC dbo.NAP_Set_JobDeploymentInfo
					@JobName = @Jobname
					,@WaitingTime = @WaitingTime OUTPUT
					,@IsWaiting	= @IsWaiting	 OUTPUT
		
				IF @IsWaiting = 1
				BEGIN
					UPDATE SystemSettings WITH(ROWLOCK)
						SET VValue = @Jobname + '-' + CONVERT(VARCHAR(50),GETDATE())
					WHERE VName = 'JobDeploymentDate'
			
					WAITFOR DELAY @WaitingTime
			
				END
				ELSE
				BREAK
			END
			SET @interval  =  GETDATE()
		END
		
		IF @Jobname  = 'bodb02: Task_BalanceTrigger_WinLimit'
			EXEC bodb02.dbo.Task_BalanceTrigger_Winlimit

		IF DATEDIFF(SECOND, @startDate, GETDATE() ) >= 600 -- loop within 10 minutes
			BREAK
	
		IF @Waitfordelay IS NOT NULL 
			WAITFOR DELAY @Waitfordelay
	END
END
GO