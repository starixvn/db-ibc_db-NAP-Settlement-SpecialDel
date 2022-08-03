/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Admin_Settlement_1_InstantCalculation_Push
	 @AdminId 			INT
    , @MatchId			INT
    , @InstantKey		INT
    , @HomeScore		VARCHAR(50)
    , @AwayScore		VARCHAR(50)
    , @Action			VARCHAR(10)
    , @Mode				VARCHAR(10)
    , @ResourceResult	VARCHAR(MAX)	 = NULL
    , @IP				VARCHAR(15)     = ''
    , @IsAutoInst		BIT				= 0
	, @BroadcastSessionId	VARCHAR(50)		= NULL
    , @ErrCode			INT             = 0     OUTPUT
    , @ErrMsg			NVARCHAR(200)   = ''    OUTPUT
AS
/*    
    Creator: 20161004@Bobby
    Task: Implement Instant Calculation
    DB: DBTXN/BODB02
    Original:

    Revisions:
		- 20161128@Bobby: #67760 - Implement IS for FGLG bet types
		- 20170815@Kathy: Using table ResultDetail to store FGLG result instead of betstatus [Redmine:#81308]
		- 20180123@Benjamin: Add @IsAutoInst and @SourceID parameter and @SourceINT variable for Determine Manual Instant/Auto Instant [Redmine:#86964]
		- 20191213@Max: Instant Settlement for Corner Bettype [Redmine:#124951]
		- 20201111@Louisa: Prevent process if SettlementStatus turn on bit 1,2,3,5,7 [Redmine:#143441]
		- 20220228@Louisa: Allow insert command into Single_Calculate_Queue by group Action [Redmine:#168497]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]

    Param's Explanation:
		- @Action: ['CAL', 'UNDO']
		- @Mode: ['INST-HT', 'INST-FT']
		- @ResourceResult
					<Results>
						<Resource Id="" HomeValue="" SettlementStatusId="" ResultStatusId=""/>
					</Results>
		- @IsAutoInst: 1-Auto Instant 0-Manual Instant
*/
BEGIN
    SET NOCOUNT ON
	
    DECLARE @matchcode 		NVARCHAR(50)
		, @sporttype 		INT
		, @leagueid 		INT
		, @procName 		NVARCHAR(128)
		, @sqlCommand 		NVARCHAR(1000)
		, @CalculationType	TINYINT
		, @InstantCompleted	BIT	
		, @SourceINT 		INT  --5-Auto Instant 100-Manual Instant
		,@ChildMatchType	TINYINT
	
	SELECT @CalculationType	= CASE 
							 WHEN @Mode = 'INST-HT' THEN 101
							 WHEN @Mode = 'INST-FT' THEN 102
							 ELSE 0
						  END
	SELECT @sporttype 	= m.sporttype
		, @leagueid 	= m.leagueid
		, @matchcode	= m.matchcode
		, @ChildMatchType = m.ChildMatchType
	FROM DBPRO.BODB02.dbo.match m WITH(NOLOCK)
	WHERE m.matchid = @matchid
    
    SELECT @ErrCode = 0, @ErrMsg = '', @procName = OBJECT_NAME(@@PROCID)
    SELECT @SourceINT = CASE 
							WHEN @ChildMatchType = 204 THEN 100
							WHEN @IsAutoInst = 0 THEN 100 
							ELSE 5 
						END

	IF(@Action = 'CAL')
	BEGIN
		SELECT @sqlCommand = 'EXEC [dbo].[NAP_Admin_Settlement_1_InstantCalculation] @matchid = ' + CONVERT(NVARCHAR(50), @MatchId) 
						  + ', @Creator = ' + CONVERT(NVARCHAR(50), @AdminId) 
						  + ', @Mode = ''' + ISNULL(CONVERT(NVARCHAR(50), @Mode), 'NULL') + ''''
						  + ', @InstantKey = ' + ISNULL(CONVERT(NVARCHAR(50), @InstantKey), 'NULL') + ''
						  + ', @HomeScore = ''' + ISNULL(CONVERT(NVARCHAR(50), @HomeScore), 'NULL') + ''''
						  + ', @AwayScore = ''' + ISNULL(CONVERT(NVARCHAR(50), @AwayScore), 'NULL') + ''''
						  + ', @ResourceResult = ' + CASE WHEN @ResourceResult IS NULL THEN 'NULL'
                                                                ELSE '''' + @ResourceResult + '''' 
											    END 
						  + ', @IP = ''' + CONVERT(NVARCHAR(50), @IP) + '''' 
						  + ', @IsAutoInst = ''' + CONVERT(NVARCHAR(50), @IsAutoInst) + '''' 
						  + ', @SourceID = ''' + CONVERT(NVARCHAR(50), @SourceINT) + '''' 
						  + ', @ErrCode = @ErrCode OUTPUT' 
						  + ', @ErrMsg = @ErrMsg OUTPUT'
	END
	ELSE IF(@Action = 'UNDO')
	BEGIN
		SELECT @sqlCommand = 'EXEC [dbo].[NAP_Admin_Settlement_1_InstantCalculation_Undo] @matchid = ' + CONVERT(NVARCHAR(50), @MatchId) 
						  + ', @Creator = ' + CONVERT(NVARCHAR(50), @AdminId) 
						  + ', @Mode = ''' + ISNULL(CONVERT(NVARCHAR(50), @Mode), 'NULL') + ''''
						  + ', @InstantKey = ' + ISNULL(CONVERT(NVARCHAR(50), @InstantKey), 'NULL') + ''
						  + ', @HomeScore = ''' + ISNULL(CONVERT(NVARCHAR(50), @HomeScore), 'NULL') + ''''
						  + ', @AwayScore = ''' + ISNULL(CONVERT(NVARCHAR(50), @AwayScore), 'NULL') + ''''
						  + ', @ResourceResult = ' + CASE WHEN @ResourceResult IS NULL THEN 'NULL'
                                                                ELSE '''' + @ResourceResult + '''' 
											    END 
						  + ', @IP = ''' + CONVERT(NVARCHAR(50), @IP) + '''' 
						  + ', @ErrCode = @ErrCode OUTPUT' 
						  + ', @ErrMsg = @ErrMsg OUTPUT'
			, @mode = 'INST-UNDO'
	END
	
	IF LEN(@sqlCommand) > 1000 --Max Field 
    BEGIN
        SELECT @ErrCode = 1001010
			, @ErrMsg  = 'There are too many inputted results to proceed at one time. Please select each one to execute separately.'    
        RETURN 
    END
	
	--SELECT @sqlCommand
	
    IF @procName LIKE '%_xtest' OR @procName LIKE '%_xpre' OR @procName LIKE '%_UAT_' -- UAT1 -->UAT9
    BEGIN
        DECLARE	@ActionId INT

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
        INSERT INTO dbo.Single_Calculate_Queue (matchid, matchcode, IsCalculating, LeagueID, SportType
			, AdminId, IP, Action, sqlCommand, execTime, BroadcastSessionId)
        SELECT @MatchId, @matchcode, 0 AS IsCalculating, @leagueid, @sporttype
			, @AdminId, @IP, @Mode, @sqlCommand, NULL, @BroadcastSessionId
    END
END
GO

