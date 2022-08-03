/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Refund_All_Push] 
    @Matchid							INT
    ,@AdminId                        	INT
    ,@BetStatus                        	NVARCHAR(50)    = NULL
    ,@IP								VARCHAR(15)    	= ''
	,@SessionId							VARCHAR(50)		= NULL
    ,@ErrCode							INT            	= 0     OUTPUT
    ,@ErrMsg							NVARCHAR(200)   = ''    OUTPUT
    ,@ServiceCommand					NVARCHAR(MAX)	= ''	OUTPUT
AS
/*
    Created: Kathy
    Date: 20140213
    Task : refund tickets 
    Original: 
    DB: DBTXN/BODB02

    Revisions: 
        - 20140304@Kathy: Execute settlement for abandoned/postponed matches- Clean Sheet, Both/One/Neither team to score, To Win To Nil 
        - 20140506@Kathy: Don't allow to calculate exists matches in queue
        - 20140825@Kathy: Support 1H FGLG (127) for Apollo [Redmine:#16276]
        - 20141024@Jamie: Sportting Solution Tennis Settlement [Redmine:#23034]
        - 20150401@Kathy: Add checking ticket status before performing settlement [Redmine:#33493]
        - 20150414@Jamie: Manual Settlement Betradar phase 2 [Redmine: #27212]
        - 20151005@Kathy: add more UAT version for testing (UAT1,UAT2,UAT3,UAT4)
        - 20160106@Kathy: Integrate Cricket [Redmine:#49727]
        - 20161028@Kathy: Extend sqlCommand column to varchar(max) [Redmine:#56367]
		- 20160824@Bobby: #62921 - Include FGLG (14,127) bet types
        - 20170215@Kathy: Basketball All-in-One [Redmine:#71372]
        - 20170522@Kathy: Correct checking waiting tickets for tennis [Redmine:#76931]
		- 20170321@Bobby: #73407 - CashOut integration
		- 20170704@Kathy: change datatype of betstatus to NVARCHAR(50) [Redmine:#79296]
		- 20170815@Kathy: Using table ResultDetail to store FGLG result instead of betstatus [Redmine:#81308]
		- 20171115@Kathy: Change datatype of @ServiceCommand to NVARCHAR(MAX) [Redmine:#86735]
		- 20171202@Kathy: Verify whether Instant Settlement has been executed with larger value than suspended score [Redmine:#86890]
		- 20170425@Bobby: 72789 - Implement bonus system into 
		- 20180926@Kathy: Add New Status "Result Pending" and "Under Settlement"  [Redmine:#102028]
		- 20190620@Kathy: Remove betradar corner bettypes [Redmine:#109584]
		- 20200511@Kathy: Remove tennis code [Redmine:#129316]
		- 20200727@Kathy: Prevent refund wrong match [Redmine:#136390]
		- 20201111@Louisa: Prevent process if SettlementStatus turn on bit 1,2,3,5,7 [Redmine:#143441]
		- 20201216@Louisa: Auto refund ET & PEN match [Redmine:#145597]
		- 20211118@Louisa: EventStatusReason for soccer only [Redmine:#164408]
		- 20220228@Louisa: Allow insert command into Single_Calculate_Queue by group Action [Redmine:#168497]
		- 20220415@July: Sporttype = 1 return message [Redmine:#171579]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]

    Param's Explanation:
    • @matchid: matchid need to refund
    * @isExistTotalCorner: = 1 When existing tickets or result details of corners bettypes 
    * @sqlCommand: just use this output for Cricket - Match Winner
	
	* @ResourceResult
					<Results>
						<Resource Id="" HomeValue="" SettlementStatusId="" ResultStatusId=""/>
					</Results>
*/
BEGIN
    SET NOCOUNT ON

    DECLARE @matchcode				NVARCHAR(50)
			,@sporttype     		INT
			,@leagueid      		INT		
			,@IsNested      		BIT
			,@Action        		VARCHAR(20)
			,@procName      		NVARCHAR(50)
			,@sqlCommand			NVARCHAR(MAX)
			,@IsSystemSettlement	BIT

    SELECT	@matchcode    = m.matchcode
			,@sporttype   = m.sporttype
			,@leagueid    = m.leagueid
			,@IsNested    = 0
			
    FROM	dbo.match m WITH (NOLOCK)
    WHERE	m.matchid = @MatchId
    
    SELECT @ErrCode     = 0
        ,@ErrMsg        = ''
        ,@procName      = OBJECT_NAME(@@procid)
        ,@sqlCommand    = 'EXEC [dbo].[NAP_Admin_Settlement_Refund_All] @Matchid = ' + CONVERT(NVARCHAR(50), @MatchId) 
                                                                  + ', @creator = ' + CONVERT(NVARCHAR(50), @AdminId)
                                                                  + ', @betstatus = ' + CASE WHEN @BetStatus IS NULL THEN 'NULL' ELSE '''' + @BetStatus + '''' END 
                                                                  + ', @Action = ''' + 'CAL' + '''' 
                                                                  + ', @IsNested = ''' + CONVERT(NVARCHAR(1), @IsNested) + '''' 
                                                                  + ', @IP = ''' + CONVERT(NVARCHAR(50), @IP) + '''' 
																  + ', @ErrCode = @ErrCode OUTPUT' 
                                                                  + ', @ErrMsg = @ErrMsg OUTPUT'
			,@IsSystemSettlement = 1

    SELECT @Action = 'REFUND'  -- ALL SPORTS

	-- add new status "Under Settlement" for a match
	IF @IsSystemSettlement IS NOT NULL
	BEGIN
		EXEC DBPRO.bodb02.dbo.NAP_Set_SettlementStatusUpd 
			@Matchid		= @Matchid
			,@Type			= 4
			,@IsEnabled		= @IsSystemSettlement 
			,@AdminId		= @AdminId
			,@IP			= @Ip
	END

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
				,SessionId
            )
        SELECT	@MatchId
				,@matchcode
				,0
				,@leagueid
				,@sporttype
				,@AdminId
				,@IP
				,@Action -- Refund
				,@sqlCommand
				,@SessionId
		
    END

END
GO
