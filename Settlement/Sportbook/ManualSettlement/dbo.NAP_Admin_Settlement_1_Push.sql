/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_1_Push] 
     @AdminId               INT
    ,@Matchid               INT
    ,@FullTimeHome          SMALLINT        = NULL
    ,@FullTimeAway          SMALLINT        = NULL
    ,@HalfTimeHome          SMALLINT        = NULL
    ,@HalfTimeAway          SMALLINT        = NULL 
    ,@GoalRecord			VARCHAR(50)     = NULL
    ,@BetStatus             NVARCHAR(50)    
   
    ,@SelectedQuarter		VARCHAR(50)		= NULL
    ,@QuarterResult			VARCHAR(MAX)	= NULL
    ,@ResourceResult		VARCHAR(MAX)	= NULL
    ,@Action                VARCHAR(10)     = 'CAL'
    ,@IP                    VARCHAR(15)     = ''
	,@IsReSettledTickets	BIT				= 1
    ,@ChildMatchIds			VARCHAR(500)	= NULL
	,@RefResultStatus		TINYINT			= 0
	,@SessionId				BIGINT			= 0
    ,@ErrCode               INT             = 0     OUTPUT
    ,@ErrMsg                NVARCHAR(200)   = ''    OUTPUT
AS
/*    Creator: Kathy
    Date: 20140213
    Task: SP for settlement
    DB: DBTXN/BODB02

    Revisions:        
        - 20140506@Kathy: Don't allow to calculate exists matches in queue
        - 20140825@Kathy: Support 1H FGLG (127) for Apollo [Redmine:#16276]
        - 20141013@Jamie: Sporting Solution for Tennis [Redmine:#23034]
        - 20150401@Kathy: Add checking ticket status before performing settlement [Redmine:#33493]
        - 20150406@Jamie: Manual Settlement Betradar phase 2 [Redmine: #27212]
        - 20150618@Jamie: Offer the option Exclude Corner tickets [Feature #38099]
        - 20151005@Kathy: add more UAT version for testing (UAT1,UAT2,UAT3,UAT4)
        - 20160106@Kathy: Integrate Cricket [Redmine:#49727]
		- 20160317@Patrick: Auto payout [Redmine: #53262]
		- 20161028@Kathy: Extend sqlCommand column to varchar(max) [Redmine:#56367]
        - 20160824@Bobby: #62921 - Include FGLG (14,127) bet types
        - 20170215@Kathy: Basketball All-in-One [Redmine:#71372]
        - 20170522@Kathy: Correct checking waiting tickets for tennis [Redmine:#76931]
        - 20170815@Kathy: Using table ResultDetail to store FGLG result instead of betstatus [Redmine:#81308]
		- 20171115@Kathy: Change datatype of @ServiceCommand to NVARCHAR(MAX) [Redmine:#86735]
		- 20170421@Bobby: 72789 - Implement bonus system into NAP Settlement
		- 20180926@Kathy: Add New Status "Result Pending" and "Under Settlement"  [Redmine:#102028]
		- 20190320@Kathy: Settlement with Tickets Exclusion [Redmine:#106823]
		- 20190620@Kathy: Remove betradar corner bettypes [Redmine:#109584]
		- 20200511@Kathy: Remove tennis code [Redmine:#129316]
		- 20200727@Kathy: Prevent refund wrong match [Redmine:#136390]
		- 20201111@Louisa: Prevent process if SettlementStatus turn on bit 1,2,3,5,7 [Redmine:#143441]
		- 20201216@Louisa: Auto refund ET & PEN match [Redmine:#145597]
		- 20210121@Kathy: Cricket AIO [Redmine:#148870]
		- 20210809@Kathy: Settle by custid [Redmine:159486]
		- 20211216@Louisa: Hide confirmed result [Redmine:#165656]
		- 20220228@Louisa: Allow insert command into Single_Calculate_Queue by group Action [Redmine:#168497]
		- 20211215@Kathy: Soccer - Include calculate parlay into calculate single tickets process [Redmine:#166072]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]

    Param's Explanation:
		* @sqlCommand: just use this output for Cricket - Match Winner
		
		* @SelectedQuarter: the list of selected quarter for settlement basketball
			'801,802,1H,803,804,2H,FT'
		* @QuarterResult: the result of each quarter bettype of basketball
			Sample:	'<Results>
					   <Resource Id="603" HomeValue="H"/> 
					   <Resource Id="604" HomeValue="H"/> 
					   <Resource Id="Q1" HomeValue="30" AwayValue="40"/> 
					 </Results>
		* @ResourceResult
					<Results>
						<Resource Id="" HomeValue="" SettlementStatusId="" ResultStatusId=""/>
					</Results>

		* @RefResultStatus ( detect by Web )
				 1: no reference result exist (result not yet confirmed or not exists Provider score)
				 2: values inconsistency
        
*/
BEGIN
    SET NOCOUNT ON

    DECLARE	@matchcode          	NVARCHAR(50)
			,@sporttype         	INT
			,@leagueid          	INT
			,@procName          	NVARCHAR(50)
			,@sqlCommand			NVARCHAR(MAX)
			,@IsSystemSettlement	BIT
			,@LeagueGroupID			SMALLINT
			,@KeyId					INT
			,@IsMergedParlay		BIT = 0
			,@xmlResourceResult		XML
			,@xmlData				VARCHAR(MAX)

	SET @xmlResourceResult = CAST(@ResourceResult AS XML)

    SELECT	@matchcode = m.matchcode
			,@sporttype   = m.sporttype
			,@leagueid    = m.leagueid
			,@LeagueGroupID = ISNULL(l.LeagueGroupID,0)
    FROM	dbo.match m WITH (NOLOCK)
		INNER JOIN dbo.League l WITH (NOLOCK)
			ON m.leagueid = l.leagueid
    WHERE	m.matchid = @MatchId

    SELECT	@ErrCode        = 0
			,@ErrMsg        = ''
			,@procName      = OBJECT_NAME(@@procid)
			,@sqlCommand    = 'EXEC [dbo].[NAP_Admin_Settlement_1] @matchid = ' + CONVERT(NVARCHAR(50), @MatchId) 
                                                          + ', @creator = ' + CONVERT(NVARCHAR(50), @AdminId) 
                                                          + ', @fth = ' + ISNULL(CONVERT(NVARCHAR(50), @FullTimeHome), 'NULL') 
                                                          + ', @fta = ' + ISNULL(CONVERT(NVARCHAR(50), @FullTimeAway), 'NULL') 
                                                          + ', @hth = ' + ISNULL(CONVERT(NVARCHAR(50), @HalfTimeHome), 'NULL') 
                                                          + ', @hta = ' + ISNULL(CONVERT(NVARCHAR(50), @HalfTimeAway), 'NULL') 
                                                          + ', @goalrecord = ' + CASE WHEN @GoalRecord IS NULL THEN 'NULL'
                                                                                      ELSE '''' + CONVERT(NVARCHAR(50), @GoalRecord) + '''' END 
                                                          + ', @betstatus = ' + CASE WHEN @BetStatus IS NULL THEN 'NULL' 
                                                                                     ELSE 'N''' + CONVERT(NVARCHAR(50), @BetStatus) + '''' END 
                                                          + ', @action = ''' + CONVERT(NVARCHAR(50), @Action) + ''''                                                          
														  + ', @ResourceResult = ' + CASE WHEN @ResourceResult IS NULL THEN 'NULL'
                                                                                     ELSE '''' + @ResourceResult + '''' END 
                                                          + ', @IP = ''' + CONVERT(NVARCHAR(50), @IP) + '''' 
														  + ', @IsReSettledTickets = ' + CONVERT(NVARCHAR(1), @IsReSettledTickets) 
														  +    CASE WHEN ISNULL(@ChildMatchIds,'') = '' THEN '' ELSE + ', @ChildMatchIds = ''' +   @ChildMatchIds + '''' END
														  +	   CASE WHEN @RefResultStatus > 0 THEN ', @RefResultStatus  = ' + CONVERT(NVARCHAR(1), @RefResultStatus) ELSE '' END
                                                          + ', @ErrCode = @ErrCode OUTPUT' 
                                                          + ', @ErrMsg = @ErrMsg OUTPUT'
                                                          
				,@IsSystemSettlement = CASE
										WHEN @Action = 'UNDO' 
											THEN CASE 
													WHEN @sporttype NOT IN (2) THEN 0
													WHEN @sporttype = 2 AND @SelectedQuarter LIKE '%FT%' THEN 0
													ELSE NULL
												END
										WHEN @Action IN ('CAL', 'CAL-FT') 
											THEN CASE
													WHEN @sporttype NOT IN (2) THEN 1
													WHEN @sporttype = 2 AND @SelectedQuarter LIKE '%FT%' THEN 1
													ELSE NULL
												END
										ELSE NULL
									END
	
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

	IF ISNULL(@ChildMatchIds ,'') <> '' AND @Action IN ('CAL', 'CAL-FT') AND @LeagueGroupID IN (42,74,108) AND ISNULL(@FullTimeAway,0) <> ISNULL(@FullTimeHome,0)
	BEGIN
		EXEC DBPRO.bodb02.dbo.NAP_Set_AutoRefund_ResultIns
			 @parentId = @Matchid
			 ,@ChildMatchIds = @ChildMatchIds
	END

    IF (@procName LIKE '%_xtest' OR @procName LIKE '%_xpre' OR @procName LIKE '%_UAT_') -- UAT1 -->UAT9
    BEGIN
        BEGIN TRY
            EXEC sys.sp_executesql @sqlCommand
                ,N'@ErrMsg VARCHAR(400) OUTPUT, @ErrCode int OUTPUT'
                ,@ErrMsg		= @ErrMsg OUTPUT
                ,@ErrCode		= @ErrCode OUTPUT
        END TRY

        BEGIN CATCH
            SELECT	@ErrMsg   = @ErrMsg + ISNULL(ERROR_MESSAGE(), '')
					,@ErrCode = @@error

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
        SELECT	@MatchId
				,@matchcode
				,CASE WHEN @sporttype = 1 THEN 99 ELSE 0 END
				,@leagueid
				,@sporttype
				,@AdminId
				,@IP
				,@Action
				,@sqlCommand

		SET @KeyId = SCOPE_IDENTITY()
		
		IF @sporttype = 1
			UPDATE Single_Calculate_Queue 
				SET sqlCommand = @sqlCommand + ', @KeyId = ' + CAST(@KeyId AS VARCHAR)
					,IsCalculating = 0
			WHERE	keyid = @KeyId
		
    END
END
GO