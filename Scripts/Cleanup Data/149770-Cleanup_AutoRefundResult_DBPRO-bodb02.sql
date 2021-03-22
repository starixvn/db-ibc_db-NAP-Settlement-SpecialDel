/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/*
	Created:20210322@Louisa
    Task: Move data from AutoRefundResult to AutoRefundResult_bk [Redmine:#149770]
    DB: DBPRO/bodb02
	
	Revisions:
		- 20210322@Louisa: Step 2: Delete data in AutoRefundResult after insert manually into AutoRefundResult_bk [Redmine:#149770]
	
	Param's Explanation: 

*/

USE bodb02
GO

BEGIN

SET NOCOUNT ON

	DECLARE @batch INT = 1000
			,@min_AutoRefundResultId INT
	
	--- Get min data in Active
	SELECT  @min_AutoRefundResultId = MIN(r.AutoRefundResultId)
	FROM dbo.AutoRefundResult r WITH(NOLOCK)
		INNER JOIN dbo.match m WITH(NOLOCK)
				ON r.MatchId = m.matchid
	
	IF @min_AutoRefundResultId IS NULL
	RETURN

	--- Delete data
	WHILE (1=1)
	BEGIN
		DELETE TOP(@batch)
		FROM dbo.AutoRefundResult WITH(ROWLOCK, UPDLOCK)
		WHERE AutoRefundResultId < @min_AutoRefundResultId

		IF @@ROWCOUNT = 0
			BREAK			

		WAITFOR DELAY '00:00:00:280'

	END

END
GO

