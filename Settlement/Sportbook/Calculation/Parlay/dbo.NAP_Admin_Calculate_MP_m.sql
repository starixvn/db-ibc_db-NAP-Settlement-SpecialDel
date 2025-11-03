/*<info serverAlias="DBCTG-bodb02,DBSID-bodb02,DBSIC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_MP_m] 
	@matchid INT
    ,@fth INT = NULL
    ,@fta INT = NULL
    ,@hth INT = NULL
    ,@hta INT = NULL
    ,@matchdate DATETIME
    ,@priorAction VARCHAR(20) = NULL
    ,@action VARCHAR(30) = 'VOID'
    ,@VoidTransID VARCHAR(2000) = ''
    ,@UserID INT = 0    
    ,@TennisTotal INT = NULL     
    ,@GoalSequence VARCHAR(50) = NULL         
    ,@resultDetail_bb VARCHAR(MAX) = NULL -- for basketball
    ,@resultDetail VARCHAR(MAX) = NULL -- for all result
    ,@strBettypes VARCHAR(MAX) = NULL
	,@betstatus	NVARCHAR(50) = NULL
	,@IsRefundHT BIT = NULL
	,@Sporttype SMALLINT = NULL
	,@strXML	VARCHAR(MAX) = ''
	,@strTransIds VARCHAR(MAX) = ''
AS
/*
    Creator: Viet
    Date: 20151001
    Task: Calculate Mix Parlay - bettransM
    Original SP: NAP_Admin_Calculate_9m
    DB: DBTXN/BODB02    
    
    Revision:        
        - 20160705@Kathy: PH-AIO phase 2 (67 bettypes ) [Redmine:#53154]
        - 20160830@Kathy: PH-AIO phase 2b [Redmine:#62861]
        - 20161205@Bobby: #61352 - Apply settle determined for parlay bet types
        - 20170215@Kathy: Basketball All-in-One [Redmine:#71372]
		- 20170525@Kathy: Add logic for bettype 617 [Redmine:#77046]
		- 20170609@Kathy: Early Settlement - BAIO [Redmine:#77835]
		- 20170719@Kathy: Correct ticket status when refund [Redmine:#77835]
		- 20170919@Kathy: Offer new 4 bettypes (461, 462, 463, 464) [Redmine:#83261]
		- 20170815@Kathy: Using table ResultDetail to store FGLG result instead of betstatus [Redmine:#81308]
		- 20171121@Kathy: Prevent lock escalation on table bettransM & betParlayDetail [Redmine:#75827]
		- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
		- 20190221@Kathy: Do not settle ticket on DB04x [Redmine:#108362]
		- 20190606@Sol: Incorporate PHAIO 4 [Redmine:#112885]
		- 20190620@Kathy: Remove betradar corner, auto betradar bettypes  PH AIO phase 4 [Redmine:#109584]
		- 20190626@Sol: Incorporate PHAIO 4b - 27 Corners Bet Types [Redmine:#115232]
		- 20190718@Sol: Relocate bettype 22 From early settlement to Main settlement [Redmine:#115232]
		- 20190909@Kathy: Do not update statuswinlost when voiding ticket [Redmine:#115376]
		- 20190715@Helen: Recover/Void tickets in Bet 14 - Update statuswinlost for VOID Tickets [Redmine:115377]
		- 20191112@Helen: Basketball calculation - sub parlay ticket is refunded then calculated in a tick [Redmine:123511]
		- 20191112@Sol: Incorporate PHAIO 5 [Redmine:#121681]
		- 20200511@Kathy: Remove tennis code [Redmine:#129316]
		- 20200901@Kathy: Change Calculate Formula for HDP Bet Types of Football [Redmine:#140769]
		- 20201027@Kathy: Change Calculate Formula for HDP Bet Types of Baseball [Redmine:#144297]
		- 20210303@Kathy: Exclude LiveScores When Calculate HDP Bet Types [Redmine:#150198]
		- 20210922@Louisa: Exclude LiveScores HDP for Ice Hockey and Rugby [Redmine:#159903]
		- 20211022@Kathy: Support Settlement Exclusion for Parlay Sub Tickets [Redmine:#163172]
		- 20220315@Kathy: Change to use STRING_SPLIT [Redmine:#166454]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
		- 20221026@Helen: resolve deadlock [Redmine:#179541]
		- 20221031@Helen: resolve deadlock - VERSION 2[Redmine:#179541]
		- 20221228@Kathy: Action UNDO match causes the sub ticket bettransm.winlostdate NULL on centralDB [Redmine:#182078]
		- 20221011@Kathy: Using Json [Redmine:#178694]
		- 20230306@Louisa: Exclude LiveScores HDP for Field Hockey [Redmine:#184450]
		- 20241113@Louisa: set priority of action MoveEvent higher than Settlement for WinlostDate value [Redmine:#213613]
		- 20250703@Max: Support re-settle when recover voided sub parlay from TVS [Redmine: #227829]
		- 20251020@Max: Basketball Main Bettype Hybrid Parlay [Redmine: #241652]

    Param's Explanation:
       
*/
BEGIN
    SET NOCOUNT ON
    
	-- CHECK SERVER BEFORE CALCULATING
	DECLARE @ServerName	SYSNAME 
			,@AllowExec	BIT
			,@transinfoJson	NVARCHAR(MAX)
			,@betparlaydetailinfoJson NVARCHAR(MAX)
			,@IsSiteDB BIT = 0
			,@FunctionName VARCHAR(100)
			,@SettlementAction VARCHAR(20)

	CREATE TABLE #tmpOutputBettransm (ID INT IDENTITY(1,1) PRIMARY KEY,transid BIGINT, refno BIGINT
		,status VARCHAR(10), StatusId TINYINT, ruben TINYINT
		,statuswinlost TINYINT, winlostdate SMALLDATETIME)
	
	CREATE TABLE #tmpOutputBetParlayDetail (ID INT IDENTITY(1,1) PRIMARY KEY,transid BIGINT, statuswinlost TINYINT, StatusId TINYINT, winlostdate SMALLDATETIME, odds SMALLMONEY)
	
	DECLARE @tmpOutputBettransmVoidRecover TABLE (transid BIGINT, winlost MONEY
		,status VARCHAR(10), statusId TINYINT, ruben TINYINT
		,statuswinlost TINYINT, creator INT, winlostdate SMALLDATETIME, odds SMALLMONEY)
	DECLARE @tmpTransIdsVoidRecover TABLE (transid BIGINT)
	DECLARE @tmpSubTransHybrid TABLE (TransId BIGINT, MatchId INT, Refno BIGINT, Odds MONEY)
	
	------ process by batch for betparlaydetail
	DECLARE @StartRow INT = 1
			, @StopRow INT 
			, @MaxRow INT = 1 -- Keep the total row of your data
			, @Threshold INT = 2000 -- the number of each batch
            
	SET @ServerName = @@SERVERNAME

	IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL 
		SET @IsSiteDB = 1

	IF OBJECT_ID('NAP_Set_ServerAction', 'P') IS NOT NULL
	BEGIN
		EXEC [dbo].[NAP_Set_ServerAction]
			@ServerName	= @ServerName
			,@AllowExec	= @AllowExec OUTPUT

		IF @AllowExec = 0
			RETURN
	END
	-- END CHECK
    
    IF @action IS NULL RETURN
    ---------------------------------------------------------------------------------------------------------
    BEGIN --BEGIN: params for corner bets, sportting solution and betradar ----------------------------------
        DECLARE 
			@xml XML     
			,@xmlBettypes XML                  
            ,@ht_fg 				VARCHAR(10)
			,@ht_lg 				VARCHAR(10)
			,@ft_fg 				VARCHAR(10)
			,@ft_lg 				VARCHAR(10)
			,@goalsequenceHT		VARCHAR(50)
			,@goalsequenceFT		VARCHAR(50)
			
			,@scorediff				SMALLINT = 0
			,@totalgoal				SMALLINT = 0
			,@totalht				SMALLINT = 0
			,@totalgoal_2H			SMALLINT = 0
			
			,@IsUpd_Void BIT = 0
			
        DECLARE @tmpResultDetail TABLE (ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50))
       
        DECLARE @tblBettypes TABLE (bettype SMALLINT, groupId SMALLINT, groupname VARCHAR(50), is3x30 BIT, isEarly BIT)
            
        SET @xmlBettypes = CONVERT(XML, @strBettypes)
        
        SET @totalgoal = @fth + @fta
        SET @scorediff = @fth - @fta
        SET @totalht = (@hth + @hta)
        SET @totalgoal_2H = (@fth + @fta) - (@hth + @hta)		
    
        INSERT INTO @tblBettypes (bettype, groupId, groupname, is3x30, isEarly)
        SELECT    T.c.value('./@t','SMALLINT')
                ,T.c.value('./@g','SMALLINT')
                ,T.c.value('./@n','VARCHAR(50)')
                ,T.c.value('./@is3x','BIT')
                ,T.c.value('./@isEarly','BIT')
        FROM    @xmlBettypes.nodes('/root/r') AS T(c)
        OPTION ( OPTIMIZE FOR ( @xmlBettypes = NULL ) )
    END --END: params for corner bets, sportting solution and betradar ----------------------------------
		
	DECLARE @modds MONEY , @doing VARCHAR(30) = 'zzz'
	
	WHILE (@doing <> @action)
    BEGIN        
        SET @doing = CASE @doing WHEN @priorAction THEN @action ELSE COALESCE(@priorAction, @action) END
		
		SET @SettlementAction = CASE WHEN @doing LIKE 'REFUND%' THEN 'REFUND' WHEN @doing IN ('CAL', 'UNDO') THEN @doing ELSE NULL END

		TRUNCATE TABLE #tmpOutputBettransm
		TRUNCATE TABLE #tmpOutputBetParlayDetail
		DELETE FROM @tmpTransIdsVoidRecover
		DELETE FROM @tmpOutputBettransmVoidRecover

        -- ===================================================
        IF @doing = 'VOID'
        BEGIN   
			SET @FunctionName = 'VoidSubParlay'

            INSERT INTO @tmpTransIdsVoidRecover(transid)
            SELECT CONVERT(BIGINT, [value])
            FROM STRING_SPLIT(@VoidTransID, ',')

            UPDATE dbo.bettransm WITH(ROWLOCK, UPDLOCK)
            SET winlost = CASE 
                    WHEN odds > 0 THEN stake
                    ELSE stake * ABS(odds)
                    END
                ,ruben = 1
                --,statuswinlost = 0
                ,STATUS = 'VOID'
                ,creator = @UserID
                ,statusID = 102
				,winlostdate = CASE WHEN @matchdate < winlostdate THEN winlostdate 
									ELSE @matchdate
								END
			OUTPUT INSERTED.transid, inserted.winlost, inserted.ruben, inserted.status, inserted.creator, inserted.statusID, inserted.winlostdate, inserted.odds
			INTO @tmpOutputBettransmVoidRecover(transid, winlost, ruben, status, creator, statusId, winlostdate, odds)
            WHERE matchid = @matchid 
                AND statusID NOT IN (101, 102) 
                AND transid IN (SELECT transid FROM @tmpTransIdsVoidRecover)

            UPDATE pd
            SET statuswinlost = 0
                ,statusID = 102
                ,winlostdate = r.winlostdate
				,odds = r.odds
			OUTPUT inserted.transid, inserted.statuswinlost, inserted.statusid, inserted.winlostdate, inserted.odds
			INTO #tmpOutputBetParlayDetail(transid, statuswinlost, StatusId, winlostdate, odds)
			FROM dbo.BetParlayDetail pd WITH(ROWLOCK,UPDLOCK)
			INNER JOIN @tmpOutputBettransmVoidRecover r
				ON pd.transid 	= r.transid
            WHERE pd.matchid = @matchid 
                AND pd.statusID NOT IN (101, 102)
        END --@doing = 'VOID'
    
        IF @doing = 'RECOVER'
        BEGIN 
			SET @FunctionName = 'RecoverSubParlay'

            INSERT INTO @tmpTransIdsVoidRecover(transid)
            SELECT CONVERT(BIGINT, [value])
            FROM STRING_SPLIT(@VoidTransId, ',')
        
            UPDATE dbo.bettransm WITH (ROWLOCK, UPDLOCK)
                SET    
					winlost = 0
                    ,ruben = 0
                    ,statuswinlost = NULL
                    ,status = 'running'
                    ,statusID = 0
                    ,winlostdate = NULL
					,creator = custid
			OUTPUT INSERTED.transid, inserted.winlost, inserted.ruben
					, Inserted.Statuswinlost
					, inserted.status, inserted.statusID, inserted.winlostdate, inserted.odds
			INTO @tmpOutputBettransmVoidRecover(transid, winlost, ruben, statuswinlost, status, statusid, winlostdate, odds)
            WHERE    matchid = @matchid
                    AND statusID = 102
                    AND transid IN (SELECT transid FROM @tmpTransIdsVoidRecover)                
        
            UPDATE  pd
                SET winlostdate = NULL
                    ,statuswinlost = NULL
                    ,statusid = 0
					,odds = r.odds
			OUTPUT inserted.transid, inserted.winlostdate, inserted.statuswinlost, inserted.statusid, inserted.odds
			INTO #tmpOutputBetParlayDetail(transid, winlostdate, statuswinlost, StatusId, odds)
			FROM dbo.BetParlayDetail pd WITH(ROWLOCK,UPDLOCK)
				INNER JOIN @tmpOutputBettransmVoidRecover r
				ON pd.transid 	= r.transid
            WHERE    matchid = @matchid 
                    AND pd.statusID = 102
        END --@doing = 'RECOVER'

		IF @doing = 'RECOVER-RECAL'
        BEGIN 
			SET @FunctionName = 'RecoverSubParlay'

            INSERT INTO @tmpTransIdsVoidRecover(transid)
            SELECT CONVERT(BIGINT, [value])
            FROM STRING_SPLIT(@VoidTransId, ',')
        
            UPDATE bm 
                SET    
					winlost = 0
                    ,ruben = CASE WHEN statuswinlost IS NULL THEN 0
								ELSE 1
							END
                    ,[status] = CASE 
							WHEN statuswinlost = 0  THEN N'DRAW'
							WHEN statuswinlost = 6 THEN N'Refund'
							WHEN statuswinlost IN (3,4) THEN N'LOSE'
							WHEN statuswinlost IN (1,2) THEN N'WON'
							WHEN statuswinlost IS NULL THEN 'running'
						END
					,statusID = CASE 
									WHEN statuswinlost = 0 THEN 111
									WHEN statuswinlost = 6 THEN 103 
									WHEN statuswinlost IN (3,4) THEN 113
									WHEN statuswinlost IN (1,2) THEN 112
									WHEN statuswinlost IS NULL THEN 0
								END
                    ,creator = z.creator
					,winlostdate = CASE WHEN statuswinlost IS NULL THEN NULL
										ELSE bm.winlostdate
									END
			OUTPUT inserted.transid, inserted.winlost, inserted.ruben
					, Inserted.status
					, inserted.statusID, inserted.creator, inserted.odds
			INTO @tmpOutputBettransmVoidRecover(transid, winlost, ruben, status, statusId, creator, odds)
			FROM dbo.bettransm bm WITH (ROWLOCK, UPDLOCK)
				INNER JOIN dbo.zzzbettrans z WITH (NOLOCK) ON z.transid = bm.TransId
            WHERE  bm.matchid = @matchid
                    AND statusID = 102
                    AND bm.transid IN (SELECT transid FROM @tmpTransIdsVoidRecover)                
        
            UPDATE  pd 
                SET pd.statusid = b.statusID
					,pd.statuswinlost = b.statuswinlost
					,pd.winlostdate = b.winlostdate
					,pd.odds = b.odds
			OUTPUT inserted.transid, inserted.winlostdate, inserted.statuswinlost, inserted.statusid, inserted.odds
			INTO #tmpOutputBetParlayDetail(transid, winlostdate, statuswinlost, StatusId, odds)
			FROM dbo.BetParlayDetail pd WITH(ROWLOCK,UPDLOCK)
				INNER JOIN dbo.bettransm b ON b.transid = pd.transid
            WHERE    pd.matchid = @matchid 
                    AND pd.statusID = 102
                    AND pd.transid IN (SELECT transid FROM @tmpTransIdsVoidRecover)
        END --@doing = 'RECOVER-RECAL'

		IF @doing = 'Hybrid_m'
        BEGIN 
			SET @FunctionName = 'SettleSubParlayHybrid'

           INSERT INTO @tmpSubTransHybrid (TransId)
            SELECT CONVERT(BIGINT, [value])
            FROM STRING_SPLIT(@strTransIds, ',')
        
            UPDATE bm 
                SET    
					winlost = 0
                    ,ruben = CASE WHEN statuswinlost IS NULL THEN 0
								ELSE 1
							END
                    ,[status] = CASE 
							WHEN statuswinlost = 0  THEN N'DRAW'
							WHEN statuswinlost = 6 THEN N'Refund'
							WHEN statuswinlost IN (3,4) THEN N'LOSE'
							WHEN statuswinlost IN (1,2) THEN N'WON'
							WHEN statuswinlost IS NULL THEN 'running'
						END
					,statusID = CASE 
									WHEN statuswinlost = 0 THEN 111
									WHEN statuswinlost = 6 THEN 103 
									WHEN statuswinlost IN (3,4) THEN 113
									WHEN statuswinlost IN (1,2) THEN 112
									WHEN statuswinlost IS NULL THEN 0
								END
					,winlostdate = CASE WHEN statuswinlost IS NULL THEN NULL
										ELSE bm.winlostdate
									END
			OUTPUT inserted.transid, inserted.winlost, inserted.ruben
					, Inserted.status
					, inserted.statusID, inserted.odds
			INTO @tmpOutputBettransmVoidRecover(transid, winlost, ruben, status, statusId, odds)
			FROM dbo.bettransm bm WITH (ROWLOCK, UPDLOCK)
            WHERE  bm.matchid = @matchid
                    AND statusID IN (0,1)
					AND statuswinlost IS NOT NULL
                    AND bm.transid IN (SELECT transid FROM @tmpSubTransHybrid)                
        
            UPDATE  pd 
                SET pd.statusid = b.statusID
					,pd.statuswinlost = b.statuswinlost
					,pd.winlostdate = b.winlostdate
					,pd.odds = b.odds
			OUTPUT inserted.transid, inserted.winlostdate, inserted.statuswinlost, inserted.statusid, inserted.odds
			INTO #tmpOutputBetParlayDetail(transid, winlostdate, statuswinlost, StatusId, odds)
			FROM dbo.BetParlayDetail pd WITH(ROWLOCK,UPDLOCK)
				INNER JOIN dbo.bettransm b ON b.transid = pd.transid
            WHERE    pd.matchid = @matchid 
                    AND pd.statusID IN (0,1)
                    AND pd.transid IN (SELECT transid FROM @tmpSubTransHybrid)
        END --@doing = 'Hybrid_m'

		IF @doing = 'updateleg'
        BEGIN   
			SET @FunctionName = 'UpdateLegOdds'

			INSERT INTO @tmpSubTransHybrid (TransId, MatchId, Refno, Odds)
			SELECT js.TransId AS TransId, js.MatchId AS MatchId, js.Refno AS Refno, js.Odds AS Odds
			FROM OPENJSON(@strXML) WITH (TransId BIGINT, MatchId INT, Refno BIGINT, Odds MONEY) js

            UPDATE bm 
            SET odds = t.Odds
			OUTPUT INSERTED.transid, inserted.odds
			INTO @tmpOutputBettransmVoidRecover(transid, odds)
			FROM dbo.bettransm bm WITH(ROWLOCK, UPDLOCK)
				INNER JOIN @tmpSubTransHybrid t ON t.TransId = bm.TransId
			WHERE bm.MatchId = @MatchId

            UPDATE pd
            SET odds = r.odds
			OUTPUT inserted.transid, inserted.odds
			INTO #tmpOutputBetParlayDetail(transid, odds)
			FROM dbo.BetParlayDetail pd WITH(ROWLOCK,UPDLOCK)
			INNER JOIN @tmpOutputBettransmVoidRecover r
				ON pd.transid 	= r.transid
			WHERE pd.MatchId = @MatchId
        END --@doing = 'VOID'

        -- ===================================================        

		IF @IsSiteDB = 1 AND @doing <> 'CAL'
		BEGIN
			IF @doing IN ('VOID', 'RECOVER', 'RECOVER-RECAL')
			BEGIN
				SET @transinfoJson = (
					SELECT	transId AS 't'	
							,winlost AS 'w'
							,Status AS 's' 
							,creator AS 'cr'
							,statusId AS 'sid' 
							,CASE WHEN @doing IN ('RECOVER','RECOVER-RECAL') AND winlostdate IS NULL THEN '' ELSE winlostdate END AS 'wld'
							,CASE WHEN @doing = 'RECOVER' AND statuswinlost IS NULL THEN '' ELSE CAST(statuswinlost AS VARCHAR(1) ) END AS 'statuswl'
							,ruben AS 'r' -- ruben
					FROM	@tmpOutputBettransmVoidRecover
					FOR JSON AUTO
				)
			END
			ELSE IF @doing IN ('Hybrid_m')
			BEGIN
				SET @transinfoJson = (
					SELECT	transId AS 't'	
							,winlost AS 'w'
							,Status AS 's' 
							,statusId AS 'sid' 
							,CASE WHEN winlostdate IS NULL THEN '' ELSE winlostdate END AS 'wld'
							,ruben AS 'r' -- ruben
					FROM	@tmpOutputBettransmVoidRecover
					FOR JSON AUTO
				)
			END
			ELSE IF @doing IN ('updateleg')
			BEGIN
				SET @transinfoJson = (
					SELECT	transId AS 't'	
							,odds AS 'o'						
					FROM	@tmpOutputBettransmVoidRecover
					FOR JSON AUTO
				)
			END

			IF @transinfoJson IS NOT NULL
				EXEC dbo.SiteDB_NAP_SettlementService_CalculationLogIns 
					@SystemName = 'Settlement' 
					,@FunctionName = @FunctionName
					,@TableName = 'bettransm'
					,@MatchId = @MatchId
					,@TransInfoJson = @transinfoJson
					,@SettlementAction = @SettlementAction
					,@TicketType = 'p'
			
			-- process by batch to insert for sync server
			SET @MaxRow = (SELECT MAX(ID) FROM #tmpOutputBetParlayDetail)
			SET @Threshold = 2000

			IF @Threshold >= @MaxRow
				SET @Threshold = @MaxRow

			-- SET for first batch
			SELECT @StartRow = 1, @StopRow = @Threshold
			WHILE (@MaxRow IS NOT NULL)
			BEGIN
				SET @betparlaydetailinfoJson = (
					SELECT	DISTINCT transId AS 't'						
							,CASE WHEN winlostdate IS NULL THEN '' ELSE winlostdate END  AS 'wld'							
							,CASE WHEN statuswinlost IS NULL THEN '' ELSE CAST(statuswinlost AS VARCHAR(1) ) END  AS 'statuswl'
							,StatusId AS 'sid'
							,odds AS 'o'
					FROM	#tmpOutputBetParlayDetail
					WHERE ID BETWEEN @StartRow AND @StopRow
					FOR JSON AUTO
				)

				IF @betparlaydetailinfoJson IS NOT NULL
					EXEC dbo.SiteDB_NAP_SettlementService_CalculationLogIns 
						@SystemName = 'Settlement' 
						,@FunctionName = @FunctionName
						,@TableName = 'BetParlayDetail'
						,@MatchId = @MatchId
						,@TransInfoJson = @betparlaydetailinfoJson
						,@SettlementAction = @SettlementAction
						,@TicketType = 'p'

				IF @StopRow = @MaxRow BREAK

				SET @StartRow = @StopRow + 1
				SET @StopRow = @StopRow + @Threshold

				IF @StopRow >= @MaxRow
					SET @StopRow = @MaxRow
			END
		END
    END -- while
END -- end SP
GO