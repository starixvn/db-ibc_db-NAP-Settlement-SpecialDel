/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created:20200820@Louisa
    Task: Cleanup data in ProviderExternalResultDetailOS [Redmine:#139627]
    DB: DBPRO/bodb02
	
	Revisions:
		- 20200820@Louisa: Cleanup data in ProviderExternalResultDetailOS [Redmine:#139627]
	
	Param's Explanation: 
		- Cleanup one time after QC test done
*/

USE [bodb02]
GO

DECLARE @batch INT = 1000

WHILE (1=1)

BEGIN

	DELETE TOP(@batch) FROM dbo.ProviderExternalResultDetailOS

	IF @@ROWCOUNT = 0
		BREAK			

	WAITFOR DELAY '00:00:00:280'

END

GO