/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*	
	Created by: Max
	Date 20210907
	Task: [TVS] Support Max Payout Per Match setting - [Redmine: #158846]
	DB: DBTXN/bodb02 - Add one more step on the job vndba:Check slowly parlay settlement, calling SP
*/
USE bodb02
GO
EXEC Nap_Admin_CustLimitBet_Notification_Job
GO
