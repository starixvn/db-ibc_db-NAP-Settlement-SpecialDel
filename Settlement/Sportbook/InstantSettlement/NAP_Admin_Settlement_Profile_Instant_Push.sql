/*<info serverAlias="DBCTG-bodb02,DBSID-bodb02,DBSIC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Admin_Settlement_Profile_Instant_Push
	 @MatchID					INT 
	,@AdminId 					INT
	,@Action					VARCHAR(20)		= 'CAL-INST'
	,@SelectedResources			VARCHAR(MAX)
	,@IP						VARCHAR(15)
	,@DeterminedType			INT			= 0
	,@BroadcastSessionId		VARCHAR(50)		= NULL
    ,@ErrCode					INT             = 0     OUTPUT
    ,@ErrMsg					NVARCHAR(200)   = ''    OUTPUT
AS
/*
	Creator: 20230801@Aries
	Task: Support Instant Settlement for Basketball
	DB: DBPRO/bodb02
	Revisions:	
		- 20230801@Aries: Created [Redmine:#189662]
		- 20240718@Kathy: Implement AiO for Baseball [Redmine:#206154]

*/
BEGIN
    SET NOCOUNT ON
	
    DECLARE @matchcode 		NVARCHAR(50)
			,@sporttype 	INT
			,@leagueid 		INT
			,@procName 		NVARCHAR(128)
			,@sqlCommand 	NVARCHAR(MAX)
			,@KeyId			INT
	
	SELECT	@sporttype 	= m.sporttype
			,@leagueid 	= m.leagueid
			,@matchcode	= m.matchcode	
	FROM	 DBPRO.BODB02.dbo.match m WITH(NOLOCK)
	WHERE	m.matchid = @matchid
    
    SELECT	@ErrCode = 0
			,@ErrMsg = ''
			,@procName = OBJECT_NAME(@@PROCID)
   
	SET @sqlCommand = 'EXEC [dbo].[NAP_Admin_Settlement_Profile_Instant] @MatchID = ' 
							+ CONVERT(NVARCHAR(50), @MatchId) 
							+ ', @AdminId = '				+ CONVERT(NVARCHAR(50), @AdminId) 
							+ ', @Action = '''				+ CONVERT(NVARCHAR(50), @Action) + '''' 
							+ ', @SelectedResources = '''	+ CONVERT(NVARCHAR(MAX), @SelectedResources) + ''''
							+ ', @IP = '''					+ CONVERT(NVARCHAR(50), @IP) + '''' 	 
							+ ', @DeterminedType = '		+ CONVERT(NVARCHAR(50), @DeterminedType) 
							+ IIF(@BroadcastSessionId IS NOT NULL,', @BroadcastSessionId = ''' + @BroadcastSessionId + '''','')
							+ ', @ErrCode = @ErrCode OUTPUT' 
							+ ', @ErrMsg = @ErrMsg OUTPUT'

    IF @procName LIKE '%_xtest' OR @procName LIKE '%_xpre' OR @procName LIKE '%_UAT_' -- UAT1 -->UAT9
    BEGIN
        BEGIN TRY
            EXEC sys.sp_executesql @sqlCommand, N'@ErrMsg VARCHAR(400) OUTPUT, @ErrCode int OUTPUT'
                , @ErrMsg	= @ErrMsg OUTPUT
                , @ErrCode	= @ErrCode OUTPUT
        END TRY

        BEGIN CATCH
            SELECT @ErrMsg = @ErrMsg + ISNULL(ERROR_MESSAGE(), ''), @ErrCode = @@ERROR

            RETURN
        END CATCH
    END
    ELSE
    BEGIN
        INSERT INTO dbo.Single_Calculate_Queue (matchid, matchcode, IsCalculating, LeagueID, SportType, AdminId, IP, Action, sqlCommand, execTime,BroadcastSessionId)
        SELECT @MatchId, @matchcode, 0 AS IsCalculating, @leagueid, @sporttype, @AdminId, @IP, @Action, @sqlCommand, NULL,@BroadcastSessionId
    END
END
GO

