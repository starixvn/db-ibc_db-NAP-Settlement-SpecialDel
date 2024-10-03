/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Refund_1_Push] 
    @Matchid			INT
	,@Action			VARCHAR(20)
    ,@AdminId           INT
    ,@SDTRecord			TINYINT			= 0
    ,@HalfTimeHome      INT             = NULL
    ,@HalfTimeAway      INT             = NULL
    ,@FullTimeHome      INT             = NULL
    ,@FullTimeAway      INT             = NULL
    ,@GoalSequence      VARCHAR(50)     = NULL 
    ,@BetStatus         NVARCHAR(50)    = NULL
    ,@IP				VARCHAR(15)    	= ''
    ,@ResourceResult	VARCHAR(MAX)	= NULL
    ,@IsAuto			BIT				= 0
	,@BroadcastSessionId VARCHAR(50)	= NULL
    ,@ErrCode			INT            	= 0     OUTPUT
    ,@ErrMsg			NVARCHAR(200)   = ''    OUTPUT
AS
/*
    Created: Kathy
    Date: 20211215
    Task : refund tickets 
    DB: DBTXN/BODB02

    Revisions: 
		- 20211215@Kathy: Soccer - Include calculate parlay into calculate single tickets process [Redmine:#166072]
        - 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
        - 20241003@Aries: Enhance that AutoPauout doesn't key Fulltime, Event Status still show complete of Basketball [Redmine:#211258]

    Param's Explanation:
    
*/
BEGIN
    SET NOCOUNT ON

    DECLARE 
			@matchcode				NVARCHAR(50)
			,@sporttype     		INT
			,@leagueid      		INT		
			,@procName      		NVARCHAR(50)
			,@sqlCommand			NVARCHAR(MAX)
			,@KeyId					INT
			
    SELECT	@matchcode    = m.matchcode
			,@sporttype   = m.sporttype
			,@leagueid    = m.leagueid	
    FROM	dbo.match m WITH (NOLOCK)
    WHERE	m.matchid = @MatchId

    SELECT @ErrCode     = 0
        ,@ErrMsg        = ''
        ,@procName      = OBJECT_NAME(@@procid)
        ,@sqlCommand    = 'EXEC [dbo].[NAP_Admin_Settlement_Refund_1] @Matchid = ' + CONVERT(VARCHAR(50), @MatchId) 
                                                                  + ', @creator = ' + CONVERT(VARCHAR(50), @AdminId) 
                                                                  + ', @SDTRecord = ' + CONVERT(VARCHAR(10), @SDTRecord)
                                                                  + ', @betstatus = ' + CASE WHEN @BetStatus IS NULL THEN 'NULL' ELSE '''' + @BetStatus + '''' END 
                                                                  + ', @fth = ' + ISNULL(CONVERT(NVARCHAR(50), @FullTimeHome), 'NULL') 
                                                                  + ', @fta = ' + ISNULL(CONVERT(NVARCHAR(50), @FullTimeAway), 'NULL') 
                                                                  + ', @hth = ' + ISNULL(CONVERT(NVARCHAR(50), @HalfTimeHome), 'NULL') 
                                                                  + ', @hta = ' + ISNULL(CONVERT(NVARCHAR(50), @HalfTimeAway), 'NULL')
                                                                  + ', @GoalSequence = ' + CASE WHEN @GoalSequence IS NULL THEN 'NULL' ELSE '''' + @GoalSequence + '''' END   
                                                                  + ', @Action = ''' + @Action + '''' 
                                                                  + ', @ResourceResult = ' + CASE WHEN @ResourceResult IS NULL THEN 'NULL'
                                                                                     ELSE '''' + @ResourceResult + '''' END 
                                                                  + ', @IP = ''' + CONVERT(NVARCHAR(50), @IP) + '''' 
																  +  CASE WHEN @IsAuto = 1 THEN + ', @IsAuto =' + CONVERT(NVARCHAR(1), @IsAuto ) +''  ELSE '' END
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
                ,@ErrMsg    = @ErrMsg    OUTPUT
                ,@ErrCode    = @ErrCode    OUTPUT
        END TRY

        BEGIN CATCH
            SELECT @ErrMsg    = @ErrMsg + ISNULL(ERROR_MESSAGE(), '')
                ,@ErrCode    = @@error

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
        SELECT	@MatchId
				,@matchcode
				,0
				,@leagueid
				,@sporttype
				,@AdminId
				,@IP
				,@Action
				,@sqlCommand
				,@BroadcastSessionId

		SET @KeyId = SCOPE_IDENTITY()
		
		IF @sporttype = 1
			UPDATE Single_Calculate_Queue 
				SET sqlCommand = @sqlCommand + ', @KeyId = ' + CAST(@KeyId AS VARCHAR)
					,IsCalculating = 0
			WHERE	keyid = @KeyId
    END

END
GO
