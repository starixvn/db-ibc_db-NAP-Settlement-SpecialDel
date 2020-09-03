/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Set_CleanUpResult_Job]  
AS
/* 
	Created:20200820@Louisa
    Task: Cleanup data in ProviderExternalResultDetailES [Redmine:#138656]
		  Cleanup data in ProviderExternalResultDetailOS [Redmine:#139627]
    DB: DBPRO/bodb02
	
	Revisions:
		- 20200820@Louisa: Cleanup data ES
		- 20200903@Louisa: Cleanup data OS [Redmine:#139627]

	Param's Explanation: 

*/
BEGIN

	DECLARE @batch INT = 1000
	DECLARE @compareDate DATETIME

	SET @compareDate =  CONVERT(VARCHAR(10),DATEADD (DAY, -7, GETDATE()), 102)
	
	--- ES 
	WHILE (1=1)
	BEGIN
		DELETE TOP(@batch) FROM dbo.ProviderExternalResultDetailES WITH(ROWLOCK, UPDLOCK)
		WHERE MatchID IN (0,-1)
			AND CreateDate < @compareDate
	
		IF @@ROWCOUNT = 0
			BREAK			

		WAITFOR DELAY '00:00:00:280'

	END

	--- OS
	WHILE (1=1)
	BEGIN

		DELETE TOP(@batch) FROM dbo.ProviderExternalResultDetailOS WITH(ROWLOCK, UPDLOCK)
		WHERE MatchID = 0
			AND CreateDate < @compareDate
	
		IF @@ROWCOUNT = 0
			BREAK			

		WAITFOR DELAY '00:00:00:280'
	END
END
GO