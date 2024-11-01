/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap,Dot_Intg" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_SMPMarket_Update]
	@matchID						INT
	,@VendorID						SMALLINT			= 34
	,@resultStatusId				TINYINT				= NULL
	,@SelectedMarket				VARCHAR(MAX)
AS 
/*
	Created by:20190104@Vicky
	Task: Update SMP_Market
	DB: DBPRO/bodb02 

	Revision
		- 20190103@Vicky: Incorporate BetBuilder [Redmine:#106903]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
		- 20240905@Aries: Enhance the settlement by Selection for Betbuilder  [Redmine:#208782]
		- 20241101@Aries: Enhance the rule for settle by selection of Betbuilder [Redmine:#212807]

	Param's Explanation:
			@SelectedMarket = '<Resources>
				            <rsc m="1"/>
				            <rsc m="2"/>
				            <rsc m="3"/>
				            <rsc m="4"/>
				            <rsc m="5"/>
				         </Resources>'
	Example:
			EXEC [dbo].[NAP_Admin_SMPMarket_Update] @MatchId	= 1
												  ,@resultStatusId = 2
												  ,@SelectedMarket = '<Resources><Resource m="200"/></Resources>'
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @xml XML
		, @ResultDefaultIsLive	VARCHAR(6) = 'Refund'
		, @ResultDefaultNoneLive VARCHAR(6) = 'Lose'
	CREATE TABLE #tblData (marketID VARCHAR(20), result VARCHAR(20), ResultStatusID TINYINT, PRIMARY KEY CLUSTERED(marketID) )
	----------------------------------------------------------------------------
	SET @xml = CAST(@SelectedMarket AS XML)

	;WITH cteData AS (
		SELECT T.C.value('@m', 'VARCHAR(20)') AS marketID
		FROM @xml.nodes('/Resources/rsc') AS T(C)
	)	
	INSERT INTO #tblData (marketID, Result, ResultStatusID)
	SELECT marketID
		,CASE WHEN STUFF(Result, 1, 2, '') = 'NULL' THEN NULL ELSE STUFF(Result, 1, 2, '') END AS Result
		,STUFF(ResultStatusID, 1, 2, '') AS ResultStatusID
	FROM
		(SELECT cteData.marketID
				,MAX(CASE
						WHEN ms.Result = IIF(mk.LiveIndicator = 1 ,'REFUND','LOSE') AND ms.ResultStatusID IN (2,5)	THEN '7_' + ms.Result
						WHEN ms.Result IS NULL 										THEN '8_NULL'
						WHEN ms.Result = IIF(mk.LiveIndicator = 1 ,'LOSE','REFUND') AND ms.ResultStatusID IN (2,5)		THEN '9_' + ms.Result
						WHEN ms.Result = 'WON'  AND ms.ResultStatusID IN (2,5)		THEN '6_' + ms.Result
						ELSE '5_' + IIF(mk.LiveIndicator = 1 ,@ResultDefaultIsLive,@ResultDefaultNoneLive) END
					 ) AS Result --priority: LOSE,RUNNING, REFUND,  LOSE, WON
				,MAX(CASE
						--WHEN ms.Result = 'REFUND' AND ms.ResultStatusID = 5			THEN '9_5' --manual Refund
						--WHEN ms.Result = 'REFUND' AND ms.ResultStatusID = 2			THEN '8_2' --auto Refund
						WHEN ms.Result = IIF(mk.LiveIndicator = 1 ,'LOSE','REFUND') AND ms.ResultStatusID = 2			THEN '9_2' --LOSE
						WHEN ms.Result = IIF(mk.LiveIndicator = 1 ,'LOSE','REFUND') AND ms.ResultStatusID = 5			THEN '9_5' --LOSE
						WHEN ms.ResultStatusID = 3									THEN '8_3' --UNDO
						WHEN ms.ResultStatusID = 0									THEN '7_0' --inital
						WHEN ms.ResultStatusID = 1									THEN '6_1' --keyin
						WHEN @resultStatusId = 2									THEN '0_2'
						ELSE '0_5' END
					 ) AS ResultStatusID --priority: LOSE,RUNNING, REFUND,  LOSE, WON
		FROM cteData
			INNER JOIN dbo.SMP_MarketSelection ms WITH (NOLOCK) ON ms.marketID = cteData.marketID
			CROSS APPLY (SELECT TOP 1 ISNULL(m.LiveIndicator,0) AS  LiveIndicator 
						 FROM dbo.SMP_Market AS m   WITH (NOLOCK) 
						 WHERE ms.marketID = m.marketID AND m.MatchID = @matchID
						) AS mk
		WHERE ms.MatchID = @MatchID
		GROUP BY cteData.marketID
		) AS t
	
	
	--update Result
	UPDATE m 
	SET ResultStatusID = CASE WHEN m.Result IS NOT NULL AND d.Result IS NULL THEN 3 --UNCAL
							  --WHEN d.Result IS NOT NULL THEN 5
	  						  ELSE d.ResultStatusID END
		,Result = d.Result
		,UpdateTime = CURRENT_TIMESTAMP
	FROM dbo.SMP_Market m WITH (ROWLOCK, UPDLOCK) 
		INNER JOIN #tblData d ON d.marketID = m.marketID
	WHERE m.matchID	= @matchID AND m.VendorID = @VendorID
	
END
GO

