/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_MarketSelection_Sel]
	@matchID						INT
	,@action						VARCHAR(20)			= 'CAL'
	,@SelectedSelection				VARCHAR(MAX)
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
							   </Resources>'
	Example:
			EXEC [dbo].[NAP_Admin_MarketSelection_Sel] @MatchId	= 1
													  ,@action = 'CAL'
													  ,@SelectedSelection = '<Resources><Resource Id="200" Result="WON"/></Resources>'
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @xml XML
	DECLARE @tblData TABLE (selectionType INT, result VARCHAR(20), PRIMARY KEY(selectionType))
	----------------------------------------------------------------------------
	SET @xml = CAST(@SelectedSelection AS XML)
	
	;WITH TmpData AS (
		SELECT T.C.value('@Id', 'INT') AS selectionType
			   ,T.C.value('@Result', 'VARCHAR(20)') AS result
		FROM @xml.nodes('/Resources/Resource') AS T(C)
	)
	INSERT INTO @tblData (selectionType, result )
	SELECT selectionType, result
	FROM TmpData
	
	SELECT	ms.marketSelectionID, d.Result
	FROM @tblData d
		INNER JOIN dbo.SMP_MarketSelection ms WITH (NOLOCK) ON ms.selectionType = d.selectionType
	WHERE ms.MatchID = @MatchID
	
END
GO

