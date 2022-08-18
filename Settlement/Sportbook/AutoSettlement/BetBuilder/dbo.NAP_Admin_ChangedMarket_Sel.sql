/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_ChangedMarket_Sel]
	@matchID						INT
	,@VendorID						SMALLINT		= 34
	,@action						VARCHAR(20)		= 'CAL'
	,@SelectedSelection				VARCHAR(MAX)
	,@ResultStatusID				TINYINT			= 5
AS 
/*
	Created by:20190104@Vicky
	Task: Update SMP_Market
	DB: DBPRO/bodb02 

	Revision
		- 20190103@Vicky: Incorporate BetBuilder [Redmine:#106903]

	Param's Explanation:
			@SelectedSelection = '<Resources>
								<Resource Id="200" Result="WON"/>
								<Resource Id="201" Result="WON"/>
								<Resource Id="202" Result="WON"/>
								<Resource Id="203" Result="REFUND"/>
								<Resource Id="204" Result="LOSE"/>
						   </Resources>'
	Example:
			EXEC [dbo].[NAP_Admin_ChangedMarket_Sel] @MatchId	= 1
													,@action 	= 'CAL'
													,@SelectedSelection = '<Resources><Resource Id="200" Result="WON"/></Resources>'
													,@ResultStatusID = 5
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @xml XML
		, @ResultDefault VARCHAR(5) = 'Lose'

	DECLARE @tblSelectionType TABLE (selectionType INT, result VARCHAR(20))
	CREATE TABLE #tblMarketChecking (MarketID VARCHAR(20) PRIMARY KEY, result VARCHAR(20), ResultStatusID TINYINT)
	CREATE TABLE #tblMarket (MarketID VARCHAR(20) PRIMARY KEY)
	
	----------------------------------------------------------------------------
	SET @xml = CAST(@SelectedSelection AS XML)
	
	;WITH TmpData AS (
		SELECT T.C.value('@Id', 'INT') AS selectionType
				,T.C.value('@Result', 'VARCHAR(20)') AS result
		FROM @xml.nodes('/Resources/Resource') AS T(C)
	)
	INSERT INTO @tblSelectionType (selectionType, Result)
	SELECT	TmpData.selectionType, TmpData.Result
	FROM TmpData

	INSERT INTO #tblMarket (MarketID)
	SELECT DISTINCT ms.marketID 
	FROM @tblSelectionType sl
		INNER JOIN dbo.SMP_MarketSelection ms WITH (NOLOCK) ON ms.SelectionType = sl.SelectionType
	WHERE ms.MatchID = @matchID
								
	--get marketID from selection
	;WITH cteFilter AS (
		SELECT	ms.MarketID
				,MAX(CASE
						WHEN sl.selectionType IS NULL THEN
								CASE 
									WHEN ms.ResultStatusID IN (0,1) THEN '0_' + ms.Result
									WHEN ms.Result = 'REFUND' 		THEN '9_' + ms.Result
									WHEN ms.Result IS NULL 			THEN '8_NULL'
									WHEN ms.Result = 'LOSE' 		THEN '7_' + ms.Result
									WHEN ms.Result = 'WON'			THEN '6_' + ms.Result
									ELSE '7_' + @ResultDefault END
						ELSE 
								CASE
									WHEN sl.Result = 'REFUND'	THEN '9_' + ms.Result
									WHEN sl.Result IS NULL 		THEN '8_NULL'
									WHEN sl.Result = 'LOSE' 	THEN '7_' + ms.Result
									WHEN sl.Result = 'WON'		THEN '6_' + ms.Result
									ELSE '7_' + @ResultDefault END
						END
					) AS Result --priority: REFUND, RUNNING, LOSE, WON
				, MAX(CASE 
							WHEN sl.Result = 'REFUND' 								 THEN '9_5'
							WHEN ms.Result = 'REFUND' AND ResultStatusID NOT IN(0,1) THEN '8_5' --+ CAST(ResultStatusID AS VARCHAR)
							WHEN sl.SelectionType IS NOT NULL AND @Action='CAL'		 THEN '0_5'
							WHEN sl.SelectionType IS NOT NULL AND @Action='UNDO'	 THEN '7_3'
							WHEN ms.ResultStatusID = 3 								 THEN '7_3'
							WHEN ms.ResultStatusID = 0 								 THEN '6_0'
							WHEN ms.ResultStatusID = 1 								 THEN '5_1'
							ELSE '0_5' END
					) AS ResultStatusID
		FROM dbo.SMP_MarketSelection ms WITH (NOLOCK)
			LEFT JOIN @tblSelectionType sl ON ms.SelectionType = sl.SelectionType
		WHERE ms.MatchID = @matchID 
			AND ms.MarketID IN (SELECT ms.marketID 
								FROM #tblMarket ms
								)
		GROUP BY ms.MarketID
	)
	,cteResult AS(
		SELECT MarketID
				,CASE WHEN STUFF(Result, 1, 2, '') = 'NULL' THEN NULL ELSE STUFF(Result, 1, 2, '') END AS Result
				,CASE WHEN STUFF(ResultStatusID, 1, 2, '') = 'NULL' THEN NULL ELSE STUFF(ResultStatusID, 1, 2, '') END AS ResultStatusID
		FROM cteFilter
	)
	
	INSERT INTO #tblMarketChecking(MarketID, Result, ResultStatusID)
	SELECT MarketID, Result, ResultStatusID
	FROM cteResult
	
	
	
	SELECT mc.MarketID
	FROM #tblMarketChecking mc
		INNER JOIN dbo.SMP_Market mk WITH (NOLOCK) ON mk.marketID = mc.MarketID
	WHERE mk.MatchID = @MatchID
		AND mk.VendorID = @VendorID
		AND 1 = CASE --WHEN mk.Result IS NULL AND mc.Result IS NULL AND mk.ResultStatusID = mc.ResultStatusID THEN 0
					 WHEN @action = 'UNDO' AND mk.Result = 'REFUND' AND mc.Result = 'REFUND' THEN 0
					 WHEN mc.ResultStatusID IN (3,5) THEN 1
					 --WHEN mc.Result IS NOT NULL AND mk.ResultStatusID IN (0,1) THEN 1
					 ELSE 0 END

END
GO

