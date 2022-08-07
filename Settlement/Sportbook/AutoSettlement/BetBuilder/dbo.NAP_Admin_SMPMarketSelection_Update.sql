/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet,Dot_Intg" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_SMPMarketSelection_Update]
	@matchID						INT
	,@action						VARCHAR(20)			= 'CAL'
	,@resultStatusId				TINYINT				= 5
	,@Resources						VARCHAR(MAX)
AS 
/*
	Created by:20190104@Vicky
	Task: Update SMP_MarketSelection
	DB: DBPRO/bodb02 

	Revision
		- 20190103@Vicky: Incorporate BetBuilder [Redmine:#106903]

	Param's Explanation:
			@Resources = '<Resources>
								<Resource Id="200" Result="WON"/>
								<Resource Id="201" Result="WON"/>
								<Resource Id="202" Result="WON"/>
								<Resource Id="203" Result="REFUND"/>
								<Resource Id="204" Result="LOSE"/>
						   </Resources>
						   </Resources>'
	Example:
			EXEC [dbo].[NAP_Admin_SMPMarketSelection_Update] @MatchId	= 1
												  ,@action = 'CAL'
												  ,@resultStatusId = 2
												  ,@Resources = '<Resources><Resource Id="200" Result="WON"/><Resource Id="201" Result="LOSE"/></Resources>'
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @xml XML
	CREATE TABLE #tblData (marketSelectionID BIGINT, Result VARCHAR(20), PRIMARY KEY CLUSTERED(marketSelectionID) )
	----------------------------------------------------------------------------
	
	SET @xml = CAST(@Resources AS XML)
	;WITH cteData AS (
		SELECT T.C.value('@Id', 'BIGINT') AS marketSelectionId
			   ,T.C.value('@Result', 'VARCHAR(20)') AS result
		FROM @xml.nodes('/Resources/Resource') AS T(C)
	)
	INSERT INTO #tblData(marketSelectionID, result)
	SELECT marketSelectionId, result
	FROM cteData
	
	UPDATE ms 
	SET resultStatusId = ISNULL(@ResultStatusId, ResultStatusId)
		,result = CASE WHEN @action LIKE 'UNDO%' THEN NULL
					   ELSE ISNULL(cte.result, ms.result)
					   END
	FROM dbo.SMP_MarketSelection ms WITH (ROWLOCK, UPDLOCK) 
		INNER JOIN #tblData cte ON cte.marketSelectionId = ms.marketSelectionId
END
GO

