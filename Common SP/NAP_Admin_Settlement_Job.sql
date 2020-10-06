/*<info serverAlias="DBTXN-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by:20201005@Louisa
    Task: Reduce UM Count & Write Job History Log Into Disk on NAP Settlement [Redmine:#140452]
    DB: DBTXN/bodb02

	Revision:
		- 20201005@Louisa: Create SP Job Step ( Job step will call to this SP)

*/
CREATE PROC NAP_Admin_Settlement_Job
(
	 @Jobname VARCHAR(100)
	,@Waitfordelay VARCHAR(12) = NULL
	
)
AS

/*
	--1.Single Settlement:		'bodb02 : NAP Single Settlement'

	--2.Parlay Settlement:		'bodb02 : NAP Parlay Settlement'

	--3.Single Settlement 3rd:	'bodb02 : NAP Single Settlement 3rd'

	--4.NG2 Settlement:			'bodb02: NAP NG2 Settlement'

	--5.BalanceUpdBonusCredit:	'bodb02 : Task_BalanceUpdBonusCredit'

	--6.BalanceUpdCreditCasino:	'bodb02 : Task_BalanceUpdCreditCasino'

	--7.BalanceUpdCreditOthers:	'bodb02 : Task_BalanceUpdCreditOthers'

	--8.BalanceUpdCreditSports:	'bodb02 : Task_BalanceUpdCreditSports'

	--9.BalanceUpdDebitCasino:	'bodb02 : Task_BalanceUpdDebitCasino'

	--10.BalanceUpdDebitOthers:	'bodb02 : Task_BalanceUpdDebitOthers'

	--11.BalanceUpdDebitSports:	'bodb02 : Task_BalanceUpdDebitSports'

	--12.Ticket Voiding:		'bodb02: Ticket Voiding'
*/


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

	ELSE IF (@Jobname = 'bodb02 : NAP Single Settlement 3rd')
		EXEC NAP_Admin_Settlement_3rd_Job

	ELSE IF (@Jobname = 'bodb02: NAP NG2 Settlement')
		EXEC [dbo].[Nap_Admin_Settlement_s213_Job]

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


	IF DATEDIFF(SECOND, @startDate, GETDATE() ) >= 600 -- loop within 10 minutes
		BREAK
	
	IF @Waitfordelay IS NOT NULL 
		WAITFOR DELAY @Waitfordelay
	
END