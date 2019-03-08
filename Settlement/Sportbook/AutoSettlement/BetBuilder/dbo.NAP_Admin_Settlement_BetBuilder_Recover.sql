/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_BetBuilder_Recover]
	 @AdminId			INT				
	,@MatchId			INT
	,@Resources			VARCHAR(MAX)	
	,@IP				VARCHAR(15)		= ''
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			NVARCHAR(200)	= ''	OUTPUT
AS
/*	Creator: Vicky
	Date: 20181228
	Task: Incorporate BetBuilder
	DB: DBTXN/BODB02
	
	Revisions:
		- 20190103@Vicky: Incorporate BetBuilder  [Redmine:#106903]
		
	Param's Explanation:
				  
		@Resources = '<Resources>
							<Resource Id="200"/>
							<Resource Id="201"/>
					  </Resources>'
					  Id: Bettrans.transID
		
		Example:
			
			DECLARE @ErrCode INT,@ErrMsg NVARCHAR(200)
			SELECT @ErrCode = 0, @ErrMsg = ''
				EXEC [dbo].[NAP_Admin_Settlement_BetBuilder_Recover] @MatchId	= 1
															  ,@AdminId = 8
															  ,@Resources = '<Resources><Resource Id="200"/></Resources>'
															  ,@ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT
			SELECT @ErrCode,@ErrMsg
*/	
BEGIN
	SET NOCOUNT ON
		
	DECLARE --------hard code---------------------------------------------------
			@Bettype			INT				= 38
			,@pfID				SMALLINT		= 38
			,@ActionID			INT				= 81009
			,@sportType 		INT				= 1
			--------------------------------------------------------------------			
			,@transIDs			VARCHAR(MAX)
			,@xml				XML
			,@minMarketID 		VARCHAR(20)
			,@maxMarketID		VARCHAR(20)

  	
	CREATE TABLE #tblTransID (transID BIGINT, marketID VARCHAR(20), modds SMALLMONEY, result VARCHAR(20))
	CREATE TABLE #tblMarket (marketID VARCHAR(20), result VARCHAR(20), modds SMALLINT
							,UNIQUE CLUSTERED (marketID)
							)
	----------------------------------------------------------------------------
	
	SELECT @ErrCode = 0,@ErrMsg = ''
	
  	------------------------------------------get transID ----------------------
	SET @xml = CAST(@Resources AS XML)
			
	;WITH TmpData AS (
		SELECT T.C.value('@Id', 'BIGINT') AS transID
		FROM @xml.nodes('/Resources/Resource') AS T(C)
	)
	INSERT INTO #tblTransID (transID, marketID)
	SELECT	d.transID, bt.betcheck
	FROM TmpData d
		INNER JOIN dbo.Bettrans bt WITH (NOLOCK) ON d.transID = bt.transID	

		
	SELECT @minMarketID = MIN(marketID)
		   ,@maxMarketID = MAX(marketID)
	FROM #tblTransID
	
	
	--get result of market & cal modds
	INSERT INTO #tblMarket (marketID, Result, modds)
	SELECT DISTINCT bt.marketID
					,mk.Result
					,m.modds
	FROM #tblTransID bt
		INNER JOIN DBPRO.bodb02.dbo.SMP_Market mk WITH (NOLOCK) ON bt.MarketID = mk.MarketID
		CROSS APPLY dbo.f_Set_Calculate_modds(@pfID, NULL, NULL, NULL, mk.Result, NULL, NULL, NULL) m
	WHERE mk.MatchID = @MatchID 
			AND mk.MarketID BETWEEN @minMarketID AND @maxMarketID
			AND mk.VendorID = 34
			AND mk.ResultStatusID NOT IN (0,1)
		
			
	--update #tblTransID
  	UPDATE #tblTransID
  	SET Result = mk.Result
  		,modds = mk.modds
  	FROM #tblTransID b
  		INNER JOIN #tblMarket mk ON b.MarketID = mk.MarketID

  		
	----------UNDO--------------------------------------------------------------
	SET @transIDs 	= (SELECT transID		AS '@t'
							   FROM #tblTransID
							   WHERE Result IS NULL
							   FOR XML PATH('r'), ROOT( 'root' ))
	
	IF ISNULL(@transIDs,'') <> ''
		EXEC [dbo].[NAP_Admin_Settlement_TransIDs]
								@matchID				= @matchID
								,@sportType				= @sporttype
								,@transIDs				= @transIDs
								,@Action				= 'UNDO'
								,@ActionID				= @actionID
								,@ErrCode				= @ErrCode		OUTPUT
								,@ErrMsg				= @ErrMsg		OUTPUT
	IF @ErrCode <> 0
		RETURN
	
		
	----------REFUND------------------------------------------------------------
	SET @transIDs 	= (SELECT transID		AS '@t'
							   FROM #tblTransID
							   WHERE Result = 'REFUND'
							   FOR XML PATH('r'), ROOT( 'root' ))
	
	IF ISNULL(@transIDs,'') <> ''
		EXEC [dbo].[NAP_Admin_Settlement_TransIDs]
								@matchID				= @matchID
								,@sportType				= @sporttype
								,@transIDs				= @transIDs
								,@Action				= 'REFUND'
								,@ActionID				= @actionID
								,@ErrCode				= @ErrCode		OUTPUT
								,@ErrMsg				= @ErrMsg		OUTPUT
	IF @ErrCode <> 0
		RETURN				
		
		
	---------------CAL----------------------------------------------------------
	SET @transIDs 	= (SELECT transID		AS '@t'
									  ,modds		AS '@m'
									  ,1			AS '@ot'
							   FROM #tblTransID
							   WHERE Result IS NOT NULL AND Result <> 'REFUND'
							   FOR XML PATH('r'), ROOT( 'root' ))
	
	IF ISNULL(@transIDs,'') <> ''
		EXEC [dbo].[NAP_Admin_Settlement_TransIDs]
								@matchID				= @matchID
								,@sportType				= @sporttype
								,@transIDs				= @transIDs
								,@Action				= 'CAL'
								,@ActionID				= @actionID
								,@ErrCode				= @ErrCode		OUTPUT
								,@ErrMsg				= @ErrMsg		OUTPUT
	
END
GO