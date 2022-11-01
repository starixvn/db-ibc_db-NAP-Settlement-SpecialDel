/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
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
    ,@TennisTotal INT = NULL     
    ,@GoalSequence VARCHAR(50) = NULL         
    ,@resultDetail_bb VARCHAR(MAX) = NULL -- for basketball
    ,@resultDetail VARCHAR(MAX) = NULL -- for all result
    ,@strBettypes VARCHAR(MAX) = NULL
	,@betstatus	NVARCHAR(50) = NULL
	,@IsRefundHT BIT = NULL
	,@Sporttype SMALLINT = NULL
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

    Param's Explanation:
       
*/
BEGIN
    SET NOCOUNT ON
    
	-- CHECK SERVER BEFORE CALCULATING
	DECLARE @ServerName	SYSNAME 
			,@AllowExec	BIT
			,@CutOffDate		DATETIME = '2021-10-07 00:00:00.000'
			,@transinfo XML
			,@betparlaydetailinfo XML
			,@IsSiteDB BIT = 0
			,@FunctionName VARCHAR(100)

	DECLARE @tmpOutputBettransm TABLE (ID INT IDENTITY(1,1) PRIMARY KEY,transid BIGINT, refno BIGINT
		,status VARCHAR(10), StatusId TINYINT, ruben TINYINT
		,statuswinlost TINYINT, winlostdate SMALLDATETIME)
	DECLARE @tmpOutputBetParlayDetail TABLE (ID INT IDENTITY(1,1) PRIMARY KEY,transid BIGINT, statuswinlost TINYINT, StatusId TINYINT, winlostdate SMALLDATETIME)   
	DECLARE @tmpOutputBettransmVoidRecover TABLE (transid BIGINT, winlost MONEY
		,status VARCHAR(10), statusId TINYINT, ruben TINYINT
		,statuswinlost TINYINT, creator INT, winlostdate SMALLDATETIME)
	DECLARE @tmpTransIdsVoidRecover TABLE (transid BIGINT)
	
	------ process by batch for betparlaydetail
	DECLARE @StartRow INT = 1
			, @StopRow INT 
			, @MaxRow INT = 1 -- Keep the total row of your data
			, @Threshold INT = 3000 -- the number of each batch
            
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
		
	DECLARE @modds MONEY , @doing VARCHAR(10) = 'zzz'
	
	WHILE (@doing <> @action)
    BEGIN        
        SET @doing = CASE @doing WHEN @priorAction THEN @action ELSE COALESCE(@priorAction, @action) END
		
		DELETE FROM @tmpOutputBettransm
		DELETE FROM @tmpOutputBetParlayDetail
		DELETE FROM @tmpTransIdsVoidRecover
		DELETE FROM @tmpOutputBettransmVoidRecover

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
			SET @FunctionName = 'RefundSubParlay'

            UPDATE bm
            SET 
				@IsUpd_Void = CASE WHEN statusID = 102 THEN 0 ELSE 1 END
				,winlostdate = CASE 
									WHEN @IsUpd_Void = 0 THEN bm.winlostdate 
									ELSE @matchdate
								END
								
                ,[status] = CASE 
								WHEN @IsUpd_Void = 0 THEN bm.[status] 
								ELSE 'Refund'
							END
                ,statuswinlost = 6
                ,ruben = 1
                ,statusID = CASE 
								WHEN @IsUpd_Void = 0 THEN bm.statusID 
								ELSE 103
							END
								
            OUTPUT INSERTED.transid, INSERTED.refno, inserted.status, inserted.statusID, inserted.ruben, inserted.statuswinlost, inserted.winlostdate
			INTO @tmpOutputBettransm(transid, refno, status, StatusId, ruben, statuswinlost, winlostdate)
            FROM dbo.bettransm bm WITH(ROWLOCK, UPDLOCK) 
				INNER JOIN @tblBettypes t
					ON bm.bettype = t.bettype
				CROSS APPLY (
					SELECT	CAST(CAST(bm.bettype AS VARCHAR) + ISNULL(SUBSTRING(bm.betcheck, 2, LEN(bm.betcheck)),'') AS VARCHAR(20)) AS ResourceId
				)r
            WHERE matchid = @matchid      
				AND bm.SiteDBGroupID = CASE WHEN @IsSiteDB = 1 THEN bm.SiteDBGroupID ELSE 0 END
                AND statusID NOT IN (101)
				AND t.groupId <> 8 -- Early Soccer						
			
			SET @MaxRow = (SELECT MAX(ID) FROM @tmpOutputBettransm)

			IF @Threshold >= @MaxRow
				SET @Threshold = @MaxRow

			-- SET for first batch
			SET @StopRow = @Threshold
			WHILE (1 = 1)
			BEGIN
					UPDATE pd
						SET winlostdate = @matchdate
							,statuswinlost = 0
							,statusID = 103
						OUTPUT inserted.transid, inserted.winlostdate, inserted.statuswinlost, inserted.statusid
						INTO @tmpOutputBetParlayDetail(transid, winlostdate, statuswinlost, StatusId)
						FROM dbo.BetParlayDetail pd WITH(ROWLOCK,UPDLOCK)
							INNER JOIN @tmpOutputBettransm r
								ON    pd.transid = r.transid
									AND pd.RefNo = r.refno
						 WHERE pd.statusid NOT IN (102)
								AND ID BETWEEN @StartRow AND @StopRow

					IF @StopRow = @MaxRow BREAK

					SET @StartRow = @StopRow + 1
					SET @StopRow = @StopRow + @Threshold

					IF @StopRow >= @MaxRow
						SET @StopRow = @MaxRow
			END

			/*
            UPDATE pd
            SET winlostdate = @matchdate
                ,statuswinlost = 0
                ,statusID = 103
			OUTPUT inserted.transid, inserted.winlostdate, inserted.statuswinlost, inserted.statusid
			INTO @tmpOutputBetParlayDetail(transid, winlostdate, statuswinlost, StatusId)
            FROM dbo.BetParlayDetail pd WITH(TABLOCK)
                INNER JOIN @tmpOutputBettransm r
                    ON    pd.transid = r.transid
                        AND pd.RefNo = r.refno
             WHERE pd.statusid NOT IN (102)
			 */
        END --@doing = 'REFUND'
    
        -- ===================================================
        IF @doing = 'REFUND-FT'
        BEGIN
			SET @FunctionName = 'RefundSubParlay'

			UPDATE	bm
				SET 
					@IsUpd_Void = CASE WHEN statusID = 102 THEN 0 ELSE 1 END
					,winlostdate = CASE 
									WHEN @IsUpd_Void = 0 THEN winlostdate 
									ELSE @matchdate
								END
								
					,[status] = CASE 
									WHEN @IsUpd_Void = 0 THEN [status] 
									ELSE 'Refund'
								END
					,statuswinlost =  6
					,ruben = 1
					,statusID = CASE 
									WHEN @IsUpd_Void = 0 THEN statusID 
									ELSE 103
								END								
            OUTPUT INSERTED.transid, INSERTED.refno, inserted.status, inserted.statusID, inserted.ruben, inserted.statuswinlost, inserted.winlostdate
			INTO @tmpOutputBettransm(transid, refno, status, StatusId, ruben, statuswinlost, winlostdate)
            FROM	@tblBettypes t
				INNER JOIN dbo.bettransm bm WITH(ROWLOCK, UPDLOCK)
					ON bm.bettype = t.bettype
            WHERE	matchid = @matchid 
					AND bm.SiteDBGroupID = CASE WHEN @IsSiteDB = 1 THEN bm.SiteDBGroupID ELSE 0 END
					AND t.groupId NOT IN (1,3,5,8)
					AND statusID NOT IN (101)
				
            -- update by batch for betparlaydetail
			SET @MaxRow = (SELECT MAX(ID) FROM @tmpOutputBettransm)
			IF @Threshold >= @MaxRow
				SET @Threshold = @MaxRow
			-- SET for first batch
			SELECT @StartRow = 1, @StopRow = @Threshold
			WHILE (1 = 1)
			BEGIN
					UPDATE pd
						SET winlostdate = @matchdate
							,statuswinlost = 0
							,statusID = 103
						OUTPUT inserted.transid, inserted.winlostdate, inserted.statuswinlost, inserted.statusid
						INTO @tmpOutputBetParlayDetail(transid, winlostdate, statuswinlost, StatusId)
						FROM dbo.BetParlayDetail pd WITH(ROWLOCK,UPDLOCK)
							INNER JOIN @tmpOutputBettransm r
								ON    pd.transid = r.transid
									AND pd.RefNo = r.refno
						WHERE pd.statusid NOT IN (102)
								AND ID BETWEEN @StartRow AND @StopRow

					IF @StopRow = @MaxRow BREAK

					SET @StartRow = @StopRow + 1
					SET @StopRow = @StopRow + @Threshold

					IF @StopRow >= @MaxRow
						SET @StopRow = @MaxRow
			END
		   /*
		   UPDATE pd
            SET winlostdate = @matchdate
                ,statuswinlost = 0
                ,statusID = 103
			OUTPUT inserted.transid, inserted.winlostdate, inserted.statuswinlost, inserted.statusid
			INTO @tmpOutputBetParlayDetail(transid, winlostdate, statuswinlost, StatusId)
            FROM dbo.BetParlayDetail pd WITH(TABLOCK)
                INNER JOIN @tmpOutputBettransm r
                    ON    pd.transid = r.transid
                        AND pd.RefNo = r.refno
            WHERE pd.statusid NOT IN (102)
			*/
        END --@doing = 'REFUND-FT'

        IF @doing = 'REFUND-HT'
        BEGIN
			SET @FunctionName = 'RefundSubParlay'

            -- Refund sub tickets of 11 bet types (FT) from BetRadar in case '30x3' match has been suspended
            UPDATE	bm
				SET 
					@IsUpd_Void = CASE WHEN statusID = 102 THEN 0 ELSE 1 END
					,winlostdate = CASE 
									WHEN @IsUpd_Void = 0 THEN winlostdate 
									ELSE @matchdate
								END
								
					,[status] = CASE 
									WHEN @IsUpd_Void = 0 THEN [status] 
									ELSE 'Refund'
								END
					,statuswinlost =  6
					,ruben = 1
					,statusID = CASE 
									WHEN @IsUpd_Void = 0 THEN statusID 
									ELSE 103
								END								
            OUTPUT INSERTED.transid, INSERTED.refno, inserted.status, inserted.statusID, inserted.ruben, inserted.statuswinlost, inserted.winlostdate
			INTO @tmpOutputBettransm(transid, refno, status, StatusId, ruben, statuswinlost, winlostdate)
            FROM	@tblBettypes t
				INNER JOIN dbo.bettransm bm WITH(ROWLOCK, UPDLOCK)
					ON	bm.bettype = t.bettype
            WHERE	matchid = @matchid 
					AND bm.SiteDBGroupID = CASE WHEN @IsSiteDB = 1 THEN bm.SiteDBGroupID ELSE 0 END
					AND t.is3x30 = 1
					AND statusID NOT IN (101)
			OPTION (FORCE ORDER)
			
			-- update by batch for betparlaydetail
			SET @MaxRow = (SELECT MAX(ID) FROM @tmpOutputBettransm)
			IF @Threshold >= @MaxRow
				SET @Threshold = @MaxRow
			-- SET for first batch
			SELECT @StartRow = 1, @StopRow = @Threshold
			WHILE (1 = 1)
			BEGIN
					UPDATE pd
						SET winlostdate = @matchdate
							,statuswinlost = 0
							,statusID = 103
					OUTPUT inserted.transid, inserted.winlostdate, inserted.statuswinlost, inserted.statusid
					INTO @tmpOutputBetParlayDetail(transid, winlostdate, statuswinlost, StatusId)
					FROM dbo.BetParlayDetail pd WITH(ROWLOCK,UPDLOCK)
						INNER JOIN @tmpOutputBettransm r
							ON    pd.transid = r.transid
								AND pd.RefNo = r.refno
					WHERE pd.statusid NOT IN (102) 
							AND ID BETWEEN @StartRow AND @StopRow

					IF @StopRow = @MaxRow BREAK

					SET @StartRow = @StopRow + 1
					SET @StopRow = @StopRow + @Threshold

					IF @StopRow >= @MaxRow
						SET @StopRow = @MaxRow
			END
			/*
            UPDATE pd
				SET winlostdate = @matchdate
					,statuswinlost = 0
					,statusID = 103
			OUTPUT inserted.transid, inserted.winlostdate, inserted.statuswinlost, inserted.statusid
			INTO @tmpOutputBetParlayDetail(transid, winlostdate, statuswinlost, StatusId)
            FROM dbo.BetParlayDetail pd WITH(TABLOCK)
                INNER JOIN @tmpOutputBettransm r
                    ON    pd.transid = r.transid
                        AND pd.RefNo = r.refno
            WHERE pd.statusid NOT IN (102) 
			*/
        END -- @doing = 'REFUND-HT'
    
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
                ,winlostdate = @matchdate
			OUTPUT INSERTED.transid, inserted.winlost, inserted.ruben, inserted.status, inserted.creator, inserted.statusID, inserted.winlostdate
			INTO @tmpOutputBettransmVoidRecover(transid, winlost, ruben, status, creator, statusId, winlostdate)
            WHERE matchid = @matchid 
                AND statusID NOT IN (101, 102) 
                AND transid IN (SELECT transid FROM @tmpTransIdsVoidRecover)

            UPDATE dbo.BetParlayDetail WITH(ROWLOCK,UPDLOCK)
            SET statuswinlost = 0
                ,statusID = 102
                ,winlostdate = @matchdate
			OUTPUT inserted.transid, inserted.statuswinlost, inserted.statusid, inserted.winlostdate
			INTO @tmpOutputBetParlayDetail(transid, statuswinlost, StatusId, winlostdate)
            WHERE matchid = @matchid 
                AND statusID NOT IN (101, 102) 
                AND transid IN (SELECT transid FROM @tmpTransIdsVoidRecover)
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
			OUTPUT INSERTED.transid, inserted.winlost, inserted.ruben
					, Inserted.Statuswinlost
					, inserted.status, inserted.statusID, inserted.winlostdate
			INTO @tmpOutputBettransmVoidRecover(transid, winlost, ruben, statuswinlost, status, statusid, winlostdate)
            WHERE    matchid = @matchid
                    AND statusID = 102
                    AND transid IN (SELECT transid FROM @tmpTransIdsVoidRecover)                
        
            UPDATE    dbo.BetParlayDetail WITH(ROWLOCK,UPDLOCK)
                SET winlostdate = NULL
                    ,statuswinlost = NULL
                    ,statusid = 0
			OUTPUT inserted.transid, inserted.winlostdate, inserted.statuswinlost, inserted.statusid
			INTO @tmpOutputBetParlayDetail(transid, winlostdate, statuswinlost, StatusId)
            WHERE    matchid = @matchid 
                    AND statusID = 102
                    AND transid IN (SELECT transid FROM @tmpTransIdsVoidRecover)
        END --@doing = 'RECOVER'

        -- ===================================================        
        IF @doing = 'UNDO'
        BEGIN            
           SET @FunctionName = 'UndoSubParlay'

            UPDATE bm WITH(ROWLOCK, UPDLOCK)
            SET 
				@IsUpd_Void = CASE WHEN statusID = 102 THEN 0 ELSE 1 END
				,[status] = CASE WHEN @IsUpd_Void = 0 THEN [status] ELSE 'running' END
                ,statuswinlost = NULL
                ,ruben = CASE WHEN @IsUpd_Void = 0 THEN ruben ELSE 0 END
                ,statusID = CASE WHEN @IsUpd_Void = 0 THEN statusID ELSE 0 END
            OUTPUT INSERTED.transid, INSERTED.refno, inserted.status, inserted.statusID, inserted.ruben
					,Inserted.Statuswinlost
			INTO @tmpOutputBettransm(transid, refno, status, statusid, ruben, statuswinlost)
            FROM    @tblBettypes t
				INNER LOOP JOIN dbo.bettransm bm
					ON	bm.bettype = t.bettype
				CROSS APPLY (
					SELECT CAST(CAST(bm.bettype AS VARCHAR) + ISNULL(SUBSTRING(bm.betcheck, 2, LEN(bm.betcheck)),'') AS VARCHAR(20)) AS ResourceId
				)r
            WHERE matchid = @matchid  
				AND bm.SiteDBGroupID = CASE WHEN @IsSiteDB = 1 THEN bm.SiteDBGroupID ELSE 0 END
                AND statusID NOT IN (101, 1)
				AND t.groupId <> 8 -- Early Soccer
			OPTION (FORCE ORDER)			
			
			-- update by batch for betparlaydetail
			SET @MaxRow = (SELECT MAX(ID) FROM @tmpOutputBettransm)
			IF @Threshold >= @MaxRow
				SET @Threshold = @MaxRow
			-- SET for first batch
			SELECT @StartRow = 1, @StopRow = @Threshold
			WHILE (1 = 1)
			BEGIN
					UPDATE pd
						SET statuswinlost = NULL 
							,statusID = 0
						OUTPUT inserted.transid, inserted.statuswinlost , inserted.statusid
						INTO @tmpOutputBetParlayDetail(transid, statuswinlost, StatusId)
						FROM dbo.BetParlayDetail pd WITH(ROWLOCK,UPDLOCK)
							INNER JOIN @tmpOutputBettransm r
								ON    pd.transid = r.transid
									AND pd.RefNo = r.refno 
						WHERE pd.statusid NOT IN (102) 
							AND ID BETWEEN @StartRow AND @StopRow

					IF @StopRow = @MaxRow BREAK

					SET @StartRow = @StopRow + 1
					SET @StopRow = @StopRow + @Threshold

					IF @StopRow >= @MaxRow
						SET @StopRow = @MaxRow
			END
			/*
            UPDATE pd
            SET statuswinlost = NULL 
                ,statusID = 0
			OUTPUT inserted.transid, inserted.statuswinlost , inserted.statusid
			INTO @tmpOutputBetParlayDetail(transid, statuswinlost, StatusId)
            FROM dbo.BetParlayDetail pd WITH(TABLOCK)
                INNER JOIN @tmpOutputBettransm r
                    ON    pd.transid = r.transid
                        AND pd.RefNo = r.refno 
            WHERE pd.statusid NOT IN (102) 
			*/
        END --@doing = 'UNDO'
        -- ===================================================
        
        IF @doing = 'CAL'
        BEGIN
			SET @FunctionName = 'CalSubParlay'

            DECLARE @csHTFT NVARCHAR(10) -- HT/FT correct score
    
            SELECT @csHTFT = CASE WHEN @hth + @hta >= 4 THEN '4+' 
                                ELSE CAST(@hth AS nvarchar(10)) + ':' + CAST(@hta AS nvarchar(10))
                                END 
                        + '/'
                        + CASE WHEN @fth + @fta >=4 THEN '4+'
                                ELSE CAST(@fth AS nvarchar(10)) + ':' + CAST(@fta AS nvarchar(10))
                                END
            DECLARE		@FirstGoal		NVARCHAR(50) 
						,@FirstGoal1H	VARCHAR(1)
						,@FirstGoal2H	VARCHAR(1)
						,@LastGoal		VARCHAR(1)
						,@LastGoal1H	VARCHAR(1)

						,@Char			VARCHAR(1)
						,@Position		TINYINT
						,@HomeRaceTo	TINYINT
						,@AwayRaceTo	TINYINT
						,@NeitherRaceTo TINYINT
						,@NeitherRaceTo1H TINYINT
						,@LenGoalSequence TINYINT
						,@ResultCornerRace VARCHAR(200)
						,@ResultCornerRace1H VARCHAR(200)
						,@RemovedSemicolonResultString NVARCHAR(50)
						,@ResultAOS NVARCHAR(10)

            SELECT  @GoalSequence = ISNULL(@GoalSequence, '')
					,@FirstGoal=''
					,@FirstGoal1H = ''
					,@FirstGoal2H = ''
					,@LastGoal = ''
					,@LastGoal1H = ''
					,@ResultCornerRace = ''
					,@ResultCornerRace1H = ''

					-- for bettype 486 Corner Race, 487 1H Corner Race
					,@Position = 1
					,@HomeRaceTo = 0
					,@AwayRaceTo = 0
					,@RemovedSemicolonResultString = REPLACE(ISNULL(@goalsequenceFT, ''),';','') 
					,@ResultAOS = ''

            SELECT   @FirstGoal = LEFT(REPLACE(@GoalSequence,';',''),1) --172  --@GoalSequence = GoalRecord 
					,@FirstGoal1H = LEFT(@goalsequenceHT,1)
					,@FirstGoal2h = CASE 
								WHEN CHARINDEX(';', @goalsequenceFT) > 0 THEN SUBSTRING(@goalsequenceFT, CHARINDEX(';', @goalsequenceFT)+1,1) 
								ELSE LEFT(@goalsequenceFT,1) 
							END
					,@LastGoal = RIGHT(REPLACE(@goalsequenceFT,';',''),1)
					,@LastGoal1H =RIGHT(@goalsequenceHT,1)

			-- 486 Corner Race
			BEGIN
				SELECT @LenGoalSequence = LEN(@goalsequenceFT)
			
				WHILE (@Position <= @LenGoalSequence)
				BEGIN
					SET @Char = SUBSTRING(@goalsequenceFT, @Position, 1)
	
					IF @Char = 'H'	
					BEGIN
						SET @HomeRaceTo = @HomeRaceTo + 1

						IF @HomeRaceTo > @AwayRaceTo
							SET  @ResultCornerRace = @ResultCornerRace + CAST(@HomeRaceTo AS VARCHAR) + @Char + ';'
					END
					ELSE IF @Char = 'A' 
					BEGIN
						SET @AwayRaceTo = @AwayRaceTo + 1

						IF @AwayRaceTo > @HomeRaceTo
							SET  @ResultCornerRace = @ResultCornerRace + CAST(@AwayRaceTo AS VARCHAR) + @Char + ';'
					END

					SET @Position = @Position + 1	 	
				END

				SET @NeitherRaceTo = CASE WHEN @HomeRaceTo > @AwayRaceTo THEN @HomeRaceTo ELSE @AwayRaceTo END + 1
			END

			-- 487 1H Corner Race
			BEGIN
				SELECT	@LenGoalSequence = 0
						,@HomeRaceTo = 0
						,@AwayRaceTo = 0
						,@Position = 1
						
				SELECT @LenGoalSequence = LEN(@goalsequenceHT)
			
				WHILE (@Position <= @LenGoalSequence)
				BEGIN
					SET @Char = SUBSTRING(@goalsequenceHT, @Position, 1)
	
					IF @Char = 'H'	
					BEGIN
						SET @HomeRaceTo = @HomeRaceTo + 1

						IF @HomeRaceTo > @AwayRaceTo
							SET  @ResultCornerRace1H = @ResultCornerRace1H + CAST(@HomeRaceTo AS VARCHAR) + @Char + ';'
					END
					ELSE IF @Char = 'A' 
					BEGIN
						SET @AwayRaceTo = @AwayRaceTo + 1

						IF @AwayRaceTo > @HomeRaceTo
							SET  @ResultCornerRace1H = @ResultCornerRace1H + CAST(@AwayRaceTo AS VARCHAR) + @Char + ';'
					END

					SET @Position = @Position + 1	 	
				END

				SET @NeitherRaceTo1H = CASE WHEN @HomeRaceTo > @AwayRaceTo THEN @HomeRaceTo ELSE @AwayRaceTo END + 1
			END

			-- 493 HT/FT Total Corners
			BEGIN
				SELECT @ResultAOS = CASE WHEN (@hth + @hta) = 0 AND (@fth + @fta) >= 8 THEN '0/8+'
												WHEN (@hth + @hta) = 1 AND (@fth + @fta) >= 9 THEN '1/9+'  
												WHEN (@hth + @hta) = 2 AND (@fth + @fta) >= 10 THEN '2/10+'
												WHEN (@hth + @hta) = 3 AND (@fth + @fta) >= 11 THEN '3/11+'
												WHEN (@hth + @hta) = 4 AND (@fth + @fta) >= 12 THEN '4/12+'
												WHEN (@hth + @hta) = 5 AND (@fth + @fta) >= 13 THEN '5/13+'
												WHEN (@hth + @hta) = 6 AND (@fth + @fta) >= 14 THEN '6/14+'
												WHEN (@hth + @hta) IN (7,8,9) AND (@fth + @fta) >= 15 THEN CAST((@hth + @hta) AS VARCHAR(5)) + '/15+'
												ELSE CAST((@hth + @hta) AS VARCHAR(5)) + '/' + CAST((@fth + @fta) AS VARCHAR(5))
									END
							
			END
            
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
				,ismarked		BIT
            )
			
			DECLARE @tmptransid TABLE (
				transid			BIGINT
				,refno			BIGINT
				,modds			MONEY
				,ismarked		BIT
			)
						
			INSERT INTO #Result(
				transid
				,refno
				,modds
			)
			SELECT	transId
                    ,refno
					,CASE bm.bettype
                        WHEN 1 THEN -- Handicap
                            CASE betteam
								WHEN N'h' THEN (hdp2 - hdp1) + (@fth - @fta) - CASE 
																					WHEN @Sporttype IN (4,26) AND bm.transdate >= @CutOffDate THEN 0
																					WHEN (@Sporttype BETWEEN 2 AND 56 AND @Sporttype NOT IN (4,26,28,43,49,51))
																						OR @Sporttype = 99 THEN 0 
																					ELSE (livehomescore - liveawayscore) 
																				END																
								WHEN N'a' THEN (hdp1 - hdp2) - (@fth - @fta) + CASE 
																					WHEN @Sporttype IN (4,26) AND bm.transdate >= @CutOffDate THEN 0
																					WHEN (@Sporttype BETWEEN 2 AND 56 AND @Sporttype NOT IN (4,26,28,43,49,51))
																						OR @Sporttype = 99 THEN 0 
																					ELSE (livehomescore - liveawayscore) 
																				END
                                END
                        WHEN 7 THEN -- 1st Handicap
                            CASE betteam
								WHEN N'h' THEN (hdp2 - hdp1) + (@hth - @hta) - CASE 
																					WHEN @Sporttype IN (4,26) AND bm.transdate >= @CutOffDate THEN 0
																					WHEN (@Sporttype BETWEEN 2 AND 56 AND @Sporttype NOT IN (4,26,28,43,49,51))
																						OR @Sporttype = 99 THEN 0 
																					ELSE (livehomescore - liveawayscore) 
																				END	
								WHEN N'a' THEN (hdp1 - hdp2) - (@hth - @hta) + CASE 
																					WHEN @Sporttype IN (4,26) AND bm.transdate >= @CutOffDate THEN 0
																					WHEN (@Sporttype BETWEEN 2 AND 56 AND @Sporttype NOT IN (4,26,28,43,49,51))
																						OR @Sporttype = 99 THEN 0 
																					ELSE (livehomescore - liveawayscore) 
																				END
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
						--STARTING for new bettype for PHAIO 3
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

						--Start #115232
						-- 470: Corners Odd/Even (own)
						WHEN 470 THEN 
									CASE WHEN betteam =N'o' AND ((@fth + @fta) % 2) = 1 THEN 1 
											WHEN betteam =N'e' AND ((@fth + @fta) % 2) = 0 THEN 1 
											ELSE - 1 
										END

						-- 471: 1H Corners Odd/Even (own)
						WHEN 471 THEN 
									CASE WHEN betteam =N'o' AND ((@hth + @hta) % 2) = 1 THEN 1 
											WHEN betteam =N'e' AND ((@hth + @hta) % 2) = 0 THEN 1 
											ELSE - 1 
										END

						-- 472: 2H Corners Odd/Even
						WHEN 472 THEN 
									CASE WHEN betteam =N'o' AND ((@fth + @fta - @hth - @hta) % 2) = 1 THEN 1 
											WHEN betteam =N'e' AND ((@fth + @fta - @hth - @hta) % 2) = 0 THEN 1 
											ELSE - 1 
										END 
						-- Total Corners
						WHEN 473 THEN 
									CASE WHEN betteam = '0-5' and @totalgoal <= 5 THEN 1
										WHEN betteam = '6-8' and @totalgoal in (6,7,8) THEN 1
										WHEN betteam = '9-11' and @totalgoal in (9,10,11) THEN 1
										WHEN betteam = '12-14' and @totalgoal in (12,13,14) THEN 1
										WHEN betteam = '15+' and @totalgoal >= 15 THEN 1
										ELSE -1 
									END
						-- 1H Total Corners
						WHEN 474 THEN 
									CASE WHEN betteam = '0-2' and @totalht <= 2 THEN 1
										WHEN betteam = '3-4' and @totalht in (3,4) THEN 1
										WHEN betteam = '5-6' and @totalht in (5,6) THEN 1
										WHEN betteam = '7+' and @totalht >= 7 THEN 1
										ELSE -1 
									END
						-- Alternative Corners
						WHEN 475 THEN 
									CASE WHEN betteam = 'o' AND @totalgoal > hdp1 THEN 1
											WHEN betteam = 'u' AND @totalgoal < hdp1 THEN 1
											WHEN betteam = 'e' AND @totalgoal = hdp1 THEN 1
											ELSE -1
										END
						-- 1H Alternative Corners
						WHEN 476 THEN 
							CASE WHEN betteam = 'o' AND @totalht > hdp1 THEN 1
								WHEN betteam = 'u' AND @totalht < hdp1 THEN 1
								WHEN betteam = 'e' AND @totalht = hdp1 THEN 1
								ELSE -1
							END
						-- Corner 3-way handicap
						WHEN 477 THEN 
							CASE 
								WHEN betteam = '1' AND (hdp2 - hdp1 + @fth - @fta) > 0 THEN 1
								WHEN betteam = '2' AND (hdp1 - hdp2 + @fta - @fth) > 0 THEN 1
								WHEN betteam = 'x' AND ((hdp1 - hdp2) - (@fth - @fta)) = 0 THEN 1
								ELSE -1
								END
						-- 478: 1H Corners 3-Way Handicap
						WHEN 478 THEN 
									CASE
										WHEN betteam = '1' AND ((@hth - hdp1) - (@hta - hdp2)) > 0  THEN 1
										WHEN betteam = '2' AND ((@hth - hdp1) - (@hta - hdp2)) < 0  THEN 1
										WHEN betteam = 'x' AND ((@hth - hdp1) - (@hta - hdp2)) = 0  THEN 1
										ELSE -1
									END
						-- 482: Home Team Corners Over/Under
						WHEN 482 THEN 
                            CASE
                                WHEN betteam = 'o' THEN @fth - hdp1
                                WHEN betteam = 'u' THEN hdp1 - @fth
                                ELSE -1 
							END
						-- 483: Away Team Corners Over/Under
						WHEN 483 THEN 
                            CASE
                                WHEN betteam = 'o' THEN @fta - hdp1
                                WHEN betteam = 'u' THEN hdp1 - @fta
                                ELSE -1 
							END
						-- 484: 1H Home Team Corners Over/Under
						WHEN 484 THEN 
                            CASE
                                WHEN betteam = 'o' THEN @hth - hdp1
                                WHEN betteam = 'u' THEN hdp1 - @hth
                                ELSE -1 
							END
						-- 485: 1H Away Team Corners Over/Under
						WHEN 485 THEN 
                            CASE
                                WHEN betteam = 'o' THEN @hta - hdp1
                                WHEN betteam = 'u' THEN hdp1 - @hta
                                ELSE -1 
							END
						-- Corners Race
						WHEN 486 THEN CASE 
										WHEN CHARINDEX(';' + CAST(CAST(hdp1 AS INT) AS VARCHAR) + betteam + ';', ';' + @ResultCornerRace) > 0 THEN 1
										WHEN betteam = 'N' AND @NeitherRaceTo <= hdp1 THEN 1
										ELSE -1
									END
						-- 1H Corners Race
						WHEN 487 THEN CASE 
										WHEN CHARINDEX(';' + CAST(CAST(hdp1 AS INT) AS VARCHAR) + betteam + ';', ';' + @ResultCornerRace1H) > 0 THEN 1
										WHEN betteam = 'N' AND @NeitherRaceTo1H <= hdp1 THEN 1
										ELSE -1
									END
						-- First Corner
						WHEN 488 THEN CASE
										WHEN bm.betteam = @FirstGoal THEN 1
										WHEN @FirstGoal = '' THEN 0
										ELSE -1
									END
						-- 1H First Corner
						WHEN 489 THEN CASE
										WHEN bm.betteam = @FirstGoal1H THEN 1
										WHEN @FirstGoal1H = '' THEN 0
										ELSE -1
									END
						-- 2H First Corner
						WHEN 490 THEN CASE
										WHEN bm.betteam = @FirstGoal2H  THEN 1
										WHEN @FirstGoal2H = '' THEN 0
										ELSE -1
									END
						-- Last Corner
						WHEN 491 THEN CASE
										WHEN bm.betteam = @LastGoal THEN 1
										WHEN @LastGoal = '' THEN 0
										ELSE -1
									END
						-- 1H Last Corner
						WHEN 492 THEN CASE
										WHEN bm.betteam = @LastGoal1H THEN 1
										WHEN @LastGoal1H = '' THEN 0
										ELSE -1
									END
						-- HT/FT Total Corners
						WHEN 493 THEN CASE WHEN 
											(
												CASE WHEN betteam = 'AOS' THEN
																			CASE WHEN CHARINDEX(@ResultAOS, transdesc) = 0 THEN 'AOS' ELSE '' END
													ELSE @ResultAOS
												END) = betteam THEN 1 
										ELSE -1
									END
						-- 1H Correct Corners
						WHEN 494 THEN CASE WHEN 
											(
											CASE 
												WHEN betteam = 'AOS' THEN 
																		CASE WHEN CHARINDEX(CAST(@hth AS VARCHAR(5)) + '-' + CAST(@hta AS VARCHAR(5)), transdesc) = 0 THEN 'AOS' ELSE '' END
												ELSE CAST(@hth AS VARCHAR(5)) + '-' + CAST(@hta AS VARCHAR(5))
											END) = betteam THEN 1 
											ELSE -1
										END
						-- 2H Correct Corners
						WHEN 495 THEN CASE WHEN 
											(
											CASE 
												WHEN betteam = 'AOS' THEN 
																		CASE WHEN CHARINDEX(CAST((@fth - @hth) AS VARCHAR(5)) + '-' + CAST((@fta - @hta) AS VARCHAR(5)), transdesc) = 0 THEN 'AOS' ELSE '' END
												ELSE CAST((@fth - @hth) AS VARCHAR(5)) + '-' + CAST((@fta - @hta) AS VARCHAR(5))
											END) = betteam THEN 1 
											ELSE -1
										END
						-- 496: Corner Highest Scoring Half
						WHEN 496 THEN 
										CASE 
										WHEN betteam = '1h' AND (@hth + @hta) > (@fth - @hth + @fta - @hta) THEN 1
										WHEN betteam = 'tie' AND (@hth + @hta) = (@fth - @hth + @fta - @hta) THEN 1
										WHEN betteam = '2h' AND (@hth + @hta) < (@fth - @hth + @fta - @hta) THEN 1
										ELSE -1
										END
						-- 497: Corner Highest Scoring Half (2-Way)
						WHEN 497 THEN 
										CASE 
										WHEN betteam = '1h' AND (@hth + @hta) > (@fth - @hth + @fta - @hta) THEN 1
										WHEN betteam IN ('1h','2h') AND (@hth + @hta) = (@fth - @hth + @fta - @hta) THEN 0
										WHEN betteam = '2h' AND (@hth + @hta) < (@fth - @hth + @fta - @hta) THEN 1
										ELSE -1
										END
						WHEN 22 
							THEN CASE
									WHEN betteam = '1' AND SUBSTRING(@RemovedSemicolonResultString, CAST(RIGHT(betcheck,2) AS INT),1) = 'H' THEN 1
									WHEN betteam = '2' AND SUBSTRING(@RemovedSemicolonResultString, CAST(RIGHT(betcheck,2) AS INT),1) = 'A' THEN 1
									WHEN betteam = 'X' AND SUBSTRING(@RemovedSemicolonResultString, CAST(RIGHT(betcheck,2) AS INT),1) = '' THEN 1
									ELSE -1
							END
						--End

						--Start: Incorporate PHAIO 5 [Redmine:#121681]

						-- 400: Extra Time Odd/Even
						WHEN 400 THEN 
									CASE WHEN betteam =N'o' AND ((@fth + @fta) % 2) = 1 THEN 1 
											WHEN betteam =N'e' AND ((@fth + @fta) % 2) = 0 THEN 1 
											ELSE -1 
										END

						-- 394: Penalty Shootout Odd/Even (Final Result)
						WHEN 394 THEN 
									CASE WHEN betteam =N'o' AND ((@fth + @fta) % 2) = 1 THEN 1 
											WHEN betteam =N'e' AND ((@fth + @fta) % 2) = 0 THEN 1 
											ELSE -1 
										END

						WHEN 398 THEN -- Extra Time Double Chance
									CASE 
										WHEN betteam = '1X' AND (@fth - @fta) >= 0 THEN 1
										WHEN betteam = '2X' AND (@fth - @fta) <= 0 THEN 1
										WHEN betteam = '12' AND (@fth - @fta) <> 0 THEN 1
										ELSE - 1
									END

						WHEN 399 THEN -- Extra Time Correct Score
									CASE 
										WHEN betteam = CAST(@fth AS VARCHAR(6)) + '-' + CAST(@fta AS VARCHAR(6)) THEN 1
										WHEN betteam = 'AOS' AND CHARINDEX(CAST(@fth AS VARCHAR(6)) + '-' + CAST(@fta AS VARCHAR(6)), transdesc) = 0 THEN 1
										ELSE -1
										END

						WHEN 397 THEN -- Extra Time Winning Margin    
                            CASE 
                                WHEN betteam = 'H1' AND (@fth - @fta) = 1 THEN 1
                                WHEN betteam = 'H2' AND (@fth - @fta) = 2 THEN 1 
                                WHEN betteam = 'H3+' AND (@fth - @fta) >= 3 THEN 1
                                WHEN betteam = 'D' AND (@fth - @fta) = 0 AND (@fth + @fta) <> 0 THEN 1
                                WHEN betteam = 'A1' AND (@fth - @fta) = -1 THEN 1 
                                WHEN betteam = 'A2' AND (@fth - @fta) = -2 THEN 1 
                                WHEN betteam = 'A3+' AND (@fth - @fta) <= -3 THEN 1 
                                WHEN betteam = 'NG' AND @fth = 0 AND @fta = 0 THEN 1
                                ELSE - 1
                                END

						WHEN 396 
							THEN CASE
									WHEN betteam = '1' AND SUBSTRING(@RemovedSemicolonResultString, CAST(RIGHT(betcheck,2) AS INT),1) = 'H' THEN 1
									WHEN betteam = '2' AND SUBSTRING(@RemovedSemicolonResultString, CAST(RIGHT(betcheck,2) AS INT),1) = 'A' THEN 1
									WHEN betteam = 'X' AND SUBSTRING(@RemovedSemicolonResultString, CAST(RIGHT(betcheck,2) AS INT),1) = '' THEN 1
									ELSE -1
							END

						WHEN 392 THEN -- Penalty Shootout Correct Score
									CASE 
										WHEN betteam = CAST(@fth AS VARCHAR(6)) + '-' + CAST(@fta AS VARCHAR(6)) THEN 1
										WHEN betteam IN ('HAOS') AND @fth > @fta AND CHARINDEX(CAST(@fth AS VARCHAR(6)) + '-' + CAST(@fta AS VARCHAR(6)), transdesc) = 0 THEN 1
										WHEN betteam IN ('AAOS') AND @fth < @fta AND CHARINDEX(CAST(@fth AS VARCHAR(6)) + '-' + CAST(@fta AS VARCHAR(6)), transdesc) = 0 THEN 1
										ELSE -1
										END

						WHEN 389 THEN -- Home Penalty Shootout Over/Under (Final Result)
                            CASE
                                WHEN betteam = 'o' THEN @fth - hdp1
                                WHEN betteam = 'u' THEN hdp1 - @fth
                                ELSE -1 END

						WHEN 388 THEN -- Away Penalty Shootout Over/Under (Final Result)
                            CASE
                                WHEN betteam = 'o' THEN @fta - hdp1
                                WHEN betteam = 'u' THEN hdp1 - @fta
                                ELSE -1 END
						--END: Incorporate PHAIO 5 [Redmine:#121681]

                        ELSE NULL -- Not support bettype
                        END AS modds
						
            FROM    @tblBettypes t
			INNER JOIN	dbo.bettransm bm WITH (NOLOCK)
				ON bm.bettype = t.bettype
			 CROSS APPLY (
					SELECT 
							CAST(CASE 
									WHEN bm.bettype = 416 THEN SUBSTRING(transdesc,0, CHARINDEX('/',transdesc)) 
									ELSE NULL 
								END AS NVARCHAR(1000)) AS ExcludingHTChoice
							,CAST(CASE 
									WHEN bm.bettype = 416 THEN SUBSTRING(transdesc,CHARINDEX('/',transdesc)+1,LEN(transdesc)) 
									ELSE NULL 
								END AS NVARCHAR(1000)) AS ExcludingFTChoice    
				) i
						
            WHERE   bm.matchid = @matchid
					AND bm.SiteDBGroupID = CASE WHEN @IsSiteDB = 1 THEN bm.SiteDBGroupID ELSE 0 END
					AND bm.statusID NOT IN (101)  
                   
			IF EXISTS (SELECT TOP 1 1 FROM dbo.MarkedTransaction mt WITH(NOLOCK) WHERE matchid = @matchid)
			BEGIN
				;WITH cteMarkedTrans
				AS(
					SELECT	b.refno
					FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
						INNER JOIN dbo.bettrans b WITH(NOLOCK)
							ON mt.TransId = b.transid
					WHERE	mt.MatchId = @matchid
							AND b.SiteDBGroupID = CASE WHEN @IsSiteDB = 1 THEN b.SiteDBGroupID ELSE 0 END
							AND b.matchid = 29
				)
				UPDATE r 
					SET ismarked = 1
				FROM	#Result r
					INNER JOIN cteMarkedTrans c
						ON r.refno = c.refno
			END

			WHILE (1 = 1)
			BEGIN				
				DELETE FROM	@tmptransid	
				DELETE FROM @tmpOutputBettransm
				DELETE FROM @tmpOutputBetParlayDetail
				
				DELETE TOP (2000 )
				FROM #Result
				OUTPUT deleted.transid, deleted.refno, deleted.modds, deleted.ismarked
				INTO @tmptransid (transid, refno, modds, ismarked)				
				
				IF @@ROWCOUNT = 0
					BREAK									
			
				UPDATE	bm WITH (ROWLOCK, UPDLOCK)
					SET 
						@IsUpd_Void = CASE WHEN bm.statusID = 102 OR t.ismarked = 1 THEN 0 ELSE 1 END
						,ruben = CASE 
									WHEN @IsUpd_Void = 0 THEN bm.ruben 
									ELSE CASE 
											WHEN t.modds IS NULL THEN 0 
											ELSE 1 
										END
								END
								
						,winlostdate = CASE 
											WHEN bm.statusID = 102 THEN bm.winlostdate 
											ELSE @matchdate
										END
								
						,[status] = CASE 
									WHEN @IsUpd_Void = 0 THEN bm.[status] 
									ELSE CASE 
											WHEN t.modds IS NULL THEN N'running'
											WHEN t.modds = 0 THEN N'DRAW'
											WHEN t.modds < 0 THEN N'LOSE'
											WHEN t.modds > 0 THEN N'WON'
										END
								END
								
						,statusID = CASE 
									WHEN @IsUpd_Void = 0 THEN bm.statusID 
									ELSE CASE 
											WHEN t.modds IS NULL THEN 0
											WHEN t.modds = 0 THEN 111
											WHEN t.modds < 0 THEN 113
											WHEN t.modds > 0 THEN 112
										END
								END
								
						,statuswinlost = CASE 
											WHEN t.modds <= - 0.5 THEN 4 -- LOSE
											WHEN t.modds >= 0.5 THEN 2 -- WIN
											WHEN t.modds > 0 THEN 1 -- Half WIN
											WHEN t.modds < 0 THEN 3 -- Half LOSE
											ELSE 0 -- DRAW
										END		
				OUTPUT INSERTED.transid, INSERTED.refno, inserted.status, inserted.statusID, inserted.ruben, inserted.statuswinlost, inserted.winlostdate
				INTO @tmpOutputBettransm(transid, refno, status, statusid, ruben, statuswinlost, winlostdate)
				FROM	dbo.bettransm bm 
					INNER JOIN @tmptransid t
						ON	bm.transid = t.transid
							AND bm.refno = t.refno
				
				UPDATE	pd 
					SET winlostdate = @matchdate
						,statusID = CASE 
									WHEN t.ismarked = 1 THEN pd.statusID 
									ELSE CASE 
											WHEN t.modds IS NULL THEN 0
											WHEN t.modds = 0 THEN 111
											WHEN t.modds < 0 THEN 113
											WHEN t.modds > 0 THEN 112
										END
								END						
						,statuswinlost = CASE 
											WHEN t.modds <= - 0.5 THEN 4 -- LOSE
											WHEN t.modds >= 0.5 THEN 2 -- WIN
											WHEN t.modds > 0 THEN 1 -- Half WIN
											WHEN t.modds < 0 THEN 3 -- Half LOSE
											ELSE 0 -- DRAW
										END
				OUTPUT INSERTED.transid, inserted.statuswinlost, inserted.statusID, inserted.winlostdate
				INTO @tmpOutputBetParlayDetail(transid, statuswinlost, statusid, winlostdate)
				FROM    dbo.BetParlayDetail pd WITH(ROWLOCK, UPDLOCK)
					INNER JOIN @tmptransid t ON  pd.transid = t.transid
				WHERE pd.statusid NOT IN (102)	

				IF @IsSiteDB = 1
				BEGIN
					SET @transInfo = (
							SELECT	transId AS '@t'		
									,refno AS '@ref'
									,CASE WHEN statuswinlost IS NULL THEN '' ELSE CAST(statuswinlost AS VARCHAR(1) ) END AS '@statuswl'
									,Status AS '@s' 
									,StatusID AS '@sid' 
									,CASE WHEN winlostdate IS NULL THEN '' ELSE winlostdate END AS '@wld'
									,ruben AS '@r' -- ruben	
							FROM	@tmpOutputBettransm
							FOR XML PATH('r'),ROOT('root'), TYPE
						)

					INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo, SettlementAction, TicketType)
					SELECT	'Settlement', @FunctionName, 'bettransm', @MatchId, @transInfo
							,CASE 
								WHEN @doing LIKE 'REFUND%' THEN 'REFUND'
								WHEN @doing IN ('CAL', 'UNDO') THEN @doing
								ELSE ''
							END
							,'p'
					WHERE @transInfo IS NOT NULL
				
					SET @betparlaydetailinfo = (
						SELECT	DISTINCT transId AS '@t'						
								,CASE WHEN winlostdate IS NULL THEN '' ELSE winlostdate END  AS '@wld'							
								,CASE WHEN statuswinlost IS NULL THEN '' ELSE CAST(statuswinlost AS VARCHAR(1) ) END  AS '@statuswl'
								,StatusId AS '@sid'
						FROM	@tmpOutputBetParlayDetail
						FOR XML PATH('r'),ROOT('root'), TYPE
					)

					INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo, SettlementAction, TicketType)
					SELECT	'Settlement', @FunctionName, 'BetParlayDetail', @MatchId, @betparlaydetailinfo
							,CASE 
								WHEN @doing LIKE 'REFUND%' THEN 'REFUND'
								WHEN @doing IN ('CAL', 'UNDO') THEN @doing
							END
							,'p'
					WHERE	@betparlaydetailinfo IS NOT NULL
				END
			END                
        END --@doing = 'CAL'

		IF @IsSiteDB = 1 AND @doing <> 'CAL'
		BEGIN
			IF @doing IN ('VOID', 'RECOVER')
			BEGIN
				SET @transInfo = (
					SELECT	transId AS '@t'	
							,winlost AS '@w'
							,Status AS '@s' 
							,creator AS '@cr'
							,statusId AS '@sid' 
							,CASE WHEN @doing = 'RECOVER' AND winlostdate IS NULL THEN '' ELSE winlostdate END AS '@wld'
							,CASE WHEN @doing = 'RECOVER' AND statuswinlost IS NULL THEN '' ELSE CAST(statuswinlost AS VARCHAR(1) ) END AS '@statuswl'
							,ruben AS '@r' -- ruben
					FROM	@tmpOutputBettransmVoidRecover
					FOR XML PATH('r'),ROOT('root'), TYPE
				)
			END
			ELSE
			BEGIN
				SET @transInfo = (
					SELECT	transId AS '@t'		
							,refno AS '@ref'
							,CASE WHEN statuswinlost IS NULL THEN '' ELSE CAST(statuswinlost AS VARCHAR(1) ) END AS '@statuswl'
							,Status AS '@s' 
							,StatusID AS '@sid' 
							,CASE WHEN winlostdate IS NULL THEN '' ELSE winlostdate END AS '@wld'
							,ruben AS '@r' -- ruben	
					FROM	@tmpOutputBettransm
					FOR XML PATH('r'),ROOT('root'), TYPE
				)
			END

			INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo, SettlementAction, TicketType)
			SELECT	'Settlement', @FunctionName, 'bettransm', @MatchId, @transInfo
					,CASE 
						WHEN @doing LIKE 'REFUND%' THEN 'REFUND'
						WHEN @doing IN ('CAL', 'UNDO') THEN @doing
						ELSE ''
					END
					,'p'
			WHERE @transInfo IS NOT NULL
			
			-- process by batch to insert for sync server
			SET @MaxRow = (SELECT MAX(ID) FROM @tmpOutputBetParlayDetail)

			IF @Threshold >= @MaxRow
				SET @Threshold = @MaxRow

			-- SET for first batch
			SET @StopRow = @Threshold
			WHILE (1 = 1)
			BEGIN

					SET @betparlaydetailinfo = (
					SELECT	DISTINCT transId AS '@t'						
							,CASE WHEN winlostdate IS NULL THEN '' ELSE winlostdate END  AS '@wld'							
							,CASE WHEN statuswinlost IS NULL THEN '' ELSE CAST(statuswinlost AS VARCHAR(1) ) END  AS '@statuswl'
							,StatusId AS '@sid'
					FROM	@tmpOutputBetParlayDetail
					WHERE ID BETWEEN @StartRow AND @StopRow
					FOR XML PATH('r'),ROOT('root'), TYPE
				)

				INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo, SettlementAction, TicketType)
				SELECT	'Settlement', @FunctionName, 'BetParlayDetail', @MatchId, @betparlaydetailinfo
						,CASE 
							WHEN @doing LIKE 'REFUND%' THEN 'REFUND'
							WHEN @doing IN ('CAL', 'UNDO') THEN @doing
						END
						,'p'
				WHERE	@betparlaydetailinfo IS NOT NULL

				IF @StopRow = @MaxRow BREAK

				SET @StartRow = @StopRow + 1
				SET @StopRow = @StopRow + @Threshold

				IF @StopRow >= @MaxRow
					SET @StopRow = @MaxRow
			END
			/*
			SET @betparlaydetailinfo = (
				SELECT	DISTINCT transId AS '@t'						
						,CASE WHEN winlostdate IS NULL THEN '' ELSE winlostdate END  AS '@wld'							
						,CASE WHEN statuswinlost IS NULL THEN '' ELSE CAST(statuswinlost AS VARCHAR(1) ) END  AS '@statuswl'
						,StatusId AS '@sid'
				FROM	@tmpOutputBetParlayDetail
				FOR XML PATH('r'),ROOT('root'), TYPE
			)

			INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo, SettlementAction, TicketType)
			SELECT	'Settlement', @FunctionName, 'BetParlayDetail', @MatchId, @betparlaydetailinfo
					,CASE 
						WHEN @doing LIKE 'REFUND%' THEN 'REFUND'
						WHEN @doing IN ('CAL', 'UNDO') THEN @doing
					END
					,'p'
			WHERE	@betparlaydetailinfo IS NOT NULL
			*/
		END
    END -- while
END -- end SP
GO