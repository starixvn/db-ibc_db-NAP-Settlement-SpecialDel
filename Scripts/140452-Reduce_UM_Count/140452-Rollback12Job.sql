/*<info serverAlias="DBTXN-msdb" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by:20201008@Louisa
    Task: Reduce UM Count & Write Job History Log Into Disk on NAP Settlement [Redmine:#140452]
    DB: DBTXN/msdb

	Revision:
		- 20201008@Louisa: Rollback job step if deployment has issues [Redmine:#140452]

*/

USE [msdb]
GO


----1. Parlay Settlement
EXEC sp_update_jobstep @job_name=N'bodb02 : NAP Parlay Settlement', 
                       @step_id=1, ---- @step_name=N'[NAP_Admin_Settlement_MP_Job]'
                       @command=N'EXEC [dbo].[NAP_Admin_Settlement_MP_Job]' 

GO

----2. Single Settlement 3rd
EXEC sp_update_jobstep @job_name=N'bodb02 : NAP Single Settlement 3rd',
						@step_id=1, ----@step_name=N'Call NAP_Admin_Settlement_3rd_Job'
						@command=N'EXEC NAP_Admin_Settlement_3rd_Job'

GO

----3. NG2 Settlement
EXEC sp_update_jobstep  @job_name=N'bodb02: NAP NG2 Settlement',
						@step_id=1, ----@step_name=N'Call Nap_Admin_Settlement_s213_Job'
						@command=N'EXEC Nap_Admin_Settlement_s213_Job'

GO

----4. BalanceUpdBonusCredit
EXEC sp_update_jobstep  @job_name=N'bodb02 : Task_BalanceUpdBonusCredit', 
						@step_id=1, ----@step_name=N'Task_BalanceUpdBonusCredit'
						@command=N'EXEC dbo.[Task_BalanceUpdBonusCredit]'

GO

----5. BalanceUpdCreditCasino
EXEC sp_update_jobstep  @job_name=N'bodb02 : Task_BalanceUpdCreditCasino',
						@step_id=1, ----@step_name=N'Task_BalanceUpdCreditCasino'
						@command=N'EXEC dbo.[Task_BalanceUpdCreditCasino]'

GO

----6. BalanceUpdCreditOthers
EXEC sp_update_jobstep   @job_name=N'bodb02 : Task_BalanceUpdCreditOthers', 
						 @step_id=1, ----@step_name=N'Task_BalanceUpdCreditOthers'
						 @command=N'EXEC dbo.[Task_BalanceUpdCreditOthers]'

GO

----7. BalanceUpdCreditSports
EXEC sp_update_jobstep   @job_name=N'bodb02 : Task_BalanceUpdCreditSports',
						 @step_id=1, ----@step_name=N'Task_BalanceUpdCreditSports'
						 @command=N'EXEC dbo.[Task_BalanceUpdCreditSports]'

GO

----8. BalanceUpdDebitCasino
EXEC sp_update_jobstep  @job_name=N'bodb02 : Task_BalanceUpdDebitCasino',
						@step_id=1, ----@step_name=N'Task_BalanceUpdDebitCasino'
						@command=N'EXEC dbo.[Task_BalanceUpdDebitCasino]'

GO

----9. BalanceUpdDebitOthers
EXEC sp_update_jobstep  @job_name=N'bodb02 : Task_BalanceUpdDebitOthers',
						@step_id=1, ----@step_name=N'Task_BalanceUpdDebitOthers'
						@command=N'EXEC dbo.[Task_BalanceUpdDebitOthers]'

GO

----10. BalanceUpdDebitSports
EXEC sp_update_jobstep  @job_name=N'bodb02 : Task_BalanceUpdDebitSports',
						@step_id=1,---- @step_name=N'Task_BalanceUpdDebitSports'
						@command=N'EXEC dbo.[Task_BalanceUpdDebitSports]'

GO

----11. Ticket Voiding
EXEC sp_update_jobstep  @job_name=N'bodb02: Ticket Voiding',
						@step_id=1, -----@step_name=N'Void ticket'
						@command=N'EXEC dbo.TicketVoiding_Queue_Job'

GO

----12. Single Settlement
EXEC sp_update_jobstep @job_name=N'bodb02 : NAP Single Settlement', 
                       @step_id=1, ---- @step_name=N'Call NAP_Admin_Settlement_SB_Job'
                       @command=N'EXEC NAP_Admin_Settlement_SB_Job' 

GO
