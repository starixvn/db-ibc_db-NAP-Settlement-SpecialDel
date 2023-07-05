/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20230706@July
	Task: [TVS] Drop SP/tables are not needed on sitedb3 and all sitedb  [Redmine:#190859]  
	DB: DBSIG-bodb02
	
*/
USE bodb02
GO
--Drop SP only SITEDB3

USE bodb02
GO

DECLARE @SPName VARCHAR(MAX)
DECLARE @tmpSPName TABLE ( SPName VARCHAR(MAX), IsDrop BIT)

INSERT INTO @tmpSPName (SPName)
SELECT 'DROP PROCEDURE ' +name
 FROM dbo.sysobjects
 WHERE (type = 'P')
 AND (
	name LIKE 'TicketVoiding_RequestDetail_AB_Update%'
OR  name LIKE 'TicketVoiding_RequestDetail_ARC_Update%'
OR  name LIKE 'TicketVoiding_RequestDetail_DARC_Update%'
OR  name LIKE 'TicketVoiding_RequestDetail_HDP_Update%'
OR  name LIKE 'TicketVoiding_RequestDetail_KO_Update%'
OR  name LIKE 'TicketVoiding_RequestDetail_OU_Update%'
OR  name LIKE 'TicketVoiding_RequestDetail_WC_Update%'
OR  name LIKE 'TicketVoiding_RequestInfo_Copy%'
OR  name LIKE 'TicketVoiding_PoolHouseTicket_Select%'
OR  name LIKE 'TicketVoiding_ManageVoidServices_VoidingHistory_Select%'
OR  name LIKE 'TicketVoiding_CheckVoidBetPermission%'
)
SELECT * FROM @tmpSPName
WHILE (1=1)
BEGIN
	UPDATE TOP (1) @tmpSPName
	SET @SPName = SPName, IsDrop = 1
	WHERE IsDrop IS NULL

	IF @@ROWCOUNT = 0 BREAK;
	
	EXEC (@SPName)

END
