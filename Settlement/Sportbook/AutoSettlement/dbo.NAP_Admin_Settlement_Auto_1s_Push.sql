/*<info serverAlias="DBCTG-bodb02,DBSID-bodb02,DBSIC-bodb02" executers="wsv_nap,Dot_CoreAPI" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Auto_1s_Push]
	 @AdminId					INT				= 148		-- calculated by system (default)
	,@MatchId					INT
	,@SelectedResources			VARCHAR(MAX)	= '' 
	,@Action					VARCHAR(10)		= 'CAL'
	,@IsAuto					BIT				= 0
	,@IP						VARCHAR(15)		= ''
	,@IsReSettledTickets		BIT				= 1
	,@BroadcastSessionId		VARCHAR(50)		= NULL
	,@ErrCode					INT				= 0		OUTPUT
	,@ErrMsg					NVARCHAR(200)	= ''	OUTPUT
AS
/*	Creator: Jamie
	Date: 20150113
	Task: BetRadar Auto/Manual Settlement
	DB: DBTXN/BODB02
	Original: 
	
	Revisions:
		- 20151005@Kathy: add more UAT version for testing (UAT1,UAT2,UAT3,UAT4)
		- 20170425@Bobby: 72789 - Implement bonus system into NAP Settlement
		- 20190320@Kathy: Settlement with Tickets Exclusion [Redmine:#106823]
		- 20190620@Kathy: Remove auto betradar bettypes [Redmine:#109584]
		- 20200727@Kathy: Prevent refund wrong match [Redmine:#136390]
		- 20201111@Louisa: Prevent process if SettlementStatus turn on bit 1,2,3,5,7 [Redmine:#143441]
		- 20201113@Louisa: Check Hold Result [Redmine:#135097]
		- 20220228@Louisa: Allow insert command into Single_Calculate_Queue by group Action [Redmine:#168497]
		- 20211215@Kathy: Soccer - Include calculate parlay into calculate single tickets process [Redmine:#166072]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
		- 20240510@Aries: Enhance SOP-Refund for Soccer's Early results [Redmine:#201462]
		- 20241028@Aries: Direct payout for early soccer [Redmine:#211079]

	Param's Explanation:
		 @SelectedResources: <Resources>
						    	<Resource Id="" Home="" Away="" />
						    	<Resource Id="" Home="" Away="" />
						      </Resources>
*/		
BEGIN
	SET NOCOUNT ON 

	DECLARE	@matchcode		NVARCHAR(50)
			,@sporttype		INT
			,@leagueid		INT
			,@sqlCommand	NVARCHAR(MAX)
			,@procName		NVARCHAR(50)

	SELECT	 @matchcode		= m.matchcode
			,@sporttype		= m.sporttype
			,@leagueid		= m.leagueid
	FROM	dbo.match m WITH(NOLOCK)
	WHERE	m.matchid = @MatchId

	SELECT	 @ErrCode		= 0
			,@ErrMsg		= ''
			,@procName		= OBJECT_NAME(@@procid)
			,@sqlCommand	= 'EXEC [dbo].[NAP_Admin_Settlement_Auto_1s] @Matchid = ' + CONVERT(NVARCHAR(50), @MatchId) 
															+ ', @AdminId = ' + CONVERT(NVARCHAR(50), @AdminId) 
															+ ', @SelectedResources = ''' + @SelectedResources + ''''
															+ ', @Action = ''' + CONVERT(NVARCHAR(50), @Action) + ''''  	
															+ ', @IsAuto = ' + CONVERT(NVARCHAR(1), @IsAuto)
															+ ', @IP = ''' + CONVERT(VARCHAR(15), @IP) + '''' 
															+ ', @IsReSettledTickets = ' + CONVERT(NVARCHAR(50), @IsReSettledTickets) 	
															+ CASE WHEN @BroadcastSessionId IS NOT NULL 
																	THEN ', @BroadcastSessionId = ''' + @BroadcastSessionId + ''''
																	ELSE '' END
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
			SELECT  @ErrMsg	= @ErrMsg + ISNULL(ERROR_MESSAGE(),'')
				   ,@ErrCode= @ErrCode
			RETURN
		END CATCH
	END
	ELSE
	BEGIN
		INSERT INTO Single_Calculate_Queue (
			matchid
			,matchcode
			,IsCalculating
			,LeagueID
			,SportType
			,AdminId
			,IP
			,Action
			,sqlCommand
			,BroadcastSessionId
			)
		SELECT @MatchId
			,@matchcode
			,0
			,@leagueid
			,@sporttype
			,@AdminId
			,@IP
			,@Action + '-' + 'EARLY'
			,@sqlCommand
			,@BroadcastSessionId
	END

END
GO 
