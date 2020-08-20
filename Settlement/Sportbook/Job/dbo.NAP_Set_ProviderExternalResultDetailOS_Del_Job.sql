/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Set_ProviderExternalResultDetailOS_Del_Job]  
	@DateBefore INT
AS
/* 
	Created:20200820@Louisa
    Task: Cleanup data in ProviderExternalResultDetailOS [Redmine:#139627]
    DB: DBPRO/bodb02
	
	Revisions:
		- 20200820@Louisa: Cleanup data in ProviderExternalResultDetailOS [Redmine:#139627]

	Param's Explanation: 
*/
BEGIN

	DECLARE @batch INT = 1000
	DECLARE @last DATETIME  =  DATEADD( DAY, - @DateBefore , GETDATE() ) 

	WHILE (1=1)

	BEGIN

		DELETE TOP(@batch) FROM dbo.ProviderExternalResultDetailOS WITH(ROWLOCK, UPDLOCK)
		WHERE MatchID = 0
			AND CreateDate < @last

		IF @@ROWCOUNT = 0
			BREAK			

		WAITFOR DELAY '00:00:00:280'

	END
END
GO