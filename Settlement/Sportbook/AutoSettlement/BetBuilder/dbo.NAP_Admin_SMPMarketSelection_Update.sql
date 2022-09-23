/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet,Dot_Intg" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_SMPMarketSelection_Update]
	@matchID						INT
	,@action						VARCHAR(20)			= 'CAL'
	,@resultStatusId				TINYINT				= 5
	,@SelectedMarket				VARCHAR(MAX)		= NULL
	,@SelectedSelection				VARCHAR(MAX)		= NULL
AS 
/*
	Created by:20190104@Vicky
	Task: Update SMP_MarketSelection
	DB: DBPRO/bodb02 

	Revision
		- 20190103@Vicky: Incorporate BetBuilder [Redmine:#106903]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]

	Param's Explanation:
			@SelectedSelection = '<Resources>
								<Resource Id="200" Result="WON"/>
								<Resource Id="201" Result="WON"/>
								<Resource Id="202" Result="WON"/>
								<Resource Id="203" Result="REFUND"/>
								<Resource Id="204" Result="LOSE"/>
						   </Resources>
			@SelectedMarket: <Resources>
				            <rsc m="1"/>
				            <rsc m="2"/>
				            <rsc m="3"/>
				            <rsc m="4"/>
				            <rsc m="5"/>
				         </Resources>

	Example:
			EXEC [dbo].[NAP_Admin_SMPMarketSelection_Update] @MatchId	= 1
												  ,@action = 'CAL'
												  ,@resultStatusId = 2
												  ,@SelectedSelection = '<Resources><Resource Id="200" Result="WON"/><Resource Id="201" Result="LOSE"/></Resources>'
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @xml XML
	CREATE TABLE #tblData (marketSelectionID BIGINT, Result VARCHAR(20), PRIMARY KEY CLUSTERED(marketSelectionID) )
	----------------------------------------------------------------------------
	
	IF ISNULL(@SelectedSelection,'') <> '' 
	BEGIN
		SET @xml = CAST(@SelectedSelection AS XML)
		
		;WITH cteData AS (
			SELECT T.C.value('@Id', 'BIGINT') AS SelectionType
				   ,T.C.value('@Result', 'VARCHAR(20)') AS result
			FROM @xml.nodes('/Resources/Resource') AS T(C)
		)
		INSERT INTO #tblData(marketSelectionID, result)
		SELECT ms.marketSelectionId, c.result
		FROM cteData c
			INNER JOIN dbo.SMP_MarketSelection ms WITH(NOLOCK)
				ON ms.SelectionType = c.SelectionType
		WHERE	ms.MatchId = @matchID
	END
	ELSE IF ISNULL(@SelectedMarket,'') <> '' 
	BEGIN
		SET @xml = CAST(@SelectedMarket AS XML)

		;WITH cteData AS (
			SELECT T.C.value('@m', 'VARCHAR(20)') AS marketId
			FROM @xml.nodes('/Resources/rsc') AS T(C)
		)
		INSERT INTO #tblData (marketSelectionID)
		SELECT	ml.marketSelectionID
		FROM	dbo.SMP_MarketSelection ml WITH (NOLOCK)
		WHERE	EXISTS (SELECT MarketID FROM cteData c WHERE ml.MarketID = c.MarketID)
				AND ml.MatchID = @MatchID
	END

	UPDATE ms 
	SET resultStatusId = ISNULL(@ResultStatusId, ResultStatusId)
		,result = CASE WHEN @action LIKE 'UNDO%' THEN NULL
					   ELSE ISNULL(cte.result, ms.result)
					   END
	FROM dbo.SMP_MarketSelection ms WITH (ROWLOCK, UPDLOCK) 
		INNER JOIN #tblData cte ON cte.marketSelectionId = ms.marketSelectionId
END
GO

