/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_2b]
     @AdminID	INT                
    ,@MatchID	INT
    ,@QuarterResult	VARCHAR(MAX)
    ,@Action    VARCHAR(10)	= 'CAL'
    ,@IsReSettledTickets BIT = 1
    ,@IP     	VARCHAR(15)    = ''
    ,@ErrCode	INT            = 0	OUTPUT
    ,@ErrMsg 	NVARCHAR(200)  = '' OUTPUT
AS
/*  Creator: 20170609@Kathy
    Task: Early Settlement for BAIO [Redmine:#77835]
    DB: DBTXN/BODB02  
    
    Revisions:
		- 20170613@Kathy: Early Settlement [Redmine:#77835] 
		- 20170801@Bobby: Implement new capture balance method [Redmine:#80774]
		- 20190813@Helen: Remove vnteam in metadata
		- 20200203@Sol: Settlement with Tickets Exclusion [Redmine:#126963]
		- 20200515@Kathy: Settlement Exclusion [Redmine:#134103]
		
    Param's Explanation:
		* @QuarterResult: the result of each quarter bettype of basketball
			Sample:	'<Results>
					   <Resource Id="604" HomeValue="H"/> 
					   <Resource Id="606" HomeValue="A"/> 
					 </Results>
*/    
BEGIN
    SET NOCOUNT ON 
    DECLARE @start        		DATETIME
            ,@stop        		DATETIME
            ,@fth            	INT
            ,@fta            	INT
            ,@hth            	INT
            ,@hta            	INT          
            ,@ActionID          INT
            ,@Remark            VARCHAR(500)
            ,@LogData           NVARCHAR(300)        
            ,@avaiableProcess	BIT  
            ,@xml				XML
            ,@strEarlyBettypes	VARCHAR(MAX) 
            ,@strResourceIds	VARCHAR(MAX)	
			,@sportType 		INT
    
    --START Balance tables	
	DECLARE @BalanceWalletBefore		TVP_BalanceWalletChange
		, @BalanceWalletAfter			TVP_BalanceWalletChange
	--END Balance tables             

	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	DECLARE @tmpResultDetail TABLE (ResourceId VARCHAR(20), bettype SMALLINT)
	
    SELECT  @start = CURRENT_TIMESTAMP
			,@xml = CAST(@QuarterResult AS XML)
			,@ActionID = CASE 
							WHEN @Action = 'CAL' THEN 189 
                            WHEN @Action = 'UNDO' THEN 190
                            WHEN @Action = 'REFUND' THEN 191
                            ELSE 0 
                         END          
                             
    --Write Log Settle
    SELECT  @fth            = finalhomescore
            ,@fta            = finalawayscore
            ,@hth            = hthomescore
            ,@hta            = htawayscore     
			,@sportType		= sportType
    FROM    DBPRO.BODB02.dbo.match WITH (NOLOCK)
    WHERE    matchid = @matchid
        
    -- check and not allow attempt to settlement same game while it's still not finish
	INSERT INTO #tblMatchProcess(matchid, KeyID)
	SELECT	@matchid AS matchid
			,1 AS KeyId
		
	--check settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch		= 1
		, @avaiableProcess 	= @avaiableProcess OUTPUT
		, @ErrCode			= @ErrCode OUTPUT
		, @ErrMsg			= @ErrMsg OUTPUT

	IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
	BEGIN
		SELECT    @ErrCode = 1000000
                ,@ErrMsg    = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'

        RETURN
	END
	
	;WITH cteResourceIds
	AS(
		SELECT	T.C.value('@Id', 'VARCHAR(20)') AS ResourceId
		FROM	@xml.nodes('/Results/Resource') AS T(C)
	)
	INSERT INTO @tmpResultDetail(ResourceId, bettype)
	SELECT	c.ResourceId
			,f.bettype
	FROM	cteResourceIds c
		INNER JOIN dbo.f_Set_GetEarlyBettypes() f
			ON c.ResourceId LIKE CAST(f.bettype AS VARCHAR) + '%'
	OPTION ( OPTIMIZE FOR ( @xml = NULL ) )	
	
	IF @Action = 'REFUND'
	BEGIN
		DECLARE @tmpBettype TABLE (bettype SMALLINT, ResourceId VARCHAR(20), BetId BIGINT)
		
		INSERT INTO @tmpBettype(ResourceID, BetType, BetID)
		SELECT DISTINCT c.ResourceID, sp.BetType, sp.BetID
		FROM @tmpResultDetail c
			INNER JOIN dbo.SettlementSpecialBettypeProfile sp WITH (NOLOCK) 
				ON sp.ResourceID = c.ResourceID
		WHERE	sp.SportType = @SportType 

		IF EXISTS (
			SELECT	TOP 1 1
			FROM	dbo.bettrans b WITH(NOLOCK)
				INNER JOIN dbo.MarkedTransaction mt WITH(NOLOCK)
					ON	b.transid = mt.TransId
			WHERE	b.matchid = @MatchID
					AND b.statusID NOT IN (101, 102)
					AND EXISTS (SELECT TOP 1 1 FROM @tmpBettype t WHERE t.bettype = b.bettype AND (t.BetId = 0 OR t.BetId = b.betid))
		)
		BEGIN
			SELECT @ErrCode = 1001032
					,@ErrMsg = 'ERROR! Cannot proceed due to marked tickets. Please unmark them and try again.'

			------ releasing Settlement process
			EXEC dbo.NAP_Admin_CheckingProcess
				@isExistMatch		= 1
				, @IsReleased		= 1
			
			RETURN
		END
	END
	
	SELECT	@strResourceIds = COALESCE(@strResourceIds + ',' + ResourceId, ResourceId)
	FROM	@tmpResultDetail
	
	SELECT	@strEarlyBettypes = COALESCE(@strEarlyBettypes + ',' + CAST(bettype AS NVARCHAR), CAST(bettype AS NVARCHAR))
	FROM	@tmpResultDetail
	GROUP BY bettype	
    
	-------------------------------------------------------------
    ---        CAPTURE value BALANCE before settlement        ---
    ---------------------------VVVV------------------------------
	INSERT INTO @BalanceWalletBefore (
		matchid
		, custid
		, balanceType
		, WalletType
		, BonusID
		, balance
	)
	EXEC [dbo].[NAP_Admin_CaptureBalanceByWallet]
		@MatchId 			= @matchId
		, @sportType		= @sportType
		, @Action 			= @Action
		, @Mode 			= 8 --@Mode Baseketball Early payout
		, @BAResults		= @QuarterResult
   
	BEGIN TRY
		IF @Action='CAL'
		BEGIN
			DECLARE @xmlResultDetail VARCHAR(MAX)
			
			EXEC DBPRO.BODB02.dbo.NAP_Admin_Result_Update_2b 
				@command = 'NAP_Admin_Settlement_2b-CAL'
				,@matchid = @MatchId
				,@Results = @QuarterResult
				,@creator = @AdminId
			
			EXEC dbo.Nap_Admin_Settlement_2 
				@mode = 'basketball'
				,@matchid = @matchid
				,@str_resultDetail = @xmlResultDetail OUTPUT
			
			EXEC dbo.NAP_Admin_Calculate_Main @matchid = @matchid
				,@mode = @Action
				,@xmlData = @xmlResultDetail
				,@sporttype = 2
				,@strBettypes = @strEarlyBettypes    
				,@ResourceIDs = @strResourceIds        
				,@IsReSettledTickets = @IsReSettledTickets

		END
		ELSE IF @action = 'UNDO'
		BEGIN						
			EXEC dbo.NAP_Admin_Calculate_Main 
				 @matchid        = @matchid
				,@ResourceIDs    = @strResourceIds
				,@action        = @action        -- Default Action for UNDO Settlement 
				,@mode            = 'UNDO-EARLY' 
				,@strBettypes    = @strEarlyBettypes

			EXEC dbo.NAP_Admin_Settlement_MP
				@matchid        = @matchid
				,@creator        = @AdminID
				,@action        = @action
				,@SelectedQuarter   = @strResourceIds
				,@IP            = @IP
	                
			EXEC DBPRO.BODB02.dbo.NAP_Admin_Result_Update_2b
				@command = 'NAP_Admin_Settlement_2b-UNDO'
				,@matchid = @MatchId
				,@Results = @QuarterResult
				,@creator = @AdminId
	           

		END
		ELSE IF @Action = 'REFUND'
		BEGIN	       
			EXEC DBPRO.BODB02.dbo.NAP_Admin_Result_Update_2b
				@command = 'NAP_Admin_Settlement_2b-REFUND'
				,@matchid = @MatchId
				,@Results = @QuarterResult
				,@creator = @AdminId  
	        
			EXEC dbo.NAP_Admin_Calculate_Main 
				 @matchid                    = @matchid
				,@ResourceIDs                = @strResourceIds
				,@action					= @Action
				,@mode                        = 'REFUND-EARLY' 
				,@strBettypes                = @strEarlyBettypes
		END
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 1001017
				,@ErrMsg = ERROR_MESSAGE() + ERROR_PROCEDURE()
	END CATCH

    -------------------------------------------------------------
    ---         CAPTURE value BALANCE after settlement        ---
    ---------------------------VVVV------------------------------
	INSERT INTO @BalanceWalletAfter (
		matchid
		, custid
		, balanceType
		, WalletType
		, BonusID
		, balance
	)
	EXEC [dbo].[NAP_Admin_CaptureBalanceByWallet]
		@MatchId 			= @matchId
		, @sportType		= @sportType
		, @Action 			= @Action
		, @Mode 			= 8 --@Mode Baseketball Early payout
		, @BAResults		= @QuarterResult

	-- Compare and update pending balance with error case
	EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
		@BalanceWalletBefore	= @BalanceWalletBefore
		, @BalanceWalletAfter	= @BalanceWalletAfter
		, @ActionId				= @ActionID

        
    --Exit process with ERROR
	IF(@ErrCode <> 0) 
	BEGIN
		------ releasing Settlement process
		EXEC dbo.NAP_Admin_CheckingProcess
			@isExistMatch		= 1
			, @IsReleased		= 1
		RETURN
	END

    -------------------------------------------------------------
    ---                      WRITE LOG                        ---
    ---------------------------VVVV------------------------------

    SELECT @stop = CURRENT_TIMESTAMP    
	
	DECLARE @xmlResults XML = CAST(@QuarterResult AS XML)
 
	SET @QuarterResult = ''
	SELECT @QuarterResult = @QuarterResult 
				+ T.C.value('@Id', 'VARCHAR(50)') 
				+ '(' + ISNULL(T.C.value('@HomeValue', 'VARCHAR(50)'),'')
				+ CASE 
					WHEN T.C.value('@AwayValue', 'VARCHAR(50)') IS NULL THEN ''
					ELSE '-' + T.C.value('@AwayValue', 'VARCHAR(50)')
					END	
				+ '),'
	 FROM @xmlResults.nodes('Results/Resource') T(c)
	 
	 IF RIGHT(@QuarterResult,1) = ','
		SELECT @QuarterResult = LEFT(@QuarterResult,LEN(@QuarterResult)-1)
		
    SELECT @logdata = 'NAP: Early Settlement (' + @action + ') for matchid:' + CAST(@matchid AS NVARCHAR(10)) 
                                                           + ' Result: ' + @QuarterResult + '<br/> '
                                                           + '(' + CAST(DATEDIFF(millisecond, @start, @stop) AS NVARCHAR(50)) + ' ms)'
														   + CASE WHEN @action = 'CAL' THEN '; Recalc: ' + CAST(@IsReSettledTickets AS VARCHAR(1)) ELSE '' END
    EXEC dbo.WriteLog_UserLog 
        @UserID = @AdminId
        ,@Doing = @logdata

    BEGIN TRY
        EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle 
            @userid                = @AdminId
            ,@matchid            = @MatchID
            ,@actionid            = @ActionID
            ,@finalhomescore    = @fth
            ,@finalawayscore    = @fta
            ,@hthomescore        = @hth
            ,@htawayscore        = @hta
            ,@GoalRecord        = NULL
            ,@betstatus            = NULL
            ,@Remark            = @logdata
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
            ,@GoalRecord        = NULL
            ,@betstatus            = NULL
            ,@Remark            = @logdata
            ,@IP                = @ip
    END CATCH
  
	------ releasing Settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch		= 1
		, @IsReleased		= 1
END
GO
