/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Admin_Settlement_Validation_BB 
(
	 @matchid		INT = 0
	,@Action		VARCHAR(10)
	,@SelectedResources	VARCHAR(MAX) = NULL 
	,@maxNumProcess	INT = 50000
	,@VendorID		SMALLINT		= 34
	,@ErrCode		INT				= 0     OUTPUT
	,@ErrMsg		NVARCHAR(300)   = ''    OUTPUT
)
AS
/*
	Created: 20220719@Louisa
    Task: Scale Out BetTrans [Redmine:#175251]
    DB: DBPRO/bodb02
	
	Revisions:
		- 20220719@Louisa: Validation Betbuider  [Redmine:#175251]

	Param's Explanation:
		@SelectedResources: 
				'<Resources><rsc m="1"/><rsc m="2"/><rsc m="3"/><rsc m="4"/><rsc m="5"/></Resources>'
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @xmlResourceResult		XML
			,@xmlData				VARCHAR(MAX)

	DECLARE @tblMarketPush TABLE (marketID VARCHAR(20), Result VARCHAR(20), ResultStatusID TINYINT)

	SET @xmlResourceResult = CAST(@SelectedResources AS XML)					

	;WITH TmpData AS (
		SELECT T.C.value('@m', 'VARCHAR(20)') AS MarketID
		FROM @xmlResourceResult.nodes('/Resources/rsc') AS T(C)
	)
	INSERT INTO @tblMarketPush  (marketID, Result, ResultStatusID )
	SELECT d.marketID, mk.ResultStatusID, mk.Result
	FROM TmpData d
		INNER JOIN dbo.SMP_Market mk WITH (NOLOCK) ON d.MarketID = mk.MarketID	
	WHERE mk.MatchID = @MatchID
		AND mk.VendorID = @VendorID
			 
	--check number of marketID
	IF EXISTS (SELECT TOP 1 1 FROM @tblMarketPush HAVING COUNT(*) > @maxNumProcess ) 
	BEGIN
		SELECT   @ErrCode = 1001010
				,@ErrMsg  = 'There are too many inputted results to proceed at one time. Please select each one to execute separately.'	
		RETURN 
	END

END