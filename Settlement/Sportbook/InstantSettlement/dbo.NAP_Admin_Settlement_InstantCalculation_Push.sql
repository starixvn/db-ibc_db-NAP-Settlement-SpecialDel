/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Admin_Settlement_InstantCalculation_Push
	 @AdminId 			INT
    , @MatchId			INT
    , @HomeScore		VARCHAR(50)
    , @AwayScore		VARCHAR(50)
    , @Action			VARCHAR(20)
    , @ResourceResult	VARCHAR(MAX)	= NULL
    , @IP				VARCHAR(15)     = ''
    , @IsAutoInst		BIT				= 0
	, @GoalRecord		VARCHAR(50)     = NULL
	, @BroadcastSessionId VARCHAR(50)	= NULL

    , @ErrCode			INT             = 0     OUTPUT
    , @ErrMsg			NVARCHAR(200)   = ''    OUTPUT
AS
/*    
    Creator: 20230404@Kathy
    Task: Implement Instant Calculation
    DB: DBTXN/BODB02
    Original:NAP_Admin_Settlement_1_InstantCalculation_Push

    Revisions:
		- 20230404@Kathy: Merge single and parlay [Redmine:#175202]
		- 20230817@Kathy: Write log [Redmine:#192311]

    Param's Explanation:
		- @Action: ['CALINST-HT', 'CALINST-FT' 'UNDOINST-FT', 'UNDOINST-HT']
		- @ResourceResult
					<Results>
						<Resource Id="" HomeValue="" SettlementStatusId="" ResultStatusId=""/>
					</Results>
		- @IsAutoInst: 1-Auto Instant 0-Manual Instant
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
   
	SELECT @sqlCommand = 'EXEC [dbo].[NAP_Admin_Settlement_InstantCalculation] @matchid = ' + CONVERT(NVARCHAR(50), @MatchId) 
						  + ', @AdminId = ' + CONVERT(NVARCHAR(50), @AdminId) 
						  + ', @Action = ''' + ISNULL(CONVERT(NVARCHAR(50), @Action), 'NULL') + ''''
						  + ', @HomeScore = ''' + ISNULL(CONVERT(NVARCHAR(50), @HomeScore), 'NULL') + ''''
						  + ', @AwayScore = ''' + ISNULL(CONVERT(NVARCHAR(50), @AwayScore), 'NULL') + ''''
						  + ', @ResourceResult = ' + CASE WHEN @ResourceResult IS NULL THEN 'NULL'
                                                                ELSE '''' + @ResourceResult + '''' 
											    END 
						  + ', @IP = ''' + CONVERT(NVARCHAR(50), @IP) + '''' 
						  + ', @IsAutoInst = ''' + CONVERT(NVARCHAR(50), @IsAutoInst) + '''' 
						  + ', @GoalRecord = ' + CASE WHEN @GoalRecord IS NULL THEN 'NULL'
                                                                ELSE '''' + CONVERT(NVARCHAR(50), @GoalRecord) + '''' END
						  +  CASE WHEN @BroadcastSessionId IS NOT NULL 
									THEN ', @BroadcastSessionId = ''' + @BroadcastSessionId + ''''
									ELSE '' END +
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
        INSERT INTO dbo.Single_Calculate_Queue (matchid, matchcode, IsCalculating, LeagueID, SportType, AdminId, IP, Action, sqlCommand, execTime, BroadcastSessionId)
        SELECT @MatchId, @matchcode, 0 AS IsCalculating, @leagueid, @sporttype, @AdminId, @IP, @Action, @sqlCommand, NULL, @BroadcastSessionId

		SET @KeyId = SCOPE_IDENTITY()

		UPDATE	dbo.Single_Calculate_Queue WITH(ROWLOCK, UPDLOCK)
			SET sqlCommand = @sqlCommand + ', @KeyId = ' + CAST(@KeyId AS VARCHAR)
				,IsCalculating = 0
		WHERE	keyid = @KeyId
    END
END
GO

