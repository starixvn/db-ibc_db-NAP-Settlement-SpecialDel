/*<info serverAlias="DBARC-bodb_Archive" executers="" viewers="" isFunction="0"></info>*/
/*
    Created: 20241028@Aries
	Task: Direct payout for early soccer [Redmine:#211079]
	DB: DBARC/bodb_Archive
*/
USE bodb_Archive;
ALTER TABLE AutoPayoutResult_bk ADD ResourceId  VARCHAR(20);