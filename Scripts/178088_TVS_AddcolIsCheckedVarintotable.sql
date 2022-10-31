/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20221020@July
	Task: [TVS] Add column IsCheckedVar into TicketVoiding_MessageTemplateSetting  - [Redmine: #178088]
	DB: DBCTG-bodb02
	Replication DB061: pub:DBTrans_API_Data
*/

USE bodb02
GO
--Add column IsCheckedVar into dbo.TicketVoiding_MessageTemplateSetting
ALTER TABLE dbo.TicketVoiding_MessageTemplateSetting ADD IsCheckedVar BIT
