/*<info serverAlias="DBSID-bodb02,DBSIC-bodb02,DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20250819@Max
	Task: Support Onelab team to review and grant permission for SP_Dot Member_ - [Redmine: #235985]
	DB: DBSID-bodb02,DBSIC-bodb02,DBCTG-bodb02
*/

USE bodb02
GO

GRANT EXECUTE ON [dbo].[NAP_Set_NotificationIns] TO [oneseal_integration]
GO