/*<info serverAlias="DBTXN-msdb" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by:20200930@Louisa
    Task: Reduce UM Count & Write Job History Log Into Disk on NAP Settlement [Redmine:#140452]
    DB: DBTXN/msdb

	Revision:
		- 20201005@Louisa: Reduce insert job history into disk [Redmine:#140452]

*/

USE [msdb]
GO


----1. Parlay Settlement
EXEC sp_update_jobstep @job_name=N'bodb02 : NAP Parlay Settlement', 
                       @step_id=1, ---- @step_name=N'[NAP_Admin_Settlement_MP_Job]'
                       @command=N'DECLARE @startDate DATETIME 
SET @startDate  = GETDATE()

WHILE (1=1)
BEGIN
	
	EXEC [dbo].[NAP_Admin_Settlement_MP_Job]

	IF DATEDIFF(SECOND, @startDate, GETDATE() ) >= 600
	BREAK

	WAITFOR DELAY ''00:00:00.280''

END' 

GO

----2. Single Settlement 3rd
EXEC sp_update_jobstep @job_name=N'bodb02 : NAP Single Settlement 3rd',
						@step_id=1, ----@step_name=N'Call NAP_Admin_Settlement_3rd_Job'
						@command=N'DECLARE @startDate DATETIME 
SET @startDate  = GETDATE()

WHILE (1=1)
BEGIN
	
	EXEC NAP_Admin_Settlement_3rd_Job

	IF DATEDIFF(SECOND, @startDate, GETDATE() ) >= 600
	BREAK

	WAITFOR DELAY ''00:00:00.100''

END'

GO

----3. NG2 Settlement
EXEC sp_update_jobstep  @job_name=N'bodb02: NAP NG2 Settlement',
						@step_id=1, ----@step_name=N'Call Nap_Admin_Settlement_s213_Job'
						@command=N'DECLARE @startDate DATETIME 
SET @startDate  = GETDATE()

WHILE (1=1)
BEGIN
	
	EXEC Nap_Admin_Settlement_s213_Job

	IF DATEDIFF(SECOND, @startDate, GETDATE() ) >= 600
	BREAK

	WAITFOR DELAY ''00:00:00.280''

END'

GO

----4. BalanceUpdBonusCredit
EXEC sp_update_jobstep  @job_name=N'bodb02 : Task_BalanceUpdBonusCredit', 
						@step_id=1, ----@step_name=N'Task_BalanceUpdBonusCredit'
						@command=N'DECLARE @startDate DATETIME 
SET @startDate  = GETDATE()

WHILE (1=1)
BEGIN
	
	EXEC dbo.[Task_BalanceUpdBonusCredit]

	IF DATEDIFF(SECOND, @startDate, GETDATE() ) >= 600
	BREAK
	
END'

GO

----5. BalanceUpdCreditCasino
EXEC sp_update_jobstep  @job_name=N'bodb02 : Task_BalanceUpdCreditCasino',
						@step_id=1, ----@step_name=N'Task_BalanceUpdCreditCasino'
						@command=N'DECLARE @startDate DATETIME 
SET @startDate  = GETDATE()

WHILE (1=1)
BEGIN
	
	EXEC dbo.[Task_BalanceUpdCreditCasino]

	IF DATEDIFF(SECOND, @startDate, GETDATE() ) >= 600
	BREAK
	
END'

GO

----6. BalanceUpdCreditOthers
EXEC sp_update_jobstep   @job_name=N'bodb02 : Task_BalanceUpdCreditOthers', 
						 @step_id=1, ----@step_name=N'Task_BalanceUpdCreditOthers'
						 @command=N'DECLARE @startDate DATETIME 
SET @startDate  = GETDATE()

WHILE (1=1)
BEGIN
	
	EXEC dbo.[Task_BalanceUpdCreditOthers]

	IF DATEDIFF(SECOND, @startDate, GETDATE() ) >= 600
	BREAK
	
END'

GO

----7. BalanceUpdCreditSports
EXEC sp_update_jobstep   @job_name=N'bodb02 : Task_BalanceUpdCreditSports',
						 @step_id=1, ----@step_name=N'Task_BalanceUpdCreditSports'
						 @command=N'DECLARE @startDate DATETIME 
SET @startDate  = GETDATE()

WHILE (1=1)
BEGIN
	
	EXEC dbo.[Task_BalanceUpdCreditSports]

	IF DATEDIFF(SECOND, @startDate, GETDATE() ) >= 600
	BREAK
	
END'

GO

----8. BalanceUpdDebitCasino
EXEC sp_update_jobstep  @job_name=N'bodb02 : Task_BalanceUpdDebitCasino',
						@step_id=1, ----@step_name=N'Task_BalanceUpdDebitCasino'
						@command=N'DECLARE @startDate DATETIME 
SET @startDate  = GETDATE()

WHILE (1=1)
BEGIN
	
	EXEC dbo.[Task_BalanceUpdDebitCasino]

	IF DATEDIFF(SECOND, @startDate, GETDATE() ) >= 600
	BREAK
	
END'

GO

----9. BalanceUpdDebitOthers
EXEC sp_update_jobstep  @job_name=N'bodb02 : Task_BalanceUpdDebitOthers',
						@step_id=1, ----@step_name=N'Task_BalanceUpdDebitOthers'
						@command=N'DECLARE @startDate DATETIME 
SET @startDate  = GETDATE()

WHILE (1=1)
BEGIN
	
	EXEC dbo.[Task_BalanceUpdDebitOthers]

	IF DATEDIFF(SECOND, @startDate, GETDATE() ) >= 600
	BREAK
	
END'

GO

----10. BalanceUpdDebitSports
EXEC sp_update_jobstep  @job_name=N'bodb02 : Task_BalanceUpdDebitSports',
						@step_id=1,---- @step_name=N'Task_BalanceUpdDebitSports'
						@command=N'DECLARE @startDate DATETIME 
SET @startDate  = GETDATE()

WHILE (1=1)
BEGIN
	
	EXEC dbo.[Task_BalanceUpdDebitSports]

	IF DATEDIFF(SECOND, @startDate, GETDATE() ) >= 600
	BREAK
	
END'

GO

----11. Ticket Voiding
EXEC sp_update_jobstep  @job_name=N'bodb02: Ticket Voiding',
						@step_id=1, -----@step_name=N'Void ticket'
						@command=N'DECLARE @startDate DATETIME 
SET @startDate  = GETDATE()

WHILE (1=1)
BEGIN
	
	EXEC dbo.TicketVoiding_Queue_Job

	IF DATEDIFF(SECOND, @startDate, GETDATE() ) >= 600
	BREAK

	WAITFOR DELAY ''00:00:00.280''

END'

GO