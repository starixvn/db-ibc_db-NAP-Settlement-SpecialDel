/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet,Dot_Member" viewers="vnteam" isFunction="0"></info>*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_1] 
    @creator			INT
    ,@matchid			INT
    ,@fth            	SMALLINT        = NULL
    ,@fta            	SMALLINT        = NULL
    ,@hth            	SMALLINT
    ,@hta            	SMALLINT
    ,@goalrecord        VARCHAR(50)     = NULL
    ,@betstatus        	NVARCHAR(50)    = NULL 
    ,@SetResult        	VARCHAR(50)		= NULL 
    ,@GameResult1    	VARCHAR(MAX)    = NULL
    ,@GameResult2    	VARCHAR(MAX)    = NULL
    ,@GameResult3    	VARCHAR(MAX)    = NULL
    ,@GameResult4    	VARCHAR(MAX)    = NULL
    ,@GameResult5    	VARCHAR(MAX)    = NULL
    ,@SelectedSet    	VARCHAR(50)		= NULL 
    ,@SelectedSet1Game	VARCHAR(MAX)    = NULL 
    ,@SelectedSet2Game	VARCHAR(MAX)    = NULL 
    ,@SelectedSet3Game	VARCHAR(MAX)    = NULL 
    ,@SelectedSet4Game	VARCHAR(MAX)    = NULL 
    ,@SelectedSet5Game	VARCHAR(MAX)    = NULL 
    ,@fthCorners        SMALLINT        = NULL
    ,@ftaCorners        SMALLINT        = NULL
    ,@hthCorners        SMALLINT        = NULL
    ,@htaCorners        SMALLINT        = NULL  
    ,@ftFCorner        	VARCHAR(1)      = NULL
    ,@ftLCorner        	VARCHAR(1)      = NULL
    ,@htFCorner        	VARCHAR(1)      = NULL
    ,@htLCorner        	VARCHAR(1)      = NULL     
    
    ,@SelectedQuarter	VARCHAR(50)		= NULL
    ,@QuarterResult		VARCHAR(MAX)	= NULL
    
    ,@ResourceResult	VARCHAR(MAX)	= NULL
    
    ,@isExcludeCorner	BIT            	= 0 
    ,@action            VARCHAR(10)    	= 'CAL'
    ,@IP                VARCHAR(50)    	= ''
    ,@ErrCode			INT            	= 0		OUTPUT
    ,@ErrMsg            NVARCHAR(200)	= ''    OUTPUT
