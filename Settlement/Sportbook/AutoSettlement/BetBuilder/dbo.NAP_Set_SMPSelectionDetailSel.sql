/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_SMPSelectionDetailSel]
	@matchID 			INT
	,@Resources		VARCHAR(MAX) = NULL
AS
/*
	Created by: 20190103@Vicky
	Task: Incorporate BetBuilder 
	DB: DBPRO.BODB02
	
	Revisions:
		- 20190103@Vicky: Incorporate BetBuilder  [Redmine:#106903]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]		
		
	Param's Explanation:
		@TicketStatus
			'<Resources>
					<Resource Id="200" s="1"/>
			</Resources>'


*/
BEGIN
	SET NOCOUNT ON
	
	
	DECLARE @tblMarketID TABLE (MarketID VARCHAR(20) NOT NULL PRIMARY KEY, IsRunning TINYINT)
	DECLARE @FixtureID VARCHAR(20)
			,@xmlData	XML
	----------------------------------------------------------------------------
	IF ISNULL(@Resources,'') = ''
	RETURN

	SET @xmlData = CAST(@Resources AS XML )

	INSERT INTO @tblMarketID (MarketID, IsRunning)
	SELECT T.C.value('@Id', 'VARCHAR(20) ') AS MarketID
 		  ,T.C.value('@s','TINYINT') as TINYINT
 	FROM @xmlData.nodes('/Resources/Resource') AS T(C)

	;WITH cteMarket AS (
		SELECT	ms.SelectionType
				,COUNT(DISTINCT ms.Result)  AS countResult			--count all result (not count NULL value)
				,MAX(ISNULL(ms.Result,'')) AS Result
				,MAX(CASE ISNULL(ms.ResultStatusID,0)
								WHEN 0 THEN '9_1' 					--Intial
								WHEN 1 THEN '9_1' 					--Running
								WHEN 3 THEN '9_1' 					--UNDO
								WHEN 5 THEN '8_5'					--Completed (Manual)
								WHEN 2 THEN '7_2'					--Completed (Auto)
								ELSE '0_1' END) AS ResultStatusID	--Running
				,MAX(m.IsRunning) AS IsRunning
		FROM @tblMarketID m
			INNER JOIN dbo.SMP_MarketSelection ms WITH (NOLOCK) ON m.MarketID = ms.MarketID
		WHERE ms.matchID = @matchID
		GROUP BY ms.SelectionType
	)
	SELECT	m.SelectionType
			,s.SelectionName
			,CASE WHEN countResult > 1 THEN '' ELSE Result	END				AS Result
			,CASE WHEN countResult > 1 THEN 1 ELSE 0 END 					AS IsDifferentResult
			,STUFF(ResultStatusID, 1, 2, '') 								AS ResultStatusID
			,CASE WHEN m.IsRunning = 1 THEN 'Running' ELSE 'Calculated' END AS TicketStatus
	FROM dbo.SMP_Selection s WITH (NOLOCK)
		INNER JOIN cteMarket m ON m.SelectionType = s.SelectionType
	ORDER BY s.SelectionName
	
END
GO

