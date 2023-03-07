/*<info serverAlias="DBLOG-bodb_CustomerLog_archive" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
USE bodb_CustomerLog_archive
GO
ALTER TABLE Single_Calculate_Queue_bk ADD SiteDBGroupId SMALLINT
GO

ALTER TABLE Parlay_Calculate_Queue_bk ADD SiteDBGroupId SMALLINT