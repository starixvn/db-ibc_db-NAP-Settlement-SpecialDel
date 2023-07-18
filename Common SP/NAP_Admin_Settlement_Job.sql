/*<info serverAlias="DBTXN-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
CREATE PROC NAP_Admin_Settlement_Job
(
	 @Jobname VARCHAR(100)
	,@Waitfordelay VARCHAR(12) = NULL
	
)
AS
/* 
	Created by:20201005@Louisa
    Task: Reduce UM Count & Write Job History Log Into Disk on NAP Settlement [Redmine:#140452]
    DB: DBTXN/bodb02

	Revision:
		- 20201005@Louisa: Create SP Job Step ( Job step will call to this SP)
		- 20201019@Louisa: Implement for 11 Jobs
		- 20210921@Max: Add new job CustLimitBet Max Payout [Redmine: #158846]
		- 20220406@Kathy: Add job bodb02 : NAP Settlement VS BetRadar [Redmine:#166457]
		- 20220419@Max: Max Payout - Retry for Reject Action [Redmine: #171674]
		- 20230718@Kathy: Add job bodb02 : Task_NetPosition_Calculation_Job [Redmine:#187311]

*/
/*
	--1.Single Settlement:		'bodb02 : NAP Single Settlement'

	--2.Parlay Settlement:		'bodb02 : NAP Parlay Settlement'

	--3.Single Settlement 3rd:	'bodb02 : NAP Single Settlement 3rd'

	--4.BalanceUpdBonusCredit:	'bodb02 : Task_BalanceUpdBonusCredit'

	--5.BalanceUpdCreditCasino:	'bodb02 : Task_BalanceUpdCreditCasino'

	--6.BalanceUpdCreditOthers:	'bodb02 : Task_BalanceUpdCreditOthers'

	--7.BalanceUpdCreditSports:	'bodb02 : Task_BalanceUpdCreditSports'

	--8.BalanceUpdDebitCasino:	'bodb02 : Task_BalanceUpdDebitCasino'

	--9.BalanceUpdDebitOthers:	'bodb02 : Task_BalanceUpdDebitOthers'

	--10.BalanceUpdDebitSports:	'bodb02 : Task_BalanceUpdDebitSports'

	--11.Ticket Voiding:		'bodb02: Ticket Voiding'
	--12.VS BetRadar			'bodb02 : NAP Settlement VS BetRadar'
	--13. NetPosition			'bodb02 : Task_NetPosition_Calculation_Job'

*/
BEGIN

	DECLARE  @startDate		DATETIME, @interval DATETIME
			,@WaitingTime	VARCHAR(10)
			,@IsWaiting		BIT

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
	
		IF(@Jobname = 'bodb02 : NAP Single Settlement')
			EXEC NAP_Admin_Settlement_SB_Job

		ELSE IF (@Jobname = 'bodb02 : NAP Parlay Settlement')
			EXEC [dbo].[NAP_Admin_Settlement_MP_Job]

		ELSE IF(@Jobname = 'bodb02 : NAP Single Settlement 3rd')
			EXEC [dbo].[NAP_Admin_Settlement_3rd_Job]

		ELSE IF (@Jobname = 'bodb02 : Task_BalanceUpdBonusCredit')
			EXEC dbo.[Task_BalanceUpdBonusCredit]

		ELSE IF (@Jobname = 'bodb02 : Task_BalanceUpdCreditCasino')
			EXEC dbo.[Task_BalanceUpdCreditCasino]

		ELSE IF (@Jobname = 'bodb02 : Task_BalanceUpdCreditOthers')
			EXEC dbo.[Task_BalanceUpdCreditOthers]
		
		ELSE IF (@Jobname = 'bodb02 : Task_BalanceUpdCreditSports')
			EXEC dbo.[Task_BalanceUpdCreditSports]

		ELSE IF (@Jobname = 'bodb02 : Task_BalanceUpdDebitCasino')
			EXEC dbo.[Task_BalanceUpdDebitCasino]

		ELSE IF (@Jobname = 'bodb02 : Task_BalanceUpdDebitOthers')
			EXEC dbo.[Task_BalanceUpdDebitOthers]

		ELSE IF (@Jobname = 'bodb02 : Task_BalanceUpdDebitSports')
			EXEC dbo.[Task_BalanceUpdDebitSports]

		ELSE IF (@Jobname = 'bodb02: Ticket Voiding')
			EXEC dbo.TicketVoiding_Queue_Job

		ELSE IF (@Jobname = 'bodb02 : Task Max Payout Per Match')
			EXEC dbo.NAP_Admin_CustLimitBet_Queue_Job

		ELSE IF (@Jobname = 'bodb02 : Task Retry Max Payout')
			EXEC dbo.NAP_Admin_CustLimitBet_Retry_Job

		ELSE IF (@Jobname = 'bodb02 : NAP Settlement VS BetRadar')
		BEGIN
			-- Single
			EXEC [dbo].[NAP_Admin_Settlement_VS_Job]

			-- Parlay
			EXEC [dbo].[NAP_Admin_Settlement_VS_MP_Job]

			-- Send notification
			EXEC [dbo].[NAP_Admin_Settlement_VS_Notify_Job]

		END

		ELSE IF (@Jobname = 'bodb02 : Task_NetPosition_Calculation_Job') AND OBJECT_ID('Task_Calculation_NetPosition_Job','p') IS NOT NULL
		BEGIN
			EXEC dbo.Task_Calculation_NetPosition_Job
		END

		IF DATEDIFF(SECOND, @startDate, GETDATE() ) >= 600 -- loop within 10 minutes
			BREAK
	
		IF @Waitfordelay IS NOT NULL 
			WAITFOR DELAY @Waitfordelay
	END
END