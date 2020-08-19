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

DECLARE @batch INT = 1000
declare @last datetime  =  dateadd( DAY, -7 , getdate() ) 

WHILE (1=1)

BEGIN

	DELETE TOP(@batch) FROM dbo.ProviderExternalResultDetailES
	WHERE MatchID IN (0,-1)
		AND CreateDate < @last

	IF @@ROWCOUNT = 0
		BREAK			

	WAITFOR DELAY '00:00:00:280'

END

GO