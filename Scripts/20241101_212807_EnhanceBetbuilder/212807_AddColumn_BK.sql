/*<info serverAlias="DBARC-bodb_Archive" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20241101@Aries
	Task:  Enhance the rule for settle by selection of Betbuilder [Redmine:#212807]
	DB: DBARC-bodb_Archive

	Revision:
		- 20241101@Aries: Enhance the rule for settle by selection of Betbuilder [Redmine:#212807]

*/
USE bodb_Archive;
ALTER TABLE SMP_Market_bk ADD LiveIndicator  BIT;
ALTER TABLE SMP_Market_bk ADD  CONSTRAINT [DF_SMP_Market_bk_LiveIndicator]  DEFAULT ((0)) FOR [LiveIndicator]