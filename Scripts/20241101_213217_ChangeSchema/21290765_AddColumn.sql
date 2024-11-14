/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20241101@Aries
	Task:  Enhance Waiting time for the LastModifyDate column of ResultDetail table [Redmine:#212907]
	DB: DBPRO-bodb02

	Revision:
		- 20241101@Aries: Enhance Waiting time for the LastModifyDate column of ResultDetail table [Redmine:#212907]

*/
USE bodb02;
ALTER TABLE ProviderExternalResultDetail ADD IsLive  BIT DEFAULT 0;
ALTER TABLE ProviderExternalResultDetail14 ADD IsLive  BIT DEFAULT 0;


GO
USE bodb02;
ALTER TABLE ProviderExternalResultDetailOS ADD IsLive  BIT DEFAULT 0;
ALTER TABLE ProviderExternalResultDetailOS14 ADD IsLive  BIT DEFAULT 0;


GO
USE bodb02;
ALTER TABLE ProviderExternalResultDetailES ADD IsLive  BIT DEFAULT 0;
ALTER TABLE ProviderExternalResultDetailES14 ADD IsLive  BIT DEFAULT 0;