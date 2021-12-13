/*<info serverAlias="DBTXN-msdb" executers="bodbAdminNet" isFunction="0"></info>*/
/*	
	Created by: Max
	Date 20211116
	Task: [TVS] Void abnormal bet of parlay
	DB: DBTXN/msdb - Stop Job bodb02 : TicketVoiding - VoidBets Automation
*/

USE [msdb]
GO

--Stop job
EXEC dbo.sp_stop_job N'bodb02 : TicketVoiding - VoidBets Automation';
GO

