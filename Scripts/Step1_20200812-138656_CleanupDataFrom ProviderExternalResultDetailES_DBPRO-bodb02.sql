/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created:20200812@Louisa
    Task: Cleanup data in ProviderExternalResultDetailES [Redmine:#138656]
    DB: DBPRO/bodb02
	
	Revisions:
		- 20200812@Louisa: Cleanup data in ProviderExternalResultDetailES [Redmine:#138656]
*/

USE [bodb02]
GO


IF OBJECT_ID('dbo.ProviderExternalResultDetailES', 'U') IS NOT NULL 

BEGIN

DECLARE @batch SMALLINT=1000

	WHILE (@batch > 0)

		BEGIN

			DELETE TOP(1000) FROM dbo.ProviderExternalResultDetailES

			SET @batch =@@ROWCOUNT

			WAITFOR DELAY '00:00:00:280'

		END

END
GO
