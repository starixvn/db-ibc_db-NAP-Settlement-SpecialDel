/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_MP_m] 
	@matchid INT
    ,@fth INT = NULL
    ,@fta INT = NULL
    ,@hth INT = NULL
    ,@hta INT = NULL
    ,@matchdate DATETIME
    ,@priorAction VARCHAR(20) = NULL
    ,@action VARCHAR(10) = 'CAL'
    ,@VoidTransID VARCHAR(2000) = ''
    ,@UserID INT = 0    
    ,@SelectedSet VARCHAR(50) = NULL     
    ,@TennisTotal INT = NULL
    ,@TotalGameHomeMatch INT = NULL
    ,@TotalGameAwayMatch INT = NULL         
    ,@GoalSequence VARCHAR(50) = NULL         
    ,@ResourceIDs VARCHAR(MAX)= NULL
    ,@resultDetail_cb VARCHAR(MAX) = NULL -- for corners bets
    ,@resultDetail_ss VARCHAR(MAX) = NULL -- sportting solution
    ,@resultDetail_br VARCHAR(MAX) = NULL -- for betradar
    ,@resultDetail_bb VARCHAR(MAX) = NULL -- for basketball
    ,@resultDetail VARCHAR(MAX) = NULL -- for all result
    ,@SelectedQuarter VARCHAR(MAX) = NULL
    ,@strBettypes VARCHAR(MAX) = NULL
	,@betstatus	NVARCHAR(50) = NULL
	,@IsRefundHT BIT = NULL
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
		
    Param's Explanation:
       
