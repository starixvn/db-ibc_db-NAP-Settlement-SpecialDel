/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet,Dot_Intg" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_BetBuilder_Push]
	 @AdminId			INT				= 148		-- calculated by system (default)
	,@MatchId			INT
	,@Resources			VARCHAR(MAX)	= ''  
	,@Action			VARCHAR(10)		= 'CAL'
	,@IsAuto			BIT				= 1
	,@VendorID			SMALLINT		= 34
	,@IP				VARCHAR(15)		= ''
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			NVARCHAR(200)	= ''	OUTPUT
	,@SettledMarketIDs	VARCHAR(MAX)	= ''	OUTPUT
AS
/*	Creator: Vicky
	Date: 20181228
	Task: BetBuilder Auto/Manual Settlement
	DB: DBTXN/BODB02
	
	Revisions:
		- 20190103@Vicky: Incorporate BetBuilder  [Redmine:#106903] 
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
		
	Param's Explanation:
		@Action : CAL, UNDO, 
				  CAL_MARKET: settle by marketIDs, ignore validation, @IsAuto should be = 0
				  
		IF @IsAuto = 1 OR @Action IN (CAL_MARKET)
			@Resources = '<Resources>
				            <rsc m="1"/>
				            <rsc m="2"/>
				            <rsc m="3"/>
				            <rsc m="4"/>
				            <rsc m="5"/>
				         </Resources>'
			
		------------------------------------------------------------------------
		IF @IsAuto = 0			  
			@Resources = '<Resources>
								<Resource Id="200" Result="WON"/>
								<Resource Id="201" Result="WON"/>
								<Resource Id="202" Result="WON"/>
								<Resource Id="203" Result="REFUND"/>
								<Resource Id="204" Result="LOSE"/>
						   </Resources>'
		
		
		Example:
			--------------------settle by auto
			DECLARE @ErrCode INT,@ErrMsg NVARCHAR(200)
			SELECT @ErrCode = 0, @ErrMsg = ''
			EXEC [dbo].[NAP_Admin_Settlement_BetBuilder_Push] @MatchId	= 1
															  ,@Action	= 'CAL'
															  ,@IsAuto	= 1
															  ,@Resources = '<Resources><rsc m="1"/><rsc m="2"/><rsc m="3"/><rsc m="4"/><rsc m="5"/></Resources>'
															  ,@ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT
			SELECT @ErrCode,@ErrMsg
			
			
			
			--------------------settle by MARKET 		
			DECLARE @ErrCode INT,@ErrMsg NVARCHAR(200)
			SELECT @ErrCode = 0, @ErrMsg = ''												         
			EXEC [dbo].[NAP_Admin_Settlement_BetBuilder_Push] @MatchId	= 1
															  ,@Action	= 'CAL_MARKET'
															  ,@IsAuto	= 0
															  ,@Resources = '<Resources><rsc m="1"/><rsc m="2"/><rsc m="3"/><rsc m="4"/><rsc m="5"/></Resources>'
															  ,@ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT
			SELECT @ErrCode,@ErrMsg
			
			
			
			-------------------settle by manual
			DECLARE @ErrCode INT,@ErrMsg NVARCHAR(200)
			SELECT @ErrCode = 0, @ErrMsg = ''
			EXEC [dbo].[NAP_Admin_Settlement_BetBuilder_Push] @MatchId	= 1
															  ,@Action	= 'CAL'
															  ,@IsAuto	= 0
															  ,@Resources = '<Resources><Resource Id="200" Result="WON"/><Resource Id="203" Result="REFUND"/></Resources>'
															  ,@ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT
			SELECT @ErrCode,@ErrMsg
*/		
BEGIN
	SET NOCOUNT ON 

	DECLARE	 @matchcode			NVARCHAR(50)
			,@sporttype			INT
			,@leagueid			INT
			,@procName			NVARCHAR(50)
			,@xml				XML
			,@AutoSetting		TINYINT
			,@sqlCommand		NVARCHAR(MAX)
			,@ActionID			INT
			-------------------------------------
			,@maxNumProcess		INT 			= 50000
			
	CREATE TABLE #tblMarketPush (marketID VARCHAR(20), Result VARCHAR(20), ResultStatusID TINYINT)
	CREATE TABLE #tblInvalidMarketID (marketID VARCHAR(20))
	----------------------------------------------------------------------------
	SELECT @ErrCode		= 0
		   ,@ErrMsg		= '' 

	IF @Action LIKE '%_MARKET'
		SET @IsAuto = 0
		
		
	SELECT	 @matchcode		= m.matchcode
			,@sporttype		= m.sporttype
			,@leagueid		= m.leagueid
			,@AutoSetting   = m.AutoSetting
	FROM	DBPRO.bodb02.dbo.match m WITH(NOLOCK)
	WHERE	m.matchid = @MatchId
		
	SELECT @ActionID = CASE
						  WHEN @Action IN ('CAL','CAL_MARKET')  AND @IsAuto = 0 THEN 81009
						  WHEN @Action = 'UNDO' AND @IsAuto = 0 THEN 81010
						  WHEN @Action = 'CAL'  AND @IsAuto = 1 THEN 81012
						  ELSE 0
					   END
					   
	IF @IsAuto = 1 OR @action LIKE '%MARKET'
	BEGIN
		--parse XML
		SET @xml = CAST(@Resources AS XML)
				
		;WITH TmpData AS (
			SELECT T.C.value('@m', 'VARCHAR(20)') AS MarketID
			FROM @xml.nodes('/Resources/rsc') AS T(C)
		)
		INSERT INTO #tblMarketPush(marketID, ResultStatusID, Result)
		SELECT d.marketID, mk.ResultStatusID, mk.Result
		FROM TmpData d
			INNER JOIN DBPRO.bodb02.dbo.SMP_Market mk WITH (NOLOCK) ON d.MarketID = mk.MarketID	
		WHERE mk.MatchID = @MatchID
			AND mk.VendorID = @VendorID
	END 
	
	IF @isAuto = 1 
	BEGIN
 	
		------------------------------check settled marketIDs-------------------
		DELETE r
		OUTPUT DELETED.MarketID INTO #tblInvalidMarketID
		FROM #tblMarketPush r
		WHERE r.ResultStatusID IN (2,5) --Manually settled, Auto Settled
			
		IF EXISTS (SELECT TOP 1 1 FROM #tblInvalidMarketID)
		BEGIN
			
			SET @SettledMarketIDs = ''
			SELECT @SettledMarketIDs = @SettledMarketIDs + ',' + CAST(marketID AS VARCHAR(20))
			FROM #tblInvalidMarketID
			
			SET @SettledMarketIDs = SUBSTRING(@SettledMarketIDs, 2 , LEN(@SettledMarketIDs))	
			
			IF @SettledMarketIDs IS NOT NULL AND @SettledMarketIDs <> ''
			BEGIN
				SELECT @ErrCode = 1000007
		       			,@ErrMsg = ISNULL(@ErrMsg,'') + 'MarketIDs cannot be auto settled since they have been settled already: ' + SUBSTRING(@SettledMarketIDs,1,125) + '... '
			END		       
		END 		
	END
	
	
	IF @IsAuto = 1 OR @action LIKE '%MARKET'
	BEGIN
		
		--delete marketID does not have Result
		DELETE r
		FROM #tblMarketPush r
		WHERE r.Result IS NULL
	
		
		IF NOT EXISTS (SELECT TOP 1 1 FROM #tblMarketPush)
			RETURN
	
			
		--parse data to XML
		SET @Resources = (SELECT MarketID   AS '@m'
						  FROM #tblMarketPush r
						  FOR XML PATH('rsc'), ROOT('Resources'))
	END 	
	
				  
	SELECT	@procName		= OBJECT_NAME(@@procid)
			,@sqlCommand	= 'EXEC [dbo].[NAP_Admin_Settlement_BetBuilder] @Matchid = ' + CONVERT(NVARCHAR(50), @MatchId) 
															+ ', @AdminId = ' + CONVERT(NVARCHAR(50), @AdminId) 
															+ ', @Resources = ''' + CONVERT(VARCHAR(MAX), @Resources) + ''''
															+ ', @Action = ''' + CONVERT(NVARCHAR(50), @Action) + ''''
															+ ', @IsAuto = ' + CONVERT(NVARCHAR(50), @IsAuto)
															+ ', @VendorID = ' + CONVERT(NVARCHAR(50), @VendorID)
															+ ', @IP = ''' + CONVERT(VARCHAR(15), @IP) + ''''
															+ ', @ErrCode = @ErrCode OUTPUT' 
															+ ', @ErrMsg = @ErrMsg OUTPUT'

														
	
	IF (@procName LIKE '%_xtest' OR @procName LIKE '%_xpre' OR @procName LIKE '%_UAT_') -- UAT1 -->UAT9
	BEGIN
		BEGIN TRY

			EXEC sys.sp_executesql @sqlCommand
				,N'@ErrMsg VARCHAR(400) OUTPUT, @ErrCode int OUTPUT'
				,@ErrMsg	= @ErrMsg OUTPUT
				,@ErrCode	= @ErrCode OUTPUT

				IF ISNULL(@ErrCode,'') = '' AND @SettledMarketIDs IS NOT NULL AND @SettledMarketIDs <> ''
				BEGIN
					SELECT @ErrCode = 1000007
			       			,@ErrMsg = ISNULL(@ErrMsg,'') + 'MarketIDs cannot be auto settled since they have been settled already: ' + @SettledMarketIDs + '. '
				END
		END TRY

		BEGIN CATCH
			SELECT  @ErrMsg	= ISNULL(@ErrMsg, '') + ISNULL(ERROR_MESSAGE(),'')
				   ,@ErrCode = @@error
			RETURN
		END CATCH
	END
	ELSE
	BEGIN
		
		INSERT INTO Single_Calculate_Queue_3rd (
			matchid
			,matchcode
			,IsCalculating
			,LeagueID
			,SportType
			,AdminId
			,IP
			,Action
			,sqlCommand
			,ActionID
			)
		SELECT @MatchId
			   ,@matchcode
			   ,0
			   ,@leagueid
			   ,@sporttype
			   ,@AdminId
			   ,@IP
			   ,@Action
			   ,@sqlCommand
			   ,@ActionID
	END
END
GO
