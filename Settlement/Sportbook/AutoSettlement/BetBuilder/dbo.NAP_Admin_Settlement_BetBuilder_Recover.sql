/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_BetBuilder_Recover]
	 @AdminId			INT				
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
		- 20200713@Kathy: Add more param for function f_Set_Calculate_modds [Redmine:#135846]
		
	Param's Explanation:
				  
		@Resources = '<Resources>
							<Resource Id="200"/>
							<Resource Id="201"/>
					  </Resources>'
					  Id: Bettrans.transID
		
		Example:
			
			DECLARE @ErrCode INT,@ErrMsg NVARCHAR(200)
			SELECT @ErrCode = 0, @ErrMsg = ''
				EXEC [dbo].[NAP_Admin_Settlement_BetBuilder_Recover] 
									@AdminId = 8
									,@Resources = '<Resources><Resource Id="200"/></Resources>'
									,@ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT
			SELECT @ErrCode,@ErrMsg
*/	
BEGIN
	SET NOCOUNT ON
		
	DECLARE --------hard code---------------------------------------------------
			@pfID				SMALLINT		= 38
			,@ActionID			INT				= 81009
			--------------------------------------------------------------------
			,@transIDs			VARCHAR(MAX)
			,@xml				XML
			,@minMarketID 		VARCHAR(20)
			,@maxMarketID		VARCHAR(20)

  	
	CREATE TABLE #tblTransID (transID BIGINT, matchID INT, marketID VARCHAR(20)
							  , modds SMALLMONEY, result VARCHAR(20))
	----------------------------------------------------------------------------
	
	SELECT @ErrCode = 0,@ErrMsg = ''
	
  	------------------------------------------get transID ----------------------
	SET @xml = CAST(@Resources AS XML)
			
	;WITH TmpData AS (
		SELECT T.C.value('@Id', 'BIGINT') AS transID
		FROM @xml.nodes('/Resources/Resource') AS T(C)
	)
	INSERT INTO #tblTransID (transID, matchID, marketID)
	SELECT	d.transID, bt.matchID, bt.betcheck
	FROM TmpData d
		INNER JOIN dbo.Bettrans bt WITH (NOLOCK) ON d.transID = bt.transID	


	--get result & cal modds
	UPDATE t 
	SET Result = mk.Result
  		,modds = m.modds
	FROM #tblTransID t 
		INNER JOIN DBPRO.bodb02.dbo.SMP_Market mk WITH (NOLOCK) ON t.matchID = mk.matchID AND t.marketID = mk.marketID
		CROSS APPLY dbo.f_Set_Calculate_modds(@pfID, NULL, NULL, NULL, mk.Result, NULL, NULL, NULL, NULL, NULL) m
	WHERE mk.VendorID = 34
		AND mk.ResultStatusID NOT IN (0,1)


	----------UNDO--------------------------------------------------------------
	SET @transIDs 			= (SELECT transID		AS '@t'
							   FROM #tblTransID
							   WHERE Result IS NULL
							   FOR XML PATH('r'), ROOT( 'root' ))
	
	IF ISNULL(@transIDs,'') <> ''
		 EXEC dbo.NAP_Admin_Calculate_Main
			@matchid = 0
			,@action = 'UNDO'
			,@IsSettingByProfile = 1
			,@strTransIds = @TransIDs	
		
	----------REFUND------------------------------------------------------------
	SET @transIDs 			= (SELECT transID		AS '@t'
							   FROM #tblTransID
							   WHERE Result = 'REFUND'
							   FOR XML PATH('r'), ROOT( 'root' ))
	
	IF ISNULL(@transIDs,'') <> ''
		 EXEC dbo.NAP_Admin_Calculate_Main
			@matchid = 0
			,@action = 'REFUND'
			,@IsSettingByProfile = 1
			,@strTransIds = @TransIDs		
		
	---------------CAL----------------------------------------------------------
	SET @transIDs 			= (SELECT transID		AS '@t'
									  ,modds		AS '@m'
									  ,1			AS '@ot'
							   FROM #tblTransID
							   WHERE Result IS NOT NULL AND Result <> 'REFUND'
							   FOR XML PATH('r'), ROOT( 'root' ))
	
	IF ISNULL(@transIDs,'') <> ''
		 EXEC dbo.NAP_Admin_Calculate_Main
			@matchid = 0
			,@action = 'CAL'
			,@IsSettingByProfile = 1
			,@strTransIds = @TransIDs
END
GO