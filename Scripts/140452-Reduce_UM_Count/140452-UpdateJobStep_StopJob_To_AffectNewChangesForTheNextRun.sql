/*<info serverAlias="DBTXN-msdb" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by:20200930@Helen
    Task: Reduce UM Count & Write Job History Log Into Disk on NAP Settlement [Redmine:#140452]
    DB: DBTXN/msdb

	Revision:
		- 20200930@Helen: Reduce insert job history into disk - stop job to affect new job changes for the next start [Redmine:#140452]
		- 20201020@Louisa: Reduce UM Count - stop 10 jobs to affect new job changes for the next start [Redmine:#140452]

*/
USE [msdb]
GO
--1
EXEC dbo.sp_stop_job N'bodb02 : NAP Parlay Settlement';
GO
--2
EXEC dbo.sp_stop_job N'bodb02 : NAP Single Settlement 3rd';
GO
----3
--EXEC dbo.sp_stop_job N'bodb02: NAP NG2 Settlement';
--GO
--4
EXEC dbo.sp_stop_job N'bodb02 : Task_BalanceUpdBonusCredit';
GO
--5
EXEC dbo.sp_stop_job N'bodb02 : Task_BalanceUpdCreditCasino';
GO
--6
EXEC dbo.sp_stop_job N'bodb02 : Task_BalanceUpdCreditOthers';
GO
--7
EXEC dbo.sp_stop_job N'bodb02 : Task_BalanceUpdCreditSports';
GO
--8
EXEC dbo.sp_stop_job N'bodb02 : Task_BalanceUpdDebitCasino';
GO
--9
EXEC dbo.sp_stop_job N'bodb02 : Task_BalanceUpdDebitOthers';
GO
--10
EXEC dbo.sp_stop_job N'bodb02 : Task_BalanceUpdDebitSports';
GO
--11
EXEC dbo.sp_stop_job N'bodb02: Ticket Voiding';
GO
----12
--EXEC dbo.sp_stop_job N'bodb02 : NAP Single Settlement';
--GO

     