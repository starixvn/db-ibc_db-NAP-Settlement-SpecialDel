/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Admin_Settlement_Betbuilder_Validation_Event
(
	 @matchid		INT = 0
	,@Action		VARCHAR(10)
	,@IsAuto		BIT = 0
	,@SelectedResources	VARCHAR(MAX) = NULL
	,@VendorID		SMALLINT = 34
	,@ErrCode		INT		 = 0 OUTPUT
	,@ErrMsg		NVARCHAR(300)  = ''    OUTPUT
	,@InvalidMarketId	VARCHAR(MAX) = ''  OUTPUT
)
AS
/*
	Created: 20220719@Louisa
    Task: Scale Out BetTrans [Redmine:#175251]
    DB: DBPRO/bodb02
	
	Revisions:
		- 20220719@Louisa: Validation event before settle 3rd [Redmine:#175251]

	Param's Explanation:
			Betbuider
				'<Resources><rsc m="1"/><rsc m="2"/><rsc m="3"/><rsc m="4"/><rsc m="5"/></Resources>'
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE  @sportType		INT
			,@AutoSetting	TINYINT
			,@xmlData		XML
			,@maxNumProcessBB	INT = 50000
	
	CREATE TABLE #tblMarketPush (marketID VARCHAR(20), Result VARCHAR(20), ResultStatusID TINYINT)
	CREATE TABLE #tblInvalidMarketID (marketID VARCHAR(20))
	DECLARE @tblMarketBB TABLE (marketID VARCHAR(20), Result VARCHAR(20), ResultStatusID TINYINT)

	SET @xmlData = CAST(@SelectedResources AS XML)
	
	SELECT @sportType 		= m.sportType
			,@AutoSetting	= ISNULL(m.AutoSetting, l.AutoSetting)
	FROM dbo.match m WITH(NOLOCK) 
		INNER JOIN dbo.league l WITH(NOLOCK)
			ON m.leagueid = l.leagueid
	WHERE m.matchid = @MatchId

	IF ISNULL(@sportType,0) = 0
	BEGIN
		SELECT	 @ErrCode	= 1000001
				,@ErrMsg	= 'Match does not exist!'			
		RETURN
	END 

	IF @IsAuto = 1 OR @action LIKE '%MARKET'
	BEGIN
		--parse XML				
		;WITH TmpData AS (
			SELECT T.C.value('@m', 'VARCHAR(20)') AS MarketID
			FROM @xmlData.nodes('/Resources/rsc') AS T(C)
		)
		INSERT INTO #tblMarketPush(marketID, ResultStatusID, Result)
		SELECT d.marketID, mk.ResultStatusID, mk.Result
		FROM TmpData d
			INNER JOIN dbo.SMP_Market mk WITH (NOLOCK) ON d.MarketID = mk.MarketID	
		WHERE mk.MatchID = @MatchID
			AND mk.VendorID = @VendorID
	END

	IF @isAuto = 1 
	BEGIN
		IF @AutoSetting & 8 = 0  -- 100 is setting of BetBuilder
		BEGIN
			SELECT	@ErrCode = 1001017
					,@ErrMsg = 'The auto-settlement failed due to OFF setting.'
			RETURN
		END
		
		--check number of marketID
		IF EXISTS (SELECT TOP 1 1 FROM #tblMarketPush HAVING COUNT(*) > @maxNumProcessBB) 
		BEGIN
			SELECT   @ErrCode = 1001010
					,@ErrMsg  = 'There are too many inputted results to proceed at one time. Please select each one to execute separately.'	
			RETURN 
		END
		--end check number of marketID		
		
		------------------------------check settled marketIDs-------------------
		DELETE r
		OUTPUT DELETED.MarketID INTO #tblInvalidMarketID
		FROM #tblMarketPush r
		WHERE r.ResultStatusID IN (2,5) --Manually settled, Auto Settled
				
	END

	IF @IsAuto = 1 OR @action LIKE '%MARKET'
	BEGIN
		--delete marketID does not have Result
		DELETE r
		OUTPUT DELETED.MarketID INTO #tblInvalidMarketID
		FROM #tblMarketPush r
		WHERE r.Result IS NULL
	END

	SET @InvalidMarketId = ''

	SELECT @InvalidMarketId = @InvalidMarketId + ',' + CAST(marketID AS VARCHAR(20))
	FROM #tblInvalidMarketID
			
	SET @InvalidMarketId = SUBSTRING(@InvalidMarketId, 2 , LEN(@InvalidMarketId))

END
GO