/*<info serverAlias="DBARC-bodb_Archive" executers="" viewers="" isFunction="0"></info>*/
/*
    Created: 20241223@Aries
	Task: Support Auto Refund for Soccer's Early Results [Redmine:#214410]
	DB: DBARC/bodb_Archive
*/
USE bodb_Archive;
ALTER TABLE dbo.AutoRefundResult_bk ADD ResourceId  VARCHAR(20);
ALTER TABLE dbo.AutoRefundResult_bk ADD HomeValue VARCHAR(50)
ALTER TABLE dbo.AutoRefundResult_bk ADD AwayValue VARCHAR(50)