AS
/*    Creator: Kathy
    Date: 20140213
    Task: main SP for settlement
    DB: DBTXN/BODB02
    Original: Admin_Settlement_1
    
    Revisions:
        - 20140423@Kathy: Remove check weekend peak-hour
        - 20140426@Kathy: Add 1H Total Goal and 1H FGLG bettypes (126, 127) [Redmine:#14449]
        - 20140617@Kathy: Apply BetRadar [Redmine:#17142]
        - 20140710@Kathy: Apply BetRadar - PenaltyShootout(135) [Redmine:#17142]
        - 20140808@Kathy: Support new 11 bettypes [Redmine:#19667]
        - 20140909@Kathy: Exclude virtual racing (bettype 1231,1232,1233, 1237, 1238), outright (bettype 10, 31, 32, 33),
                         sportting solution (from 1301 -> 1334), keno (1501 -> 1599)
        - 20140910@Kathy: Update SettlementStatus135 = 4 if the match hasn't any PS ticket [Redmine:#21560]
        - 20141009@Jamie: Sporting Solution for Tennis [Redmine:#23034]
        - 20150406@Jamie: Manual Settlement Betradar phase 2 [Redmine: #27212]
        - 20150618@Jamie: Offer the option Exclude Corner tickets [Feature #38099]
        - 20150610@Johnson: Add bettrade [Redmine: #35921]
        - 20150715@Johnson: Exclude range bettype of Metric Gaming from settlement of SB [Redmine: #37688]
        - 20150806@Kathy: Using new balance table (BalCreditSportsPending,BalDebitSportsPending) [Redmine:#40125]
        - 20150918@Johnson: Check status of corner tickets when settle FT [Redmine: #43806]
        - 20150919@Kathy: Intergrate Myanmar Odds ( 4 new bettypes: 301->304)        
        - 20151126@Patrick: Apply 28 Live Bettypes for Settlement [Redmine:#47843]
        - 20151207@Patrick: Database - Change datatype [Redmine: #48660]
        - 20160120@Patrick: PH-AiO - Change request [Redmine: #51116]
        - 20160106@Kathy: - Integrate Cricket [Redmine:#49727]
                          - Capture balance incase of failure
        - 20160419@Kathy: change main SP to NAP_Admin_Settlement_MP [Redmine:#52426]
        - 20160705@Kathy: PH-AIO phase 2 (67 bettypes ) [Redmine:#53154]
        - 20160808@Kathy: BetTrade - changes for new commercial terms - add bettype 904 [Redmine:#61905]
        - 20160830@Kathy: PH-AIO phase 2b [Redmine:#62861]
		- 20160824@Bobby: #62921 - Include FGLG (14,127) bet types
		- 20160428@Kathy: Exclude Fast Market bettypes [Redmine:#56367]
		- 20170215@Kathy: Basketball All-in-One [Redmine:#71372]
		- 20170521@Kathy: Correct balance for Basketball [Redmine:#76931]
		- 20170522@Kathy: Correct balance for Tennis [Redmine:#76931]
		- 20170316@Bobby: Integrate CashOut bettypes [Redmine:#71355]
		- 20170609@Kathy: Remove some "early settlement" bettypes [Redmine:#77835]
		- 20170815@Kathy: Using table ResultDetail to store FGLG result instead of betstatus [Redmine:#81308]
		- 20171226@Kathy: Clear data in table AutoPayoutResult if match has been undo [Redmine:#86890]
		
    Param's Explanation:
        + @betstatus: Used for score table, FGLG status, refund status
        + @GameResult: Game result for Set(s) of Tennis Sport 
                + In case, the score clear, N-N 
                'A-40,30-40,15-40;N-N;N-N;N-N;N-N' : Only Set 1 key score 
        + @SelectedSet: The list of selected SET(s) for Settlement - Tennis 
            Sample: '1,2,3,4,5,6' : 6: Match option checked 

        + @SelectedGame: The list of Games with changed score 
                + '2,5,6'   
                
        + @SelectedQuarter: the list of selected quarter for settlement basketball
			'801,802,1H,803,804,2H,FT'
		+ @QuarterResult: the result of each quarter bettype
		
		+ @ResourceResult
					<Results>
						<Resource Id="" HomeValue="" SettlementStatusId="" ResultStatusId=""/>
					</Results>
 
*/
BEGIN
    SET NOCOUNT ON
    
    DECLARE @SkipBalanceUpdate          BIT
        ,@start                         DATETIME
        ,@stop                          DATETIME
        ,@avaiableProcess				BIT
        ,@goalrecord_old                VARCHAR(50)
        ,@LogData                       NVARCHAR(300)
        ,@eventstatus                   NVARCHAR(50)
        ,@sporttype                     SMALLINT
        ,@TicketCount                   INT    
        ,@betCount_1324                 INT        -- Set x Game y Winner - 1324
        ,@MaxGameSet1                	INT
        ,@MaxGameSet2                	INT
        ,@MaxGameSet3                	INT
        ,@MaxGameSet4                	INT
        ,@MaxGameSet5                	INT
        ,@Remark                        VARCHAR(500)
        ,@ActionID						INT
        ,@HomeValue						VARCHAR(20)
        ,@AwayValue						VARCHAR(20)
        ,@TotalAccount					INT
        ,@TotalAccount_BalanceUpdate    INT
        ,@HTDone                        BIT
        ,@FTDone                        BIT
        ,@isExistRunningCornerBet       BIT = 0
        ,@strAutoBettypes				VARCHAR(MAX)
        ,@strHTBettypes					VARCHAR(MAX)
        ,@strBettypes					VARCHAR(MAX)		
        
    CREATE TABLE #tmpTrans (transid BIGINT, refno BIGINT)--tickets of bettrade and refno for CashOut tickets
    DECLARE @status TABLE (FTBet BIT, BetCount INT, InRunning INT)
    
    CREATE TABLE #BalanceBefore (custid INT PRIMARY KEY, balance MONEY)
    CREATE TABLE #BalanceAfter (custid INT PRIMARY KEY, balance MONEY)    
    CREATE TABLE #Balance (custid INT PRIMARY KEY, balance MONEY, Increased BIT)
    CREATE INDEX IX_Balance_Increased ON #Balance (Increased)
    
    DECLARE @tblDebitPending TVP_BalanceList
    DECLARE @tblCreditPending TVP_BalanceList
    
    CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
    
    SELECT    @start                    = CURRENT_TIMESTAMP
            ,@SkipBalanceUpdate     = 0
            ,@TicketCount            = 0
            ,@MaxGameSet1            = 0
            ,@MaxGameSet2            = 0 
            ,@MaxGameSet3            = 0
            ,@MaxGameSet4            = 0
            ,@MaxGameSet5            = 0 
            ,@ActionID                = CASE @Action
											WHEN 'CAL' THEN 100
											WHEN 'CAL-FT' THEN 101
											WHEN 'CAL-HT' THEN 102
											WHEN 'UNDO'	THEN 103
                                        END

    SELECT  @sporttype        = m.sporttype
            ,@goalrecord_old    = ISNULL(m.goalrecord, '')
    FROM    dbo.match m WITH(NOLOCK)
    WHERE    m.matchid = @matchid

    SELECT  @HomeValue    = CAST(@fth AS VARCHAR(20))
            ,@AwayValue    = CAST(@fta AS VARCHAR(20)) 
            ,@SelectedQuarter = CASE WHEN @sporttype <> 2 THEN NULL ELSE @SelectedQuarter END
            ,@SelectedSet = CASE WHEN @sporttype <> 5 THEN NULL ELSE @SelectedSet END

    IF @@ROWCOUNT = 0
    BEGIN
        SELECT @ErrCode = 1001001
            ,@ErrMsg    = 'Match does not exist!'

        RETURN
    END

    -- check result of horse racing fixodds
    IF @action = 'CAL' AND @sporttype = 154 AND (@fth = 0 OR @fth IS NULL OR @fta = 0 OR @fta IS NULL)
    BEGIN
        SELECT @ErrCode = 1001002
            ,@ErrMsg    = 'Score is not valid.'

        RETURN
    END
    
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
		
    SELECT  @strAutoBettypes = COALESCE(@strAutoBettypes + ',' + CAST(bettype AS NVARCHAR), CAST(bettype AS NVARCHAR))
    FROM    dbo.f_Set_GetGroupBettypes() f 
    WHERE   f.IsAuto = 1   

    SELECT	@strHTBettypes = COALESCE(@strHTBettypes + ',' + CAST(bettype AS NVARCHAR), CAST(bettype AS NVARCHAR))
    FROM    dbo.f_Set_GetGroupBettypes() f 
	WHERE  	f.GroupId IN (1,3,5) -- include HT-FGLG groupId = 3
			AND f.IsAuto = 0
	
	SET @strBettypes = CAST((SELECT  BetType '@t'
								,GroupId '@g'
								,GroupName '@n'
						FROM	dbo.f_Set_GetGroupBettypes()			
						WHERE	IsAuto = 0
						FOR XML PATH ('r'), ROOT('root'), TYPE
							) AS VARCHAR(MAX))
	
    IF @Action = 'CAL-HT'
        SELECT    @TicketCount = COUNT(1)
        FROM    dbo.bettrans b WITH(NOLOCK)
        WHERE    b.matchid = @matchid
                AND 1 = CASE 
                            WHEN CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',', ',' + @strHTBettypes + ',') > 0 THEN 1
                            ELSE 0
                        END
    ELSE IF @Action = 'CAL-FT'
        SELECT    @TicketCount = COUNT(1)
        FROM    dbo.bettrans b WITH(NOLOCK)
        WHERE    b.matchid = @matchid
                AND 1 = CASE 
                            WHEN CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',', ',' + @strHTBettypes + ',') > 0 THEN 0
                            WHEN CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',', ',' + @strAutoBettypes + ',') > 0 THEN 0
                            ELSE 1
                        END
                AND b.bettype NOT BETWEEN 901 AND 910
                AND b.bettype NOT BETWEEN 801 AND 899
				AND b.bettype NOT BETWEEN 911 AND 920
    ELSE 
        SELECT    @TicketCount = COUNT(1)
        FROM    dbo.bettrans b WITH(NOLOCK)
			INNER JOIN dbo.f_Set_GetGroupBettypes() f
					ON b.bettype = f.BetType
        WHERE  	b.matchid = @matchid
				AND 1 = CASE -- Basketball
						WHEN @SelectedQuarter IS NULL THEN 1
						WHEN @SelectedQuarter LIKE '%' + f.GroupName + '%' THEN 1 -- 1H, 2H, FT
						WHEN f.GroupId = 10 AND @SelectedQuarter LIKE '%' + LEFT(CAST(b.betid AS VARCHAR),3) + '%' THEN 1 -- 801, 802, 803, 804
						ELSE 0
					END
				AND 1 = CASE -- tennis
							WHEN @SelectedSet IS NULL THEN 1
							WHEN @SelectedSet LIKE '%6%' AND b.bettype IN (1,2,3,20,153,1301,1302,1303,1305,1306,1308) THEN 1
							WHEN b.bettype IN (154,155,156,1311,1312,1316,1317,1318,1324) 
								THEN CASE 
										WHEN @SelectedSet LIKE '%1%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '801' THEN 1
										WHEN @SelectedSet LIKE '%2%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '802' THEN 1
										WHEN @SelectedSet LIKE '%3%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '803' THEN 1
										WHEN @SelectedSet LIKE '%4%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '804' THEN 1
										WHEN @SelectedSet LIKE '%5%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '805' THEN 1
									ELSE 0
								END
							ELSE 0
						END
				AND b.bettype <= 19000
                AND b.bettype NOT IN (10, 31, 32, 33, 1231, 1232, 1233, 1237, 1238) -- Outright, VSRacing
                AND b.bettype NOT BETWEEN 1501 AND 1599 -- Keno
                AND 1 = CASE 
                            WHEN CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',', ',' + @strAutoBettypes + ',') > 0 THEN 0
                            ELSE 1
                        END
                AND b.bettype NOT BETWEEN 901 AND 910
                AND b.bettype NOT BETWEEN 801 AND 899
				AND b.bettype NOT BETWEEN 911 AND 920
    
    SELECT    @MaxGameSet1 =   ISNULL(MAX(CASE WHEN b.bettype = 1324 AND LEFT(CAST(b.betID AS VARCHAR(20)),3) LIKE '801%' THEN (b.betID - 80100) ELSE 0 END),0)  --  Tennis - Set x Game y Winner
            ,@MaxGameSet2 =   ISNULL(MAX(CASE WHEN b.bettype = 1324 AND LEFT(CAST(b.betID AS VARCHAR(20)),3) LIKE '802%' THEN (b.betID - 80200) ELSE 0 END),0)
            ,@MaxGameSet3 =   ISNULL(MAX(CASE WHEN b.bettype = 1324 AND LEFT(CAST(b.betID AS VARCHAR(20)),3) LIKE '803%' THEN (b.betID - 80300) ELSE 0 END),0)
            ,@MaxGameSet4 =   ISNULL(MAX(CASE WHEN b.bettype = 1324 AND LEFT(CAST(b.betID AS VARCHAR(20)),3) LIKE '804%' THEN (b.betID - 80400) ELSE 0 END),0)
            ,@MaxGameSet5 =   ISNULL(MAX(CASE WHEN b.bettype = 1324 AND LEFT(CAST(b.betID AS VARCHAR(20)),3) LIKE '805%' THEN (b.betID - 80500) ELSE 0 END),0)
    FROM    dbo.bettrans b WITH (NOLOCK)
    WHERE    matchid = @matchid
            AND bettype = 1324

    IF @Sporttype = 5 
    BEGIN
        DECLARE     @MaxGameSet1Parlay        INT    = 0
                ,@MaxGameSet2Parlay        INT    = 0 
                ,@MaxGameSet3Parlay        INT    = 0 
                ,@MaxGameSet4Parlay        INT    = 0 
                ,@MaxGameSet5Parlay        INT    = 0 
        SELECT     @MaxGameSet1Parlay    =   ISNULL(MAX(CASE WHEN bm.betcheck LIKE '801%' THEN (CAST(bm.betcheck AS INT) - 80100) ELSE 0 END),0)  --  Tennis - Set x Game y Winner
                ,@MaxGameSet2Parlay    =   ISNULL(MAX(CASE WHEN bm.betcheck LIKE '802%' THEN (CAST(bm.betcheck AS INT) - 80200) ELSE 0 END),0)
                ,@MaxGameSet3Parlay    =   ISNULL(MAX(CASE WHEN bm.betcheck LIKE '803%' THEN (CAST(bm.betcheck AS INT) - 80300) ELSE 0 END),0)
                ,@MaxGameSet4Parlay    =   ISNULL(MAX(CASE WHEN bm.betcheck LIKE '804%' THEN (CAST(bm.betcheck AS INT) - 80400) ELSE 0 END),0)
                ,@MaxGameSet5Parlay    =   ISNULL(MAX(CASE WHEN bm.betcheck LIKE '805%' THEN (CAST(bm.betcheck AS INT) - 80500) ELSE 0 END),0)
        FROM    dbo.bettransm bm WITH(NOLOCK)
        WHERE    bettype = 1324        --Set x Game y - Tennis 
                AND matchID = @MatchID 

        SELECT     @MaxGameSet1 = CASE WHEN @MaxGameSet1 < @MaxGameSet1Parlay THEN @MaxGameSet1Parlay ELSE @MaxGameSet1 END 
                ,@MaxGameSet2 = CASE WHEN @MaxGameSet2 < @MaxGameSet2Parlay THEN @MaxGameSet2Parlay ELSE @MaxGameSet2 END
                ,@MaxGameSet3 = CASE WHEN @MaxGameSet3 < @MaxGameSet3Parlay THEN @MaxGameSet3Parlay ELSE @MaxGameSet3 END
                ,@MaxGameSet4 = CASE WHEN @MaxGameSet4 < @MaxGameSet4Parlay THEN @MaxGameSet4Parlay ELSE @MaxGameSet4 END
                ,@MaxGameSet5 = CASE WHEN @MaxGameSet5 < @MaxGameSet5Parlay THEN @MaxGameSet5Parlay ELSE @MaxGameSet5 END
    END

    -------------------------------------------------------------
    ---        CAPTURE value BALANCE before settlement        ---
    ---------------------------VVVV------------------------------
    IF @SkipBalanceUpdate = 0
    BEGIN
        IF @Action IN ('CAL', 'CAL-FT')
        BEGIN
            INSERT INTO #tmpTrans(transid)
            SELECT ISNULL(co.transid, b.transid) AS transid
            FROM dbo.bettrans b WITH(NOLOCK)
				LEFT JOIN dbo.bettrans co WITH(NOLOCK) 
				ON b.matchid = co.matchid 
					AND co.refno = b.transid 
					AND co.bettype = 911 --CashOut tickets
				
            WHERE    b.matchid = @matchid 
                    AND b.bettype NOT IN (10, 31, 32, 33, 1231, 1232, 1233, 1237, 1238) -- Outright, VSRacing
                    AND b.bettype NOT BETWEEN 1501 and 1599 -- Keno
                    AND b.betdaqid = 0--bettrade and cashout tickets
                    AND CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',', ',' + @strAutoBettypes + ',') = 0 --ignore auto bettypes

            INSERT INTO #BalanceBefore
            SELECT    b.custid
                    ,SUM(b.winlost - b.actual_stake + b.playercomm)
            FROM    dbo.bettrans b WITH (ROWLOCK)
				LEFT JOIN dbo.f_Set_GetGroupBettypes() f
					ON b.bettype = f.BetType
            WHERE    b.matchid = @matchid 
                    AND b.bettype NOT IN (10, 31, 32, 33, 1231, 1232, 1233, 1237, 1238) -- Outright, VSRacing
                    AND b.bettype NOT BETWEEN 1501 and 1599 -- Keno
                    AND b.bettype NOT BETWEEN 801 AND 899--Metric Gaming                    
                    AND 1 = CASE 
                                WHEN (b.bettype NOT BETWEEN 901 AND 920) THEN 1
								WHEN (b.bettype IN(904,914)) THEN 1 --BT & CashOut WL sharing
								WHEN (b.bettype BETWEEN 901 AND 904 AND b.refno IN (SELECT transid FROM #tmpTrans)) THEN 1 --BT transaction
								WHEN b.bettype BETWEEN 911 AND 914 THEN --CashOut transaction
									CASE
										WHEN b.bettype = 911 AND b.transid IN (SELECT transid FROM #tmpTrans) THEN 1
										WHEN b.bettype <> 911 AND b.refno IN (SELECT transid FROM #tmpTrans) THEN 1
										ELSE 0
									END
                                ELSE 0 
                            END
                    AND CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',', ',' + @strAutoBettypes + ',') = 0 --ignore auto bettypes
					AND 1 = CASE -- basketball
								WHEN @SelectedQuarter IS NULL THEN 1
								WHEN @SelectedQuarter LIKE '%' + f.GroupName + '%' THEN 1 -- 1H, 2H, FT
								WHEN f.GroupId = 10 AND @SelectedQuarter LIKE '%' + LEFT(CAST(b.betid AS VARCHAR),3) + '%' THEN 1 -- 801, 802, 803, 804
								ELSE 0
							END
					AND 1 = CASE -- tennis
								WHEN @SelectedSet IS NULL THEN 1
								WHEN @SelectedSet LIKE '%6%' AND b.bettype IN (1,2,3,20,153,1301,1302,1303,1305,1306,1308) THEN 1
								WHEN b.bettype IN (154,155,156,1311,1312,1316,1317,1318,1324) 
									THEN CASE 
											WHEN @SelectedSet LIKE '%1%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '801' THEN 1
											WHEN @SelectedSet LIKE '%2%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '802' THEN 1
											WHEN @SelectedSet LIKE '%3%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '803' THEN 1
											WHEN @SelectedSet LIKE '%4%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '804' THEN 1
											WHEN @SelectedSet LIKE '%5%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '805' THEN 1
										ELSE 0
									END
								ELSE 0
							END
            GROUP BY b.custid

            SET @TotalAccount = @@ROWCOUNT
        END
        ELSE IF @Action = 'CAL-HT'
        BEGIN            
            INSERT INTO #tmpTrans(transid)
            SELECT ISNULL(co.transid, b.transid) AS transid
            FROM dbo.bettrans b WITH(NOLOCK)
				LEFT JOIN dbo.bettrans co WITH(NOLOCK) 
				ON b.matchid = co.matchid 
					AND co.refno = b.transid 
					AND co.bettype = 911 --CashOut tickets
					
            WHERE    b.matchid = @matchid 
                    AND CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',', ',' + @strHTBettypes + ',') > 0
					AND b.betdaqid = 0--bettrade and CashOut tickets

            INSERT INTO #BalanceBefore
            SELECT    b.custid
                    ,SUM(b.winlost - b.actual_stake + b.playercomm)
            FROM    dbo.bettrans b WITH (ROWLOCK)
            WHERE    b.matchid = @matchid 
                    AND (
						CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',', ',' + @strHTBettypes + ',') > 0
						OR 1 = CASE 
                                --WHEN (b.bettype NOT BETWEEN 901 AND 920) THEN 1
								WHEN (b.bettype IN(904,914)) THEN 1 --BT & CashOut WL sharing
								WHEN (b.bettype BETWEEN 901 AND 904 AND b.refno IN (SELECT transid FROM #tmpTrans)) THEN 1 --BT transaction
								WHEN (b.bettype BETWEEN 911 AND 914) THEN --CashOut transaction
									CASE
										WHEN b.bettype = 911 AND b.transid IN (SELECT transid FROM #tmpTrans) THEN 1
										WHEN b.bettype <> 911 AND b.refno IN (SELECT transid FROM #tmpTrans) THEN 1
										ELSE 0
									END
                                ELSE 0 
                            END
					)
            GROUP BY b.custid

            SET @TotalAccount = @@ROWCOUNT
        END
        ELSE IF @Action = 'UNDO'
        BEGIN
            INSERT INTO #tmpTrans(transid)
            SELECT ISNULL(co.transid, b.transid) AS transid
            FROM dbo.bettrans b WITH(NOLOCK)
				LEFT JOIN dbo.bettrans co WITH(NOLOCK) 
				ON b.matchid = co.matchid 
					AND co.refno = b.transid 
					AND co.bettype = 911 --CashOut tickets
					
            WHERE    b.matchid = @matchid
                    AND b.bettype NOT IN (10, 31, 32, 33, 1231, 1232, 1233, 1237, 1238) -- Outright, VSRacing
                    AND b.bettype NOT BETWEEN 1501 and 1599 -- Keno
					AND CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',', ',' + @strAutoBettypes + ',') = 0 --ignore auto bettypes
                    AND b.betdaqid = 0--bettrade tickets
            
            INSERT INTO #BalanceBefore
            SELECT    b.custid
                    ,SUM(b.winlost - b.actual_stake + b.playercomm)
            FROM    dbo.bettrans b WITH (ROWLOCK)
				LEFT JOIN dbo.f_Set_GetGroupBettypes() f
					ON b.bettype = f.BetType
            WHERE    b.matchid = @matchid
                    AND b.bettype NOT IN (10, 31, 32, 33, 1231, 1232, 1233, 1237, 1238) -- Outright, VSRacing
                    AND b.bettype NOT BETWEEN 1501 and 1599 -- Keno
                    AND b.bettype NOT BETWEEN 801 AND 899--Metric Gaming
                    AND 1 = CASE 
                                WHEN (b.bettype NOT BETWEEN 901 AND 920) THEN 1
								WHEN (b.bettype IN(904,914)) THEN 1 --BT & CashOut WL sharing
								WHEN (b.bettype BETWEEN 901 AND 904 AND b.refno IN (SELECT transid FROM #tmpTrans)) THEN 1 --BT transaction
								WHEN b.bettype BETWEEN 911 AND 914 THEN --CashOut transaction
									CASE
										WHEN b.bettype = 911 AND b.transid IN (SELECT transid FROM #tmpTrans) THEN 1
										WHEN b.bettype <> 911 AND b.refno IN (SELECT transid FROM #tmpTrans) THEN 1
										ELSE 0
									END
                                ELSE 0 
                            END
                    AND CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',', ',' + @strAutoBettypes + ',') = 0 --ignore auto bettypes
					AND 1 = CASE -- basketball
								WHEN @SelectedQuarter IS NULL THEN 1
								WHEN @SelectedQuarter LIKE '%' + f.GroupName + '%' THEN 1 -- 1H, 2H, FT
								WHEN f.GroupId = 10 AND @SelectedQuarter LIKE '%' + LEFT(CAST(b.betid AS VARCHAR),3) + '%' THEN 1 -- 801, 802, 803, 804
								ELSE 0
							END
					AND 1 = CASE -- tennis
								WHEN @SelectedSet IS NULL THEN 1
								WHEN @SelectedSet LIKE '%6%' AND b.bettype IN (1,2,3,20,153,1301,1302,1303,1305,1306,1308) THEN 1
								WHEN b.bettype IN (154,155,156,1311,1312,1316,1317,1318,1324) 
									THEN CASE 
											WHEN @SelectedSet LIKE '%1%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '801' THEN 1
											WHEN @SelectedSet LIKE '%2%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '802' THEN 1
											WHEN @SelectedSet LIKE '%3%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '803' THEN 1
											WHEN @SelectedSet LIKE '%4%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '804' THEN 1
											WHEN @SelectedSet LIKE '%5%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '805' THEN 1
										ELSE 0
									END
								ELSE 0
							END
            GROUP BY b.custid
            
            SET @TotalAccount = @@ROWCOUNT
        END
                --===
    END --IF @SkipBalanceUpdate = 0
            --^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    BEGIN TRY
            -- 20090412 : Joe : case for unsettle the game.
        IF @action = 'UNDO'
        BEGIN
            EXEC dbo.NAP_Admin_Calculate_Main 
                @matchid        = @matchid
                ,@SelectedSet    = @SelectedSet
                ,@SelectedQuarter = @SelectedQuarter
                ,@action        = 'CAL'        -- Default Action for UNDO Settlement 
                ,@mode            = 'UNDO'
                ,@strBettypes = @strBettypes
            
            --Cricket: Charged Commision
            EXEC dbo.NAP_Admin_Calculate_500
                @MatchId = @matchId
                ,@Action = @Action
            
            -- BetTrade Winlost Sharing
            IF EXISTS (SELECT TOP 1 1 FROM dbo.bettrans WITH(NOLOCK) WHERE matchid = @matchid AND bettype = 904)
                EXEC dbo.NAP_Admin_Calculate_904
                    @MatchId = @matchid
                    ,@Action = @Action
					
			-- CashOut Winlost Sharing
            IF EXISTS (SELECT TOP 1 1 FROM dbo.bettrans WITH(NOLOCK) WHERE matchid = @matchid AND bettype = 914)
			BEGIN
                EXEC dbo.NAP_Admin_Calculate_914
                    @MatchId = @matchid
                    ,@Action = @Action
			END	

            EXEC dbo.NAP_Admin_Settlement_MP
                @matchid        = @matchid
                ,@creator        = @creator
                ,@action        = 'UNDO'
                ,@SelectedSet    = @SelectedSet
                ,@SelectedQuarter = @SelectedQuarter
                ,@IP            = @IP

            EXEC DBPRO.BODB02.dbo.NAP_UpdateMatch_Remark 
                @matchid        = @matchid
                ,@command        = 'U'                
                ,@SelectedSet    = @SelectedSet    --Tennis 
                ,@SelectedQuarter = @SelectedQuarter

            EXEC DBPRO.BODB02.dbo.NAP_Admin_Match_Update 
                @Command        = 'NAP_Admin_Settlement_1-UNDO'
                ,@MatchID        = @matchid
                ,@betstatus        = @betstatus
                ,@SelectedSet    = @SelectedSet
                ,@SelectedQuarter = @SelectedQuarter
                ,@creator        = @creator

            IF @Sporttype = 5 -- Tennis 
            BEGIN
                EXEC DBPRO.BODB02.dbo.NAP_Admin_Result_Update 
                        @Command            = 'NAP_Admin_Settlement_1-UNDO',
                        @MatchID            = @MatchID,
                        @SelectedSet        = @SelectedSet
            END
			ELSE IF @Sporttype = 1 -- Soccer
            BEGIN
                EXEC DBPRO.BODB02.dbo.NAP_Admin_Result_Update_1s 
                    @Command            = 'NAP_Admin_Settlement_1-UNDO',
                    @MatchID            = @MatchID,
                    @creator            = @creator 

				EXEC DBPRO.BODB02.dbo.NAP_Set_AutoPayoutResultUpd 
					@MatchId = @matchid
					,@TypeId = NULL
					,@StatusId = NULL 
					,@IsUndoMatch = 1 --Clear data in table AutoPayoutResult if match has been undo

            END
            ELSE IF @sporttype = 2 -- basketball
            BEGIN
				 EXEC DBPRO.BODB02.dbo.NAP_Admin_Result_Update_2b
                    @Command            = 'NAP_Admin_Settlement_1-UNDO',
                    @MatchID            = @MatchID,
                    @creator            = @creator, 
                    @SelectedQuarter    = @SelectedQuarter,
                    @Results			= @QuarterResult	
            END
            
            /* --20110620@Thien: replace by calling SP instead
            -- RESET 'SaveBet' of DB06
            DELETE FROM DB06.bodb02.dbo.Save_Jobs WHERE matchid = @matchid
            UPDATE DB06.bodb02.dbo.Save_ListMatch SET IsGameFinish = 1 WHERE matchid = @matchid

            INSERT INTO DB06.bodb02.dbo.SAve_Jobs (matchid, liveindicator, savetype, bettype, typename)
            SELECT @matchid, 1, 'DEL', 0, 0
            */
            EXEC DBACC.bodb02.dbo.NAP_Admin_Match_UpdateSaveBet 
                @action            = 'UNDO'
                ,@matchid        = @matchid
                ,@SelectedSet    = @SelectedSet --Tennis 
                ,@SelectedQuarter = @SelectedQuarter -- Basketball
                
        END
        ELSE
        BEGIN
            /* 06 OCT 2008 : Joe
            As of Today.  Match Remark can't tell game just settled for HT yet
            need below code to determine for mark match as calculated (all bets settled)
            */
			INSERT INTO @status(FTBet, BetCount, InRunning)		
            SELECT    CASE WHEN CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',', ',' + @strHTBettypes + ',') > 0 THEN 0 ELSE 1 END AS FTBet
                    ,SUM(CASE 
                        WHEN statusID IN (101, 102) THEN 0
                        ELSE 1
                        END)
                    ,SUM(CASE 
                            WHEN statusID = 0 THEN 1
                            ELSE 0
                            END)
            FROM    dbo.bettrans b with (NOLOCK)
            WHERE    b.matchid = @matchid
                    AND b.bettype NOT IN (10, 31, 32, 33, 1231, 1232, 1233, 1237, 1238) -- Outright, VSRacing
                    AND b.bettype NOT BETWEEN 1501 and 1599 -- Keno
                    AND b.bettype NOT BETWEEN 801 AND 899--Metric Gaming
					AND b.bettype NOT BETWEEN 901 AND 920 --BT & CashOut 
                    AND CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',', ',' + @strAutoBettypes + ',') = 0 --ignore auto bettypes
					
            GROUP BY CASE WHEN CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',', ',' + @strHTBettypes + ',') > 0 THEN 0 ELSE 1 END    

            IF NOT EXISTS (SELECT * FROM @status WHERE FTBet = 0)
                INSERT INTO @status VALUES (0, 0,0)

            IF NOT EXISTS (SELECT * FROM @status WHERE FTBet = 1)
                INSERT INTO @status VALUES (1, 0, 0)

            SELECT    @HTDone = CASE InRunning
                                WHEN 0 THEN 1
                                ELSE 0
                                END
            FROM    @status
            WHERE    FTBet = 0

            SELECT    @FTDone = CASE InRunning
                                WHEN 0 THEN 1
                                ELSE 0
                                END
            FROM    @status
            WHERE    FTBet = 1

            IF @Sporttype = 1 
            BEGIN
                IF EXISTS(    SELECT TOP 1 1 FROM Bettrans WITH (NOLOCK) 
                            WHERE    bettype IN (194,195,196,197,198,199,200,201,202,203,204,205,206,207,208,209)
                                    AND matchID = @MatchID 
                                    AND statusID = 0     
                                    AND @isExcludeCorner = 1 
                )
                SELECT    @isExistRunningCornerBet = 1 
            END

            /* Mode
            CAL : (default) Settle ALL BetTypes
            CAL-FT : Full Time Only
            CAL-HT : Half Time Only
            SCORE : Only Save Score -- not use
            UNDO : Unsettle the match  -- not use
            */
            SELECT    @eventstatus = CASE 
                                        WHEN @action = 'CAL' AND @Sporttype NOT IN (1,2,5)        THEN N'completed'
                                        WHEN @action = 'CAL' AND @Sporttype = 1 AND @isExcludeCorner = 0 THEN N'completed'
                                        WHEN @action = 'CAL' AND @Sporttype = 1 AND @isExcludeCorner = 1 AND @isExistRunningCornerBet = 0 THEN N'completed'
                                        WHEN @action = 'CAL' 
												AND ((@Sporttype = 5 AND @SelectedSet LIKE '%6%')
													OR (@sporttype = 2 AND @SelectedQuarter LIKE '%FT%')) THEN N'completed'    -- Match Option checked 
                                        WHEN @action = 'CAL-HT' AND m.matchcode LIKE '%hedge%'    THEN eventstatus -- Jamie@20120330: Not change eventstatus='completed' for Hedge Match although 
                                        WHEN @action = 'CAL-HT' AND @FTDone = 1    AND @isExcludeCorner = 0 THEN N'completed'
                                        WHEN @action = 'CAL-HT' AND @FTDone = 1    AND @isExcludeCorner = 1 AND @isExistRunningCornerBet = 0 THEN N'completed'
                                        WHEN @action = 'CAL-FT' AND @HTDone = 1 AND @isExcludeCorner = 0 THEN N'completed'
                                        WHEN @action = 'CAL-FT' AND @HTDone = 1 AND @isExcludeCorner = 1 AND @isExistRunningCornerBet = 0 THEN N'completed'
                                        ELSE m.eventstatus
                                        END
                    ,@FTDone        = CASE 
                                        WHEN @action = 'CAL-HT' AND m.matchcode LIKE '%hedge%' THEN 0
                                        ELSE @FTDone
                                        END
            FROM    DBPRO.BODB02.dbo.Match m WITH(NOLOCK)
            WHERE    m.matchid = @matchid

            EXEC DBPRO.BODB02.dbo.NAP_Admin_Match_Update 
                @Command            = 'NAP_Admin_Settlement_1-CAL'
                ,@MatchID            = @matchid
                ,@FTHome            = @fth
                ,@FTAway            = @fta
                ,@HTHome            = @hth
                ,@HTAway            = @hta
                ,@BetStatus         = @betstatus
                ,@GoalRecord        = @goalrecord
                ,@SelectedSet        = @SelectedSet        -- Tennis selected 
                ,@SelectedQuarter	= @SelectedQuarter  -- Basketball
                ,@Action            = @action
                ,@FTDone            = @FTDone
                ,@HTDone            = @HTDone
                ,@isExcludeCorner    = @isExcludeCorner
                ,@isExistRunningCornerBet = @isExistRunningCornerBet
                ,@creator            = @creator

            IF @Sporttype = 5 AND @Action='CAL'
            BEGIN
                EXEC DBPRO.BODB02.dbo.NAP_Admin_Result_Update 
                    @Command            = 'NAP_Admin_Settlement_1-CAL',
                    @MatchID            = @MatchID,
                    @HomeValue            = @HomeValue,
                    @AwayValue            = @AwayValue,
                    @SetResult            = @SetResult, 
                    @GameResult1        = @GameResult1,
                    @GameResult2        = @GameResult2,
                    @GameResult3        = @GameResult3,
                    @GameResult4        = @GameResult4,
                    @GameResult5        = @GameResult5,
                    @SelectedSet        = @SelectedSet,
                    @SelectedSet1Game    = @SelectedSet1Game,
                    @SelectedSet2Game    = @SelectedSet2Game,
                    @SelectedSet3Game    = @SelectedSet3Game,
                    @SelectedSet4Game    = @SelectedSet4Game,
                    @SelectedSet5Game    = @SelectedSet5Game,
                    @MaxGameSet1        = @MaxGameSet1,
                    @MaxGameSet2        = @MaxGameSet2,
                    @MaxGameSet3        = @MaxGameSet3,
                    @MaxGameSet4        = @MaxGameSet4,
                    @MaxGameSet5        = @MaxGameSet5,
                    @action                = @Action,
                    @creator            = @creator             
            END
            IF @sporttype = 2 AND @Action = 'CAL'
            BEGIN
				EXEC DBPRO.BODB02.dbo.NAP_Admin_Result_Update_2b
					@Command = 'NAP_Admin_Settlement_1-CAL'		
					,@MatchID = @matchid								
					,@Results = @QuarterResult					
					,@creator = @creator
					,@SelectedQuarter = @SelectedQuarter					
            END

            IF @Sporttype = 1 AND LEFT(@Action, 3) = 'CAL'
            BEGIN						
                EXEC DBPRO.BODB02.dbo.NAP_Admin_Result_Update_1s
                    @Command        = 'NAP_Admin_Settlement_1-CAL',
                    @MatchID        = @MatchID,
                    @ResourceIDs    = NULL,
                    @Results        = NULL,
                    @fth             = @fth,
                    @fta             = @fta,
                    @hth             = @hth,
                    @hta             = @hta,
                    @fthCorners     = @fthCorners,
                    @ftaCorners     = @ftaCorners,
                    @hthCorners     = @hthCorners,
                    @htaCorners     = @htaCorners,
                    @ftFCorner         = @ftFCorner,
                    @ftLCorner         = @ftLCorner,
                    @htFCorner         = @htFCorner,
                    @htLCorner         = @htLCorner,
                    @isExcludeCorner = @isExcludeCorner,
                    @ResourceResult	= @ResourceResult,
                    @Action            = @Action,
                    @IsAuto            = 0,
                    @creator        = @creator
            END
          
            IF LEFT(@action, 3) = 'CAL'
            BEGIN
                IF @Sporttype = 5 -- Tennis settlement 
                BEGIN 
                    EXEC dbo.NAP_Admin_Settlement_5 
                        @MatchID        = @MatchID,
                        @Action            = 'CAL',
                        @Mode            = 'CAL',
                        @SelectedSet    = @SelectedSet
                END
                ELSE IF @sporttype = 2 -- Basketball
                BEGIN
					EXEC dbo.NAP_Admin_Settlement_3_Basketball
						@matchId = @matchid
						,@Mode	= @action
						,@SelectedQuarter = @SelectedQuarter
                END
                ELSE
                BEGIN
                    EXEC dbo.NAP_Admin_Settlement_3 
                        @matchid            = @matchid
                        ,@mode                = @action    
                        ,@isExcludeCorner    = @isExcludeCorner  
                END
            END

        IF @eventstatus = 'completed'
        BEGIN
            EXEC DBPRO.BODB02.dbo.NAP_updateMatch_remark 
                @matchid    = @matchid
                ,@command    = 'C'
                ,@SelectedQuarter = @SelectedQuarter
        END
        ELSE IF (@action = 'CAL-HT' OR (@sporttype = 2 AND @SelectedQuarter LIKE '%1H%'))
        BEGIN
            EXEC DBPRO.BODB02.dbo.NAP_updateMatch_remark 
                @matchid    = @matchid
                ,@command    = 'H'
        END
    END 
    END TRY
    BEGIN CATCH
        -- Capture Balance incase of failure
        IF @SkipBalanceUpdate = 0
        BEGIN
            IF @Action IN ('CAL', 'CAL-FT')
            BEGIN
                INSERT INTO #BalanceAfter
                SELECT    b.custid
                        ,SUM(b.winlost - b.actual_stake + b.playercomm)
                FROM    dbo.bettrans b WITH (ROWLOCK)	
					LEFT JOIN dbo.f_Set_GetGroupBettypes() f
					ON b.bettype = f.BetType
                WHERE    b.matchid = @matchid 
                        AND b.bettype NOT IN (10, 31, 32, 33, 1231, 1232, 1233, 1237, 1238) -- Outright, VSRacing
                        AND b.bettype NOT BETWEEN 1501 and 1599 -- Keno
                        AND b.bettype NOT BETWEEN 801 AND 899--Metric Gaming
                        AND 1 = CASE 
                                WHEN (b.bettype NOT BETWEEN 901 AND 920) THEN 1
								WHEN (b.bettype IN(904,914)) THEN 1 --BT & CashOut WL sharing
								WHEN (b.bettype BETWEEN 901 AND 904 AND b.refno IN (SELECT transid FROM #tmpTrans)) THEN 1 --BT transaction
								WHEN b.bettype BETWEEN 911 AND 914 THEN --CashOut transaction
									CASE
										WHEN b.bettype = 911 AND b.transid IN (SELECT transid FROM #tmpTrans) THEN 1
										WHEN b.bettype <> 911 AND b.refno IN (SELECT transid FROM #tmpTrans) THEN 1
										ELSE 0
									END
                                ELSE 0 
                            END
                        AND CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',', ',' + @strAutoBettypes + ',') = 0 --ignore auto bettypes
						AND 1 = CASE -- basketball
									WHEN @SelectedQuarter IS NULL THEN 1
									WHEN @SelectedQuarter LIKE '%' + f.GroupName + '%' THEN 1 -- 1H, 2H, FT
									WHEN f.GroupId = 10 AND @SelectedQuarter LIKE '%' + LEFT(CAST(b.betid AS VARCHAR),3) + '%' THEN 1 -- 801, 802, 803, 804
									ELSE 0
								END
						AND 1 = CASE -- tennis
									WHEN @SelectedSet IS NULL THEN 1
									WHEN @SelectedSet LIKE '%6%' AND b.bettype IN (1,2,3,20,153,1301,1302,1303,1305,1306,1308) THEN 1
									WHEN b.bettype IN (154,155,156,1311,1312,1316,1317,1318,1324) 
										THEN CASE 
												WHEN @SelectedSet LIKE '%1%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '801' THEN 1
												WHEN @SelectedSet LIKE '%2%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '802' THEN 1
												WHEN @SelectedSet LIKE '%3%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '803' THEN 1
												WHEN @SelectedSet LIKE '%4%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '804' THEN 1
												WHEN @SelectedSet LIKE '%5%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '805' THEN 1
											ELSE 0
										END
									ELSE 0
								END
                GROUP BY b.custid
            END
            ELSE IF @Action = 'CAL-HT'
            BEGIN
                INSERT INTO #BalanceAfter
                SELECT    b.custid
                        ,SUM(b.winlost - b.actual_stake + b.playercomm)
                FROM    dbo.bettrans b WITH (ROWLOCK)
                WHERE    b.matchid = @matchid
                        AND (
							CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',', ',' + @strHTBettypes + ',') > 0
							OR 1 = CASE 
                                --WHEN (b.bettype NOT BETWEEN 901 AND 920) THEN 1
								WHEN (b.bettype IN(904,914)) THEN 1 --BT & CashOut WL sharing
								WHEN (b.bettype BETWEEN 901 AND 904 AND b.refno IN (SELECT transid FROM #tmpTrans)) THEN 1 --BT transaction
								WHEN (b.bettype BETWEEN 911 AND 914) THEN --CashOut transaction
									CASE
										WHEN b.bettype = 911 AND b.transid IN (SELECT transid FROM #tmpTrans) THEN 1
										WHEN b.bettype <> 911 AND b.refno IN (SELECT transid FROM #tmpTrans) THEN 1
										ELSE 0
									END
                                ELSE 0 
                            END
						)
						
                GROUP BY b.custid
            END
            ELSE IF @Action = 'UNDO'
            BEGIN
                INSERT INTO #BalanceAfter
                SELECT    b.custid
                        ,SUM(b.winlost - b.actual_stake + b.playercomm)
                FROM    dbo.bettrans b WITH (ROWLOCK)
					LEFT JOIN dbo.f_Set_GetGroupBettypes() f
					ON b.bettype = f.BetType
                WHERE    b.matchid = @matchid
                        AND b.bettype NOT IN (10, 31, 32, 33, 1231, 1232, 1233, 1237, 1238) -- Outright, VSRacing
                        AND b.bettype NOT BETWEEN 1501 and 1599 -- Keno
                        AND b.bettype NOT BETWEEN 801 AND 899--Metric Gaming 
                        AND 1 = CASE 
                                WHEN (b.bettype NOT BETWEEN 901 AND 920) THEN 1
								WHEN (b.bettype IN(904,914)) THEN 1 --BT & CashOut WL sharing
								WHEN (b.bettype BETWEEN 901 AND 904 AND b.refno IN (SELECT transid FROM #tmpTrans)) THEN 1 --BT transaction
								WHEN b.bettype BETWEEN 911 AND 914 THEN --CashOut transaction
									CASE
										WHEN b.bettype = 911 AND b.transid IN (SELECT transid FROM #tmpTrans) THEN 1
										WHEN b.bettype <> 911 AND b.refno IN (SELECT transid FROM #tmpTrans) THEN 1
										ELSE 0
									END
                                ELSE 0 
                            END
                        AND CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',', ',' + @strAutoBettypes + ',') = 0 --ignore auto bettypes
						AND 1 = CASE -- basketball
									WHEN @SelectedQuarter IS NULL THEN 1
									WHEN @SelectedQuarter LIKE '%' + f.GroupName + '%' THEN 1 -- 1H, 2H, FT
									WHEN f.GroupId = 10 AND @SelectedQuarter LIKE '%' + LEFT(CAST(b.betid AS VARCHAR),3) + '%' THEN 1 -- 801, 802, 803, 804
									ELSE 0
								END
						AND 1 = CASE -- tennis
									WHEN @SelectedSet IS NULL THEN 1
									WHEN @SelectedSet LIKE '%6%' AND b.bettype IN (1,2,3,20,153,1301,1302,1303,1305,1306,1308) THEN 1
									WHEN b.bettype IN (154,155,156,1311,1312,1316,1317,1318,1324) 
										THEN CASE 
												WHEN @SelectedSet LIKE '%1%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '801' THEN 1
												WHEN @SelectedSet LIKE '%2%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '802' THEN 1
												WHEN @SelectedSet LIKE '%3%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '803' THEN 1
												WHEN @SelectedSet LIKE '%4%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '804' THEN 1
												WHEN @SelectedSet LIKE '%5%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '805' THEN 1
											ELSE 0
										END
									ELSE 0
								END
                GROUP BY b.custid
            END
        END --IF @SkipBalanceUpdate = 0
        
        -- Compare Balance
        INSERT INTO #Balance
        SELECT    b.custid
                ,a.balance - b.balance
                ,CASE 
                    WHEN a.balance > b.balance THEN 1
                    ELSE 0
                    END
        FROM    #BalanceBefore b
            INNER JOIN #BalanceAfter a 
                ON    b.custid = a.custid
        WHERE    b.balance <> a.balance
        
        INSERT INTO @tblDebitPending (custID, balance)
        SELECT    custid, ABS(balance)
        FROM    #Balance
        WHERE    Increased = 0
        
        IF @@rowcount <> 0
            EXEC dbo.Dot_BalancePendingDebitIns 
                @BalancePending = @tblDebitPending
                ,@Type            = 1 -- Sports
        
        INSERT INTO @tblCreditPending (custID, balance)
        SELECT    custid, balance
        FROM    #Balance
        WHERE    Increased = 1
        
        IF @@rowcount <> 0
            EXEC dbo.Dot_BalancePendingCreditIns 
                @BalancePending = @tblCreditPending
                ,@Type            = 1 -- Sports
                
        -- Add Negative Balance into BalanceNegative table 
        INSERT INTO [bodb02].[dbo].[BalanceNegative] (
                [ExecDate]
                ,[MatchID]
                ,[ActionID]
                ,[GroupID]
                ,[CustID]
                ,[Balance]
                ,[StatusID]
                ,[Remark]
            )
        SELECT    GETDATE()
                ,@MatchID
                ,@ActionID
                ,1 -- Sportsbook Single bet Settlement 
                ,CustID
                ,Balance
                ,0
                ,NULL
        FROM    #Balance WITH(NOLOCK)
        WHERE    Increased = 0
				
        SELECT    @ErrCode = 1001017 
                ,@ErrMsg = ERROR_MESSAGE()
        
        RETURN        
    END CATCH
    
    -------------------------------------------------------------
    ---         CAPTURE value BALANCE after settlement        ---
    ---------------------------VVVV------------------------------

    IF @SkipBalanceUpdate = 0
    BEGIN
        IF @Action IN ('CAL', 'CAL-FT')
            BEGIN
                INSERT INTO #BalanceAfter
                SELECT    b.custid
                        ,SUM(b.winlost - b.actual_stake + b.playercomm)
                FROM    dbo.bettrans b WITH (ROWLOCK)
					LEFT JOIN dbo.f_Set_GetGroupBettypes() f
					ON b.bettype = f.BetType
                WHERE    b.matchid = @matchid 
                        AND b.bettype NOT IN (10, 31, 32, 33, 1231, 1232, 1233, 1237, 1238) -- Outright, VSRacing
                        AND b.bettype NOT BETWEEN 1501 and 1599 -- Keno
                        AND b.bettype NOT BETWEEN 801 AND 899--Metric Gaming
                        AND 1 = CASE 
                                WHEN (b.bettype NOT BETWEEN 901 AND 920) THEN 1
								WHEN (b.bettype IN(904,914)) THEN 1 --BT & CashOut WL sharing
								WHEN (b.bettype BETWEEN 901 AND 904 AND b.refno IN (SELECT transid FROM #tmpTrans)) THEN 1 --BT transaction
								WHEN b.bettype BETWEEN 911 AND 914 THEN --CashOut transaction
									CASE
										WHEN b.bettype = 911 AND b.transid IN (SELECT transid FROM #tmpTrans) THEN 1
										WHEN b.bettype <> 911 AND b.refno IN (SELECT transid FROM #tmpTrans) THEN 1
										ELSE 0
									END
                                ELSE 0 
                            END
                        AND CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',', ',' + @strAutoBettypes + ',') = 0 --ignore auto bettypes
						AND 1 = CASE -- basketball
									WHEN @SelectedQuarter IS NULL THEN 1
									WHEN @SelectedQuarter LIKE '%' + f.GroupName + '%' THEN 1 -- 1H, 2H, FT
									WHEN f.GroupId = 10 AND @SelectedQuarter LIKE '%' + LEFT(CAST(b.betid AS VARCHAR),3) + '%' THEN 1 -- 801, 802, 803, 804
									ELSE 0
								END
						AND 1 = CASE -- tennis
									WHEN @SelectedSet IS NULL THEN 1
									WHEN @SelectedSet LIKE '%6%' AND b.bettype IN (1,2,3,20,153,1301,1302,1303,1305,1306,1308) THEN 1
									WHEN b.bettype IN (154,155,156,1311,1312,1316,1317,1318,1324) 
										THEN CASE 
												WHEN @SelectedSet LIKE '%1%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '801' THEN 1
												WHEN @SelectedSet LIKE '%2%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '802' THEN 1
												WHEN @SelectedSet LIKE '%3%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '803' THEN 1
												WHEN @SelectedSet LIKE '%4%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '804' THEN 1
												WHEN @SelectedSet LIKE '%5%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '805' THEN 1
											ELSE 0
										END
									ELSE 0
								END
                GROUP BY b.custid
            END
            ELSE IF @Action = 'CAL-HT'
            BEGIN
                INSERT INTO #BalanceAfter
                SELECT    b.custid
                        ,SUM(b.winlost - b.actual_stake + b.playercomm)
                FROM    dbo.bettrans b WITH (ROWLOCK)
                WHERE   b.matchid = @matchid 
						AND (
							CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',', ',' + @strHTBettypes + ',') > 0
							OR 1 = CASE 
                                --WHEN (b.bettype NOT BETWEEN 901 AND 920) THEN 1
								WHEN (b.bettype IN(904,914)) THEN 1 --BT & CashOut WL sharing
								WHEN (b.bettype BETWEEN 901 AND 904 AND b.refno IN (SELECT transid FROM #tmpTrans)) THEN 1 --BT transaction
								WHEN (b.bettype BETWEEN 911 AND 914) THEN --CashOut transaction
									CASE
										WHEN b.bettype = 911 AND b.transid IN (SELECT transid FROM #tmpTrans) THEN 1
										WHEN b.bettype <> 911 AND b.refno IN (SELECT transid FROM #tmpTrans) THEN 1
										ELSE 0
									END
                                ELSE 0 
                            END
						)
                GROUP BY b.custid
            END
            ELSE IF @Action = 'UNDO'
            BEGIN                
                INSERT INTO #BalanceAfter
                SELECT    b.custid
                        ,SUM(b.winlost - b.actual_stake + b.playercomm)
                FROM    dbo.bettrans b WITH (ROWLOCK)
					LEFT JOIN dbo.f_Set_GetGroupBettypes() f
					ON b.bettype = f.BetType
                WHERE    b.matchid = @matchid
                        AND b.bettype NOT IN (10, 31, 32, 33, 1231, 1232, 1233, 1237, 1238) -- Outright, VSRacing
                        AND b.bettype NOT BETWEEN 1501 and 1599 -- Keno
                        AND b.bettype NOT BETWEEN 801 AND 899--Metric Gaming
                        AND 1 = CASE 
                                WHEN (b.bettype NOT BETWEEN 901 AND 920) THEN 1
								WHEN (b.bettype IN(904,914)) THEN 1 --BT & CashOut WL sharing
								WHEN (b.bettype BETWEEN 901 AND 904 AND b.refno IN (SELECT transid FROM #tmpTrans)) THEN 1 --BT transaction
								WHEN b.bettype BETWEEN 911 AND 914 THEN --CashOut transaction
									CASE
										WHEN b.bettype = 911 AND b.transid IN (SELECT transid FROM #tmpTrans) THEN 1
										WHEN b.bettype <> 911 AND b.refno IN (SELECT transid FROM #tmpTrans) THEN 1
										ELSE 0
									END
									ELSE 0
								END
						AND CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',', ',' + @strAutoBettypes + ',') = 0 --ignore auto bettypes
						AND 1 = CASE -- basketball
									WHEN @SelectedQuarter IS NULL THEN 1
									WHEN @SelectedQuarter LIKE '%' + f.GroupName + '%' THEN 1 -- 1H, 2H, FT
									WHEN f.GroupId = 10 AND @SelectedQuarter LIKE '%' + LEFT(CAST(b.betid AS VARCHAR),3) + '%' THEN 1 -- 801, 802, 803, 804
									ELSE 0
								END
						AND 1 = CASE -- tennis
									WHEN @SelectedSet IS NULL THEN 1
									WHEN @SelectedSet LIKE '%6%' AND b.bettype IN (1,2,3,20,153,1301,1302,1303,1305,1306,1308) THEN 1
									WHEN b.bettype IN (154,155,156,1311,1312,1316,1317,1318,1324) 
										THEN CASE 
												WHEN @SelectedSet LIKE '%1%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '801' THEN 1
												WHEN @SelectedSet LIKE '%2%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '802' THEN 1
												WHEN @SelectedSet LIKE '%3%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '803' THEN 1
												WHEN @SelectedSet LIKE '%4%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '804' THEN 1
												WHEN @SelectedSet LIKE '%5%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '805' THEN 1
											ELSE 0
										END
                                ELSE 0 
                            END
                        
                GROUP BY b.custid
            END
    END --IF @SkipBalanceUpdate = 0

    -------------------------------------------------------------
    ---                   compare BALANCE                     ---
    ---------------------------VVVV------------------------------

    INSERT INTO #Balance
    SELECT    b.custid
            ,a.balance - b.balance
            ,CASE 
                WHEN a.balance > b.balance THEN 1
                ELSE 0
                END
    FROM    #BalanceBefore b
        INNER JOIN #BalanceAfter a 
            ON    b.custid = a.custid
    WHERE    b.balance <> a.balance

    SET @TotalAccount_BalanceUpdate = @@ROWCOUNT

    INSERT INTO @tblDebitPending (custID, balance)
    SELECT    custid, ABS(balance)
    FROM    #Balance
    WHERE    Increased = 0
    
    IF @@rowcount <> 0
        EXEC dbo.Dot_BalancePendingDebitIns 
            @BalancePending = @tblDebitPending
            ,@Type            = 1 -- Sports
    
    INSERT INTO @tblCreditPending (custID, balance)
    SELECT    custid, balance
    FROM    #Balance
    WHERE    Increased = 1
    
    IF @@rowcount <> 0
        EXEC dbo.Dot_BalancePendingCreditIns 
            @BalancePending = @tblCreditPending
            ,@Type            = 1 -- Sports
    ----
    -- Add Negative Balance into BalanceNegative table 
    ----
    INSERT INTO [bodb02].[dbo].[BalanceNegative] (
        [ExecDate]
        ,[MatchID]
        ,[ActionID]
        ,[GroupID]
        ,[CustID]
        ,[Balance]
        ,[StatusID]
        ,[Remark]
        )
    SELECT GETDATE()
        ,@MatchID
        ,@ActionID
        ,1 -- Sportsbook Single bet Settlement 
        ,CustID
        ,Balance
        ,0
        ,NULL
    FROM #Balance WITH(NOLOCK)
    WHERE Increased = 0

    ---------------------------------------------------
    DROP TABLE #Balance

    DROP TABLE #BalanceBefore

    DROP TABLE #BalanceAfter
    
    DROP TABLE #tmpTrans
    -------------------------------------------------------------
    ---                      WRITE LOG                        ---
    ---------------------------VVVV------------------------------
    SELECT @stop = CURRENT_TIMESTAMP
	
	DECLARE @xmlQuarterResult XML = CAST(@QuarterResult AS XML)
 
	SET @QuarterResult = ''
	SELECT @QuarterResult = @QuarterResult 
				+ T.C.value('@Id', 'VARCHAR(50)') 
				+ '(' + ISNULL(T.C.value('@HomeValue', 'VARCHAR(50)'),'')
				+ CASE 
					WHEN T.C.value('@AwayValue', 'VARCHAR(50)') IS NULL THEN ''
					ELSE '-' + T.C.value('@AwayValue', 'VARCHAR(50)')
					END	
				+ '),'
	 FROM @xmlQuarterResult.nodes('Results/Resource') T(c)
	 
	 IF RIGHT(@QuarterResult,1) = ','
		SELECT @QuarterResult = LEFT(@QuarterResult,LEN(@QuarterResult)-1)
 
    SELECT @LogData = 'NAP: Calculate (' + @action + ') for matchid:' + CAST(@matchid AS NVARCHAR(10)) 
                                                        + ' score:' + CAST(ISNULL(@fth, 0) AS NVARCHAR(10)) 
                                                        + '-' + CAST(ISNULL(@fta, 0) AS NVARCHAR(10)) 
                                                        + ' HT:' + CAST(@hth AS NVARCHAR(10)) 
                                                        + '-' + CAST(@hta AS NVARCHAR(10)) 
                                                        + ' GoalRecord:' + ISNULL(@goalrecord, '') 
                                                        + '(Old:' + @goalrecord_old + ') Remark(' + @betstatus + ')' 

                                                        + CASE    WHEN @SelectedSet IS NULL THEN ''
                                                                ELSE ' (Set:' + @SelectedSet + ')' 
                                                                END  
                                                        + CASE    WHEN @SetResult IS NULL THEN ''
                                                                ELSE ' (SR:' + @SetResult + ')' 
                                                                END
                                                        + CASE    WHEN @SelectedSet1Game IS NULL THEN ''
                                                                ELSE ' (S1Game:' + @SelectedSet1Game + ') ' 
                                                                END   
                                                        + CASE    WHEN @GameResult1 IS NULL THEN ''
                                                                ELSE '(S1GR:' + @GameResult1 + ') ' 
                                                                END  
                                                        + CASE    WHEN @SelectedSet2Game IS NULL THEN ''
                                                                ELSE ' (S2Game:' + @SelectedSet2Game + ') ' 
                                                                END   
                                                        + CASE    WHEN @GameResult2 IS NULL THEN ''
                                                                ELSE '(S2GR:' + @GameResult2 + ') ' 
                                                                END
                                                        + CASE    WHEN @SelectedSet3Game IS NULL THEN ''
                                                                ELSE ' (S3Game:' + @SelectedSet3Game + ') ' 
                                                                END   
                                                        + CASE    WHEN @GameResult3 IS NULL THEN ''
                                                                ELSE '(S3GR:' + @GameResult3 + ') ' 
                                                                END
                                                        + CASE    WHEN @SelectedSet4Game IS NULL THEN ''
                                                                ELSE ' (S4Game:' + @SelectedSet4Game + ') ' 
                                                                END   
                                                        + CASE    WHEN @GameResult4 IS NULL THEN ''
                                                                ELSE '(S4GR:' + @GameResult1 + ') ' 
                                                                END
                                                        + CASE    WHEN @SelectedSet5Game IS NULL THEN ''
                                                                ELSE ' (S5Game:' + @SelectedSet5Game + ') ' 
                                                                END   
                                                        + CASE    WHEN @GameResult5 IS NULL THEN ''
                                                                ELSE '(S5GR:' + @GameResult5 + ') ' 
                                                                END
                                                        + CASE WHEN @fthCorners IS NULL THEN '' ELSE '(fthCorners:' + CAST(@fthCorners AS VARCHAR(50))  + ') ' END 
                                                        + CASE WHEN @ftaCorners IS NULL THEN '' ELSE '(ftaCorners:' + CAST(@ftaCorners AS VARCHAR(50))  + ') ' END
                                                        + CASE WHEN @hthCorners IS NULL THEN '' ELSE '(hthCorners:' + CAST(@hthCorners AS VARCHAR(50))  + ') ' END
                                                        + CASE WHEN @htaCorners IS NULL THEN '' ELSE '(htaCorners:' + CAST(@htaCorners AS VARCHAR(50))  + ') ' END
                                                        + CASE WHEN @ftFCorner IS NULL THEN '' ELSE '(ftFCorner:' + @ftFCorner + ') ' END
                                                        + CASE WHEN @ftLCorner IS NULL THEN '' ELSE '(ftLCorner:' + @ftLCorner + ') ' END
                                                        + CASE WHEN @htFCorner IS NULL THEN '' ELSE '(htFCorner:' + @htFCorner + ') ' END
                                                        + CASE WHEN @htLCorner IS NULL THEN '' ELSE '(htLCorner:' + @htLCorner + ') ' END
                                                        + CASE WHEN @isExcludeCorner IS NULL THEN '' ELSE '(isExcludeCorner:' + CAST(@isExcludeCorner AS VARCHAR(50)) + ') ' END
														+ CASE WHEN @SelectedQuarter IS NULL THEN '' ELSE 'SelectedQuarter:' + @SelectedQuarter + '<br/> ' END
														+ CASE WHEN @QuarterResult <> '' THEN 'Result: ' + @QuarterResult + '<br/> ' ELSE '' END
                                                        +' (' + CAST(DATEDIFF(millisecond, @start, @stop) AS NVARCHAR(50)) + ' ms)'

    EXEC dbo.WriteLog_UserLog 
        @UserID = @creator
        ,@Doing = @LogData

        
    SELECT @Remark ='NAP: ' + CASE    WHEN ISNULL(@goalrecord_old,'')='' THEN ''
                                    ELSE 'Old GoalRecord:' + @goalrecord_old + '<br/> '
                                    END
                            + CASE    WHEN @SelectedSet IS NULL THEN ''
                                    ELSE 'Set:' + @SelectedSet + '<br/> ' 
                                    END  
                            + CASE    WHEN @SetResult IS NULL THEN ''
                                    ELSE 'SR:' + @SetResult + '<br/> ' 
                                    END 
                            + CASE    WHEN @SelectedSet1Game IS NULL THEN ''
                                    ELSE 'S1Game:' + @SelectedSet1Game + '<br/> ' 
                                    END  
                            + CASE    WHEN @GameResult1 IS NULL THEN ''
                                    ELSE 'S1GR:' + @GameResult1 + '<br/> ' 
                                    END  
                            + CASE    WHEN @SelectedSet2Game IS NULL THEN ''
                                    ELSE 'S2Game:' + @SelectedSet2Game + '<br/> ' 
                                    END  
                            + CASE    WHEN @GameResult2 IS NULL THEN ''
                                    ELSE 'S2GR:' + @GameResult2 + '<br/> ' 
                                    END  
                            + CASE    WHEN @SelectedSet3Game IS NULL THEN ''
                                    ELSE 'S3Game:' + @SelectedSet3Game + '<br/> ' 
                                    END  
                            + CASE    WHEN @GameResult3 IS NULL THEN ''
                                    ELSE 'S3GR:' + @GameResult3 + '<br/> ' 
                                    END  
                            + CASE    WHEN @SelectedSet4Game IS NULL THEN ''
                                    ELSE 'S4Game:' + @SelectedSet4Game + '<br/> ' 
                                    END  
                            + CASE    WHEN @GameResult4 IS NULL THEN ''
                                    ELSE 'S4GR:' + @GameResult4 + '<br/> ' 
                                    END  
                            + CASE    WHEN @SelectedSet5Game IS NULL THEN ''
                                    ELSE 'S5Game:' + @SelectedSet5Game + '<br/> ' 
                                    END  
                            + CASE    WHEN @GameResult5 IS NULL THEN ''
                                    ELSE 'S5GR:' + @GameResult5 + '<br/> ' 
                                    END  

                            + CASE WHEN @fthCorners IS NULL THEN '' ELSE 'fthCorners:' + CAST(@fthCorners AS VARCHAR(50))  + ' ' END 
                            + CASE WHEN @ftaCorners IS NULL THEN '' ELSE 'ftaCorners:' + CAST(@ftaCorners AS VARCHAR(50))  + '<br/> ' END
                            + CASE WHEN @hthCorners IS NULL THEN '' ELSE 'hthCorners:' + CAST(@hthCorners AS VARCHAR(50))  + ' ' END
                            + CASE WHEN @htaCorners IS NULL THEN '' ELSE 'htaCorners:' + CAST(@htaCorners AS VARCHAR(50))  + '<br/> ' END
                            + CASE WHEN @ftFCorner IS NULL THEN '' ELSE 'ftFCorner:' + @ftFCorner + '<br/> ' END
                            + CASE WHEN @ftLCorner IS NULL THEN '' ELSE 'ftLCorner:' + @ftLCorner + '<br/> ' END
                            + CASE WHEN @htFCorner IS NULL THEN '' ELSE 'htFCorner:' + @htFCorner + '<br/> ' END
                            + CASE WHEN @htLCorner IS NULL THEN '' ELSE 'htLCorner:' + @htLCorner + '<br/> ' END
                            + CASE WHEN @isExcludeCorner IS NULL THEN '' ELSE 'isExcludeCorner:' + CAST( @isExcludeCorner AS VARCHAR(50)) + '<br/> ' END 
							+ CASE WHEN @SelectedQuarter IS NULL THEN '' ELSE 'SelectedQuarter:' + @SelectedQuarter + '<br/> ' END
							+ CASE WHEN @QuarterResult <> '' THEN 'Result: ' + @QuarterResult + '<br/> ' ELSE '' END
                            + 'Duration:' + CAST(DATEDIFF(MILLISECOND, @start, @stop) AS NVARCHAR(50)) + ' ms;' 
                            + ' TC:' + CAST(ISNULL(@ticketCount, 0) AS VARCHAR(20)) 
                            + ' Bal:' + CAST(ISNULL(@TotalAccount_BalanceUpdate, 0) AS VARCHAR(20)) + '/' + CAST(IsNull(@TotalAccount, 0) AS VARCHAR(20))

    BEGIN TRY
        EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle 
            @UserID                = @creator
            ,@Matchid            = @matchid
            ,@ActionID            = @ActionID
            ,@finalhomescore    = @fth
            ,@finalawayscore    = @fta
            ,@hthomescore        = @hth
            ,@htawayscore        = @hta
            ,@GoalRecord        = @goalrecord
            ,@betstatus            = @betstatus
            ,@Remark            = @Remark
            ,@IP                = @IP
    END TRY

    BEGIN CATCH
        SELECT @Remark = @Remark + ' ErrMsg=' + left(error_message(), 250)

        EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle 
            @UserID                = @creator
            ,@Matchid            = @matchid
            ,@ActionID            = @ActionID
            ,@finalhomescore    = @fth
            ,@finalawayscore    = @fta
            ,@hthomescore        = @hth
            ,@htawayscore        = @hta
            ,@GoalRecord        = @goalrecord
            ,@betstatus            = @betstatus
            ,@Remark            = @Remark
            ,@IP                = @IP
    END CATCH
    
    ------ releasing Settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch		= 1
		, @IsReleased		= 1
	
	DROP TABLE #tblMatchProcess
END
GO
GRANT EXECUTE ON [dbo].[NAP_Admin_Settlement_1] TO [bodbAdminNet]
GO
GRANT EXECUTE ON [dbo].[NAP_Admin_Settlement_1] TO [Dot_Member]
GO


