/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet,Dot_Intg" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_BetBuilder_Push]
	 @AdminId			INT				= 148		-- calculated by system (default)
	,@MatchId			INT
	,@SelectedMarket	VARCHAR(MAX)	= NULL
	,@SelectedSelection	VARCHAR(MAX)	= NULL
	,@Action			VARCHAR(10)		= 'CAL'
	,@IsAuto			BIT				= 1
	,@VendorID			SMALLINT		= 34
	,@IP				VARCHAR(15)		= ''
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			NVARCHAR(200)	= ''	OUTPUT

AS
/*	Creator: Vicky
	Date: 20181228
	Task: BetBuilder Auto/Manual Settlement
	DB: DBTXN/BODB02
	
	Revisions:
		- 20190103@Vicky: Incorporate BetBuilder  [Redmine:#106903] 
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
		
	Param's Explanation:
		@Action : CAL, UNDO
				
		@SelectedMarket: <Resources>
				            <rsc m="200342" />
				            <rsc m="200462" />
				         </Resources>
*/		
BEGIN
	SET NOCOUNT ON 

	DECLARE	 @matchcode			NVARCHAR(50)
			,@sporttype			INT
			,@leagueid			INT
			,@procName			NVARCHAR(50)
			,@sqlCommand		NVARCHAR(MAX)
			,@ActionID			INT
			
	SELECT @ErrCode		= 0
		   ,@ErrMsg		= '' 

	SELECT	 @matchcode		= m.matchcode
			,@sporttype		= m.sporttype
			,@leagueid		= m.leagueid			
	FROM	DBPRO.bodb02.dbo.match m WITH(NOLOCK)
	WHERE	m.matchid = @MatchId
		
	SELECT @ActionID = CASE
						  WHEN @Action = 'CAL' AND @IsAuto = 0 THEN 81009
						  WHEN @Action = 'UNDO' AND @IsAuto = 0 THEN 81010
						  WHEN @Action = 'CAL'  AND @IsAuto = 1 THEN 81012
						  ELSE 0
					   END
					   
	SELECT	@procName		= OBJECT_NAME(@@procid)
			,@sqlCommand	= 'EXEC [dbo].[NAP_Admin_Settlement_BetBuilder] @Matchid = ' + CONVERT(NVARCHAR(50), @MatchId) 
									+ ', @AdminId = ' + CONVERT(NVARCHAR(50), @AdminId) 								
									+ ', @SelectedMarket = ''' + CONVERT(VARCHAR(MAX), @SelectedMarket) + '''' 
									+ CASE WHEN @SelectedSelection IS NOT NULL THEN + ', @SelectedSelection = ''' + CONVERT(VARCHAR(MAX), @SelectedSelection) + '''' ELSE '' END
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
