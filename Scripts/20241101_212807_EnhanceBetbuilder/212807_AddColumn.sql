/*<info serverAlias="DBPRO-bodb02,DBM2STAGE-bodb_Odds,DBODDSN1-bodb_odds,DBODDSN2-bodb_odds,IHRDISTC1-ReplDB" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20241101@Aries
	Task:  Enhance the rule for settle by selection of Betbuilder [Redmine:#212807]
	DB: DBPRO-bodb02,DBM2STAGE-bodb_Odds,DBODDSN1-bodb_odds,DBODDSN2-bodb_odds,IHRDISTC1-ReplDB

	Revision:
		- 20241101@Aries: Enhance the rule for settle by selection of Betbuilder [Redmine:#212807]

*/
ALTER TABLE SMP_Market ADD LiveIndicator  BIT;
ALTER TABLE SMP_Market ADD  CONSTRAINT [DF_SMP_Market_LiveIndicator]  DEFAULT ((0)) FOR [LiveIndicator]
GO
ALTER TABLE SMP_Market14 ADD LiveIndicator  BIT;
ALTER TABLE SMP_Market14 ADD  CONSTRAINT [DF_SMP_Market14_LiveIndicator]  DEFAULT ((0)) FOR [LiveIndicator]