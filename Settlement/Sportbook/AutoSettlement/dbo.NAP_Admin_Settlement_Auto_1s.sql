/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet,Dot_CoreAPI" viewers="vnteam" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Admin_Settlement_Auto_1s]
     @AdminID                       INT             = 148        -- calculated by system (default)
    ,@MatchID                       INT
    ,@ResourceIDs                   VARCHAR(MAX)	= '' 
    ,@Results                       VARCHAR(MAX)    = ''
    ,@IsSettleAbandonedMatchIBC     BIT             = 0 
    ,@Action                    	VARCHAR(10)     = 'CAL'
    ,@IsAuto                        BIT             = 1
    ,@IP                            VARCHAR(15)     = ''
    ,@ErrCode            			INT             = 0		OUTPUT
    ,@ErrMsg            			NVARCHAR(200)   = ''    OUTPUT
AS
/*    Creator: Jamie
    Date: 20150120
    Task: BetRadar Auto/Manual Settlement
    DB: DBTXN/BODB02
    Original: 
    
    Revisions:
        - 20150610@Johnson: Add bettrade [Redmine: #35921]
        - 20150806@Kathy: Using new balance table (BalCreditSportsPending,BalDebitSportsPending) [Redmine:#40125]
        - 20160525@Kathy: Change the main Parlay Settlement SP
        - 20160830@Kathy: PH-AIO phase 2b [Redmine:#62861]
        - 20170215@Kathy: Get list bettypes with xml format [Redmine:#71372]
        - 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
		- 20170425@Bobby: 72789 - Implement bonus system into NAP Settlement

    Param's Explanation:
*/    
BEGIN
    SET NOCOUNT ON 
    DECLARE @start                  	DATETIME
            ,@stop                      DATETIME
            ,@fth                       INT
            ,@fta                       INT
            ,@hth                       INT
            ,@hta                       INT
            ,@goalrecord                VARCHAR(50)
            ,@betstatus                 VARCHAR(50) 
            ,@ActionID                  INT
            ,@Remark					VARCHAR(500)
            ,@LogData                   NVARCHAR(300)
            ,@strAutoBetRadarBettypes   VARCHAR(MAX)
            ,@strBettypes               VARCHAR(MAX)   
            ,@strXML					VARCHAR(MAX)                             
			, @avaiableProcess			BIT
			,@bettype_22				VARCHAR(20)
			,@bettype_160				VARCHAR(20)
    
    SET @bettype_22 = '22'
    SET @bettype_160 = '160'
		
	--START Balance tables	
	DECLARE @BalanceWalletBefore		TVP_BalanceWalletChange
		, @BalanceWalletAfter			TVP_BalanceWalletChange
	--END Balance tables
	
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)

    SELECT    @start = CURRENT_TIMESTAMP
    SELECT    @ActionID = CASE WHEN @Action = 'CAL'    THEN 148 
                             WHEN @Action = 'UNDO'    THEN 149 
                             WHEN @Action = 'REFUND'THEN 150
                             ELSE 0 END  
        
                             
    --Write Log Settle
    SELECT     @fth            = finalhomescore
            ,@fta            = finalawayscore
            ,@hth            = hthomescore
            ,@hta            = htawayscore
            ,@goalrecord    = goalrecord 
            ,@betstatus        = betstatus 
    FROM    DBPRO.BODB02.dbo.match WITH (NOLOCK)
    WHERE    matchid = @matchid
        
    INSERT INTO #tblMatchProcess (matchid, KeyID)
	SELECT @matchId AS matchid
		, 1 AS KeyID
		
	--check settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch		= 1
		, @avaiableProcess 	= @avaiableProcess OUTPUT
		, @ErrCode			= @ErrCode OUTPUT
		, @ErrMsg			= @ErrMsg OUTPUT
	
	--CHECK avaiable process
	IF(@ErrCode <> 0 OR @avaiableProcess = 0) RETURN
	
	SELECT     @strAutoBetRadarBettypes = COALESCE(@strAutoBetRadarBettypes + ',' + CAST(bettype AS NVARCHAR), CAST(bettype AS NVARCHAR))
    FROM    dbo.f_Set_GetGroupBettypes() f 
    WHERE      f.GroupId = 8 -- auto betradar
	
    -------------------------------------------------------------
    ---        CAPTURE value BALANCE before settlement        ---
    ---------------------------VVVV------------------------------    
    INSERT INTO @BalanceWalletBefore (
        matchid
        , custid
        , balanceType
        , walletType
        , bonusId
        , balance
    )
    EXEC [dbo].[NAP_Admin_CaptureBalanceByWallet]
        @MatchId 			= @matchId
        , @Action 			= @Action
        , @Mode 			= 6 --@Mode auto settlement
		

    SET @strXML = CAST((SELECT  BetType '@t'
								,GroupId '@g'
								,GroupName '@n'
						FROM	dbo.f_Set_GetGroupBettypes()			
						WHERE	GroupId = 8
						FOR XML PATH ('r'), ROOT('root'), TYPE
							) AS VARCHAR(MAX))
							
		
    --^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    IF @Action='CAL'
    BEGIN
        EXEC DBPRO.BODB02.dbo.NAP_Admin_Result_Update_1s 
            @Command            = 'NAP_Admin_Settlement_Auto_1s-CAL',
            @MatchID            = @MatchID,
            @ResourceIDs        = @ResourceIDs, 
            @Results            = @Results,
            @IsAuto             = @IsAuto,
            @creator            = @AdminID             

        EXEC dbo.NAP_Admin_Settlement_3_Auto_1s 
             @matchid        	= @matchid
            ,@ResourceIDs    	= @ResourceIDs
            ,@mode            	= @action                        

    END
    ELSE IF @action = 'UNDO'
    BEGIN						
        EXEC dbo.NAP_Admin_Calculate_Main 
             @matchid        	= @matchid
            ,@ResourceIDs    	= @ResourceIDs
            ,@action        	= 'CAL'        -- Default Action for UNDO Settlement 
            ,@mode            	= 'UNDO' 
            ,@strBettypes    = @strXML

        EXEC dbo.NAP_Admin_Settlement_MP
                @matchid        = @matchid
                ,@creator       = @AdminID
                ,@action        = 'UNDO'
                ,@ResourceIDs   = @ResourceIDs
                ,@IP            = @IP
                
        EXEC DBPRO.BODB02.dbo.NAP_Admin_Result_Update_1s 
            @Command            = 'NAP_Admin_Settlement_Auto_1s-UNDO',
            @MatchID            = @MatchID,
            @ResourceIDs        = @ResourceIDs, 
            @Results            = @Results,
            @IsAuto                = @IsAuto,
            @creator            = @AdminID 

    END
    ELSE IF @Action = 'REFUND'
    BEGIN
        
        IF @IsSettleAbandonedMatchIBC = 1 
        BEGIN
            DECLARE     @GoalScorerAnytime        VARCHAR(MAX)=''
            
            DECLARE    @tmpResourceIDs    TABLE(
                 ID            INT IDENTITY(1,1)
                ,ResourceID    VARCHAR(20)
                ,Bettype    INT
            )
            INSERT INTO @tmpResourceIDs(ResourceID, Bettype)
            SELECT    Val, CAST(LEFT(val,3) AS INT) FROM dbo.StrSplit(@ResourceIDs,',')

            DECLARE    @tmpResults TABLE(
                 ID            INT IDENTITY(1,1)
                ,HomeValue    VARCHAR(50)
            )
            INSERT INTO @tmpResults(HomeValue)
            SELECT    Val FROM dbo.StrSplit(@Results,',') WHERE @Results IS NOT NULL 

            UPDATE @tmpResults
            SET        HomeValue = NULL
            WHERE    HomeValue ='NL'

            ;WITH cteBettypes
            AS
            (
                SELECT    BetType
                FROM    dbo.f_Set_GetGroupBettypes()
                WHERE    GroupId = 8
                        AND IsDetermined = 1
            )
            SELECT    @strBettypes = COALESCE(@strBettypes + ',' + CAST(bettype AS NVARCHAR), CAST(bettype AS NVARCHAR))
            FROM    dbo.bettrans WITH(NOLOCK)
            WHERE    matchid = @MatchId
                    AND statusID NOT BETWEEN 101 AND 102
                    AND bettype IN (SELECT Bettype FROM @tmpResourceIDs)
                    AND bettype IN (SELECT Bettype FROM cteBettypes)
            GROUP BY bettype
            
            SELECT    @GoalScorerAnytime        = @GoalScorerAnytime + CASE WHEN t.ResourceID LIKE '216__' THEN ISNULL(r.HomeValue,'') +',' ELSE '' END             
            FROM    @tmpResourceIDs t
                    INNER JOIN @tmpResults r ON t.ID = r.ID 
            WHERE    t.ResourceID LIKE '216__'

            IF ISNULL(@GoalScorerAnytime,'') =''
            BEGIN
                SELECT     @ErrCode    = 1001014
                        ,@ErrMsg    = 'Cannot settle determined ticket(s) without suspended result!'    
                        
                ------ releasing Settlement process
				EXEC dbo.NAP_Admin_CheckingProcess
				@isExistMatch		= 1
				, @IsReleased		= 1 
                        
                RETURN     
            END

            EXEC dbo.NAP_Admin_Calculate_Main 
                 @matchid                    	= @matchid
                ,@ResourceIDs                	= @ResourceIDs
                ,@action                    	= 'REFUND'    
                ,@mode                        	= 'ABANDONED' 
                ,@GoalScorerAnytime            	= @GoalScorerAnytime
                ,@IsSettleAbandonedMatchIBC    	= @IsSettleAbandonedMatchIBC
                ,@strBettypes                	= @strBettypes
        END

        EXEC DBPRO.BODB02.dbo.NAP_Admin_Result_Update_1s 
            @Command            = 'NAP_Admin_Settlement_Auto_1s-REFUND',
            @MatchID            = @MatchID,
            @ResourceIDs        = @ResourceIDs, 
            @Results            = @Results,
            @IsAuto            	= @IsAuto,
            @creator            = @AdminID     
        
        EXEC dbo.NAP_Admin_Calculate_Main 
             @matchid                    	= @matchid
            ,@ResourceIDs                	= @ResourceIDs
            ,@IsSettleAbandonedMatchIBC 	= @IsSettleAbandonedMatchIBC
            ,@action                    	= 'REFUND'    
            ,@mode                        	= 'REFUND' 
            ,@strBettypes                = @strXML
    END


    -------------------------------------------------------------
    ---         CAPTURE value BALANCE after settlement        ---
    ---------------------------VVVV------------------------------
	INSERT INTO @BalanceWalletAfter (
		matchid
        , custid
        , balanceType
        , walletType
        , bonusId
        , balance
    )
    EXEC [dbo].[NAP_Admin_CaptureBalanceByWallet]
        @MatchId 			= @matchId
        , @Action 			= @Action
        , @Mode 			= 6 --@Mode auto settlement
		
    -------------------------------------------------------------
    ---                   compare BALANCE                     ---
    ---------------------------VVVV------------------------------
    	---INSERT data into pending balance table   
	EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
		@BalanceWalletBefore	= @BalanceWalletBefore
		, @BalanceWalletAfter	= @BalanceWalletAfter
		, @ActionId				= @ActionID
	
    -------------------------------------------------------------
    ---                      WRITE LOG                        ---
    ---------------------------VVVV------------------------------

    SELECT @stop = CURRENT_TIMESTAMP

    SELECT @logdata = 'NAP: Auto-Settlement (' + @action + ') for matchid:' + CAST(@matchid AS NVARCHAR(10)) 
                                                           + ' ResourceID:' + CAST(@ResourceIDs AS VARCHAR(MAX))
                                                           + ' SettleDeterminedTickets:' + CAST(@IsSettleAbandonedMatchIBC AS VARCHAR(1))
                                                           + ' Result:' + @Results + '(' + CAST(DATEDIFF(millisecond, @start, @stop) AS NVARCHAR(50)) + ' ms)'
    EXEC dbo.WriteLog_UserLog 
        @UserID = @AdminId
        ,@Doing = @logdata

    SELECT @Remark = 'NAP: ResourceID:' + @ResourceIDs +  ' <br/> ' 
                        + CASE WHEN ISNULL(@Results,'') ='' THEN '' ELSE ' Result:'+ ISNULL(@Results,'') + ' <br/> ' END
                        + ' SettleDeterminedTickets:' + CAST(@IsSettleAbandonedMatchIBC AS VARCHAR(1))
                        + ' IsAuto:' + CAST(@IsAuto AS VARCHAR(1))
                        + ' Duration:' + CAST(DATEDIFF(millisecond, @start, @stop) AS NVARCHAR(50)) + 'ms' 
    BEGIN TRY
        EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle 
            @userid                = @AdminId
            ,@matchid            = @MatchID
            ,@actionid            = @ActionID
            ,@finalhomescore    = @fth
            ,@finalawayscore    = @fta
            ,@hthomescore        = @hth
            ,@htawayscore        = @hta
            ,@GoalRecord        = @goalrecord
            ,@betstatus            = @betstatus
            ,@Remark            = @Remark
            ,@ip                = @ip
    END TRY

    BEGIN CATCH
        SELECT @remark = @remark + ' ErrMsg=' + LEFT(ERROR_MESSAGE(), 250)

        EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle 
            @UserID                = @AdminId
            ,@MatchID            = @matchid
            ,@actionid            = @actionid
            ,@finalhomescore    = @fth
            ,@finalawayscore    = @fta
            ,@hthomescore        = @hth
            ,@htawayscore        = @hta
            ,@GoalRecord        = @goalrecord
            ,@betstatus            = @betstatus
            ,@Remark            = @Remark
            ,@IP                = @ip
    END CATCH

   ------ releasing Settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
	@isExistMatch		= 1
	, @IsReleased		= 1
	
END
GO
