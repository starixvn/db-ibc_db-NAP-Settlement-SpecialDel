/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created by: 20210305@Louisa
	Task	  : SOP for Tennis [Redmine:#150425]
	DB		  : DBPRO/bodb02

	Revisions:
		20210305@Louisa: Add new column sporttype [Redmine:#150425]
*/

USE bodb02
GO


ALTER TABLE dbo.ProviderGameTypeMapping ADD sporttype SMALLINT NULL

GO