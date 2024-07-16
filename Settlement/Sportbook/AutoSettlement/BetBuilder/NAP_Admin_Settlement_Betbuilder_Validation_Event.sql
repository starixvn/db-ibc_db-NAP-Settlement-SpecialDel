/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Admin_Settlement_Betbuilder_Validation_Event
(
	 @matchid			INT			= 0
	,@Action			VARCHAR(10)
	,@IsAuto			BIT			= 0
	,@SelectedMarket	VARCHAR(MAX)
	,@VendorID			SMALLINT	= 34
	,@ErrCode			INT			= 0			OUTPUT
	,@ErrMsg			NVARCHAR(300) = ''		OUTPUT
	,@InvalidMarketId	VARCHAR(MAX)= ''		OUTPUT
	,@NoResultMarketId	VARCHAR(MAX)= ''		OUTPUT
)
AS
/*
	Created: 20220719@Louisa
    Task: Scale Out BetTrans [Redmine:#175251]
    DB: DBPRO/bodb02
	
	Revisions:
		- 20220719@Louisa: Validation event before settle 3rd [Redmine:#175251]
		- 20240625@Aries: Enhance the error message when settle with the NULL result for Bebuilder [Redmine:#206992]

	Param's Explanation:
	@SelectedMarket
				'<Resources><rsc m="1"/><rsc m="2"/><rsc m="3"/><rsc m="4"/><rsc m="5"/></Resources>'
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE  @sportType		INT
			,@AutoSetting	TINYINT
			,@xmlData		XML
			,@maxNumProcessBB	INT = 50000
	
	CREATE TABLE #tblMarketPush (marketID VARCHAR(20), Result VARCHAR(20), ResultStatusID TINYINT)
	CREATE TABLE #tblInvalidMarketID (marketID VARCHAR(20), Flag TINYINT)
	DECLARE @tblMarketBB TABLE (marketID VARCHAR(20), Result VARCHAR(20), ResultStatusID TINYINT)

	SET @xmlData = CAST(@SelectedMarket AS XML)
	
	SELECT @sportType 		= m.sportType
			,@AutoSetting	= ISNULL(m.AutoSetting, l.AutoSetting)
	FROM	dbo.match m WITH(NOLOCK) 
		INNER JOIN dbo.league l WITH(NOLOCK)
			ON m.leagueid = l.leagueid
	WHERE	m.matchid = @MatchId

	IF ISNULL(@sportType,0) = 0
	BEGIN
		SELECT	 @ErrCode	= 1000001
				,@ErrMsg	= 'Match does not exist!'			
		RETURN
	END 

	IF @IsAuto = 1 
	BEGIN
		IF @AutoSetting & 8 = 0  -- 100 is setting of BetBuilder
		BEGIN
			SELECT	@ErrCode = 1001017
					,@ErrMsg = 'The auto-settlement failed due to OFF setting.'
			RETURN
		END

		--parse XML				
		;WITH TmpData AS (
			SELECT T.C.value('@m', 'VARCHAR(20)') AS MarketID
			FROM @xmlData.nodes('/Resources/rsc') AS T(C)
		)
		INSERT INTO #tblMarketPush(marketID, ResultStatusID, Result)
		SELECT	d.marketID, mk.ResultStatusID, mk.Result
		FROM	TmpData d
			INNER JOIN dbo.SMP_Market mk WITH (NOLOCK) 
				ON	d.MarketID = mk.MarketID	
		WHERE	mk.MatchID = @MatchID
				AND mk.VendorID = @VendorID

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
		OUTPUT DELETED.MarketID, 1
		INTO #tblInvalidMarketID(MarketID,Flag)
		FROM #tblMarketPush r
		WHERE r.ResultStatusID IN (2,5) --Manually settled, Auto Settled
				
		--delete marketID does not have Result
		DELETE r
		OUTPUT DELETED.MarketID,2
		INTO #tblInvalidMarketID(MarketID,Flag)
		FROM #tblMarketPush r
		WHERE r.Result IS NULL

		SELECT @InvalidMarketId = ISNULL(@InvalidMarketId,'') + ',' + CAST(marketID AS VARCHAR(20))
		FROM #tblInvalidMarketID
		WHERE Flag = 1
			
		IF ISNULL(@InvalidMarketId,'') <> ''
			SET @InvalidMarketId = SUBSTRING(@InvalidMarketId, 2 , LEN(@InvalidMarketId))

		SELECT @NoResultMarketId = ISNULL(@NoResultMarketId,'') + ',' + CAST(marketID AS VARCHAR(20))
		FROM #tblInvalidMarketID
		WHERE Flag = 2
			
		IF ISNULL(@NoResultMarketId,'') <> ''
			SET @NoResultMarketId = SUBSTRING(@NoResultMarketId, 2 , LEN(@NoResultMarketId))
	END
END
GO