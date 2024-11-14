/*<info serverAlias="DBARC-bodb_Archive" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20241101@Aries
	Task:  Enhance Waiting time for the LastModifyDate column of ResultDetail table [Redmine:#212907]
	DB: DBARC-bodb_Archive

	Revision:
		- 20241101@Aries: Enhance Waiting time for the LastModifyDate column of ResultDetail table [Redmine:#212907]

*/
USE bodb_Archive
ALTER TABLE ProviderExternalResultDetail_bk ADD IsLive  BIT DEFAULT 0;
ALTER TABLE ProviderExternalResultDetailOS_bk ADD IsLive  BIT DEFAULT 0;
ALTER TABLE ProviderExternalResultDetailES_bk ADD IsLive  BIT DEFAULT 0;
