/*<info serverAlias="DBBAH-BalanceRecord" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: July@20200928
	Task: TVS - Resettled Affected Tickets [Redmine: #138552]
	DB: DBBAH/BalanceRecord
*/
USE [BalanceRecord]
GO
CREATE USER [bodbAdminNet] FOR LOGIN [bodbAdminNet]
GO
GRANT SELECT ON BalanceRecord_bk TO bodbAdminNet
GO