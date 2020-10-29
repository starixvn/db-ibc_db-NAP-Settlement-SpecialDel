/*<info serverAlias="DBTXN-msdb" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by:20201019@Louisa
    Task: Reduce UM Count [Redmine:#140452]
    DB: DBTXN/msdb

	Revision:
		- 20201019@Louisa: Reduce UM Count for 11 Jobs [Redmine:#140452]

*/
   
 USE [msdb]
GO


----1. Parlay Settlement
EXEC sp_update_jobstep @job_name=N'bodb02 : NAP Parlay Settlement', 
                       @step_id=1, ---- @step_name=N'[NAP_Admin_Settlement_MP_Job]'
                       @command=N'EXEC dbo.NAP_Admin_Settlement_Job  @Jobname = ''bodb02 : NAP Parlay Settlement''
									,@Waitfordelay = ''00:00:00.280''' 

GO

----2. Single Settlement 3rd
EXEC sp_update_jobstep @job_name=N'bodb02 : NAP Single Settlement 3rd',
						@step_id=1, ----@step_name=N'Call NAP_Admin_Settlement_3rd_Job'
						@command=N'EXEC dbo.NAP_Admin_Settlement_Job  @Jobname = ''bodb02 : NAP Single Settlement 3rd''
									,@Waitfordelay = ''00:00:00.100'''

GO

----3. BalanceUpdBonusCredit
EXEC sp_update_jobstep  @job_name=N'bodb02 : Task_BalanceUpdBonusCredit', 
						@step_id=1, ----@step_name=N'Task_BalanceUpdBonusCredit'
						@command=N'EXEC dbo.NAP_Admin_Settlement_Job  @Jobname = ''bodb02 : Task_BalanceUpdBonusCredit'''

GO

----4. BalanceUpdCreditCasino
EXEC sp_update_jobstep  @job_name=N'bodb02 : Task_BalanceUpdCreditCasino',
						@step_id=1, ----@step_name=N'Task_BalanceUpdCreditCasino'
						@command=N'EXEC dbo.NAP_Admin_Settlement_Job  @Jobname = ''bodb02 : Task_BalanceUpdCreditCasino'''

GO

----5. BalanceUpdCreditOthers
EXEC sp_update_jobstep   @job_name=N'bodb02 : Task_BalanceUpdCreditOthers',
						 @step_id=1, ----@step_name=N'Task_BalanceUpdCreditOthers'
						 @command=N'EXEC dbo.NAP_Admin_Settlement_Job  @Jobname = ''bodb02 : Task_BalanceUpdCreditOthers'''

GO

----6. BalanceUpdCreditSports
EXEC sp_update_jobstep   @job_name=N'bodb02 : Task_BalanceUpdCreditSports',
						 @step_id=1, ----@step_name=N'Task_BalanceUpdCreditSports'
						 @command=N'EXEC dbo.NAP_Admin_Settlement_Job  @Jobname = ''bodb02 : Task_BalanceUpdCreditSports'''

GO

----7. BalanceUpdDebitCasino
EXEC sp_update_jobstep  @job_name=N'bodb02 : Task_BalanceUpdDebitCasino',
						@step_id=1, ----@step_name=N'Task_BalanceUpdDebitCasino'
						@command=N'EXEC dbo.NAP_Admin_Settlement_Job  @Jobname = ''bodb02 : Task_BalanceUpdDebitCasino'''

GO

----8. BalanceUpdDebitOthers
EXEC sp_update_jobstep  @job_name=N'bodb02 : Task_BalanceUpdDebitOthers',
						@step_id=1, ----@step_name=N'Task_BalanceUpdDebitOthers'
						@command=N'EXEC dbo.NAP_Admin_Settlement_Job  @Jobname = ''bodb02 : Task_BalanceUpdDebitOthers'''

GO

----9. BalanceUpdDebitSports
EXEC sp_update_jobstep  @job_name=N'bodb02 : Task_BalanceUpdDebitSports',
						@step_id=1,---- @step_name=N'Task_BalanceUpdDebitSports'
						@command=N'EXEC dbo.NAP_Admin_Settlement_Job  @Jobname = ''bodb02 : Task_BalanceUpdDebitSports'''

GO

----10. Ticket Voiding
EXEC sp_update_jobstep  @job_name=N'bodb02: Ticket Voiding',
						@step_id=1, -----@step_name=N'Void ticket'
						@command=N'EXEC dbo.NAP_Admin_Settlement_Job  @Jobname = ''bodb02: Ticket Voiding''
									,@Waitfordelay = ''00:00:00.280'''

GO