*/
BEGIN
    SET NOCOUNT ON
    
	-- CHECK SERVER BEFORE CALCULATING
	DECLARE @ServerName	SYSNAME 
			,@AllowExec	BIT

	SET @ServerName = @@SERVERNAME

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
            ,@homeScoreSet1         tinyint
            ,@homeScoreSet2         tinyint
            ,@homeScoreSet3         tinyint
            ,@homeScoreSet4         tinyint
            ,@homeScoreSet5         tinyint
            ,@awayScoreSet1         tinyint
            ,@awayScoreSet2         tinyint
            ,@awayScoreSet3         tinyint
            ,@awayScoreSet4         tinyint
            ,@awayScoreSet5         tinyint
            ,@SetxGameyHomeWON        VARCHAR(MAX) = NULL 
            ,@SetxGameyAwayWON        VARCHAR(MAX) = NULL 
            ,@SetxGameyDRAW            VARCHAR(MAX) = NULL 
            ,@SetxGameyREFUND        VARCHAR(MAX) = NULL
            ,@SelectedSetCAL        VARCHAR(50)  = NULL
            ,@SelectedSetREFUND        VARCHAR(50)  = NULL 
            ,@fthCorners            INT = NULL 
            ,@ftaCorners            INT = NULL 
            ,@hthCorners            INT = NULL 
            ,@htaCorners            INT = NULL     
            ,@FTFCorner                VARCHAR(10)    = NULL 
            ,@FTLCorner                VARCHAR(10)    = NULL 
            ,@HTFCorner                VARCHAR(10)    = NULL 
            ,@HTLCorner                VARCHAR(10)    = NULL
            ,@penaltyshootout        VARCHAR(10)    = NULL
            ,@matchDecidedMethod    VARCHAR(10)    = NULL
            ,@first10Min1x2            VARCHAR(10)    = NULL
            ,@firstGoalTime10Min    VARCHAR(10)    = NULL
            ,@firstGoalTime15Min    VARCHAR(10)    = NULL
            ,@WhoAdvancesNextRound    VARCHAR(10) = NULL
            ,@ExtraTimeandGoal        VARCHAR(10)    = NULL
            ,@ExtraTimeYN            VARCHAR(10) = NULL
            ,@PlayerSentOff            VARCHAR(10) = NULL
            ,@HTPlayerSentOff        VARCHAR(10) = NULL
            ,@PlayerSentOffHome        VARCHAR(10) = NULL
            ,@HTPlayerSentOffHome    VARCHAR(10) = NULL
            ,@PlayerSentOffAway        VARCHAR(10) = NULL
            ,@HTPlayerSentOffAway    VARCHAR(10) = NULL
            ,@GoalScorerFirst        VARCHAR(10) = NULL                
            ,@firstHNextGoal        VARCHAR(MAX)= NULL
            ,@NextGoal                VARCHAR(MAX)= NULL
            ,@NextGoalTime15Min        VARCHAR(MAX)= NULL
            ,@ExtraNextGoal            VARCHAR(MAX)= NULL
            ,@GoalScorerAnytime        VARCHAR(MAX)= NULL
            ,@FirstGoalMethod			VARCHAR(2) = NULL
            ,@TimeFirstGoal			VARCHAR(10) = NULL
            ,@ResourceIDsCAL        VARCHAR(MAX)= NULL
            ,@ResourceIDsREFUND        VARCHAR(MAX)= NULL
            
            ,@ht_fg 				VARCHAR(10)
			,@ht_lg 				VARCHAR(10)
			,@ft_fg 				VARCHAR(10)
			,@ft_lg 				VARCHAR(10)
			
			,@scorediff				SMALLINT = 0
			,@totalgoal				SMALLINT = 0
			,@totalht				SMALLINT = 0
			,@totalgoal_2H			SMALLINT = 0
			
            -- for basketball
            ,@basketball_ResourceIdsCAL	VARCHAR(MAX) = NULL
			,@basketball_ResourceIdsREFUND VARCHAR(MAX) = NULL
			
			,@FTHighestQuarter	VARCHAR(10) = NULL			
			,@Q1Home			INT
			,@Q2Home			INT
			,@Q3Home			INT
			,@Q4Home			INT			
			,@Q1Away			INT
			,@Q2Away			INT
			,@Q3Away			INT
			,@Q4Away			INT
			,@bettype_22 VARCHAR(20)
			,@bettype_160 VARCHAR(20)
    
			
        DECLARE @tmpResultDetail TABLE (ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50))
        
        DECLARE @tblBettypes TABLE (bettype SMALLINT, groupId SMALLINT, groupname VARCHAR(50), is3x30 BIT, isAuto BIT, isEarly BIT)
            
        SET @xmlBettypes = CONVERT(XML, @strBettypes)
        
        SET @totalgoal = @fth + @fta
        SET @scorediff = @fth - @fta
        SET @totalht = (@hth + @hta)
        SET @totalgoal_2H = (@fth + @fta) - (@hth + @hta)
        
        SET @bettype_22 = '22'
		SET @bettype_160 = '160'			
    
        INSERT INTO @tblBettypes (bettype, groupId, groupname, is3x30, isAuto, isEarly)
        SELECT    T.c.value('./@t','SMALLINT')
                ,T.c.value('./@g','SMALLINT')
                ,T.c.value('./@n','VARCHAR(50)')
                ,T.c.value('./@is3x','BIT')
                ,T.c.value('./@isAuto','BIT')
                ,T.c.value('./@isEarly','BIT')
        FROM    @xmlBettypes.nodes('/root/r') AS T(c)
        OPTION ( OPTIMIZE FOR ( @xmlBettypes = NULL ) )
    END --END: params for corner bets, sportting solution and betradar ----------------------------------
		
    DECLARE @modds MONEY , @doing VARCHAR(10) = 'zzz'

    WHILE (@doing <> @action)
    BEGIN        
        SET @doing = CASE @doing WHEN @priorAction THEN @action ELSE COALESCE(@priorAction, @action) END
    --    --------------------------------------
    
        IF @doing = 'correctBettype'
        BEGIN
            UPDATE BM
            SET bettype = o.bettype
            FROM dbo.bettransm BM WITH(ROWLOCK, UPDLOCK)
                INNER JOIN dbo.odds o WITH (NOLOCK) ON BM.oddsid = o.oddsid
            WHERE BM.matchid = @matchid AND BM.bettype <> o.bettype
        END

        IF @doing = 'REFUND'
        BEGIN
            IF @resultDetail_ss IS NOT NULL -- sportting solution
            BEGIN
                SET @xml = CONVERT(XML, @resultDetail_ss)    
                
                SELECT TOP(1) 
                    @SelectedSetCAL = ISNULL(T.C.value('./@SelectedSetCAL[1]', 'varchar(50)'), '')
                    ,@SelectedSetREFUND = ISNULL(T.C.value('./@SelectedSetREFUND[1]', 'varchar(50)'), '')
                FROM @xml.nodes('/root/r') as [T](C) --T: table, C: column    
                OPTION ( OPTIMIZE FOR ( @xml = NULL ) )    
            END
                
            IF @resultDetail_br IS NOT NULL -- for betradar
            BEGIN
                SET @xml = CONVERT(XML, @resultDetail_br)
                
                SELECT TOP(1)
                    @ResourceIDsREFUND = ISNULL(T.C.value('./@ResourceIDsREFUND[1]', 'varchar(MAX)'), '')                
                FROM @xml.nodes('/root/r') as [T](C) --T: table, C: column
                OPTION ( OPTIMIZE FOR ( @xml = NULL ) )
            END
            
            IF @resultDetail_bb IS NOT NULL -- for basketball
            BEGIN
				SET @xml = CONVERT(XML, @resultDetail_bb)
				
				;WITH cteResourceIds
				AS(
					SELECT	T.c.value('./@rid','VARCHAR(20)') AS ResourceId
							,T.c.value('./@ssId','TINYINT') AS SettlementStatusId
					FROM	@xml.nodes('/root/r') AS T(c)
				)
				SELECT	@basketball_ResourceIdsREFUND = COALESCE(@basketball_ResourceIdsREFUND + ',' + r.ResourceId ,r.ResourceId)						
				FROM	cteResourceIds
					CROSS APPLY (
						SELECT CASE
									WHEN ResourceId = '00' THEN 'FT'
									WHEN ResourceId = '01' THEN '1H'
									WHEN ResourceId = '02' THEN '2H'
									ELSE ResourceId
								END AS ResourceId
									
					) r
				WHERE	SettlementStatusId = 1					
				OPTION	( OPTIMIZE FOR ( @xml = NULL ) )  
            END
           
            CREATE TABLE #RefundResult (transid BIGINT, refno BIGINT)
        
            UPDATE bm
            SET winlostdate = @matchdate
                ,[status] = 'Refund'
                ,statuswinlost = 0
                ,ruben = 1
                ,statusID = 103
            OUTPUT INSERTED.transid, INSERTED.refno INTO #RefundResult(transid, refno)
            FROM dbo.bettransm bm WITH(ROWLOCK, UPDLOCK) 
				INNER JOIN @tblBettypes t
					ON bm.bettype = t.bettype
				CROSS APPLY (
					SELECT	CAST(CAST(bm.bettype AS VARCHAR) + ISNULL(SUBSTRING(bm.betcheck, 2, LEN(bm.betcheck)),'') AS VARCHAR(20)) AS ResourceId
				)r
				CROSS APPLY (
					SELECT CASE 
								WHEN t.groupId = 10 
									THEN CASE 
											WHEN bm.betcheck = '801' THEN 'Q1'
											WHEN bm.betcheck = '802' THEN 'Q2'
											WHEN bm.betcheck = '803' THEN 'Q3'
											WHEN bm.betcheck = '804' THEN 'Q4'
											ELSE ''
										END
								ELSE ''
							END AS QuarterX
				)q
            WHERE matchid = @matchid                 
                --AND bettype NOT IN (14, 127) 
                AND statusID NOT IN (101, 102)
                AND 1 = CASE WHEN @SelectedSetREFUND IS NULL AND @SelectedSetCAL IS NULL THEN 1 
                             WHEN @SelectedSetREFUND LIKE '%1%' AND bm.Bettype IN (154,155,156,1311,1312,1316,1317,1318) AND betcheck LIKE '801%' THEN 1  --Exclude 1324
                             WHEN @SelectedSetREFUND LIKE '%2%' AND bm.Bettype IN (154,155,156,1311,1312,1316,1317,1318) AND betcheck LIKE '802%' THEN 1
                             WHEN @SelectedSetREFUND LIKE '%3%' AND bm.Bettype IN (154,155,156,1311,1312,1316,1317,1318) AND betcheck LIKE '803%' THEN 1
                             WHEN @SelectedSetREFUND LIKE '%4%' AND bm.Bettype IN (154,155,156,1311,1312,1316,1317,1318) AND betcheck LIKE '804%' THEN 1
                             WHEN @SelectedSetREFUND LIKE '%5%' AND bm.Bettype IN (154,155,156,1311,1312,1316,1317,1318) AND betcheck LIKE '805%' THEN 1
                             WHEN @SelectedSetREFUND LIKE '%6%' AND bm.Bettype IN (1,2,3,20,153,1301,1302,1303,1305,1306,1308) THEN 1 
                             ELSE 0 END
                AND 1 = CASE WHEN @ResourceIDsREFUND IS NULL AND t.groupId <> 8 THEN 1  
							 WHEN @ResourceIDsREFUND IS NOT NULL AND bm.Bettype = 22 AND CHARINDEX(REPLACE(SUBSTRING(CAST(Betcheck AS VARCHAR(20)),2,5),@bettype_22,@bettype_160),@ResourceIDsREFUND)>0 THEN 1 
							 WHEN @ResourceIDsREFUND IS NOT NULL AND bm.Bettype IN (160,164,169,180) AND CHARINDEX(SUBSTRING(CAST(Betcheck AS VARCHAR(20)),2,5),@ResourceIDsREFUND)>0 THEN 1 
							 WHEN @ResourceIDsREFUND IS NOT NULL AND t.groupId = 8	AND bm.Bettype NOT IN (160,164,169,180,22) AND CHARINDEX(CAST(bm.Bettype AS VARCHAR(20)),@ResourceIDsREFUND)>0 THEN 1 
							 ELSE 0 END   --Betradar 2 Auto Bettype
				AND 1 = CASE
							WHEN @basketball_ResourceIdsREFUND IS NULL THEN 1 --s basketball
							WHEN t.isEarly = 1 THEN CASE
														WHEN CHARINDEX(',' + r.ResourceId + ',', ',' + @basketball_ResourceIdsREFUND + ',') > 0 THEN 1
														ELSE 0
													END
							WHEN t.groupId = 10 THEN CASE
														WHEN CHARINDEX(',' + q.QuarterX + ',', ',' + @basketball_ResourceIdsREFUND + ',') > 0 THEN 1
														ELSE 0
													END
							WHEN CHARINDEX(',' + t.groupName + ',', ',' + @basketball_ResourceIdsREFUND + ',') > 0 THEN 1
							ELSE 0
							END														
			
            UPDATE pd
            SET winlostdate = @matchdate
                ,statuswinlost = 0
                ,statusID = 103
            FROM dbo.BetParlayDetail pd WITH(ROWLOCK, UPDLOCK)
                INNER JOIN #RefundResult r
                    ON    pd.transid = r.transid
                        AND pd.RefNo = r.refno
                
        END --@doing = 'REFUND'
    
        -- ===================================================
        IF @doing = 'REFUND-FT'
        BEGIN
            IF @resultDetail_br IS NOT NULL -- for betradar
            BEGIN
                SET @xml = CONVERT(XML, @resultDetail_br)
                
                SELECT TOP(1) 
                    @ResourceIDsREFUND = ISNULL(T.C.value('./@ResourceIDsREFUND[1]', 'varchar(MAX)'), '')                
                FROM @xml.nodes('/root/r') as [T](C) --T: table, C: column
                OPTION ( OPTIMIZE FOR ( @xml = NULL ) )
            END
            
            CREATE TABLE #RefundFTResult (transid BIGINT, refno BIGINT)
            
            UPDATE	bm
				SET winlostdate = @matchdate
					,[status] = 'Refund'
					,statuswinlost = 0
					,ruben = 1
					,statusID = 103
            OUTPUT INSERTED.transid, INSERTED.refno INTO #RefundFTResult(transid, refno)
            FROM	@tblBettypes t
				INNER JOIN dbo.bettransm bm WITH(ROWLOCK, UPDLOCK)
					ON bm.bettype = t.bettype
            WHERE	matchid = @matchid 
					AND t.groupId NOT IN (1,3,4,5)
					AND statusID NOT IN (101, 102)
					AND 1 = CASE 
								WHEN @ResourceIDsREFUND IS NULL AND t.groupId <> 8 THEN 1  
								WHEN @ResourceIDsREFUND IS NOT NULL AND bm.Bettype = 22 AND CHARINDEX(REPLACE(SUBSTRING(CAST(Betcheck AS VARCHAR(20)),2,5),@bettype_22,@bettype_160),@ResourceIDsREFUND)>0 THEN 1 
								WHEN @ResourceIDsREFUND IS NOT NULL AND bm.Bettype IN (160,164,169,180) AND CHARINDEX(SUBSTRING(CAST(Betcheck AS VARCHAR(20)),2,5),@ResourceIDsREFUND)>0 THEN 1 
								WHEN @ResourceIDsREFUND IS NOT NULL AND bm.Bettype NOT IN (160,164,169,180,22) AND t.groupId = 8 AND CHARINDEX(CAST(bm.Bettype AS VARCHAR(20)),@ResourceIDsREFUND)>0 THEN 1 
						ELSE 0 END   --Betradar 2 Auto Bettype

            UPDATE pd
            SET winlostdate = @matchdate
                ,statuswinlost = 0
                ,statusID = 103
            FROM dbo.BetParlayDetail pd WITH(ROWLOCK, UPDLOCK)
                INNER JOIN #RefundFTResult r
                    ON    pd.transid = r.transid
                        AND pd.RefNo = r.refno
                        
        END --@doing = 'REFUND-FT'


        IF @doing = 'REFUND-HT'
        BEGIN
            IF @resultDetail_br IS NOT NULL -- for betradar
            BEGIN
                SET @xml = CONVERT(XML, @resultDetail_br)
                
                SELECT TOP(1) 
                    @ResourceIDsREFUND = ISNULL(T.C.value('./@ResourceIDsREFUND[1]', 'varchar(MAX)'), '')                
                FROM @xml.nodes('/root/r') as [T](C) --T: table, C: column
                OPTION ( OPTIMIZE FOR ( @xml = NULL ) )
            END
            
            CREATE TABLE #RefundHTResult (transid BIGINT, refno BIGINT)
            
            -- Refund sub tickets of 11 bet types (FT) from BetRadar in case '30x3' match has been suspended
            UPDATE	bm
				SET winlostdate = @matchdate
					,[status] = 'Refund'
					,statuswinlost = 0
					,ruben = 1
					,statusID = 103
            OUTPUT	INSERTED.transid, INSERTED.refno INTO #RefundHTResult(transid, refno)
            FROM	@tblBettypes t
				INNER JOIN dbo.bettransm bm WITH(ROWLOCK, UPDLOCK)
					ON	bm.bettype = t.bettype
            WHERE	matchid = @matchid 
					AND t.is3x30 = 1
					AND statusID NOT IN (101, 102)
			OPTION (FORCE ORDER)
			
            UPDATE pd
            SET winlostdate = @matchdate
                ,statuswinlost = 0
                ,statusID = 103
            FROM dbo.BetParlayDetail pd WITH(ROWLOCK, UPDLOCK)
                INNER JOIN #RefundHTResult r
                    ON    pd.transid = r.transid
                        AND pd.RefNo = r.refno
                        
        END -- @doing = 'REFUND-HT'
    
        -- ===================================================
        IF @doing = 'VOID'
        BEGIN
            DECLARE @transtbl TABLE (transid BIGINT)

            INSERT INTO @transtbl
            SELECT CONVERT(BIGINT, val)
            FROM dbo.strSplit(@VoidTransID, ',')

            UPDATE dbo.bettransm WITH(ROWLOCK, UPDLOCK)
            SET winlost = CASE 
                    WHEN odds > 0 THEN stake
                    ELSE stake * ABS(odds)
                    END
                ,ruben = 1
                ,statuswinlost = 0
                ,STATUS = 'VOID'
                ,creator = @UserID
                ,statusID = 102
                ,winlostdate = @matchdate
            WHERE matchid = @matchid 
                AND statusID NOT IN (101, 102) 
                AND transid IN (SELECT transid FROM @transtbl)

            UPDATE dbo.BetParlayDetail WITH(ROWLOCK, UPDLOCK)
            SET statuswinlost = 0
                ,statusID = 102
                ,winlostdate = @matchdate
            WHERE matchid = @matchid 
                AND statusID NOT IN (101, 102) 
                AND transid IN (SELECT transid FROM @transtbl)
        END --@doing = 'VOID'
    
        IF @doing = 'RECOVER'
        BEGIN
            DECLARE @tblTransIds TABLE (transid BIGINT)
        
            INSERT INTO @tblTransIds
            SELECT CONVERT(BIGINT, val)
            FROM dbo.strSplit(@VoidTransId, ',')
        
            UPDATE dbo.bettransm WITH (ROWLOCK, UPDLOCK)
                SET    winlost = 0
                    ,ruben = 0
                    ,statuswinlost = NULL
                    ,status = 'running'
                    ,statusID = 0
                    ,winlostdate = NULL
            WHERE    matchid = @matchid
                    AND statusID = 102
                    AND transid IN (SELECT transid FROM @tblTransIds)
                
        
            UPDATE    dbo.BetParlayDetail WITH(ROWLOCK, UPDLOCK)
                SET winlostdate = NULL
                    ,statuswinlost = NULL
                    ,statusid = 0
            WHERE    matchid = @matchid 
                    AND statusID = 102
                    AND transid IN (SELECT transid FROM @tblTransIds)
        
        END --@doing = 'RECOVER'

        -- ===================================================        
        IF @doing = 'UNDO'
        BEGIN            
            CREATE TABLE #UndoResult (transid BIGINT, refno BIGINT)
         
            UPDATE bm WITH(ROWLOCK, UPDLOCK)
            SET [status] = 'running'
                ,statuswinlost = 0
                ,ruben = 0
                ,statusID = 0
            OUTPUT INSERTED.transid, INSERTED.refno INTO #UndoResult(transid, refno)
            FROM    @tblBettypes t
				INNER LOOP JOIN dbo.bettransm bm
					ON	bm.bettype = t.bettype
				CROSS APPLY (
					SELECT CAST(CAST(bm.bettype AS VARCHAR) + ISNULL(SUBSTRING(bm.betcheck, 2, LEN(bm.betcheck)),'') AS VARCHAR(20)) AS ResourceId
				)r
            WHERE matchid = @matchid  
                AND statusID NOT IN (101, 102, 1)
                AND 1 = CASE WHEN @SelectedSet IS NULL THEN 1 
                             WHEN @SelectedSet LIKE '%1%' AND bm.Bettype IN (154,155,156,1311,1312,1316,1317,1318,1324) AND betcheck LIKE '801%' THEN 1 
                             WHEN @SelectedSet LIKE '%2%' AND bm.Bettype IN (154,155,156,1311,1312,1316,1317,1318,1324) AND betcheck LIKE '802%' THEN 1
                             WHEN @SelectedSet LIKE '%3%' AND bm.Bettype IN (154,155,156,1311,1312,1316,1317,1318,1324) AND betcheck LIKE '803%' THEN 1
                             WHEN @SelectedSet LIKE '%4%' AND bm.Bettype IN (154,155,156,1311,1312,1316,1317,1318,1324) AND betcheck LIKE '804%' THEN 1
                             WHEN @SelectedSet LIKE '%5%' AND bm.Bettype IN (154,155,156,1311,1312,1316,1317,1318,1324) AND betcheck LIKE '805%' THEN 1
                             WHEN @SelectedSet LIKE '%6%' AND bm.Bettype IN (1,2,3,20,153,1301,1302,1303,1305,1306,1308) THEN 1 
                             ELSE 0 END
                AND 1 = CASE WHEN @ResourceIDs IS NULL AND t.groupId <> 8 THEN 1 
							 WHEN @ResourceIDs IS NOT NULL AND bm.Bettype = 22 AND CHARINDEX(REPLACE(SUBSTRING(CAST(betcheck AS VARCHAR(20)),2,5),@bettype_22,@bettype_160),@ResourceIDs)>0 THEN 1 
                             WHEN @ResourceIDs IS NOT NULL AND bm.Bettype IN (160,164,169,180) AND CHARINDEX(SUBSTRING(CAST(betcheck AS VARCHAR(20)),2,5),@ResourceIDs)>0 THEN 1 
                             WHEN @ResourceIDs IS NOT NULL AND bm.Bettype NOT IN (160,164,169,180,22) AND t.groupId = 8 AND CHARINDEX(CAST(bm.Bettype AS VARCHAR(20)),@ResourceIDs)>0 THEN 1 
                             ELSE 0 END 
              AND 1 = CASE -- basketball
							WHEN @SelectedQuarter IS NULL THEN 1
							WHEN t.isEarly = 1 THEN CASE
														WHEN CHARINDEX(',' + r.ResourceId + ',', ',' + @SelectedQuarter + ',') > 0 THEN 1
														ELSE 0
														END
							WHEN t.groupId = 10 THEN CASE
														WHEN CHARINDEX(',' + bm.betcheck + ',', ',' + @SelectedQuarter + ',') > 0 THEN 1
														ELSE 0
													END
							WHEN CHARINDEX(',' + t.groupName + ',', ',' + @SelectedQuarter + ',') > 0 THEN 1
							ELSE 0
							END	
			OPTION (FORCE ORDER)			
					
            UPDATE pd
            SET statuswinlost = 0
                ,statusID = 0
            FROM dbo.BetParlayDetail pd WITH(ROWLOCK, UPDLOCK)
                INNER JOIN #UndoResult r
                    ON    pd.transid = r.transid
                        AND pd.RefNo = r.refno 
                        
        END --@doing = 'UNDO'
        -- ===================================================
        
        IF @doing = 'CAL'
        BEGIN
            IF @resultDetail_cb IS NOT NULL -- corners bets 
            BEGIN
                SET @xml = CONVERT(XML, @resultDetail_cb)    
                
                SELECT @fthCorners = ISNULL(T.C.value('./@fthCorners[1]', 'int'), 0)
                    ,@ftaCorners = ISNULL(T.C.value('./@ftaCorners[1]', 'int'), 0)
                    ,@hthCorners = ISNULL(T.C.value('./@hthCorners[1]', 'int'), 0)
                    ,@htaCorners = ISNULL(T.C.value('./@htaCorners[1]', 'int'), 0)
                    ,@ftfCorner = ISNULL(T.C.value('./@ftfCorner[1]', 'varchar(10)'), '')
                    ,@htfCorner = ISNULL(T.C.value('./@htfCorner[1]', 'varchar(10)'), '')
                    ,@ftlCorner = ISNULL(T.C.value('./@ftlCorner[1]', 'varchar(10)'), '')
                    ,@htlCorner = ISNULL(T.C.value('./@htlCorner[1]', 'varchar(10)'), '')
                FROM @xml.nodes('/root/r') as [T](C) --T: table, C: column    
                OPTION ( OPTIMIZE FOR ( @xml = NULL ) )    
            END

            IF @resultDetail_ss IS NOT NULL -- sportting solution
            BEGIN
                SET @xml = CONVERT(XML, @resultDetail_ss)    
                
                SELECT TOP(1) 
                    @homeScoreSet1 = ISNULL(T.C.value('./@homeScoreSet1[1]', 'tinyint'), 0)
                    ,@homeScoreSet2 = ISNULL(T.C.value('./@homeScoreSet2[1]', 'tinyint'), 0)
                    ,@homeScoreSet3 = ISNULL(T.C.value('./@homeScoreSet3[1]', 'tinyint'), 0)
                    ,@homeScoreSet4 = ISNULL(T.C.value('./@homeScoreSet4[1]', 'tinyint'), 0)
                    ,@homeScoreSet5 = ISNULL(T.C.value('./@homeScoreSet5[1]', 'tinyint'), 0)
                    ,@awayScoreSet1 = ISNULL(T.C.value('./@awayScoreSet1[1]', 'tinyint'), 0)
                    ,@awayScoreSet2 = ISNULL(T.C.value('./@awayScoreSet2[1]', 'tinyint'), 0)
                    ,@awayScoreSet3 = ISNULL(T.C.value('./@awayScoreSet3[1]', 'tinyint'), 0)
                    ,@awayScoreSet4 = ISNULL(T.C.value('./@awayScoreSet4[1]', 'tinyint'), 0)
                    ,@awayScoreSet5 = ISNULL(T.C.value('./@awayScoreSet5[1]', 'tinyint'), 0)
                    ,@SetxGameyHomeWON = ISNULL(T.C.value('./@SetxGameyHomeWON[1]', 'varchar(max)'), '')
                    ,@SetxGameyAwayWON = ISNULL(T.C.value('./@SetxGameyAwayWON[1]', 'varchar(max)'), '')
                    ,@SetxGameyDRAW = ISNULL(T.C.value('./@SetxGameyDRAW[1]', 'varchar(max)'), '')
                    ,@SetxGameyREFUND = ISNULL(T.C.value('./@SetxGameyREFUND[1]', 'varchar(max)'), '')
                    ,@SelectedSetCAL = ISNULL(T.C.value('./@SelectedSetCAL[1]', 'varchar(50)'), '')
                    ,@SelectedSetREFUND = ISNULL(T.C.value('./@SelectedSetREFUND[1]', 'varchar(50)'), '')
                FROM @xml.nodes('/root/r') as [T](C) --T: table, C: column    
                OPTION ( OPTIMIZE FOR ( @xml = NULL ) )
                
            END

            IF @resultDetail_br IS NOT NULL -- for betradar
            BEGIN
                SET @xml = CONVERT(XML, @resultDetail_br)
                
                SELECT TOP(1) @penaltyshootout = ISNULL(T.C.value('./@penaltyshootout[1]', 'varchar(10)'), '')
                    ,@WhoAdvancesNextRound = ISNULL(T.C.value('./@WhoAdvancesNextRound[1]', 'varchar(10)'), '')
                    ,@ExtraTimeYN = ISNULL(T.C.value('./@ExtraTimeYN[1]', 'varchar(10)'), '')
                    ,@ExtraTimeandGoal = ISNULL(T.C.value('./@ExtraTimeandGoal[1]', 'varchar(10)'), '')
                    ,@matchDecidedMethod = ISNULL(T.C.value('./@matchDecidedMethod[1]', 'varchar(10)'), '')
                    ,@first10Min1x2 = ISNULL(T.C.value('./@first10Min1x2[1]', 'varchar(10)'), '')
                    ,@firstGoalTime10Min = ISNULL(T.C.value('./@firstGoalTime10Min[1]', 'varchar(10)'), '')
                    ,@firstGoalTime15Min = ISNULL(T.C.value('./@firstGoalTime15Min[1]', 'varchar(10)'), '')
                    ,@PlayerSentOff = ISNULL(T.C.value('./@PlayerSentOff[1]', 'varchar(10)'), '')
                    ,@HTPlayerSentOff = ISNULL(T.C.value('./@HTPlayerSentOff[1]', 'varchar(10)'), '')
                    ,@PlayerSentOffHome = ISNULL(T.C.value('./@PlayerSentOffHome[1]', 'varchar(10)'), '')
                    ,@HTPlayerSentOffHome = ISNULL(T.C.value('./@HTPlayerSentOffHome[1]', 'varchar(10)'), '')
                    ,@PlayerSentOffAway = ISNULL(T.C.value('./@PlayerSentOffAway[1]', 'varchar(10)'), '')
                    ,@HTPlayerSentOffAway = ISNULL(T.C.value('./@HTPlayerSentOffAway[1]', 'varchar(10)'), '')
                    ,@GoalScorerFirst = ISNULL(T.C.value('./@GoalScorerFirst[1]', 'varchar(10)'), '')
                    ,@NextGoal = ISNULL(T.C.value('./@NextGoal[1]', 'varchar(MAX)'), '')
                    ,@ExtraNextGoal = ISNULL(T.C.value('./@ExtraNextGoal[1]', 'varchar(MAX)'), '')
                    ,@NextGoalTime15Min = ISNULL(T.C.value('./@NextGoalTime15Min[1]', 'varchar(MAX)'), '')
                    ,@firstHNextGoal = ISNULL(T.C.value('./@firstHNextGoal[1]', 'varchar(MAX)'), '')
                    ,@GoalScorerAnytime = ISNULL(T.C.value('./@GoalScorerAnytime[1]', 'varchar(MAX)'), '')
                    ,@FirstGoalMethod = ISNULL(T.C.value('./@FirstGoalMethod[1]', 'varchar(2)'), '')
                    ,@TimeFirstGoal = ISNULL(T.C.value('./@TimeFirstGoal[1]', 'varchar(10)'), '')
                    ,@ResourceIDsCAL = ISNULL(T.C.value('./@ResourceIDsCAL[1]', 'varchar(MAX)'), '')
                    ,@ResourceIDsREFUND = ISNULL(T.C.value('./@ResourceIDsREFUND[1]', 'varchar(MAX)'), '')                
                FROM @xml.nodes('/root/r') as [T](C) --T: table, C: column
                OPTION ( OPTIMIZE FOR ( @xml = NULL ) )
            END        
            
            IF @resultDetail_bb IS NOT NULL -- for basketball
            BEGIN
									
                SET @xml = CONVERT(XML, @resultDetail_bb)
                
                ;WITH cteResultDetail
				AS(
					SELECT	T.c.value('./@rid','VARCHAR(20)') AS ResourceId
							,T.c.value('./@home','VARCHAR(50)') AS HomeValue
							,T.c.value('./@away','VARCHAR(50)') AS AwayValue
							,T.c.value('./@ssId','TINYINT') AS SettlementStatusId
					FROM	@xml.nodes('/root/r') AS T(c)
				)
				INSERT INTO @tmpResultDetail(ResourceId, HomeValue, AwayValue)
				SELECT	ResourceId, HomeValue, AwayValue
				FROM	cteResultDetail r
				WHERE	SettlementStatusId = 4
				OPTION ( OPTIMIZE FOR ( @xml = NULL ) )
				
				SELECT	@FTHighestQuarter = CASE
											WHEN MAX(result.HomeValue) > MAX(result.AwayValue) THEN 'H'
											WHEN MAX(result.HomeValue) < MAX(result.AwayValue) THEN 'A'
											ELSE 'N'
										END
				FROM	@tmpResultDetail t
					CROSS APPLY (
						SELECT CAST(t.HomeValue AS INT) HomeValue
							,CAST(t.AwayValue AS INT) AwayValue
					)result
				WHERE	ResourceId LIKE 'Q[1-4]'
					
				SELECT	@Q1Home = HomeValue
						,@Q1Away = AwayValue
				FROM	@tmpResultDetail
				WHERE	ResourceId = 'Q1'
				
				SELECT	@Q2Home = HomeValue
						,@Q2Away = AwayValue
				FROM	@tmpResultDetail
				WHERE	ResourceId = 'Q2'
				
				SELECT	@Q3Home = HomeValue
						,@Q3Away = AwayValue
				FROM	@tmpResultDetail
				WHERE	ResourceId = 'Q3'
				
				SELECT	@Q4Home = HomeValue
						,@Q4Away = AwayValue
				FROM	@tmpResultDetail
				WHERE	ResourceId = 'Q4'
				
				SELECT @basketball_ResourceIdsCAL = COALESCE(@basketball_ResourceIdsCAL + ',' + r.ResourceId , r.ResourceId)	 
				FROM	@tmpResultDetail t
					CROSS APPLY (
						SELECT CASE
									WHEN t.ResourceId = '00' THEN 'FT'
									WHEN t.ResourceId = '01' THEN '1H'
									WHEN t.ResourceId = '02' THEN '2H'
									ELSE t.ResourceId
								END AS ResourceId
					) r
				
            END  
   
			IF @resultDetail IS NOT NULL
			BEGIN
				 SET @xml = CONVERT(XML, @resultDetail)
				
				;WITH cteResult
				AS(
					SELECT	T.c.value('./@rid','VARCHAR(20)') AS ResourceId
							,T.c.value('./@home','VARCHAR(50)') AS HomeValue
							,T.c.value('./@away','VARCHAR(50)') AS AwayValue
					FROM	@xml.nodes('/root/r') AS T(c)
				)
				SELECT	@ht_fg = ISNULL(MAX(CASE 
												WHEN ResourceID ='127F' 
													THEN CASE 
															WHEN HomeValue = 'N' THEN '0:0'
															WHEN HomeValue = 'H' THEN '1:1'
															WHEN HomeValue = 'A' THEN '2:1'
															ELSE ''
														END
													ELSE '' 
											END),'')		
						,@ht_lg = ISNULL(MAX(CASE 
												WHEN ResourceID ='127L' 
													THEN CASE 
															WHEN HomeValue = 'N' THEN '0:0'
															WHEN HomeValue = 'H' THEN '1:2'
															WHEN HomeValue = 'A' THEN '2:2'
															ELSE ''
														END
													ELSE '' 
											END),'')			
						
						,@ft_fg = ISNULL(MAX(CASE WHEN ResourceId = '14F' THEN HomeValue ELSE '' END),'')
						,@ft_lg = ISNULL(MAX(CASE WHEN ResourceId = '14L' THEN HomeValue ELSE '' END),'')
																					
				FROM	cteResult r
				OPTION ( OPTIMIZE FOR ( @xml = NULL ) )
				
			END
			
            DECLARE @csHTFT NVARCHAR(10) -- HT/FT correct score
    
            SELECT @csHTFT = CASE WHEN @hth + @hta >= 4 THEN '4+' 
                                ELSE CAST(@hth AS nvarchar(10)) + ':' + CAST(@hta AS nvarchar(10))
                                END 
                        + '/'
                        + CASE WHEN @fth + @fta >=4 THEN '4+'
                                ELSE CAST(@fth AS nvarchar(10)) + ':' + CAST(@fta AS nvarchar(10))
                                END
            DECLARE @FirstGoal NVARCHAR(50) 
            SELECT    @FirstGoal=''
            SELECT    @FirstGoal = LEFT(REPLACE(ISNULL(@GoalSequence,''),';',''),1) --172  --@GoalSequence = GoalRecord 
            
            DECLARE  @home_firstteam2goals    INT
                    ,@away_firstteam2goals    INT
                    ,@home_firstteam3goals    INT
                    ,@away_firstteam3goals    INT
                    ,@oddeven 					SMALLMONEY
            
            SET @home_firstteam2goals = CHARINDEX('H',@GoalSequence,(CHARINDEX('H',@GoalSequence)+1))
            SET @away_firstteam2goals = CHARINDEX('A',@GoalSequence,(CHARINDEX('A',@GoalSequence)+1))    
            SET @home_firstteam3goals = CASE WHEN @home_firstteam2goals > 0 THEN CHARINDEX('H',@GoalSequence, @home_firstteam2goals + 1) ELSE 0 END
            SET @away_firstteam3goals = CASE WHEN @away_firstteam2goals > 0 THEN CHARINDEX('A',@GoalSequence, @away_firstteam2goals + 1) ELSE 0 END    
			SET @oddeven = (@fth + @fta) % 2
            -- Win from behind
            DECLARE @WinFromBehind NVARCHAR(1)
                    ,@curHome INT = 0
                    ,@curAway INT = 0
                    ,@index INT = 1
                    
            IF (@fth <> @fta) AND (@fth + @fta) > 2
            BEGIN
                WHILE (@index <= LEN(REPLACE(@GoalSequence,';','')))
                BEGIN
                    IF SUBSTRING(REPLACE(@GoalSequence,';',''),@index, 1) = 'H'
                        SET @curHome = @curHome + 1
                        
                    IF SUBSTRING(REPLACE(@GoalSequence,';',''),@index, 1) = 'A' 
                        SET @curAway = @curAway + 1                
                    
                    IF @fth > @fta AND @curHome < @curAway 
                    BEGIN
                        SET @WinFromBehind = 'H' 
                        BREAK
                    END
                    IF @fta > @fth AND @curAway < @curHome
                    BEGIN
                        SET @WinFromBehind = 'A'
                        BREAK
                    END
                    
                    SET @index = @index + 1
                END
            END
            
            CREATE TABLE #Result (
                transid         BIGINT
                ,refno          BIGINT
				,modds			MONEY
                ,isrefundgame	BIT
            )
			
			DECLARE @tmptransid TABLE (
				transid			BIGINT
				,refno			BIGINT
				,modds			MONEY
				,isrefundgame	BIT
			)
        
			INSERT INTO #Result(
				transid
				,refno
				,modds
				,isrefundgame
			)
			SELECT	transId
                    ,refno
					,CASE bm.bettype
                        WHEN 1 THEN -- Handicap
                            CASE betteam
                                WHEN N'h' THEN (hdp2 - hdp1) + (@fth - livehomescore) - (@fta - liveawayscore)
                                WHEN N'a' THEN (hdp1 - hdp2) - (@fth - livehomescore) + (@fta - liveawayscore)
                                END
                        WHEN 7 THEN -- 1st Handicap
                            CASE betteam
                                WHEN N'h' THEN (hdp2 - hdp1) + (@hth - livehomescore) - (@hta - liveawayscore)
                                WHEN N'a' THEN (hdp1 - hdp2) - (@hth - livehomescore) + (@hta - liveawayscore)
                                END
                        WHEN 3 THEN -- Over/Under
                            CASE betteam
                                WHEN N'h' THEN (CASE 
                                        WHEN ISNULL(@TennisTotal,0)=0 THEN @fth + @fta
                                        ELSE @TennisTotal END
                                        ) - hdp1
                                WHEN N'a' THEN hdp1 - (CASE 
                                        WHEN ISNULL(@TennisTotal,0)=0 THEN @fth + @fta
                                        ELSE @TennisTotal END
                                        )
                                END
                        WHEN 8 THEN -- 1st Over/Under
                            CASE betteam
                                WHEN N'h' THEN (@hth + @hta) - hdp1
                                WHEN N'a' THEN hdp1 - (@hth + @hta)
                                END
                        WHEN 2 THEN -- Odd/Even
                            CASE 
                                WHEN (betteam = N'h') AND (
                                        (CASE 
                                            WHEN ISNULL(@TennisTotal,0)=0 THEN @fth + @fta
                                            ELSE @TennisTotal END
                                            ) & 1 = 1
                                        ) THEN 1
                                WHEN (betteam = N'a') AND (
                                        (CASE 
                                            WHEN ISNULL(@TennisTotal,0)=0 THEN @fth + @fta
                                            ELSE @TennisTotal END
                                            ) & 1 = 0
                                        ) THEN 1
                                ELSE - 1
                                END
                        WHEN 12 THEN -- 1st Odd/Even
                            CASE 
                                WHEN (betteam = N'h') AND ((@hth + @hta) & 1 = 1) THEN 1
                                WHEN (betteam = N'a') AND ((@hth + @hta) & 1 = 0) THEN 1
                                ELSE - 1
                                END
                        WHEN 4 THEN -- Correct Score
                            CASE 
                                WHEN betteam = (CAST(@fth AS VARCHAR(4)) + ':' + CAST(@fta AS VARCHAR(4))) THEN 1
                                WHEN betteam = '5:0' AND (@fth - @fta) >= 5 THEN 1
                                WHEN betteam = '0:5' AND (@fth - @fta) <= - 5 THEN 1
                                ELSE - 1
                                END
                        WHEN 30 THEN -- 1st Correct Score
                            CASE 
                                WHEN betteam = (CAST(@hth AS VARCHAR(4)) + ':' + CAST(@hta AS VARCHAR(4))) THEN 1
                                WHEN betteam = '4:0' AND (@hth - @hta) >= 4 THEN 1 -- 4UP for 1st Correct Score
                                WHEN betteam = '0:4' AND (@hth - @hta) <= - 4 THEN 1 -- 4UP for 1st Correct Score
                                WHEN betteam = '5:0' AND (@hth - @hta) >= 5 THEN 1
                                WHEN betteam = '0:5' AND (@hth - @hta) <= - 5 THEN 1
                                ELSE - 1
                                END
                        WHEN 16 THEN -- HT/FT
                            CASE 
                                WHEN betteam = CASE 
                                        WHEN @hth = @hta THEN '0'
                                        WHEN @hth > @hta THEN '1'
                                        ELSE '2'
                                        END + ':' + CASE 
                                        WHEN @fth = @fta THEN '0'
                                        WHEN @fth > @fta THEN '1'
                                        ELSE '2'
                                        END THEN 1
                                ELSE - 1
                                END
                        /*
                        WHEN 16 THEN -- HT/FT
                            CASE 
                                WHEN betteam = CASE
                                                    WHEN @hth > @hta THEN 'H' + CASE
                                                                                    WHEN @fth > @fta THEN 'H'
                                                                                    WHEN @fth = @fta THEN 'D'
                                                                                    WHEN @fth < @fta THEN 'A'
                                                                                    ELSE NULL
                                                                                END
                                                    WHEN @hth = @hta THEN 'D' + CASE
                                                                                    WHEN @fth > @fta THEN 'H'
                                                                                    WHEN @fth = @fta THEN 'D'
                                                                                    WHEN @fth < @fta THEN 'A'
                                                                                    ELSE NULL
                                                                                END
                                                    WHEN @hth < @hta THEN 'A' + CASE
                                                                                    WHEN @fth > @fta THEN 'H'
                                                                                    WHEN @fth = @fta THEN 'D'
                                                                                    WHEN @fth < @fta THEN 'A'
                                                                                    ELSE NULL
                                                                                END
                                            END THEN 1
                                ELSE - 1
                                END
                        */
                        WHEN 17 THEN  
                            CASE betteam
                                WHEN N'h' THEN (hdp2 - hdp1) + (@fth - @hth - livehomescore) - (@fta - @hta - liveawayscore)
                                WHEN N'a' THEN (hdp1 - hdp2) - (@fth - @hth - livehomescore) + (@fta - @hta - liveawayscore)
                                END
                        WHEN 18 THEN  
                            CASE betteam
                                WHEN N'o' THEN (@fth + @fta - @hth - @hta) - hdp1
                                WHEN N'u' THEN hdp1 - (@fth + @fta - @hth - @hta)
                                END
                        WHEN 5 THEN -- 1x2
                            CASE 
                                WHEN (betteam = N'1') AND (@fth > @fta) THEN 1
                                WHEN (betteam = N'2') AND (@fta > @fth) THEN 1
                                WHEN (betteam = N'x') AND (@fth = @fta) THEN 1
                                ELSE - 1
                                END
                        WHEN 15 THEN -- 1st 1x2
                            CASE 
                                WHEN (betteam = N'1') AND (@hth > @hta) THEN 1
                                WHEN (betteam = N'2') AND (@hta > @hth) THEN 1
                                WHEN (betteam = N'x') AND (@hth = @hta) THEN 1
                                ELSE - 1
                                END
                        WHEN 6 THEN -- Total Goal
                            CASE 
                                WHEN (CASE 
                                        WHEN @TennisTotal IS NULL THEN @fth + @fta
                                        ELSE @TennisTotal END >= cast(left(betteam, 1) AS INT) AND CASE 
                                        WHEN @TennisTotal IS NULL THEN @fth + @fta
                                        ELSE @TennisTotal END <= (CASE 
                                            WHEN right(betteam, 1) = 'r' THEN 999
                                            ELSE cast(right(betteam, 1) AS INT) END
                                            )
                                        ) THEN 1
                                ELSE - 1
                                END
                        WHEN 126 THEN -- 1H total goal
                            CASE WHEN (
                                        CASE WHEN @TennisTotal IS NULL THEN @hth + @hta ELSE @TennisTotal END >= CAST(LEFT(betteam,1) AS int) AND
                                        CASE WHEN @TennisTotal IS NULL then @hth + @hta ELSE @TennisTotal END <= (
                                            CASE when RIGHT(betteam,1)= 'r' then 999 ELSE CAST(RIGHT(betteam,1)AS int) END 
                                            )
                                    ) then 1 ELSE -1 END 
                        WHEN 13 THEN -- Clean Sheet
                            CASE 
                                WHEN betteam = 'hy' AND @fta = 0 THEN 1
                                WHEN betteam = 'hn' AND @fta > 0 THEN 1
                                WHEN betteam = 'ay' AND @fth = 0 THEN 1
                                WHEN betteam = 'an' AND @fth > 0 THEN 1
                                ELSE - 1
                                END
                        WHEN 20 THEN -- Money Line
                            CASE betteam
                                WHEN N'h' THEN @fth - @fta
                                ELSE @fta - @fth
                                END
                        WHEN 21 THEN -- 1st Money Line
                            CASE betteam
                                WHEN N'h' THEN @hth - @hta
                                ELSE @hta - @hth
                                END
                        WHEN 24 THEN -- Double Chance
                            CASE 
                                WHEN betteam = '1X' AND (@fth - @fta) >= 0 THEN 1
                                WHEN betteam = '2X' AND (@fth - @fta) <= 0 THEN 1
                                WHEN betteam = '12' AND (@fth - @fta) <> 0 THEN 1
                                ELSE - 1
                                END
                        WHEN 25 THEN -- Draw No Bet
                            CASE 
                                WHEN (@fth - @fta) = 0 THEN 0
                                WHEN betteam = 'h' AND (@fth - @fta) > 0 THEN 1
                                WHEN betteam = 'a' AND (@fth - @fta) < 0 THEN 1
                                ELSE - 1
                                END
                        WHEN 26 THEN -- Both/One/Neither team to score
                            CASE 
                                WHEN betteam = 'b' AND (@fth > 0 AND @fta > 0) THEN 1
                                WHEN betteam = 'o' AND ((@fth > 0 AND @fta = 0) OR (@fta > 0 AND @fth = 0)) THEN 1
                                WHEN betteam = 'n' AND (@fth = 0 AND @fta = 0) THEN 1
                                ELSE - 1
                                END
                        WHEN 27 THEN -- To win to nil
                            CASE 
                                WHEN betteam = 'h' AND (@fth > @fta AND @fta = 0) THEN 1
                                WHEN betteam = 'a' AND (@fta > @fth AND @fth = 0) THEN 1
                                ELSE - 1
                                END
                        WHEN 28 THEN -- 3-way handicap
                            CASE 
                                WHEN betteam = '1' AND (hdp2 - hdp1 + @fth - @fta) > 0 THEN 1
                                WHEN betteam = '2' AND (hdp1 - hdp2 + @fta - @fth) > 0 THEN 1
                                WHEN betteam = 'x' AND ((hdp1 - hdp2) - (@fth - @fta)) = 0 THEN 1
                                ELSE - 1
                                END
                        WHEN 121 THEN -- home no bet
                            CASE 
                                WHEN (@fth - @fta) > 0 THEN 0
                                WHEN betteam = 'x' AND (@fth - @fta) = 0 THEN 1
                                WHEN betteam = 'a' AND (@fth - @fta) < 0 THEN 1
                                ELSE - 1
                                END
                        WHEN 122 THEN -- away no bet
                            CASE 
                                WHEN (@fth - @fta) < 0 THEN 0
                                WHEN betteam = 'h' AND (@fth - @fta) > 0 THEN 1
                                WHEN betteam = 'x' AND (@fth - @fta) = 0 THEN 1
                                ELSE - 1
                                END
                        WHEN 123 THEN -- draw/no draw
                            CASE 
                                WHEN betteam = 'h' AND (@fth - @fta) = 0 THEN 1
                                WHEN betteam = 'a' AND (@fth - @fta) <> 0 THEN 1
                                ELSE - 1
                                END
                        WHEN 133 THEN -- Home To Win Both Halves
                            CASE 
                                WHEN betteam = 'y' AND (@hth > @hta) AND ((@fth - @hth) > (@fta - @hta)) THEN 1
                                WHEN betteam = 'n' AND ((@hth <= @hta) OR ((@fth - @hth) <= (@fta - @hta))) THEN 1
                                ELSE -1
                                END 
                        WHEN 134 THEN -- Away To Win Both Halves 
                            CASE 
                                WHEN betteam = 'y' AND (@hta > @hth) AND ((@fta - @hta) > (@fth - @hth)) THEN 1
                                WHEN betteam = 'n' AND ((@hta <=@hth) OR ((@fta - @hta) <= (@fth - @hth))) THEN 1
                                ELSE -1
                                END 
                        WHEN 140 THEN -- Highest Scoring Half
                            CASE 
                                WHEN betteam = '1h' AND (@hth + @hta) > (@fth - @hth + @fta - @hta) THEN 1
                                WHEN betteam = 'tie' AND (@hth + @hta) = (@fth - @hth + @fta - @hta) THEN 1
                                WHEN betteam = '2h' AND (@hth + @hta) < (@fth - @hth + @fta - @hta) THEN 1
                                ELSE -1
                                END
                        WHEN 141 THEN -- Highest Scoring Half Home Team
                            CASE 
                                WHEN betteam = '1h' AND @hth > (@fth - @hth) THEN 1
                                WHEN betteam = 'tie' AND @hth = (@fth - @hth) THEN 1
                                WHEN betteam = '2h' AND @hth < (@fth - @hth) THEN 1
                                ELSE -1
                                END 
                        WHEN 142 THEN -- Highest Scoring Half Away Team
                            CASE 
                                WHEN betteam = '1h' AND @hta > (@fta - @hta) THEN 1
                                WHEN betteam = 'tie' AND @hta = (@fta - @hta) THEN 1
                                WHEN betteam = '2h' AND @hta < (@fta - @hta) THEN 1
                                ELSE -1
                                END 
                        WHEN 145 THEN -- Both Teams To Score
                            CASE 
                                WHEN betteam = 'y' AND (@fth > 0) AND (@fta > 0) THEN 1
                                WHEN betteam = 'n' AND ((@fth = 0) OR (@fta = 0)) THEN 1
                                ELSE -1
                                END 
                        WHEN 146 THEN -- 2nd Half Both Teams To Score
                            CASE 
                                WHEN betteam = 'y' AND (@fth - @hth) > 0 AND (@fta - @hta) > 0 THEN 1
                                WHEN betteam = 'n' AND ((@fth - @hth) = 0 OR (@fta - @hta) = 0) THEN 1
                                ELSE -1
                                END
                        WHEN 147 THEN -- Home To Score In Both Halves 
                            CASE 
                                WHEN betteam = 'y' AND @hth > 0 AND (@fth - @hth) > 0 THEN 1
                                WHEN betteam = 'n' AND (@hth = 0 OR (@fth - @hth) = 0) THEN 1
                                ELSE -1
                                END
                        WHEN 148 THEN -- Away To Score In Both Halves 
                            CASE 
                                WHEN betteam = 'y' AND @hta > 0 AND (@fta - @hta) > 0 THEN 1
                                WHEN betteam = 'n' AND (@hta = 0 OR (@fta - @hta) = 0) THEN 1
                                ELSE -1
                                END
                        WHEN 149 THEN -- Home To Win Either Half 
                            CASE 
                                WHEN betteam = 'y' AND ((@hth > @hta) OR (@fth - @hth) > (@fta - @hta)) THEN 1
                                WHEN betteam = 'n' AND (@hth <= @hta) AND (@fth - @hth) <=(@fta - @hta) THEN 1
                                ELSE -1
                                END
                        WHEN 150 THEN -- Away To Win Either Half
                            CASE 
                                WHEN betteam = 'y' AND ((@hta > @hth) OR (@fta - @hta) > (@fth - @hth)) THEN 1
                                WHEN betteam = 'n' AND (@hta <= @hth) AND (@fta - @hta) <= (@fth - @hth) THEN 1
                                ELSE -1
                                END 
                        WHEN 151 THEN -- 1st Half Double Chance
                            CASE 
                                WHEN betteam = '1x' AND (@hth - @hta) >= 0 THEN 1
                                WHEN betteam = '2x' AND (@hta - @hth) >= 0 THEN 1
                                WHEN betteam = '12' AND (@hth - @hta) <> 0 THEN 1
                                ELSE -1
                                END
                        WHEN 152 THEN -- Half Time/Full Time Correct Score
                            CASE 
                                WHEN betteam = @csHTFT THEN 1
                                ELSE -1
                                END 
                        WHEN 135 THEN -- Penalty Shootout
                            CASE 
                                WHEN betteam = @penaltyshootout THEN 1
                                ELSE -1
                                END        
                        WHEN 128 THEN -- HT/FT Odd/Even
                            CASE
                                WHEN betteam = 'oo' AND (@hth + @hta) % 2 = 1 AND (@fth + @fta) % 2 = 1 THEN 1
                                WHEN betteam = 'oe' AND (@hth + @hta) % 2 = 1 AND (@fth + @fta) % 2 = 0 THEN 1
                                WHEN betteam = 'eo' AND (@hth + @hta) % 2 = 0 AND (@fth + @fta) % 2 = 1 THEN 1
                                WHEN betteam = 'ee' AND (@hth + @hta) % 2 = 0 AND (@fth + @fta) % 2 = 0 THEN 1
                                ELSE -1
                                END                
                        WHEN 129 THEN -- 1H Exact Goal
                            CASE
                                WHEN betteam = '5&over' AND (@hth + @hta) >= 5 THEN 1
                                WHEN betteam <> '5&over' AND cast(betteam as INT) = (@hth + @hta) THEN 1
                                ELSE -1
                                END
                        WHEN 130 THEN --  Exact Goal
                            CASE 
                                WHEN betteam = '7&over' AND (@fth + @fta) >= 7 THEN 1
                                WHEN betteam <> '7&over' AND cast(betteam AS INT) = (@fth + @fta) THEN 1
                                ELSE -1
                                END
                        WHEN 131 THEN -- Home Team Total Goal 
                            CASE
                                WHEN cast(LEFT(betteam,1) as INT) <= @fth 
                                    AND case when right(betteam,1) = 'r' 
                                                then 999 
                                             else cast(RIGHT(betteam,1) as int) 
                                             END >= @fth THEN 1
                                ELSE -1
                                END        
                        WHEN 132 THEN -- Away Team Total Goal
                            CASE 
                                WHEN cast(left(betteam,1) as int) <= @fta    
                                    AND case when right(betteam,1) = 'r'
                                                then 999
                                             else cast(right(betteam,1) as int)
                                             END >= @fta THEN 1
                                ELSE -1
                                END
                        WHEN 136 THEN -- 1H Home Team Odd/Even            
                            CASE    
                                WHEN betteam = 'o' and (@hth % 2) = 1 THEN 1
                                WHEN betteam = 'e' and (@hth % 2) = 0 THEN 1
                                ELSE -1
                                END
                        WHEN 137 THEN -- Home Team Odd/Even
                            CASE
                                WHEN betteam = 'o' and (@fth % 2) = 1 THEN 1
                                WHEN betteam = 'e' and (@fth % 2) = 0 THEN 1
                                ELSE -1
                                END 
                        WHEN 138 THEN -- 1H Away Team Odd/Even             
                            CASE    
                                WHEN betteam = 'o' and (@hta % 2) = 1 THEN 1
                                WHEN betteam = 'e' and (@hta % 2) = 0 THEN 1
                                ELSE -1
                                END
                        WHEN 139 THEN -- Away Team Odd/Even
                            CASE
                                WHEN betteam = 'o' and (@fta % 2) = 1 THEN 1
                                WHEN betteam = 'e' and (@fta % 2) = 0 THEN 1
                                ELSE -1
                                END 
                        WHEN 143 THEN -- 1H Result/Total Goals
                            CASE
                                WHEN betteam = 'ho' and (@hth - @hta) > 0 THEN (@hth+ @hta) - hdp1
                                WHEN betteam = 'hu' and (@hth - @hta) > 0 THEN hdp1 - (@hth+ @hta) 
                                WHEN betteam = 'ao' and (@hth - @hta) < 0 THEN (@hth+ @hta) - hdp1
                                WHEN betteam = 'au' and (@hth - @hta) < 0 THEN hdp1 - (@hth+ @hta) 
                                WHEN betteam = 'do' and (@hth - @hta) = 0 THEN (@hth+ @hta) - hdp1
                                WHEN betteam = 'du' AND (@hth - @hta) = 0 THEN hdp1 - (@hth+ @hta) 
                                ELSE -1
                                END        
                        WHEN 144 THEN -- Result/Total Goals
                            CASE
                                WHEN betteam = 'ho' and (@fth - @fta) > 0 THEN (@fth+ @fta) - hdp1
                                WHEN betteam = 'hu' and (@fth - @fta) > 0 THEN hdp1 - (@fth+ @fta)
                                WHEN betteam = 'ao' and (@fth - @fta) < 0 THEN (@fth+ @fta) - hdp1
                                WHEN betteam = 'au' and (@fth - @fta) < 0 THEN hdp1 - (@fth+ @fta)
                                WHEN betteam = 'do' and (@fth - @fta) = 0 THEN (@fth+ @fta) - hdp1
                                WHEN betteam = 'du' AND (@fth - @fta) = 0 THEN hdp1 - (@fth+ @fta)
                                ELSE -1
                                END        
                        -- Tennis New bet types         
                        WHEN 153 THEN -- Match Games Handicap
                            CASE betteam 
                                WHEN N'h' THEN (hdp2 - hdp1) + (@TotalGameHomeMatch - livehomescore) - (@TotalGameAwayMatch - liveawayscore)
                                WHEN N'a' THEN (hdp1 - hdp2) - (@TotalGameHomeMatch - livehomescore) + (@TotalGameAwayMatch - liveawayscore)
                                END 
                        WHEN 154 THEN -- Set x Winner
                            CASE betteam 
                                WHEN N'h' THEN (i.TotalGameHomeSetx - i.TotalGameAwaySetx)
                                WHEN N'a' THEN (i.TotalGameAwaySetx - i.TotalGameHomeSetx)
                                END 
                        WHEN 155 THEN -- Set x Game Handicap
                            CASE betteam
                                WHEN N'h' THEN (hdp2 - hdp1) + (i.TotalGameHomeSetx - livehomescore) - (i.TotalGameAwaySetx - liveawayscore)
                                WHEN N'a' THEN (hdp1 - hdp2) - (i.TotalGameHomeSetx - livehomescore) + (i.TotalGameAwaySetx - liveawayscore)
                                END
                        WHEN 156 THEN --Set x Total Games Over/Under 
                            CASE betteam 
                                WHEN N'o' THEN (i.TotalGameHomeSetx + i.TotalGameAwaySetx) - hdp1 
                                WHEN N'u' THEN hdp1 - (i.TotalGameHomeSetx + i.TotalGameAwaySetx) 
                                END
                        -- Betradar 2 
                        WHEN 160 THEN 
                            CASE WHEN CHARINDEX((SUBSTRING(CAST(betcheck AS VARCHAR(10)),2,5) + betteam),@NextGoal)> 0 THEN 1 
                                 ELSE - 1 
                                 END
                                                                                                
                        WHEN 164 THEN 
                            CASE WHEN CHARINDEX((SUBSTRING(CAST(betcheck AS VARCHAR(10)),2,5) + betteam),@ExtraNextGoal)> 0 THEN 1 
                                 ELSE - 1 
                                 END

                        WHEN 168 THEN 
                            CASE WHEN Betteam = @WhoAdvancesNextRound THEN 1 
                                 ELSE - 1
                                 END 
                        WHEN 169 THEN 
                            CASE WHEN CHARINDEX((SUBSTRING(CAST(betcheck AS VARCHAR(10)),2,5) + betteam),@NextGoalTime15Min)> 0 THEN 1 
                                 ELSE - 1 
                                 END
                        WHEN 173 THEN 
                            CASE WHEN Betteam = @ExtraTimeYN THEN 1 
                                 ELSE - 1
                                 END 

                        WHEN 174 THEN 
                            CASE WHEN Betteam = @ExtraTimeandGoal THEN 1 
                                 ELSE - 1
                                 END 
                        WHEN 175 THEN 
                            CASE WHEN Betteam = @matchDecidedMethod THEN 1 
                                 ELSE - 1
                                 END 

                        WHEN 176 THEN 
                            CASE WHEN Betteam = @first10Min1x2 THEN 1 
                                 ELSE - 1
                                 END 

                        WHEN 180 THEN 
                            CASE WHEN CHARINDEX((SUBSTRING(CAST(betcheck AS VARCHAR(10)),2,5) + betteam),@firstHNextGoal)> 0 THEN 1 
                                 ELSE - 1 
                                 END
                        WHEN 192 THEN 
                            CASE WHEN Betteam = @firstGoalTime10Min THEN 1 
                                 ELSE - 1
                                 END 
                        WHEN 193 THEN 
                            CASE WHEN Betteam = @firstGoalTime15Min THEN 1 
                                 ELSE - 1
                                 END 
                        WHEN 210 THEN 
                            CASE WHEN Betteam = @PlayerSentOff THEN 1 
                                 ELSE - 1
                                 END 
                        WHEN 211 THEN 
                            CASE WHEN Betteam = @HTPlayerSentOff THEN 1 
                                 ELSE - 1
                                 END 
                        WHEN 212 THEN 
                            CASE WHEN Betteam = @PlayerSentOffHome THEN 1 
                                 ELSE - 1
                                 END 

                        WHEN 213 THEN 
                            CASE WHEN Betteam = @HTPlayerSentOffHome THEN 1 
                                 ELSE - 1
                                 END 

                        WHEN 214 THEN 
                            CASE WHEN Betteam = @PlayerSentOffAway THEN 1 
                                 ELSE - 1
                                 END 

                        WHEN 215 THEN 
                            CASE WHEN Betteam = @HTPlayerSentOffAway THEN 1 
                                 ELSE - 1
                                 END 

                        WHEN 216 THEN 
                            CASE WHEN CHARINDEX(betteam,@GoalScorerAnytime)>0 THEN 1 
                                 ELSE - 1
                                 END 

                        WHEN 217 THEN 
                            CASE WHEN Betteam = @GoalScorerFirst THEN 1 
                                 ELSE - 1
                                 END 

                        -- Betradar 2 Manual Bettype 
                        WHEN 157 THEN 
                            CASE WHEN betteam =N'h' AND ((@fth + @fta) &1) = 1 THEN 1 
                                 WHEN betteam =N'a' AND ((@fth + @fta) &1) = 0 THEN 1 
                                 ELSE - 1 
                                 END 
                        WHEN 159 THEN 
                            CASE WHEN betteam LIKE 'G[0-5]' AND ((@fth + @fta) = CAST(RIGHT(betteam,1)AS TINYINT)) THEN 1 
                                 WHEN betteam ='G6' AND ((@fth + @fta) >=CAST(RIGHT(betteam,1)AS TINYINT)) THEN 1 
                                 ELSE - 1 
                                 END 
                        WHEN 161 THEN 
                            CASE WHEN betteam LIKE 'G[0-2]' AND (@fth = CAST(RIGHT(betteam,1)AS TINYINT)) THEN 1 
                                 WHEN betteam ='G3' AND (@fth >=CAST(RIGHT(betteam,1)AS TINYINT)) THEN 1 
                                 ELSE - 1 
                                 END 
                        WHEN 162 THEN 
                            CASE WHEN betteam LIKE 'G[0-2]' AND (@fta = CAST(RIGHT(betteam,1)AS TINYINT)) THEN 1 
                                 WHEN betteam ='G3' AND (@fta >=CAST(RIGHT(betteam,1)AS TINYINT)) THEN 1 
                                 ELSE - 1 
                                 END 
                        WHEN 163 THEN 
                            CASE WHEN betteam = 'ho' AND (@fth -@fta) > 0 THEN (@fth + @fta) - hdp1
                                 WHEN betteam = 'hu' AND (@fth -@fta) > 0 THEN hdp1 - (@fth + @fta)
                                 WHEN betteam = 'ao' AND (@fth -@fta) < 0 THEN (@fth + @fta) - hdp1
                                 WHEN betteam = 'au' AND (@fth -@fta) < 0 THEN hdp1 - (@fth + @fta)
                                 WHEN betteam = 'do' AND (@fth -@fta) = 0 THEN (@fth + @fta) - hdp1
                                 WHEN betteam = 'du' AND (@fth -@fta) = 0 THEN hdp1 - (@fth + @fta)    
                                 ELSE -1 
                                 END 
                        WHEN 165 THEN 
                            CASE 
                                WHEN betteam = (CAST(@hth AS VARCHAR(4)) + ':' + CAST(@hta AS VARCHAR(4))) THEN 1
                                ELSE - 1
                                END                
                        WHEN 166 THEN 
                            CASE 
                                WHEN betteam = (CAST(@fth AS VARCHAR(4)) + ':' + CAST(@fta AS VARCHAR(4))) THEN 1
                                ELSE - 1
                                END    
                        WHEN 167 THEN 
                            CASE 
                                WHEN (betteam = N'1') AND (@fth > @fta) THEN 1
                                WHEN (betteam = N'2') AND (@fta > @fth) THEN 1
                                WHEN (betteam = N'x') AND (@fth = @fta) THEN 1
                                ELSE - 1
                                END
                        WHEN 170 THEN        
                            CASE 
                                WHEN betteam =N'h' AND (@fth > 0 AND @fta = 0) THEN 1
                                WHEN betteam =N'a' AND (@fth = 0 AND @fta > 0) THEN 1
                                WHEN betteam =N'b' AND (@fth > 0 AND @fta > 0) THEN 1
                                WHEN betteam =N'n' AND (@fth = 0 AND @fta = 0) THEN 1
                                ELSE -1
                                END 
                        WHEN 171 THEN    
                            CASE 
                                WHEN betteam = 'h1' AND (@fth -@fta) = 1 THEN 1        --171 
                                WHEN betteam = 'h2' AND (@fth -@fta) = 2 THEN 1 
                                WHEN betteam = 'h3' AND (@fth -@fta) >=3 THEN 1 
                                WHEN betteam = 'd' AND (@fth -@fta) =0 THEN 1 
                                WHEN betteam = 'a1' AND (@fth -@fta) =-1 THEN 1 
                                WHEN betteam = 'a2' AND (@fth -@fta) =-2 THEN 1 
                                WHEN betteam = 'a3' AND (@fth -@fta)<=-3 THEN 1 
                                ELSE - 1                    
                                END
                        WHEN 172 THEN    
                            CASE 
                                WHEN betteam = 'HH' AND @FirstGoal='H' AND (@fth - @fta) >0 THEN 1 
                                WHEN betteam = 'DH' AND @FirstGoal='H' AND (@fth - @fta) =0 THEN 1
                                WHEN betteam = 'AH' AND @FirstGoal='H' AND (@fth - @fta) <0 THEN 1
                                WHEN betteam = 'HA' AND @FirstGoal='A' AND (@fth - @fta) >0 THEN 1
                                WHEN betteam = 'DA' AND @FirstGoal='A' AND (@fth - @fta) =0 THEN 1
                                WHEN betteam = 'AA' AND @FirstGoal='A' AND (@fth - @fta) <0 THEN 1
                                WHEN betteam = 'NO' AND @fth =0 AND @fta= 0 THEN 1
                                ELSE - 1
                                END
                        WHEN 177 THEN    
                            CASE 
                                WHEN (betteam = N'1') AND ((@fth -@hth) -(@fta - @hta))>0 THEN 1
                                WHEN (betteam = N'2') AND ((@fth -@hth) -(@fta - @hta))<0 THEN 1
                                WHEN (betteam = N'x') AND ((@fth -@hth) -(@fta - @hta))=0 THEN 1
                                ELSE - 1
                                END
                        WHEN 178 THEN 
                            CASE betteam 
                                WHEN N'o' THEN ((@fth + @fta) - (@hth + @hta)) - hdp1 
                                WHEN N'u' THEN hdp1 - ((@fth + @fta) - (@hth + @hta)) 
                                END
                        WHEN 179 THEN 
                            CASE 
                                WHEN betteam LIKE 'G[0-3]' AND (@hth + @hta) = CAST(RIGHT(betteam,1)AS TINYINT) THEN 1 
                                WHEN betteam ='G4' AND (@hth + @hta) >=CAST(RIGHT(betteam,1)AS TINYINT) THEN 1 
                                ELSE -1
                                END 
                        WHEN 181 THEN 
                            CASE 
                                 WHEN betteam LIKE 'G[0-2]' AND (@hth = CAST(RIGHT(betteam,1)AS TINYINT)) THEN 1 
                                 WHEN betteam ='G3' AND (@hth >=CAST(RIGHT(betteam,1)AS TINYINT)) THEN 1 
                                 ELSE - 1 
                                 END 
                        WHEN 182 THEN 
                            CASE 
                                 WHEN betteam LIKE 'G[0-2]' AND (@hta = CAST(RIGHT(betteam,1)AS TINYINT)) THEN 1 
                                 WHEN betteam ='G3' AND (@hta >=CAST(RIGHT(betteam,1)AS TINYINT)) THEN 1 
                                 ELSE - 1 
                                 END 
                        WHEN 183 THEN 
                            CASE 
                                WHEN betteam =N'h' THEN (hdp2 - hdp1) + ((@fth - @hth) - livehomescore) - ((@fta - @hta) - liveawayscore)
                                WHEN betteam =N'a' THEN (hdp1 - hdp2) - ((@fth - @hth) - livehomescore) + ((@fta - @hta) - liveawayscore)
                                END
                        WHEN 184 THEN 
                            CASE WHEN betteam =N'o' AND ((@fth + @fta - @hth - @hta) &1) = 1 THEN 1 
                                 WHEN betteam =N'e' AND ((@fth + @fta - @hth - @hta) &1) = 0 THEN 1 
                                 ELSE - 1 
                                 END 
                        WHEN 185 THEN -- Draw No Bet
                            CASE 
                                WHEN ((@fth -@hth) -(@fta - @hta)) = 0 THEN 0
                                WHEN betteam = 'h' AND ((@fth -@hth) -(@fta - @hta)) > 0 THEN 1
                                WHEN betteam = 'a' AND ((@fth -@hth) -(@fta - @hta)) < 0 THEN 1
                                ELSE - 1
                                END
                        WHEN 186 THEN -- Double Chance
                            CASE 
                                WHEN betteam = 'HD' AND ((@fth -@hth) -(@fta - @hta)) >= 0 THEN 1
                                WHEN betteam = 'DA' AND ((@fth -@hth) -(@fta - @hta)) <= 0 THEN 1
                                WHEN betteam = 'HA' AND ((@fth -@hth) -(@fta - @hta)) <> 0 THEN 1
                                ELSE - 1
                                END
                        WHEN 187 THEN
                            CASE 
                                WHEN betteam LIKE 'G[0-1]' AND ((@fth + @fta) - (@hth + @hta)) = CAST(RIGHT(betteam,1)AS TINYINT) THEN 1
                                WHEN betteam ='G2'AND ((@fth + @fta) - (@hth + @hta)) >=CAST(RIGHT(betteam,1)AS TINYINT) THEN 1
                                ELSE - 1
                                END
                        WHEN 188 THEN 
                            CASE 
                                WHEN betteam = 'Y' AND @hth > 0 AND @hta > 0 THEN 1 
                                WHEN betteam = 'N' AND (@hth = 0 OR @hta = 0) THEN 1 
                                ELSE - 1
                                END
                        WHEN 189 THEN    
                            CASE 
                                WHEN betteam ='y' AND (@hth + @hta - 1.5) > 0 AND ((@fth-@hth) + (@fta -@hta) - 1.5)>0 THEN 1 
                                WHEN betteam ='n' AND ((@hth + @hta - 1.5) <=0 OR ((@fth-@hth) + (@fta -@hta) - 1.5)<=0) THEN 1 
                                ELSE -1 
                                END  
                        WHEN 190 THEN -- Both Halves Under 1.5 Yes/No  [190]
                            CASE 
                                WHEN betteam ='y' AND (@hth + @hta - 1.5) < 0 AND ((@fth-@hth) + (@fta -@hta) - 1.5)<0 THEN 1  
                                WHEN betteam ='n' AND ((@hth + @hta - 1.5) >=0 OR ((@fth-@hth) + (@fta -@hta) - 1.5)>=0) THEN 1 
                                ELSE -1 
                            END    
                        WHEN 191 THEN 
                            CASE 
                                WHEN (@hth - @hta) = 0 THEN 0
                                WHEN betteam = 'h' AND (@hth - @hta) > 0 THEN 1
                                WHEN betteam = 'a' AND (@hth - @hta) < 0 THEN 1
                                ELSE -1
                                END
                        WHEN 194 THEN
                            CASE 
                                WHEN betteam =N'o' AND ((@fthCorners + @ftaCorners) &1) = 1 THEN 1 
                                WHEN betteam =N'e' AND ((@fthCorners + @ftaCorners) &1) = 0 THEN 1 
                                ELSE - 1 
                                END   
                        WHEN 195 THEN 
                            CASE 
                                WHEN betteam = '0-2' AND @fthCorners <=2 THEN 1            
                                WHEN betteam = '3-4' AND @fthCorners IN (3, 4) THEN 1    
                                WHEN betteam = '5-6' AND @fthCorners IN(5, 6) THEN 1    
                                WHEN betteam = '7-over' AND @fthCorners >= 7 THEN 1        
                                ELSE -1
                                END 
                        WHEN 196 THEN 
                            CASE 
                                WHEN betteam = '0-2' AND @ftaCorners <=2 THEN 1            
                                WHEN betteam = '3-4' AND @ftaCorners IN (3, 4) THEN 1    
                                WHEN betteam = '5-6' AND @ftaCorners IN(5, 6) THEN 1    
                                WHEN betteam = '7-over' AND @ftaCorners >= 7 THEN 1        
                                ELSE -1
                                END 
                        WHEN 197 THEN 
                            CASE    
                                WHEN betteam = N'o' THEN @fthCorners-hdp1    
                                WHEN betteam = N'u' THEN hdp1-@fthCorners    
                                ELSE -1
                                END
                        WHEN 198 THEN
                            CASE    
                                WHEN betteam = N'o' THEN @ftaCorners-hdp1    
                                WHEN betteam = N'u' THEN hdp1-@ftaCorners    
                                ELSE -1
                                END
                        WHEN 199 THEN 
                            CASE 
                                WHEN betteam ='0-8' AND (@fthCorners + @ftaCorners) <=8 THEN 1
                                WHEN betteam ='9-11' AND (@fthCorners + @ftaCorners) IN(9,10,11) THEN 1
                                WHEN betteam ='12-over' AND (@fthCorners + @ftaCorners)>=12 THEN 1 
                            ELSE -1
                            END
                        WHEN 200 THEN
                            CASE 
                                WHEN betteam = '0-1' AND @hthCorners <= 1 THEN 1    
                                WHEN betteam ='2' AND @hthCorners = 2 THEN 1
                                WHEN betteam ='3' AND @hthCorners = 3 THEN 1
                                WHEN betteam ='4-over' AND @hthCorners >=4 THEN 1
                                ELSE -1
                                END
                        WHEN 201 THEN
                            CASE 
                                WHEN betteam = '0-1' AND @htaCorners <= 1 THEN 1    
                                WHEN betteam ='2' AND @htaCorners = 2 THEN 1
                                WHEN betteam ='3' AND @htaCorners = 3 THEN 1
                                WHEN betteam ='4-over' AND @htaCorners >=4 THEN 1
                                ELSE -1
                                END
                        WHEN 202 THEN
                            CASE 
                                WHEN betteam ='0-4' AND  (@hthCorners+@htaCorners)<=4 THEN 1
                                WHEN betteam = '5-6' AND (@hthCorners+@htaCorners) IN(5, 6) THEN 1
                                WHEN betteam ='7-over' AND (@hthCorners+@htaCorners) >= 7 THEN 1    
                                ELSE -1
                                END
                        WHEN 203 THEN 
                            CASE 
                                WHEN betteam =N'o' AND ((@hthCorners + @htaCorners) &1) = 1 THEN 1 
                                WHEN betteam =N'e' AND ((@hthCorners + @htaCorners) &1) = 0 THEN 1 
                                ELSE - 1 
                                END  

                        WHEN 204 THEN 
                            CASE 
                                WHEN betteam = N'o' THEN @hthCorners-hdp1    
                                WHEN betteam = N'u' THEN hdp1-@hthCorners    
                                ELSE -1
                                END
                        WHEN 205 THEN 
                            CASE 
                                WHEN betteam = N'o' THEN @htaCorners-hdp1    
                                WHEN betteam = N'u' THEN hdp1-@htaCorners    
                                ELSE -1
                                END    
                        WHEN 206 THEN
                            CASE 
                                WHEN betteam = @FTFCorner THEN 1
                                ELSE -1 
                                END
                        WHEN 207 THEN
                            CASE 
                                WHEN betteam = @HTFCorner THEN 1
                                ELSE -1 
                                END
                        WHEN 208 THEN
                            CASE 
                                WHEN betteam = @FTLCorner THEN 1
                                ELSE -1 
                                END
                        WHEN 209 THEN
                            CASE 
                                WHEN betteam = @HTLCorner THEN 1
                                ELSE -1 
                                END
                        WHEN 401 THEN --Home Team Over/Under
                            CASE
                                WHEN betteam = 'o' THEN @fth - hdp1
                                WHEN betteam = 'u' THEN hdp1 - @fth
                                ELSE -1 END
						 WHEN 461 THEN --Home Team Over/Under (dec)
                            CASE
                                WHEN betteam = 'o' THEN @fth - hdp1
                                WHEN betteam = 'u' THEN hdp1 - @fth
                                ELSE -1 END
                        WHEN 402 THEN --Away Team Over/Under
                            CASE
                                WHEN betteam = 'o' THEN @fta - hdp1
                                WHEN betteam = 'u' THEN hdp1 - @fta
                                ELSE -1 END
						WHEN 462 THEN --Away Team Over/Under (dec)
                            CASE
                                WHEN betteam = 'o' THEN @fta - hdp1
                                WHEN betteam = 'u' THEN hdp1 - @fta
                                ELSE -1 END
                        WHEN 403 THEN --1H Home Team Over/Under
                            CASE
                                WHEN betteam = 'o' THEN @hth - hdp1
                                WHEN betteam = 'u' THEN hdp1 - @hth
                                ELSE -1 END
						 WHEN 463 THEN --1H Home Team Over/Under (dec)
                            CASE
                                WHEN betteam = 'o' THEN @hth - hdp1
                                WHEN betteam = 'u' THEN hdp1 - @hth
                                ELSE -1 END
                        WHEN 404 THEN --1H Away Team Over/Under
                            CASE
                                WHEN betteam = 'o' THEN @hta - hdp1
                                WHEN betteam = 'u' THEN hdp1 - @hta
                                ELSE -1 END
						WHEN 464 THEN --1H Away Team Over/Under (dec)
                            CASE
                                WHEN betteam = 'o' THEN @hta - hdp1
                                WHEN betteam = 'u' THEN hdp1 - @hta
                                ELSE -1 END
                        WHEN 405 THEN --2H Correct Score
                            CASE
                                WHEN betteam = CAST((@fth - @hth) AS NVARCHAR(6)) + ':' + CAST((@fta - @hta) AS NVARCHAR(6)) THEN 1
                                WHEN betteam = 'AOS' --Any Other Scores
                                    AND CHARINDEX(CAST((@fth - @hth) AS NVARCHAR(6)) + ':' + CAST((@fta - @hta) AS NVARCHAR(6)), transdesc) = 0 THEN 1
                                ELSE -1    END
                        WHEN 406 THEN --Exact Total Goals
                            CASE 
                                WHEN betteam LIKE 'G[0-5]' AND ((@fth + @fta) = CAST(RIGHT(betteam,1)AS TINYINT)) THEN 1 
                                WHEN betteam ='G6' AND ((@fth + @fta) >=CAST(RIGHT(betteam,1)AS TINYINT)) THEN 1 
                                ELSE -1 
                                END 
                        WHEN 407 THEN --Exact Home Team Goals
                            CASE 
                                WHEN betteam LIKE 'G[0-2]' AND (@fth = CAST(RIGHT(betteam,1)AS TINYINT)) THEN 1 
                                WHEN betteam ='G3' AND (@fth >= CAST(RIGHT(betteam,1)AS TINYINT)) THEN 1 
                                ELSE - 1 
                                END 
                        WHEN 408 THEN --Winning Margin    
                            CASE 
                                WHEN betteam = 'H1' AND (@fth - @fta) = 1 THEN 1
                                WHEN betteam = 'H2' AND (@fth - @fta) = 2 THEN 1 
                                WHEN betteam = 'H3' AND (@fth - @fta) >= 3 THEN 1
                                WHEN betteam = 'D' AND (@fth - @fta) = 0 AND (@fth + @fta) <> 0 THEN 1
                                WHEN betteam = 'A1' AND (@fth - @fta) = -1 THEN 1 
                                WHEN betteam = 'A2' AND (@fth - @fta) = -2 THEN 1 
                                WHEN betteam = 'A3' AND (@fth - @fta) <= -3 THEN 1 
                                WHEN betteam = 'NG' AND @fth = 0 AND @fta = 0 THEN 1
                                ELSE - 1
                                END
                        WHEN 409 THEN --Exact Away Team Goals
                            CASE 
                                WHEN betteam LIKE 'G[0-2]' AND (@fta = CAST(RIGHT(betteam,1)AS TINYINT)) THEN 1 
                                WHEN betteam ='G3' AND (@fta >=CAST(RIGHT(betteam,1)AS TINYINT)) THEN 1 
                                ELSE - 1 
                                END 
                        WHEN 410 THEN --1H Double Chance    
                            CASE 
                                WHEN betteam = '1x' AND (@hth - @hta) >= 0 THEN 1
                                WHEN betteam = '12' AND (@hth - @hta) <> 0 THEN 1 
                                WHEN betteam = '2x' AND (@hth - @hta) <= 0 THEN 1
                                ELSE - 1                    
                                END         
                        WHEN 411 THEN --1H Draw No Bet
                            CASE 
                                WHEN (@hth - @hta) = 0 THEN 0
                                WHEN betteam = 'h' AND (@hth - @hta) > 0 THEN 1
                                WHEN betteam = 'a' AND (@hth - @hta) < 0 THEN 1
                                ELSE -1
                                END
                        WHEN 412 THEN --Exact 1st Half Goal
                            CASE 
                                WHEN betteam <> '3-over' AND CAST(betteam AS INT) = (@hth + @hta) THEN 1
                                WHEN betteam = '3-over' AND (@hth + @hta) >= 3 THEN 1
                                ELSE -1
                                END
                        WHEN 413 THEN --Correct Score (aos)
                            CASE 
                                WHEN betteam = CAST(@fth AS VARCHAR) + ':' + CAST(@fta AS VARCHAR) THEN 1
                                WHEN betteam = 'AOS'
                                    AND CHARINDEX(CAST(@fth AS VARCHAR) + ':' + CAST(@fta AS VARCHAR), transdesc) = 0 THEN 1
                                ELSE -1
                                END
                        WHEN 414 THEN --1H Correct Score (aos)
                            CASE 
                                WHEN betteam = CAST(@hth AS VARCHAR) + ':' + CAST(@hta AS VARCHAR) THEN 1
                                WHEN betteam = 'AOS'
                                    AND CHARINDEX(CAST(@hth AS VARCHAR) + ':' + CAST(@hta AS VARCHAR), transdesc) = 0 THEN 1
                                ELSE -1
                                END
                        WHEN 415 THEN    
                            CASE 
                                WHEN betteam = 'HH' AND @FirstGoal='H' AND (@fth - @fta) >0 THEN 1 
                                WHEN betteam = 'DH' AND @FirstGoal='H' AND (@fth - @fta) =0 THEN 1
                                WHEN betteam = 'AH' AND @FirstGoal='H' AND (@fth - @fta) <0 THEN 1
                                WHEN betteam = 'HA' AND @FirstGoal='A' AND (@fth - @fta) >0 THEN 1
                                WHEN betteam = 'DA' AND @FirstGoal='A' AND (@fth - @fta) =0 THEN 1
                                WHEN betteam = 'AA' AND @FirstGoal='A' AND (@fth - @fta) <0 THEN 1
                                WHEN betteam = 'NO' AND @fth =0 AND @fta= 0 THEN 1
                                ELSE - 1
                                END
                        WHEN 416 THEN -- Half Time/Full Time Correct Score (own)
                            CASE 
                                WHEN CHARINDEX('AOS',betteam) = 0 THEN CASE
                                                                            WHEN betteam = CAST(@hth AS NVARCHAR(10)) + ':' + CAST(@hta AS NVARCHAR(10)) + '/' + CAST(@fth AS NVARCHAR(10)) + ':' + CAST(@fta AS NVARCHAR(10)) THEN 1
                                                                            ELSE -1
                                                                        END
                                WHEN CHARINDEX('AOS/AOS',betteam) > 0 THEN CASE
                                                                                WHEN CHARINDEX(CAST(@hth AS NVARCHAR(10)) + ':' + CAST(@hta AS NVARCHAR(10)),i.ExcludingHTChoice) = 0 AND CHARINDEX(CAST(@fth AS NVARCHAR(10)) + ':' + CAST(@fta AS NVARCHAR(10)),i.ExcludingFTChoice) = 0 THEN 1
                                                                                ELSE -1
                                                                            END
                                WHEN CHARINDEX('/AOS',betteam) > 0 THEN CASE
                                                                            WHEN betteam = CAST(@hth AS NVARCHAR(10)) + ':' + CAST(@hta AS NVARCHAR(10)) + '/AOS' AND CHARINDEX(CAST(@fth AS NVARCHAR(10)) + ':' + CAST(@fta AS NVARCHAR(10)),i.ExcludingFTChoice) = 0 THEN 1
                                                                            ELSE -1
                                                                        END
                                WHEN CHARINDEX('AOS/',betteam) > 0 THEN CASE
                                                                            WHEN betteam = 'AOS/' + CAST(@fth AS NVARCHAR(10)) + ':' + CAST(@fta AS NVARCHAR(10)) AND CHARINDEX(CAST(@hth AS NVARCHAR(10)) + ':' + CAST(@hta AS NVARCHAR(10)),i.ExcludingHTChoice) = 0 THEN 1
                                                                            ELSE -1
                                                                        END
                                ELSE -1
                            END
                        WHEN 417 THEN
                            CASE
                                WHEN betteam = CASE 
                                                    WHEN @fth > 0 AND @fta > 0 THEN CASE
                                                                                        WHEN @fth > @fta THEN 'YH'
                                                                                        WHEN @fth < @fta THEN 'YA'
                                                                                        ELSE 'YD'
                                                                                    END
                                                    ELSE CASE 
                                                            WHEN @fth > @fta THEN 'NH'
                                                            WHEN @fth < @fta THEN 'NA'
                                                            ELSE 'ND'
                                                         END
                                                END THEN 1
                                ELSE - 1
                            END
                        WHEN 418 THEN
                            CASE
                                WHEN betteam = CASE 
                                                    WHEN @fth + @fta > hdp1 THEN CASE 
                                                                                    WHEN @fth > 0 AND @fta > 0 THEN 'Y'
                                                                                    ELSE 'N'
                                                                                 END + 'O'
                                                    WHEN @fth + @fta < hdp1 THEN CASE 
                                                                                    WHEN @fth > 0 AND @fta > 0 THEN 'Y'
                                                                                    ELSE 'N'
                                                                                 END + 'U'
                                                    ELSE NULL
                                                END THEN 1
                                ELSE -1
                            END
                        WHEN 419 THEN
                            CASE
                                WHEN betteam = CASE
                                                    WHEN @hth + @hta > 0 THEN '1H'
                                                    WHEN @fth + @fta - (@hth + @hta) > 0 THEN '2H'
                                                    ELSE 'N'
                                               END THEN 1
                                ELSE -1
                            END
                        WHEN 420 THEN
                            CASE
                                WHEN betteam = CASE
                                                    WHEN @hth > 0 THEN '1H'
                                                    WHEN @fth - @hth > 0 THEN '2H'
                                                    ELSE 'N'
                                                END THEN 1
                                ELSE -1
                            END
                        WHEN 421 THEN
                            CASE
                                WHEN betteam = CASE 
                                                    WHEN @hta > 0 THEN '1H'
                                                    WHEN @fta - @hta > 0 THEN '2H'
                                                    ELSE 'N'
                                                END THEN 1
                                ELSE -1
                            END        
                        WHEN 422 THEN
                            CASE
                                WHEN betteam = CASE 
                                                    WHEN (@home_firstteam2goals > 0 AND @away_firstteam2goals = 0) OR (@home_firstteam2goals <> 0 AND @home_firstteam2goals - @away_firstteam2goals < 0) THEN 'H'
                                                    WHEN (@away_firstteam2goals > 0 AND @home_firstteam2goals = 0) OR (@away_firstteam2goals <> 0 AND @away_firstteam2goals - @home_firstteam2goals < 0) THEN 'A'
                                                    ELSE 'N'
                                                END THEN 1
                                ELSE -1
                            END
                        WHEN 423 THEN
                            CASE
                                WHEN betteam = CASE
                                                    WHEN (@home_firstteam3goals > 0 AND @away_firstteam3goals = 0) OR (@home_firstteam3goals <> 0 AND @home_firstteam3goals - @away_firstteam3goals < 0) THEN 'H'
                                                    WHEN (@away_firstteam3goals > 0 AND @home_firstteam3goals = 0) OR (@away_firstteam3goals <> 0 AND @away_firstteam3goals - @home_firstteam3goals < 0) THEN 'A'
                                                    ELSE 'N'
                                               END THEN 1
                                ELSE -1
                            END
                        WHEN 424 THEN
							CASE 
								WHEN betteam = @FirstGoalMethod THEN 1
								ELSE -1
							END	
                        WHEN 425 THEN
                            CASE
                                WHEN betteam = @WinFromBehind THEN 1
                                ELSE -1
                            END
                        WHEN 426 THEN
                            CASE
                                WHEN betteam = CASE 
                                                    WHEN @hth - @hta = 1 THEN 'H1'
                                                    WHEN @hth - @hta >= 2 THEN 'H2+'
                                                    WHEN @hth - @hta = -1 THEN 'A1'
                                                    WHEN @hth - @hta <= -2 THEN 'A2+'
                                                    WHEN @hth + @hta = 0 THEN 'NG'
                                                    WHEN @hth - @hta = 0 THEN 'D'
                                                    ELSE NULL
                                               END THEN 1
                                ELSE -1
                            END
                        WHEN 427 THEN 
                            CASE 
                                WHEN betteam = 'Y' AND @hth > 0 AND @hta > 0 THEN 1 
                                WHEN betteam = 'N' AND (@hth = 0 OR @hta = 0) THEN 1 
                                ELSE - 1
                                END
                        WHEN 428 THEN 
                            CASE 
                                WHEN betteam =N'o' AND ((@fth + @fta - @hth - @hta) &1) = 1 THEN 1 
                                WHEN betteam =N'e' AND ((@fth + @fta - @hth - @hta) &1) = 0 THEN 1 
                                ELSE - 1 
                            END 
                        WHEN 429 THEN
                            CASE
                                WHEN betteam = CASE 
                                                    WHEN @fth - @hth + @fta - @hta >=3 THEN '3-Over'
                                                    ELSE CAST((@fth - @hth + @fta - @hta) AS NVARCHAR(10)) 
                                               END THEN 1
                                ELSE -1
                            END
                        WHEN 430 THEN    
                            CASE 
                                WHEN (betteam = N'1') AND ((@fth -@hth) -(@fta - @hta))>0 THEN 1
                                WHEN (betteam = N'2') AND ((@fth -@hth) -(@fta - @hta))<0 THEN 1
                                WHEN (betteam = N'x') AND ((@fth -@hth) -(@fta - @hta))=0 THEN 1
                                ELSE - 1
                                END
                        WHEN 431 THEN -- Double Chance
                            CASE 
                                WHEN betteam = 'HD' AND ((@fth -@hth) -(@fta - @hta)) >= 0 THEN 1
                                WHEN betteam = 'DA' AND ((@fth -@hth) -(@fta - @hta)) <= 0 THEN 1
                                WHEN betteam = 'HA' AND ((@fth -@hth) -(@fta - @hta)) <> 0 THEN 1
                                ELSE - 1
                                END
                        WHEN 432 THEN -- Draw No Bet
                            CASE 
                                WHEN ((@fth -@hth) -(@fta - @hta)) = 0 THEN 0
                                WHEN betteam = 'h' AND ((@fth -@hth) -(@fta - @hta)) > 0 THEN 1
                                WHEN betteam = 'a' AND ((@fth -@hth) -(@fta - @hta)) < 0 THEN 1
                                ELSE - 1
                                END
                        WHEN 433 THEN -- 2nd Half Both Teams To Score
                            CASE 
                                WHEN betteam = 'y' AND (@fth - @hth) > 0 AND (@fta - @hta) > 0 THEN 1
                                WHEN betteam = 'n' AND ((@fth - @hth) = 0 OR (@fta - @hta) = 0) THEN 1
                                ELSE -1
                                END
                        WHEN 434 THEN    
                            CASE 
                                WHEN betteam ='y' AND (@hth + @hta - 1.5) > 0 AND ((@fth-@hth) + (@fta -@hta) - 1.5)>0 THEN 1 
                                WHEN betteam ='n' AND ((@hth + @hta - 1.5) <=0 OR ((@fth-@hth) + (@fta -@hta) - 1.5)<=0) THEN 1 
                                ELSE -1 
                                END 
                        WHEN 435 THEN -- Both Halves Under 1.5 Yes/No  [190]
                            CASE 
                                WHEN betteam ='y' AND (@hth + @hta - 1.5) < 0 AND ((@fth-@hth) + (@fta -@hta) - 1.5)<0 THEN 1  
                                WHEN betteam ='n' AND ((@hth + @hta - 1.5) >=0 OR ((@fth-@hth) + (@fta -@hta) - 1.5)>=0) THEN 1 
                                ELSE -1 
                            END    
                        WHEN 436 THEN -- Home To Score In Both Halves 
                            CASE 
                                WHEN betteam = 'y' AND @hth > 0 AND (@fth - @hth) > 0 THEN 1
                                WHEN betteam = 'n' AND (@hth = 0 OR (@fth - @hth) = 0) THEN 1
                                ELSE -1
                                END
                        WHEN 437 THEN -- Away To Score In Both Halves 
                            CASE 
                                WHEN betteam = 'y' AND @hta > 0 AND (@fta - @hta) > 0 THEN 1
                                WHEN betteam = 'n' AND (@hta = 0 OR (@fta - @hta) = 0) THEN 1
                                ELSE -1
                                END
                        WHEN 438 THEN -- Home To Win Both Halves
                            CASE 
                                WHEN betteam = 'y' AND (@hth > @hta) AND ((@fth - @hth) > (@fta - @hta)) THEN 1
                                WHEN betteam = 'n' AND ((@hth <= @hta) OR ((@fth - @hth) <= (@fta - @hta))) THEN 1
                                ELSE -1
                                END 
                        WHEN 439 THEN -- Away To Win Both Halves 
                            CASE 
                                WHEN betteam = 'y' AND (@hta > @hth) AND ((@fta - @hta) > (@fth - @hth)) THEN 1
                                WHEN betteam = 'n' AND ((@hta <=@hth) OR ((@fta - @hta) <= (@fth - @hth))) THEN 1
                                ELSE -1
                                END 
                        WHEN 440 THEN -- Home To Win Either Half 
                            CASE 
                                WHEN betteam = 'y' AND ((@hth > @hta) OR (@fth - @hth) > (@fta - @hta)) THEN 1
                                WHEN betteam = 'n' AND (@hth <= @hta) AND (@fth - @hth) <=(@fta - @hta) THEN 1
                                ELSE -1
                                END
                        WHEN 441 THEN -- Away To Win Either Half
                            CASE 
                                WHEN betteam = 'y' AND ((@hta > @hth) OR (@fta - @hta) > (@fth - @hth)) THEN 1
                                WHEN betteam = 'n' AND (@hta <= @hth) AND (@fta - @hta) <= (@fth - @hth) THEN 1
                                ELSE -1
                                END
                        WHEN 442 THEN -- Highest Scoring Half
                            CASE 
                                WHEN betteam = '1h' AND (@hth + @hta) > (@fth - @hth + @fta - @hta) THEN 1
                                WHEN betteam = 'tie' AND (@hth + @hta) = (@fth - @hth + @fta - @hta) THEN 1
                                WHEN betteam = '2h' AND (@hth + @hta) < (@fth - @hth + @fta - @hta) THEN 1
                                ELSE -1
                                END
                        WHEN 443 THEN -- Highest Scoring Half Home Team
                            CASE 
                                WHEN betteam = '1h' AND @hth > (@fth - @hth) THEN 1
                                WHEN betteam = 'tie' AND @hth = (@fth - @hth) THEN 1
                                WHEN betteam = '2h' AND @hth < (@fth - @hth) THEN 1
                                ELSE -1
                                END 
                        WHEN 444 THEN -- Highest Scoring Half Away Team
                            CASE 
                                WHEN betteam = '1h' AND @hta > (@fta - @hta) THEN 1
                                WHEN betteam = 'tie' AND @hta = (@fta - @hta) THEN 1
                                WHEN betteam = '2h' AND @hta < (@fta - @hta) THEN 1
                                ELSE -1
                                END
                        WHEN 445 THEN
                            CASE 
                                WHEN betteam = CASE
                                                    WHEN @hth > 0 AND @hta > 0 THEN CASE
                                                                                            WHEN (@fth - @hth) > 0 AND (@fta - @hta) > 0 THEN 'YY'
                                                                                            ELSE 'YN'
                                                                                    END
                                                    ELSE CASE 
                                                                WHEN (@fth - @hth) > 0 AND (@fta - @hta) > 0 THEN 'NY'
                                                                ELSE 'NN'
                                                         END
                                               END THEN 1
                                ELSE -1
                            END 
                        WHEN 446 THEN
                            CASE
                                WHEN betteam = CASE
                                                    WHEN @hth > 0 THEN CASE 
                                                                            WHEN @fth - @hth > 0 THEN 'YY'
                                                                            ELSE 'YN'
                                                                       END
                                                    ELSE CASE
                                                                WHEN @fth - @hth > 0 THEN 'NY'
                                                                ELSE 'NN'
                                                         END
                                              END THEN 1
                                ELSE -1
                            END
                        WHEN 447 THEN
                            CASE
                                WHEN betteam = CASE
                                                    WHEN @hta > 0 THEN CASE 
                                                                            WHEN @fta - @hta > 0 THEN 'YY'
                                                                            ELSE 'YN'
                                                                       END
                                                    ELSE CASE
                                                                WHEN @fta - @hta > 0 THEN 'NY'
                                                                ELSE 'NN'
                                                         END
                                              END THEN 1
                                ELSE -1
                            END
                        WHEN 501 THEN --Match Winner
                            CASE 
                                WHEN betteam = 'h' AND @fth > @fta THEN 1
                                WHEN betteam = 'a' AND @fth < @fta THEN 1
                                WHEN @fth = @fta THEN 0
                                ELSE -1
                                END
                        -- Tennis Sporting Solution 
                        WHEN 1301 THEN -- Match Winner 
                            CASE betteam
                                WHEN N'h' THEN (hdp2 - hdp1) + (@fth - livehomescore) - (@fta - liveawayscore)
                                WHEN N'a' THEN (hdp1 - hdp2) - (@fth - livehomescore) + (@fta - liveawayscore)
                                END
                        WHEN 1302 THEN -- Match Correct Score 
                            CASE 
                                WHEN betteam = (CAST(@fth AS VARCHAR(4)) + CAST(@fta AS VARCHAR(4))) THEN 1
                                ELSE - 1
                                END
                        WHEN 1303 THEN -- Set Handicap 
                            CASE betteam
                                WHEN N'h' THEN (hdp2 - hdp1) + (@fth - livehomescore) - (@fta - liveawayscore)
                                WHEN N'a' THEN (hdp1 - hdp2) - (@fth - livehomescore) + (@fta - liveawayscore)
                                END
                        WHEN 1305 THEN -- Match Total Games Odd/Even
                            CASE WHEN betteam = N'h' AND (@TotalGameHomeMatch + @TotalGameAwayMatch)%2 = 1 THEN 1 
                                 WHEN betteam = N'a' AND (@TotalGameHomeMatch + @TotalGameAwayMatch)%2 = 0 THEN 1 
                                 ELSE - 1 
                                 END 
                        WHEN 1306 THEN -- Match Total Games Over/Under - 1306
                            CASE betteam 
                                WHEN N'h' THEN  (@TotalGameHomeMatch + @TotalGameAwayMatch) - hdp1 
                                WHEN N'a' THEN  hdp1 - (@TotalGameHomeMatch + @TotalGameAwayMatch) 
                                END 
                        WHEN 1308 THEN  -- Match Games Handicap - 1308
                            CASE betteam 
                                WHEN N'h' THEN (hdp2 - hdp1) + (@TotalGameHomeMatch - livehomescore) - (@TotalGameAwayMatch - liveawayscore)
                                WHEN N'a' THEN (hdp1 - hdp2) - (@TotalGameHomeMatch - livehomescore) + (@TotalGameAwayMatch - liveawayscore)
                                END 
                        WHEN 1311 THEN -- Set x Winner - 1311
                            CASE betteam 
                                WHEN N'h' THEN (i.TotalGameHomeSetx - i.TotalGameAwaySetx)
                                WHEN N'a' THEN (i.TotalGameAwaySetx - i.TotalGameHomeSetx)
                                END 
                        WHEN 1312 THEN --Set x Total Games Over/Under - 1312
                            CASE betteam 
                                WHEN N'o' THEN (i.TotalGameHomeSetx + i.TotalGameAwaySetx) - hdp1 
                                WHEN N'u' THEN hdp1 - (i.TotalGameHomeSetx +i.TotalGameAwaySetx) 
                                END
                        WHEN 1316 THEN -- Set x Game Handicap
                            CASE betteam
                                WHEN N'h' THEN (hdp2 - hdp1) + (i.TotalGameHomeSetx - livehomescore) - (i.TotalGameAwaySetx - liveawayscore)
                                WHEN N'a' THEN (hdp1 - hdp2) - (i.TotalGameHomeSetx - livehomescore) + (i.TotalGameAwaySetx - liveawayscore)
                                END
                        WHEN 1317 THEN -- Set x Correct Score
                            CASE 
                                WHEN betteam = (CASE WHEN i.TotalGameHomeSetx > 7 AND (i.TotalGameHomeSetx - i.TotalGameAwaySetx)>=2 THEN 'haos'
                                                     WHEN i.TotalGameAwaySetx > 7 AND (i.TotalGameAwaySetx - i.TotalGameHomeSetx)>=2 THEN 'aaos'
                                                     ELSE (CAST(i.TotalGameHomeSetx AS VARCHAR(4)) + CAST(i.TotalGameAwaySetx AS VARCHAR(4))) 
                                                     END) THEN 1
                                ELSE - 1
                                END
                        WHEN 1318 THEN -- Set x Total Games Odd/Even
                            CASE WHEN betteam = N'o' AND (i.TotalGameHomeSetx + i.TotalGameAwaySetx)%2 = 1 THEN 1 
                                 WHEN betteam = N'e' AND (i.TotalGameHomeSetx + i.TotalGameAwaySetx)%2 = 0 THEN 1 
                                 ELSE - 1 
                                 END 
                        WHEN 1324 THEN -- Set x Game y Winner 
                            CASE WHEN betteam =N'h' AND CHARINDEX(SUBSTRING(CAST(betcheck AS VARCHAR(10)),2,4),@SetxGameyHomeWON)>0 THEN 1 
                                 WHEN betteam =N'a' AND CHARINDEX(SUBSTRING(CAST(betcheck AS VARCHAR(10)),2,4),@SetxGameyAwayWON)>0 THEN 1   
                                 WHEN CHARINDEX(SUBSTRING(CAST(betcheck AS VARCHAR(10)),2,4),@SetxGameyDRAW)>0 THEN 0 
                                 WHEN CHARINDEX(SUBSTRING(CAST(betcheck AS VARCHAR(10)),2,4),@SetxGameyREFUND)>0 THEN 0
                                 ELSE -1 END
                      
                        WHEN 14 THEN 
							CASE WHEN (betteam = (CASE 
													WHEN @ft_fg = 'N' THEN '0:0'
													WHEN @ft_fg = 'H' THEN '1:1'
													WHEN @ft_fg = 'A' THEN '2:1'
													ELSE ''
												END) 
									OR betteam =(CASE 
													WHEN @ft_lg = 'N' THEN '0:0'
													WHEN @ft_lg = 'H' THEN '1:2'
													WHEN @ft_lg = 'A' THEN '2:2'
													ELSE ''
												END) 
										) THEN 1
								ELSE - 1
							END
						
						WHEN 127 THEN 
							CASE 
								WHEN (betteam = @ht_fg OR betteam = @ht_lg) THEN 1
								ELSE - 1
							END
                        WHEN 601 THEN -- FT Winning Margin 14 Way
							CASE 
								WHEN betteam = 'H1-2' AND (@fth - @fta) BETWEEN 1 AND 2 THEN 1
								WHEN betteam = 'H3-6' AND (@fth - @fta) BETWEEN 3 AND 6 THEN 1
								WHEN betteam = 'H7-9' AND (@fth - @fta) BETWEEN 7 AND 9 THEN 1
								WHEN betteam = 'H10-13' AND (@fth - @fta) BETWEEN 10 AND 13 THEN 1
								WHEN betteam = 'H14-16' AND (@fth - @fta) BETWEEN 14 AND 16 THEN 1
								WHEN betteam = 'H17-20' AND (@fth - @fta) BETWEEN 17 AND 20 THEN 1
								WHEN betteam = 'H21+' AND (@fth - @fta) >= 21 THEN 1
								WHEN betteam = 'A1-2' AND (@fth - @fta) BETWEEN -2 AND -1 THEN 1
								WHEN betteam = 'A3-6' AND (@fth - @fta) BETWEEN -6 AND -3 THEN 1
								WHEN betteam = 'A7-9' AND (@fth - @fta) BETWEEN -9 AND -7 THEN 1
								WHEN betteam = 'A10-13' AND (@fth - @fta) BETWEEN -13 AND -10 THEN 1
								WHEN betteam = 'A14-16' AND (@fth - @fta) BETWEEN -16 AND -14 THEN 1
								WHEN betteam = 'A17-20' AND (@fth - @fta) BETWEEN -20 AND -17 THEN 1
								WHEN betteam = 'A21+' AND (@fth - @fta) <= -21 THEN 1
								ELSE -1
							END 
						WHEN 602 THEN -- FT Winning Margin 12 Way
							CASE
								WHEN betteam = 'H1-5' AND (@fth - @fta) BETWEEN 1 AND 5 THEN 1
								WHEN betteam = 'H6-10' AND (@fth - @fta) BETWEEN 6 AND 10 THEN 1
								WHEN betteam = 'H11-15' AND (@fth - @fta) BETWEEN 11 AND 15 THEN 1
								WHEN betteam = 'H16-20' AND (@fth - @fta) BETWEEN 16 AND 20 THEN 1
								WHEN betteam = 'H21-25' AND (@fth - @fta) BETWEEN 21 AND 25 THEN 1
								WHEN betteam = 'H26+' AND (@fth - @fta) >= 26 THEN 1
								WHEN betteam = 'A1-5' AND (@fth - @fta) BETWEEN -5 AND -1 THEN 1
								WHEN betteam = 'A6-10' AND (@fth - @fta) BETWEEN -10 AND -6 THEN 1
								WHEN betteam = 'A11-15' AND (@fth - @fta) BETWEEN -15 AND -11 THEN 1
								WHEN betteam = 'A16-20' AND (@fth - @fta) BETWEEN -20 AND -16 THEN 1
								WHEN betteam = 'A21-25' AND (@fth - @fta) BETWEEN -25 AND -21 THEN 1
								WHEN betteam = 'A26+' AND (@fth - @fta) <= -26 THEN 1	
								ELSE -1
							END
						WHEN 603 THEN -- FT Which team to score the highest quarter
							CASE 
								WHEN @FTHighestQuarter = 'N' THEN 0
								WHEN betteam = @FTHighestQuarter THEN 1 
								ELSE -1 
							END
						WHEN 604 THEN -- FT Which team to score the first basket
							CASE
								WHEN betteam = rd.HomeValue THEN 1 
								ELSE -1 
							END
						WHEN 605 THEN -- FT Which team to score the last basket 	
							CASE
								WHEN betteam = rd.HomeValue THEN 1 
								ELSE -1 
							END
						WHEN 606 THEN -- 1H Race to YY
							CASE 
								WHEN rd.HomeValue = 'N' THEN 0 
								WHEN betteam = rd.HomeValue THEN 1 
								ELSE -1 
							END
						WHEN 607 THEN -- 2H Race to YY
							CASE 
								WHEN rd.HomeValue = 'N' THEN 0 
								WHEN betteam = rd.HomeValue THEN 1 
								ELSE -1 
							END
						WHEN 608 THEN -- 1H Winning Margin 12 Way
							CASE
								WHEN (@hth - @hta) BETWEEN 1 AND 5 AND betteam = 'H1-5' THEN 1
								WHEN (@hth - @hta) BETWEEN 6 AND 10 AND betteam = 'H6-10' THEN 1
								WHEN (@hth - @hta) BETWEEN 11 AND 15 AND betteam = 'H11-15' THEN 1 
								WHEN (@hth - @hta) BETWEEN 16 AND 20 AND betteam = 'H16-20' THEN 1
								WHEN (@hth - @hta) BETWEEN 21 AND 25 AND betteam = 'H21-25' THEN 1 
								WHEN (@hth - @hta) >= 26 AND betteam = 'H26+' THEN 1
								WHEN (@hth - @hta) = 0 AND betteam = 'D' THEN 1
								WHEN (@hth - @hta) BETWEEN -5 AND -1 AND betteam = 'A1-5' THEN 1
								WHEN (@hth - @hta) BETWEEN -10 AND -6 AND betteam = 'A6-10' THEN 1
								WHEN (@hth - @hta) BETWEEN -15 AND -11 AND betteam = 'A11-15' THEN 1
								WHEN (@hth - @hta) BETWEEN -20 AND -16 AND betteam = 'A16-20' THEN 1
								WHEN (@hth - @hta) BETWEEN -25 AND -21 AND betteam = 'A21-25' THEN 1
								WHEN (@hth - @hta) <= -26 AND betteam = 'A26+' THEN 1
								ELSE -1
							END
						WHEN 609 THEN -- Quarter X Handicap
							CASE 
								WHEN betteam = 'h' THEN (res.QXHome - hdp1) - (res.QXAway - hdp2)
								WHEN betteam = 'a' THEN (res.QXAway - hdp2) - (res.QXHome - hdp1)
								ELSE -1
							END
						WHEN 610 THEN -- Quarter X Over Under
							CASE 
								WHEN betteam = 'o' THEN res.QXHome + res.QXAway - hdp1
								WHEN betteam = 'u' THEN hdp1 - (res.QXHome + res.QXAway) 
								ELSE -1
							END
						WHEN 611 THEN -- Quarter X Odd Even
							CASE 
								WHEN betteam = 'o' AND (res.QXHome + res.QXAway) % 2 = 1 THEN 1
								WHEN betteam = 'e' AND (res.QXHome + res.QXAway) % 2 = 0 THEN 1
								ELSE -1
							END
						WHEN 612 THEN -- Quarter X Moneyline
							CASE 
								WHEN betteam = 'h' THEN (res.QXHome - res.QXAway)
								WHEN betteam = 'a' THEN (res.QXAway - res.QXHome)
								ELSE -1
							END
						WHEN 613 THEN -- Quarter X Race to YY
							CASE 
								WHEN rd.HomeValue = 'N' THEN 0
								WHEN bm.betteam = rd.HomeValue THEN 1
								ELSE -1
							END
						WHEN 614 THEN -- Quarter X Winning Margin 7 Way
							CASE	
								WHEN betteam = 'H1-4' AND (res.QXHome - res.QXAway) BETWEEN 1 AND 4 THEN 1
								WHEN betteam = 'H5-8' AND (res.QXHome - res.QXAway) BETWEEN 5 AND 8 THEN 1
								WHEN betteam = 'H9+' AND (res.QXHome - res.QXAway) >= 9 THEN 1
								WHEN betteam = 'D' AND (res.QXHome - res.QXAway) = 0 THEN 1
								WHEN betteam = 'A1-4' AND (res.QXAway - res.QXHome) BETWEEN 1 AND 4 THEN 1
								WHEN betteam = 'A5-8' AND (res.QXAway - res.QXHome) BETWEEN 5 AND 8 THEN 1
								WHEN betteam = 'A9+' AND (res.QXAway - res.QXHome) >= 9 THEN 1
								ELSE -1
							END
						WHEN 615 THEN -- Quarter X Home Team Over Under
							CASE	
								WHEN betteam = 'o' THEN res.QXHome - hdp1
								WHEN betteam = 'u' THEN hdp1 - res.QXHome
								ELSE -1
							END
						WHEN 616 THEN -- Quarter X Away Team Over Under
							CASE	
								WHEN betteam = 'o' THEN res.QXAway - hdp1
								WHEN betteam = 'u' THEN hdp1 - res.QXAway
								ELSE -1
							END
						WHEN 617 THEN -- Quarter X Which team to score the last basket
							CASE	
								WHEN rd.HomeValue = 'N' THEN 0
								WHEN bm.betteam = rd.HomeValue THEN 1
								ELSE -1
							END
						
						--STARTING for new bettype for PHAIO 3
						-- 22: Next Goal
						 WHEN 22 THEN 
                            CASE WHEN CHARINDEX((REPLACE(SUBSTRING(CAST(betcheck AS VARCHAR(10)),2,5),@bettype_22,@bettype_160) + betteam),@NextGoal)> 0 THEN 1 
                                 ELSE - 1 
                                 END
                        -- 455: Time Of First Goal
                         WHEN 455 THEN 
                            CASE WHEN Betteam = @TimeFirstGoal THEN 1 
                                 ELSE - 1
                                 END 
						-- 456: 1H Both Teams To Score / Result
						WHEN 456 THEN 
									CASE WHEN bm.betteam = (CASE 
																WHEN @hth > 0 AND @hta > 0 THEN CASE 
																									WHEN @hth > @hta THEN 'YH'
																									WHEN @hth < @hta THEN 'YA'
																									ELSE 'YD'
																								END
																ELSE CASE 
																		WHEN @hth > @hta THEN 'NH'
																		WHEN @hth < @hta THEN 'NA'
																		ELSE 'ND'
																	 END
															  END
													  ) THEN 1
											ELSE -1			  
									END
						 -- 457: 1H Both Teams To Score / Total Goals
						WHEN 457 THEN CASE WHEN bm.betteam =(CASE WHEN @hth > 0 AND @hta > 0 THEN 'Y' ELSE 'N' END
															 
															 + CASE WHEN @hth + @hta > hdp1 THEN  'O'
                                                                    WHEN @hth + @hta < hdp1 THEN  'U'
                                                                    ELSE NULL
                                                               END     
                                                             ) THEN 1     
                                                                                
											ELSE -1
                                    END  
                                      			  
                         -- 453: 1H 3-Way Handicap
                         WHEN 453 THEN 
								CASE
									WHEN betteam = '1' AND ((@hth - [hdp1]) - (@hta - [hdp2])) > 0  THEN 1
									WHEN betteam = '2' AND ((@hth - [hdp1]) - (@hta - [hdp2])) < 0  THEN 1
									WHEN betteam = 'x' AND ((@hth - [hdp1]) - (@hta - [hdp2])) = 0  THEN 1
									ELSE - 1
								END		         
							
                         --459:	1H Asian 1X2
                         WHEN 459 THEN 
								CASE
									WHEN betteam = '1' AND @hth - livehomescore > @hta - liveawayscore THEN 1
									WHEN betteam = '2' AND @hth - livehomescore < @hta - liveawayscore THEN 1
									WHEN betteam = 'X' AND @hth - livehomescore = @hta - liveawayscore THEN 1
									ELSE -1
								END
						 --458: FT Asia 1X2
                         WHEN 458 THEN 
								CASE
									WHEN betteam = '1' AND @fth - livehomescore > @fta - liveawayscore THEN 1
									WHEN betteam = '2' AND @fth - livehomescore < @fta - liveawayscore THEN 1
									WHEN betteam = 'X' AND @fth - livehomescore = @fta - liveawayscore THEN 1
									ELSE -1
								END
						--448: Last Team To Score
						WHEN 448 THEN 
									CASE WHEN betteam = (CASE 
															WHEN @ft_lg = 'N' THEN 'NG'
															ELSE @ft_lg 
														END) THEN 1 ELSE -1 END		
						--449: Double Chance & Total Goals
						WHEN 449 THEN 
									CASE 
										WHEN betteam = '1XO' AND @ScoreDiff >= 0 AND @totalgoal - [hdp1] > 0 THEN 1
										WHEN betteam = '1XU' AND @ScoreDiff >= 0 AND @totalgoal - [hdp1] < 0 THEN 1
										WHEN betteam = '12O' AND @ScoreDiff <> 0 AND @totalgoal - [hdp1] > 0 THEN 1
										WHEN betteam = '12U' AND @ScoreDiff <> 0 AND @totalgoal - [hdp1] < 0 THEN 1
										WHEN betteam = '2XO' AND @ScoreDiff <= 0 AND @totalgoal - [hdp1] > 0 THEN 1
										WHEN betteam = '2XU' AND @ScoreDiff <= 0 AND @totalgoal - [hdp1] < 0 THEN 1
										ELSE -1 
									END
																				
                        --450: Odd/Even & Total Goals
                        WHEN 450 THEN	
									CASE 
										WHEN betteam = 'OO' AND @oddeven = 1 AND @totalgoal > [hdp1] THEN 1
										WHEN betteam = 'OU' AND @oddeven = 1 AND @totalgoal < [hdp1] THEN 1
										WHEN betteam = 'EO' AND @oddeven = 0 AND @totalgoal > [hdp1] THEN 1
										WHEN betteam = 'EU' AND @oddeven = 0 AND @totalgoal < [hdp1] THEN 1
										ELSE -1
									 END	
						--451: Both Teams To Score / Double Chance
						WHEN 451 THEN CASE
											WHEN betteam = 'Y1X' AND (@fth > 0  AND @fta > 0) AND @ScoreDiff >= 0 THEN 1
											WHEN betteam = 'Y12' AND (@fth > 0  AND @fta > 0) AND @ScoreDiff <> 0 THEN 1
											WHEN betteam = 'Y2X' AND (@fth > 0  AND @fta > 0) AND @ScoreDiff <= 0 THEN 1
											WHEN betteam = 'N1X' AND (@fth = 0  OR @fta = 0)  AND @ScoreDiff >= 0 THEN 1
											WHEN betteam = 'N12' AND (@fth = 0  OR @fta = 0)  AND @ScoreDiff <> 0 THEN 1
											WHEN betteam = 'N2X' AND (@fth = 0  OR @fta = 0)  AND @ScoreDiff <= 0 THEN 1
											ELSE -1
										END
						
						--452: Highest Scoring Half (2 Way)
						WHEN 452 THEN CASE
											WHEN betteam = '1H' AND @totalht > @totalgoal_2H THEN 1
											WHEN betteam = '2H' AND @totalht < @totalgoal_2H THEN 1
											WHEN @totalht = @totalgoal_2H THEN 0
											ELSE -1
										END
						 --460: Which Team Will Win By 5+ Goals
						 WHEN 460 THEN CASE
											WHEN betteam = 'H' AND @ScoreDiff >= 5  THEN 1
											WHEN betteam = 'A' AND @ScoreDiff <= -5 THEN 1
											ELSE -1
										END					
						--454: Double Chance & First Team To Score	
                        WHEN 454 THEN CASE
											WHEN betteam = '1XH' AND @ScoreDiff >= 0 AND @ft_fg = 'H' THEN 1
											WHEN betteam = '12H' AND @ScoreDiff <> 0 AND @ft_fg = 'H' THEN 1
											WHEN betteam = '2XH' AND @ScoreDiff <= 0 AND @ft_fg = 'H' THEN 1
											WHEN betteam = '1XA' AND @ScoreDiff >= 0 AND @ft_fg = 'A' THEN 1
											WHEN betteam = '12A' AND @ScoreDiff <> 0 AND @ft_fg = 'A' THEN 1
											WHEN betteam = '2XA' AND @ScoreDiff <= 0 AND @ft_fg = 'A' THEN 1
											WHEN betteam = 'NG'  AND @ft_fg = 'N' THEN 1
											ELSE -1
										END
						-- -- #112885 - PH4 - 467: HT/FT Exact Total Goal
						WHEN 467 THEN CASE WHEN 
											(CASE WHEN @totalht IN (0,1,2,3) AND @totalgoal >= 7 
												THEN 'G' + CAST(@totalht AS VARCHAR(5)) + '/G7+'
											WHEN @totalht = 4 AND @totalgoal >= 8 
												THEN 'G4/G8+'
											WHEN @totalht = 5 AND @totalgoal >= 9 
												THEN 'G5/G9+'  
											WHEN @totalht = 6 AND @totalgoal >= 10 
												THEN 'G6/G10+'
											WHEN @totalht >= 7 AND @totalgoal >= 7 
												THEN 'G7+/G7+'
											ELSE 'G' + CAST(@totalht AS VARCHAR(5)) + '/G' + CAST(@totalgoal AS VARCHAR(5))
										END) = betteam THEN 1 
									ELSE -1
								END   
                        ELSE NULL -- Not support bettype
                        END AS modds
						,CAST(CASE 
							WHEN bm.Bettype = 1324 AND CHARINDEX(SUBSTRING(CAST(Betcheck AS VARCHAR(10)),2,4),@SetxGameyREFUND)>0 THEN 1 
							ELSE 0 
						END AS BIT) AS isRefundGame
            FROM    @tblBettypes t
			INNER JOIN	dbo.bettransm bm WITH (NOLOCK)
				ON bm.bettype = t.bettype
			 CROSS APPLY (
					SELECT CAST(CASE 
								WHEN betCheck = '801' THEN @homeScoreSet1
                                WHEN betCheck = '802' THEN @homeScoreSet2
                                WHEN betCheck = '803' THEN @homeScoreSet3
                                WHEN betCheck = '804' THEN @homeScoreSet4
                                WHEN betCheck = '805' THEN @homeScoreSet5
                                ELSE NULL 
                                END AS INT) AS  TotalGameHomeSetx
							,CAST(CASE 
								WHEN betCheck = '801' THEN @awayScoreSet1
                                WHEN betCheck = '802' THEN @awayScoreSet2
                                WHEN betCheck = '803' THEN @awayScoreSet3
                                WHEN betCheck = '804' THEN @awayScoreSet4
                                WHEN betCheck = '805' THEN @awayScoreSet5
                                ELSE NULL
                                END AS INT)  AS TotalGameAwaySetx
							,CAST(CASE 
									WHEN bm.bettype = 416 THEN SUBSTRING(transdesc,0, CHARINDEX('/',transdesc)) 
									ELSE NULL 
								END AS NVARCHAR(1000)) AS ExcludingHTChoice
							,CAST(CASE 
									WHEN bm.bettype = 416 THEN SUBSTRING(transdesc,CHARINDEX('/',transdesc)+1,LEN(transdesc)) 
									ELSE NULL 
								END AS NVARCHAR(1000)) AS ExcludingFTChoice    
				) i
				CROSS APPLY (
					SELECT	CAST(bm.bettype AS VARCHAR) + ISNULL(SUBSTRING(bm.betcheck, 2, LEN(bm.betcheck)), '') AS ResourceId
				)r
				CROSS APPLY ( -- for basketball
					SELECT 	CASE
								WHEN bm.betcheck = '801' THEN @Q1Home
								WHEN bm.betcheck = '802' THEN @Q2Home
								WHEN bm.betcheck = '803' THEN @Q3Home
								WHEN bm.betcheck = '804' THEN @Q4Home
								ELSE 0
							END AS QXHome
							,CASE
								WHEN bm.betcheck = '801' THEN @Q1Away
								WHEN bm.betcheck = '802' THEN @Q2Away
								WHEN bm.betcheck = '803' THEN @Q3Away
								WHEN bm.betcheck = '804' THEN @Q4Away
								ELSE 0
							END AS QXAway
							,CASE 
								WHEN t.groupId = 10 
									THEN CASE 
											WHEN bm.betcheck = '801' THEN 'Q1'
											WHEN bm.betcheck = '802' THEN 'Q2'
											WHEN bm.betcheck = '803' THEN 'Q3'
											WHEN bm.betcheck = '804' THEN 'Q4'
											ELSE ''
										END
								ELSE ''
							END AS QuarterX
				) res
				LEFT JOIN @tmpResultDetail rd
					ON r.ResourceId = rd.ResourceId
            WHERE   bm.matchid = @matchid
					AND bm.statusID NOT IN (101, 102)  
					AND 1 = CASE 
							WHEN @SelectedSetCAL IS NULL AND @SelectedSetREFUND IS NULL THEN 1 
                            WHEN @SelectedSetCAL LIKE '%1%' AND bm.Bettype IN (154,155,156,1311,1312,1316,1317,1318,1324) AND betcheck LIKE '801%' THEN 1 
                            WHEN @SelectedSetCAL LIKE '%2%' AND bm.Bettype IN (154,155,156,1311,1312,1316,1317,1318,1324) AND betcheck LIKE '802%' THEN 1 
                            WHEN @SelectedSetCAL LIKE '%3%' AND bm.Bettype IN (154,155,156,1311,1312,1316,1317,1318,1324) AND betcheck LIKE '803%' THEN 1 
                            WHEN @SelectedSetCAL LIKE '%4%' AND bm.Bettype IN (154,155,156,1311,1312,1316,1317,1318,1324) AND betcheck LIKE '804%' THEN 1 
                            WHEN @SelectedSetCAL LIKE '%5%' AND bm.Bettype IN (154,155,156,1311,1312,1316,1317,1318,1324) AND betcheck LIKE '805%' THEN 1 
                            WHEN @SelectedSetCAL LIKE '%6%' AND bm.Bettype IN (1,2,3,20,153,1301,1302,1303,1305,1306,1308) THEN 1
                            WHEN @SelectedSetREFUND LIKE '%1%' AND bm.Bettype = 1324 AND betcheck LIKE '801%' THEN 1 
                            WHEN @SelectedSetREFUND LIKE '%2%' AND bm.Bettype = 1324 AND betcheck LIKE '802%' THEN 1 
                            WHEN @SelectedSetREFUND LIKE '%3%' AND bm.Bettype = 1324 AND betcheck LIKE '803%' THEN 1 
                            WHEN @SelectedSetREFUND LIKE '%4%' AND bm.Bettype = 1324 AND betcheck LIKE '804%' THEN 1 
                            WHEN @SelectedSetREFUND LIKE '%5%' AND bm.Bettype = 1324 AND betcheck LIKE '805%' THEN 1  
                            ELSE 0 
                            END 
                    AND 1 = CASE WHEN @ResourceIDsCAL IS NULL AND t.groupId <> 8 THEN 1  
								WHEN @ResourceIDsCAL IS NOT NULL AND bm.Bettype = 22 AND CHARINDEX(REPLACE(SUBSTRING(CAST(Betcheck AS VARCHAR(20)),2,5),@bettype_22,@bettype_160),@ResourceIDsCAL)>0 THEN 1 	
								WHEN @ResourceIDsCAL IS NOT NULL AND bm.Bettype IN (160,164,169,180) AND CHARINDEX(SUBSTRING(CAST(Betcheck AS VARCHAR(20)),2,5),@ResourceIDsCAL)>0 THEN 1 
								WHEN @ResourceIDsCAL IS NOT NULL AND t.groupId = 8 AND bm.Bettype NOT IN (160,164,169,180,22) AND CHARINDEX(CAST(bm.Bettype AS VARCHAR(20)),@ResourceIDsCAL)>0 THEN 1 
								ELSE 0 END  --Betradar 2 Auto Bettypes 
                    AND 1 = CASE -- basketball
								WHEN @resultDetail_bb IS NULL THEN 1
								WHEN t.isEarly = 1 THEN CASE
															WHEN CHARINDEX(',' + r.ResourceId + ',', ',' + @basketball_ResourceIdsCAL + ',') > 0 THEN 1
															ELSE 0
															END
								WHEN t.groupId = 10 THEN CASE
															WHEN CHARINDEX(',' + res.QuarterX + ',', ',' + @basketball_ResourceIdsCAL + ',') > 0 THEN 1
															ELSE 0
														END
								WHEN CHARINDEX(',' + t.groupName + ',', ',' + @basketball_ResourceIdsCAL + ',') > 0 THEN 1
								ELSE 0
								END		
	
			WHILE (1 = 1)
			BEGIN
				
				DELETE
				FROM	@tmptransid
				
				DELETE TOP (2000 )
				FROM #Result
				OUTPUT deleted.transid, deleted.refno, deleted.modds, deleted.isrefundgame 
				INTO @tmptransid (transid, refno, modds, isrefundgame)				
				
				IF @@ROWCOUNT = 0
					BREAK									
			
				UPDATE	bm WITH (ROWLOCK, UPDLOCK)
					SET ruben = CASE 
									WHEN t.modds IS NOT NULL THEN 0 
									ELSE 1 
								END
						,winlostdate = @matchdate
						,[status] = CASE 
										WHEN t.modds IS NULL THEN N'running'
										WHEN t.modds = 0 AND t.isRefundGame = 0 THEN N'DRAW'
										WHEN t.modds = 0 AND t.isRefundGame = 1 THEN N'Refund'
										WHEN t.modds < 0 THEN N'LOSE'
										WHEN t.modds > 0 THEN N'WON'
									END
						,statusID = CASE 
										WHEN t.modds IS NULL THEN 0
										WHEN t.modds = 0 AND t.isRefundGame = 0 THEN 111
										WHEN t.modds = 0 AND t.isRefundGame = 1 THEN 103 
										WHEN t.modds < 0 THEN 113
										WHEN t.modds > 0 THEN 112
									END
						,statuswinlost = CASE 
											WHEN t.modds <= - 0.5 THEN 4 -- LOSE
											WHEN t.modds >= 0.5 THEN 2 -- WIN
											WHEN t.modds > 0 THEN 1 -- Half WIN
											WHEN t.modds < 0 THEN 3 -- Half LOSE
											ELSE 0 -- DRAW
										END										
				FROM	dbo.bettransm bm 
					INNER JOIN @tmptransid t
						ON	bm.transid = t.transid
							AND bm.refno = t.refno
				
				UPDATE	pd 
					SET winlostdate = @matchdate
						 ,statusID = CASE 
										WHEN t.modds IS NULL THEN 0
										WHEN t.modds = 0 AND t.isRefundGame = 0 THEN 111
										WHEN t.modds = 0 AND t.isRefundGame = 1 THEN 103 
										WHEN t.modds < 0 THEN 113
										WHEN t.modds > 0 THEN 112
									END
						,statuswinlost = CASE 
											WHEN t.modds <= - 0.5 THEN 4 -- LOSE
											WHEN t.modds >= 0.5 THEN 2 -- WIN
											WHEN t.modds > 0 THEN 1 -- Half WIN
											WHEN t.modds < 0 THEN 3 -- Half LOSE
											ELSE 0 -- DRAW
										END
				FROM    dbo.BetParlayDetail pd WITH(ROWLOCK, UPDLOCK)
					INNER JOIN @tmptransid t
						ON  pd.transid = t.transid						
			END                
        END --@doing = 'CAL'
    END -- while
END -- end SP
GO