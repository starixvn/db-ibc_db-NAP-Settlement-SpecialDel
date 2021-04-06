/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created by: 20210305@Louisa
	Task	  : SOP for Tennis [Redmine:#150425]
	DB		  : DBPRO/bodb02

	Revisions:
		20210305@Louisa: Update sporttype [Redmine:#150425]
*/

USE bodb02
GO
	
	IF EXISTS(	SELECT 1 
				FROM sys.columns 
				WHERE Name = N'sporttype'		---new column
				AND Object_ID = Object_ID(N'ProviderGameTypeMapping')
			)
	BEGIN

		UPDATE dbo.ProviderGameTypeMapping WITH( ROWLOCK, UPDLOCK)
		SET sporttype = 43 
		WHERE GameType IN ( 1, 2, 3, 4, 99 )

	END

GO