/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Profile_Push]
	 @AdminId			INT				
	,@MatchId			INT
	,@SelectedResources	VARCHAR(MAX)	 
	,@Action			VARCHAR(10)		= 'CAL'
	,@IP				VARCHAR(15)		= ''
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			NVARCHAR(200)	= ''	OUTPUT
AS
/*	Creator: 20180821@Vicky
	Task: Settlement for sport in profile
	DB: DBTXN/BODB02
	
	Revisions:
		- 20180801@Vicky: Incorporate eSports 2.0 [Redmine #95874] 
		
	Param's Explanation:
		  @SelectedResources: <Resources>
						    	<Resource Id="M1" Home="1" Away="3" />
						    	<Resource Id="M2" Home="2" Away="4" />
						      </Resources>
*/		
BEGIN
	SET NOCOUNT ON 

	DECLARE	 @matchcode				NVARCHAR(50)
			,@sporttype				INT
			,@leagueid				INT
			,@sqlCommand			NVARCHAR(MAX)
			,@procName				NVARCHAR(50)
			,@IsSystemSettlement	BIT = NULL
			,@handle 				INT
	DECLARE @tmpSelectedRID 		TABLE (ResourceID VARCHAR(20), isFinal BIT, GroupType VARCHAR(2))
								  

	SELECT	 @matchcode		= m.matchcode
			,@sporttype		= m.sporttype
			,@leagueid		= m.leagueid
	FROM	dbo.match m WITH(NOLOCK)
	WHERE	m.matchid = @MatchId

	IF @@ROWCOUNT = 0
	BEGIN
		SELECT	 @ErrCode	= 1001001
				,@ErrMsg	= 'Match does not exist!'
		RETURN
	END

	IF EXISTS (
			SELECT 1
			FROM Single_Calculate_Queue s WITH (NOLOCK)
			WHERE s.matchid = @matchid 
			AND s.IsCalculating IN (0, 1)
			) OR EXISTS (
			SELECT 1
			FROM Parlay_Calculate_Queue p WITH (NOLOCK)
			WHERE p.matchid = @matchid 
			AND p.IsCalculating IN (0, 1)
			)
	BEGIN
		SELECT	 @ErrCode = 1001003
				,@ErrMsg	= 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'

		RETURN
	END

	-- check waiting ticket
	EXEC NAP_Admin_Settlement_Checking
		@MatchId = @MatchId
		,@Action = @Action
		,@Mode = 'CAL'
		,@xmlData = @SelectedResources
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT
	IF @ErrCode <> 0
	BEGIN
		SELECT @ErrCode
			,@ErrMsg
		
		RETURN
	END

	SELECT	 @ErrCode		= 0
			,@ErrMsg		= ''
			,@procName		= OBJECT_NAME(@@procid)
			,@sqlCommand	= 'EXEC [dbo].[NAP_Admin_Settlement_Profile] @Matchid = ' + CONVERT(NVARCHAR(50), @MatchId) 
															+ ', @creator = ' + CONVERT(NVARCHAR(50), @AdminId) 
															+ ', @SelectedResources = ''' + CONVERT(VARCHAR(MAX), @SelectedResources) + ''''
															+ ', @Action = ''' + CONVERT(NVARCHAR(50), @Action) + ''''
															+ ', @IP = ''' + CONVERT(VARCHAR(15), @IP) + '''' 
															+ ', @ErrCode = @ErrCode OUTPUT' 
															+ ', @ErrMsg = @ErrMsg OUTPUT'


	EXEC sp_xml_preparedocument @handle OUTPUT, @SelectedResources
	INSERT INTO @tmpSelectedRID(ResourceID, isFinal, GroupType)
	SELECT DISTINCT Id, sd.isFinal, sd.GroupType
	FROM OPENXML(@handle,'Resources/Resource',1) WITH( Id	VARCHAR(20) ) AS tbl
		LEFT JOIN dbo.f_Set_MajorRound(@Sporttype) sd ON tbl.Id = sd.ResourceID
	EXEC sp_xml_removedocument @handle
	
	
	---check FT round
  	SELECT TOP 1 @IsSystemSettlement = CASE
										WHEN @Action = 'UNDO' 	THEN 0
										WHEN @Action IN ('CAL', 'REFUND') 	THEN 1
										ELSE NULL
									  END 
  	FROM @tmpSelectedRID sr
  	WHERE GroupType = 'FT' AND isFinal = 1
  	
  	
	-- add new status "Under Settlement" for a match
	IF @IsSystemSettlement IS NOT NULL 
	BEGIN
		EXEC DBPRO.bodb02.dbo.NAP_Set_SettlementStatusUpd 
			@Matchid		= @Matchid
			,@Type			= 4
			,@IsEnabled		= @IsSystemSettlement 
			,@AdminId		= @AdminId
			,@IP			= @IP
	END
	
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
			)
		SELECT @MatchId
			,@matchcode
			,0
			,@leagueid
			,@sporttype
			,@AdminId
			,@IP
			,'CAL'
			,@sqlCommand
	END

END
GO 
