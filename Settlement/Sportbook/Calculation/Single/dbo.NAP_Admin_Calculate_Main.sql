/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_Main]
    @matchid                        INT
    ,@mode                          VARCHAR(15) = 'CAL'
    ,@action                        VARCHAR(20) = 'CAL'
    ,@fth                           INT         = NULL
    ,@fta                           INT         = NULL
    ,@hth                           INT         = NULL
    ,@hta                           INT         = NULL
    ,@home_2nd                      INT         = NULL
    ,@away_2nd                      INT         = NULL
    ,@sporttype                     SMALLINT    = NULL
    ,@betstatus                     NVARCHAR(50)= NULL
    ,@GoalRecord                    VARCHAR(50) = NULL
	,@goalsequenceFT				VARCHAR(50) = NULL
	,@goalsequenceHT				VARCHAR(50) = NULL
    ,@matchCode                     NVARCHAR(50)= NULL
    ,@oddeven                       SMALLMONEY  = NULL
    ,@oddevenht                     SMALLMONEY  = NULL
    ,@oddevenhome                   SMALLMONEY  = NULL
    ,@oddevenhome_ht                SMALLMONEY  = NULL
    ,@oddevenaway                   SMALLMONEY  = NULL
    ,@oddevenaway_ht                SMALLMONEY  = NULL
    ,@oddeven_2H                    SMALLMONEY  = NULL
    ,@totalgoal                     SMALLMONEY  = NULL
    ,@totalht                       SMALLMONEY  = NULL
    ,@totalgoal_2H                  SMALLMONEY  = NULL
    ,@totalhome                     SMALLMONEY  = NULL
    ,@totalaway                     SMALLMONEY  = NULL
    ,@goaldiff                      SMALLMONEY  = NULL
    ,@scorediff                     SMALLMONEY  = NULL
    ,@scorediff_ht                  SMALLMONEY  = NULL
    ,@scorediff_2H                  SMALLMONEY  = NULL
    ,@correctscore                  NVARCHAR(10)= NULL
    ,@correctscore_ht               NVARCHAR(10)= NULL
    ,@correctscore_2h               NVARCHAR(10)= NULL
    ,@HTFT                          NVARCHAR(10)= NULL
    ,@ft_fg                         VARCHAR(10) = NULL
    ,@ft_lg                         VARCHAR(10) = NULL
    ,@ht_fg                         VARCHAR(10) = NULL
    ,@ht_lg                         VARCHAR(10) = NULL
    ,@WinFromBehind                 VARCHAR(1)  = NULL
    ,@TennisTotal                   SMALLINT    = NULL
    ,@T_Home                        SMALLINT    = NULL
    ,@T_Away                        SMALLINT    = NULL
    ,@SelectedSet                   VARCHAR(50) = NULL
    ,@SelectedSettleFinishedGame    VARCHAR(50) = NULL
    ,@TotalGameHomeMatch            INT         = NULL
    ,@TotalGameAwayMatch            INT         = NULL
    ,@TotalGameHomeSet1             INT         = NULL
    ,@TotalGameHomeSet2             INT         = NULL
    ,@TotalGameHomeSet3             INT         = NULL
    ,@TotalGameHomeSet4             INT         = NULL
    ,@TotalGameHomeSet5             INT         = NULL
    ,@TotalGameAwaySet1             INT         = NULL
    ,@TotalGameAwaySet2             INT         = NULL
    ,@TotalGameAwaySet3             INT         = NULL
    ,@TotalGameAwaySet4             INT         = NULL
    ,@TotalGameAwaySet5             INT         = NULL
    ,@TotalSetMatch                 INT         = NULL
    ,@TotalGameSet1                 INT         = NULL
    ,@TotalGameSet2                 INT         = NULL
    ,@TotalGameSet3                 INT         = NULL
    ,@TotalGameSet4                 INT         = NULL
    ,@TotalGameSet5                 INT         = NULL
    ,@OddEvenSetMatch               SMALLMONEY  = NULL
    ,@OddEvenGameSet1               SMALLMONEY  = NULL
    ,@OddEvenGameSet2               SMALLMONEY  = NULL
    ,@OddEvenGameSet3               SMALLMONEY  = NULL
    ,@OddEvenGameSet4               SMALLMONEY  = NULL
    ,@OddEvenGameSet5               SMALLMONEY  = NULL
    ,@GameDiffSet1                  SMALLMONEY  = NULL
    ,@GameDiffSet2                  SMALLMONEY  = NULL
    ,@GameDiffSet3                  SMALLMONEY  = NULL
    ,@GameDiffSet4                  SMALLMONEY  = NULL
    ,@GameDiffSet5                  SMALLMONEY  = NULL
    ,@CorrectScoreSet1              NVARCHAR(10)= NULL
    ,@CorrectScoreSet2              NVARCHAR(10)= NULL
    ,@CorrectScoreSet3              NVARCHAR(10)= NULL
    ,@CorrectScoreSet4              NVARCHAR(10)= NULL
    ,@CorrectScoreSet5              NVARCHAR(10)= NULL
    ,@SetxGameyHomeWON              VARCHAR(MAX)= NULL
    ,@SetxGameyAwayWON              VARCHAR(MAX)= NULL
    ,@SetxGameyDRAW                 VARCHAR(MAX)= NULL
    ,@SetxGameyREFUND               VARCHAR(MAX)= NULL
    ,@SetxGameyFinishedGame         VARCHAR(MAX)= NULL
    ,@ResourceIDs                   VARCHAR(MAX)= NULL  
    ,@isRefundHT                    BIT         = NULL
    ,@IsHTCal                       BIT         = NULL
    ,@betcount_1                    INT         = NULL
    ,@betcount_2                    INT         = NULL
    ,@betcount_3                    INT         = NULL
    ,@betcount_20                   INT         = NULL
    ,@betCount_153                  INT         = NULL
    ,@betCount_154                  INT         = NULL
    ,@betCount_155                  INT         = NULL
    ,@betCount_156                  INT         = NULL
    ,@betcount_1301                 INT         = NULL        -- Tennis SS
    ,@betCount_1302                 INT         = NULL
    ,@betCount_1303                 INT         = NULL
    ,@betCount_1305                 INT         = NULL
    ,@betCount_1306                 INT         = NULL
    ,@betCount_1308                 INT         = NULL
    ,@betCount_1311                 INT         = NULL
    ,@betCount_1312                 INT         = NULL
    ,@betCount_1316                 INT         = NULL
    ,@betCount_1317                 INT         = NULL
    ,@betCount_1318                 INT         = NULL
    ,@betCount_1324                 INT         = NULL

    ,@strBettypes                   VARCHAR(MAX)= NULL

    --to do instant calculation
    ,@strTransIds                   VARCHAR(MAX)= NULL

    ,@SelectedQuarter               VARCHAR(50)= NULL

    ,@IsSettleAbandonedMatch        BIT         = 0
    ,@IsSettleAbandonedMatchBetFair BIT         = 0
    ,@IsExcludeBetdaq               BIT         = 0
    ,@IsExcludeBetfair              BIT         = 0
    ,@IsSettleAbandonedMatchIBC     BIT         = 0
    ,@LGOnly                        BIT         = NULL
    ,@IncludeLG                     BIT         = NULL
    ,@matchdate                     DATETIME    = NULL
    ,@xmlData                       VARCHAR(MAX)= NULL
	,@strTransCashout				VARCHAR (MAX) = NULL OUTPUT
    ,@CalledByBrokerService         BIT         = 0
    ,@IsSettingByProfile            BIT 		= NULL
	,@IsReSettledTickets			BIT			= 1

AS
/*
    Created: Viet
    Task : Covered SP for settlement
    Original SP: Admin_Settlement_3
    DB: EXECREP SP (DBTrans_Bet)

    Revisions:
        - 20140304@Kathy: Execute settlement for abandoned/postponed matches- Clean Sheet, Both/One/Neither team to score, To Win To Nil
        - 20140424@Lukas: add DBTP server
        - 20140426@Kathy: Add 1H Total Goal and 1H FGLG bettypes (126, 127) [Redmine:#14449]
        - 20140617@Kathy: Apply BetRadar [Redmine:#17142]
        - 20140710@Kathy: Apply BetRadar - PenaltyShootout(135) [Redmine:#17142]
        - 20140728@Kathy: Settle determined tickets for Correct Score(4,30), Total Goal (6,126) [Redmine:#19310]
        - 20140807@Kathy: Support new 11 bettypes [Redmine:#19667]
        - 20141016@Jamie: Sporting Solution for Tennis [Redmine:#23034]
        - 20150128@Jamie: Hotfix Settlement SS
        - 20150206@Jamie: Auto Settlement Betradar phase 2 [Redmine: #27212]
        - 20150618@Jamie: Offer the option Exclude Corner tickets [Feature #38099]
        - 20150529@Johnson: Add bettrade [Redmine: #35921]
        - 20150919@Kathy: Intergrate Myanmar Odds ( 4 new bettypes: 301->304)
        - 20151019@Kathy: add more param @IsRefundHT for calculate_4 (Refund HT/FT & 2nd FT bettypes in case of match 3x30 [Redmine:#45626])
        - 20151124@Patrick: Apply 28 Live Bettypes for Settlement [Redmine:#47843]
        - 20151207@Patrick: Database - Change datatype [Redmine: #48660]
        - 20160120@Patrick: PH-AiO - Change request [Redmine: #51116]
        - 20160106@Kathy: Integrate Cricket [Redmine:#49727]
        - 20160314@Patrick: Support auto-payout [Redmine: #53262]
        - 20160705@Kathy: PH-AIO phase 2 (67 bettypes ) [Redmine:#53154]
        - 20160824@Bobby: #62921 - Include FGLG (14,127) bet types into CAL/Refund single process
        - 20161010@Bobby: #62003 - Implement instant calculation process
        - 20161108@Kathy: Settlement for new server [Redmine:#66849]
        - 20160428@Patrick: Fast market integration [Redmine: #56367]
        - 20161118@Bobby: #67462 - Implement SDT for Over/Under bettypes full winlost
        - 20161201@Bobby: #68128 - Implement Uncalculate instant settlement process
        - 20170215@Kathy: Basketball All-in-One [Redmine:#71372]
        - 20170317@Bobby: #73404 - Integrate CashOut bettypes
        - 20170614@Kathy: Setup settlement on new DB Servers DBLicAPI2 [Redmine:#77991]
        - 20170613@Kathy: Early Settlement [Redmine:#77835]
        - 20170919@Kathy: Offer new 4 bettypes (461, 462, 463, 464) [Redmine:#83261]
        - 20170815@Kathy: Using table ResultDetail to store FGLG result instead of betstatus [Redmine:#81308]
        - 20171211@Kathy: Do not calculate bettype 22 with old format (betteam:h,a) [Redmine:#80947]
        - 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
        - 20180419@Benjamin: Adding 2 New Bet Types: 465,466 for Asian 1x2 [Redmine:#93654]
        - 20180622@Kathy: Do not settle on server DB042, correct server name DBLicAPI2 to DBLicAPI02 [Redmine#97076]
        - 20180717@Kathy: Allow to UNDO on DB042 [Redmine:#97842]
		- 20181106@Kathy: correct datatype of SetxGameyHomeWON & SetxGameyAwayWON when sending to subscriber [Redmine:#103985]
        - 20181109@Helen: Wrong member balance while doing Cashout /Bettrade at the same time of Instant settle [Redmine:101652]
        - 20180801@Vicky: Incorporate eSports 2.0 [Redmine #95874]
		- 20190315@Kathy: Add 2 new servers DB061, DB062 [Redmine:#110276]
		- 20190320@Kathy: Settlement with Tickets Exclusion [Redmine:#106823]
		- 20190426@Kathy: Remove redundant param on cricket sp [Redmine:#112572]
		- 20190603@Sol: Incorporate PHAIO 4 [Redmine:#112885]
		- 20190620@Kathy: Remove corner, auto betradar bettypes [Redmine:#109584]
		- 20190626@Sol: Incorporate PHAIO 4b - 27 Corners Bet Types [Redmine:#115232]
		- 20190718@Sol: Relocate bettype 22 From early settlement to Main settlement [Redmine:#115232]
		- 20190715@Helen: Recover/Void tickets in Bet 14 - Update statuswinlost for VOID Tickets [Redmine:115377]
		- 20191119@Helen: Do not settle ticket on DB054 [Redmine:#123963]
		- 20191112@Sol: Incorporate PHAIO 5 [Redmine:#121681]
		
    Param's Explanation:
        @action             @mode
        + CAL               CAL, CAL-HT, CAL-FT, UNDO,
        + CAL-FGLG          CAL, CAL-HT, CAL-FT
        + REFUND            ALL, HT, FT, BetDaq, BetFair
        + REFUND-FGLG       REFUND-FT, REFUND-HT
        + CAL-SET           CAL        --Tennis
        + CAL-CORNER
        + CAL-INST          INST-HT,INST-FT
*/
BEGIN
    SET NOCOUNT ON;

    DECLARE @isUndo BIT

    SET @isUndo = CASE
                    WHEN @mode LIKE '%UNDO%' THEN 1
                    WHEN @action LIKE '%UNDO%' THEN 1
                    ELSE 0
                END

    IF @@SERVERNAME IN ('DB054','DB042', 'SITDB042','DB232\SQLSERVER2008R2', 'DB233\SQLSERVER2008R2' ) AND @isUndo = 0
        RETURN

    IF @@SERVERNAME IN ('DB052', 'DB053', 'DB054', 'DB06', 'DBTP', 'DB042', 'DB061', 'DB062'
            , 'DB231', 'DB231\SQLSERVER2008R2', 'DB232', 'DB232\SQLSERVER2008R2'
            , 'DB215', 'DB215\SQLSERVER2008R2', 'DB234', 'DB233\SQLSERVER2008R2'
            , 'SITDB052', 'SITDB053','SITDB06'
            , 'DBLicAPI', 'SITDBLicAPI', 'DBLicAPI02')
        AND @CalledByBrokerService = 0
    BEGIN
        -- DB052/DB053/DB054/DB06: got servicebroker, then just send a message to service broker and then let it to handle the rest.
        DECLARE @sMessage NVARCHAR(MAX)

        SET @sMessage = 'EXEC dbo.NAP_Admin_Calculate_Main @matchid = ' + CONVERT(NVARCHAR(50), @matchid) + '
            ,@mode = ' + CASE
                WHEN @mode IS NULL THEN 'NULL'
                ELSE '''' + CONVERT(NVARCHAR(50), @mode) + ''''
                END + '
            ,@action = ' + CASE
                WHEN @action IS NULL THEN 'NULL'
                ELSE '''' + CONVERT(NVARCHAR(50), @action) + ''''
                END + '
            ,@fth = ' + CASE
                WHEN @fth IS NULL THEN 'NULL'
                ELSE CONVERT(NVARCHAR(50), @fth)
                END + '
            ,@fta = ' + CASE
                WHEN @fta IS NULL THEN 'NULL'
                ELSE CONVERT(NVARCHAR(50), @fta)
                END + '
            ,@hth = ' + CASE
                WHEN @hth IS NULL THEN 'NULL'
                ELSE CONVERT(NVARCHAR(50), @hth)
                END + '
            ,@hta = ' + CASE
                WHEN @hta IS NULL THEN 'NULL'
                ELSE CONVERT(NVARCHAR(50), @hta)
                END
            + CASE WHEN @home_2nd IS NULL THEN '' ELSE ',@home_2nd = ' + CONVERT(NVARCHAR(50), @home_2nd) END
            + CASE WHEN @away_2nd IS NULL THEN '' ELSE ',@away_2nd = ' + CONVERT(NVARCHAR(50), @away_2nd) END
            + CASE WHEN @sporttype IS NULL THEN '' ELSE ',@sporttype = ' + CONVERT(NVARCHAR(50), @sporttype) END
            + CASE WHEN @betstatus IS NULL THEN '' ELSE ',@betstatus = ' + '''' + CONVERT(NVARCHAR(50), @betstatus) + '''' END
            + CASE WHEN @GoalRecord IS NULL THEN '' ELSE ',@GoalRecord = ' + '''' + CONVERT(NVARCHAR(50), @GoalRecord) + '''' END
			+ CASE WHEN @goalsequenceHT IS NULL THEN '' ELSE ',@goalsequenceHT = ' + '''' + CONVERT(NVARCHAR(50), @goalsequenceHT) + '''' END
			+ CASE WHEN @goalsequenceFT IS NULL THEN '' ELSE ',@goalsequenceFT = ' + '''' + CONVERT(NVARCHAR(50), @goalsequenceFT) + '''' END
            + CASE WHEN @matchCode IS NULL THEN '' ELSE ',@matchCode = ' + '''' + CONVERT(NVARCHAR(50), @matchCode) + '''' END
            + CASE WHEN @oddeven IS NULL THEN '' ELSE ',@oddeven = ' + CONVERT(NVARCHAR(50), @oddeven) END
            + CASE WHEN @oddevenht IS NULL THEN '' ELSE ',@oddevenht = ' + CONVERT(NVARCHAR(50), @oddevenht) END
            + CASE WHEN @oddevenhome IS NULL THEN '' ELSE ',@oddevenhome = ' + CONVERT(NVARCHAR(50), @oddevenhome) END
            + CASE WHEN @oddevenhome_ht IS NULL THEN '' ELSE ',@oddevenhome_ht = ' + CONVERT(NVARCHAR(50), @oddevenhome_ht) END
            + CASE WHEN @oddevenaway IS NULL THEN '' ELSE ',@oddevenaway = ' + CONVERT(NVARCHAR(50), @oddevenaway) END
            + CASE WHEN @oddevenaway_ht IS NULL THEN '' ELSE ',@oddevenaway_ht = ' + CONVERT(NVARCHAR(50), @oddevenaway_ht)END
            + CASE WHEN @oddeven_2H IS NULL THEN '' ELSE ',@oddeven_2H = ' + CONVERT(NVARCHAR(50), @oddeven_2H) END
            + CASE WHEN @totalgoal IS NULL THEN '' ELSE ',@totalgoal = ' + CONVERT(NVARCHAR(50), @totalgoal) END
            + CASE WHEN @totalht IS NULL THEN '' ELSE ',@totalht = ' + CONVERT(NVARCHAR(50), @totalht) END
            + CASE WHEN @totalgoal_2H IS NULL THEN '' ELSE ',@totalgoal_2H = ' + CONVERT(NVARCHAR(50), @totalgoal_2H) END
            + CASE WHEN @totalhome IS NULL THEN '' ELSE ',@totalhome = ' + CONVERT(NVARCHAR(50), @totalhome) END
            + CASE WHEN @totalaway IS NULL THEN '' ELSE ',@totalaway = ' + CONVERT(NVARCHAR(50), @totalaway) END
            + CASE WHEN @goaldiff IS NULL THEN '' ELSE ',@goaldiff = ' + CONVERT(NVARCHAR(50), @goaldiff) END
            + CASE WHEN @scorediff IS NULL THEN '' ELSE ',@scorediff = ' + CONVERT(NVARCHAR(50), @scorediff) END
            + CASE WHEN @scorediff_ht IS NULL THEN '' ELSE ',@scorediff_ht = ' + CONVERT(NVARCHAR(50), @scorediff_ht) END
            + CASE WHEN @scorediff_2H IS NULL THEN '' ELSE ',@scorediff_2H = ' + CONVERT(NVARCHAR(50), @scorediff_2H) END
            + CASE WHEN @correctscore IS NULL THEN '' ELSE ',@correctscore = ' + '''' + CONVERT(NVARCHAR(50), @correctscore) + '''' END
            + CASE WHEN @correctscore_ht IS NULL THEN '' ELSE ',@correctscore_ht = ' + '''' + CONVERT(NVARCHAR(50), @correctscore_ht) + '''' END
            + CASE WHEN @correctscore_2h IS NULL THEN '' ELSE ',@correctscore_2h = ' + '''' + CONVERT(NVARCHAR(50), @correctscore_2h) + '''' END
            + CASE WHEN @HTFT IS NULL THEN '' ELSE ',@HTFT = ' + '''' + CONVERT(NVARCHAR(50), @HTFT) + '''' END
            + CASE WHEN @ft_fg IS NULL THEN '' ELSE ',@ft_fg = ' + '''' + CONVERT(NVARCHAR(50), @ft_fg) + '''' END
            + CASE WHEN @ft_lg IS NULL THEN '' ELSE ',@ft_lg = ' + '''' + CONVERT(NVARCHAR(50), @ft_lg) + '''' END
            + CASE WHEN @ht_fg IS NULL THEN '' ELSE ',@ht_fg = ' + '''' + CONVERT(NVARCHAR(50), @ht_fg) + '''' END
            + CASE WHEN @ht_lg IS NULL THEN '' ELSE ',@ht_lg = ' + '''' + CONVERT(NVARCHAR(50), @ht_lg) + '''' END
            + CASE WHEN @TennisTotal IS NULL THEN '' ELSE ',@TennisTotal = ' + CONVERT(NVARCHAR(50), @TennisTotal) END
            + CASE WHEN @T_Home IS NULL THEN '' ELSE ',@T_Home = ' + CONVERT(NVARCHAR(50), @T_Home) END
            + CASE WHEN @T_Away IS NULL THEN '' ELSE ',@T_Away = ' + CONVERT(NVARCHAR(50), @T_Away) END    
            + CASE WHEN @SelectedSet IS NULL THEN '' ELSE ',@SelectedSet = ' + '''' + CONVERT(NVARCHAR(50), @SelectedSet) + '''' END
            + CASE WHEN @SelectedSettleFinishedGame IS NULL THEN '' ELSE ',@SelectedSettleFinishedGame = ' + '''' + CONVERT(NVARCHAR(50), @SelectedSettleFinishedGame) + '''' END
            + CASE WHEN @TotalGameHomeMatch IS NULL THEN '' ELSE ',@TotalGameHomeMatch = ' + CONVERT(NVARCHAR(50), @TotalGameHomeMatch) END
            + CASE WHEN @TotalGameAwayMatch IS NULL THEN '' ELSE ',@TotalGameAwayMatch = ' + CONVERT(NVARCHAR(50), @TotalGameAwayMatch) END
            + CASE WHEN @TotalGameHomeSet1 IS NULL THEN '' ELSE ',@TotalGameHomeSet1 = ' + CONVERT(NVARCHAR(50), @TotalGameHomeSet1) END
            + CASE WHEN @TotalGameHomeSet2 IS NULL THEN '' ELSE ',@TotalGameHomeSet2 = ' + CONVERT(NVARCHAR(50), @TotalGameHomeSet2) END
            + CASE WHEN @TotalGameHomeSet3 IS NULL THEN '' ELSE ',@TotalGameHomeSet3 = ' + CONVERT(NVARCHAR(50), @TotalGameHomeSet3) END
            + CASE WHEN @TotalGameHomeSet4 IS NULL THEN '' ELSE ',@TotalGameHomeSet4 = ' + CONVERT(NVARCHAR(50), @TotalGameHomeSet4) END
            + CASE WHEN @TotalGameHomeSet5 IS NULL THEN '' ELSE ',@TotalGameHomeSet5 = ' + CONVERT(NVARCHAR(50), @TotalGameHomeSet5) END
            + CASE WHEN @TotalGameAwaySet1 IS NULL THEN '' ELSE ',@TotalGameAwaySet1 = ' + CONVERT(NVARCHAR(50), @TotalGameAwaySet1) END
            + CASE WHEN @TotalGameAwaySet2 IS NULL THEN '' ELSE ',@TotalGameAwaySet2 = ' + CONVERT(NVARCHAR(50), @TotalGameAwaySet2) END
            + CASE WHEN @TotalGameAwaySet3 IS NULL THEN '' ELSE ',@TotalGameAwaySet3 = ' + CONVERT(NVARCHAR(50), @TotalGameAwaySet3) END
            + CASE WHEN @TotalGameAwaySet4 IS NULL THEN '' ELSE ',@TotalGameAwaySet4 = ' + CONVERT(NVARCHAR(50), @TotalGameAwaySet4) END
            + CASE WHEN @TotalGameAwaySet5 IS NULL THEN '' ELSE ',@TotalGameAwaySet5 = ' + CONVERT(NVARCHAR(50), @TotalGameAwaySet5) END
            + CASE WHEN @TotalSetMatch IS NULL THEN '' ELSE ',@TotalSetMatch = ' + CONVERT(NVARCHAR(50), @TotalSetMatch) END
            + CASE WHEN @TotalGameSet1 IS NULL THEN '' ELSE ',@TotalGameSet1 = ' + CONVERT(NVARCHAR(50), @TotalGameSet1) END
            + CASE WHEN @TotalGameSet2 IS NULL THEN '' ELSE ',@TotalGameSet2 = ' + CONVERT(NVARCHAR(50), @TotalGameSet2) END
            + CASE WHEN @TotalGameSet3 IS NULL THEN '' ELSE ',@TotalGameSet3 = ' + CONVERT(NVARCHAR(50), @TotalGameSet3) END
            + CASE WHEN @TotalGameSet4 IS NULL THEN '' ELSE ',@TotalGameSet4 = ' + CONVERT(NVARCHAR(50), @TotalGameSet4) END
            + CASE WHEN @TotalGameSet5 IS NULL THEN '' ELSE ',@TotalGameSet5 = ' + CONVERT(NVARCHAR(50), @TotalGameSet5) END
            + CASE WHEN @OddEvenSetMatch IS NULL THEN '' ELSE ',@OddEvenSetMatch = ' + CONVERT(NVARCHAR(50), @OddEvenSetMatch) END
            + CASE WHEN @OddEvenGameSet1 IS NULL THEN '' ELSE ',@OddEvenGameSet1 = ' + CONVERT(NVARCHAR(50), @OddEvenGameSet1) END
            + CASE WHEN @OddEvenGameSet2 IS NULL THEN '' ELSE ',@OddEvenGameSet2 = ' + CONVERT(NVARCHAR(50), @OddEvenGameSet2) END
            + CASE WHEN @OddEvenGameSet3 IS NULL THEN '' ELSE ',@OddEvenGameSet3 = ' + CONVERT(NVARCHAR(50), @OddEvenGameSet3) END
            + CASE WHEN @OddEvenGameSet4 IS NULL THEN '' ELSE ',@OddEvenGameSet4 = ' + CONVERT(NVARCHAR(50), @OddEvenGameSet4) END
            + CASE WHEN @OddEvenGameSet5 IS NULL THEN '' ELSE ',@OddEvenGameSet5 = ' + CONVERT(NVARCHAR(50), @OddEvenGameSet5) END
            + CASE WHEN @GameDiffSet1 IS NULL THEN '' ELSE ',@GameDiffSet1 = ' + CONVERT(NVARCHAR(50),@GameDiffSet1,0) END
            + CASE WHEN @GameDiffSet2 IS NULL THEN '' ELSE ',@GameDiffSet2 = ' + CONVERT(NVARCHAR(50),@GameDiffSet2,0) END
            + CASE WHEN @GameDiffSet3 IS NULL THEN '' ELSE ',@GameDiffSet3 = ' + CONVERT(NVARCHAR(50),@GameDiffSet3,0) END
            + CASE WHEN @GameDiffSet4 IS NULL THEN '' ELSE ',@GameDiffSet4 = ' + CONVERT(NVARCHAR(50),@GameDiffSet4,0) END
            + CASE WHEN @GameDiffSet5 IS NULL THEN '' ELSE ',@GameDiffSet5 = ' + CONVERT(NVARCHAR(50),@GameDiffSet5,0) END
            + CASE WHEN @CorrectScoreSet1 IS NULL THEN '' ELSE ',@CorrectScoreSet1 = ' + '''' + CONVERT(NVARCHAR(50), @CorrectScoreSet1) + '''' END
            + CASE WHEN @CorrectScoreSet2 IS NULL THEN '' ELSE ',@CorrectScoreSet2 = ' + '''' + CONVERT(NVARCHAR(50), @CorrectScoreSet2) + '''' END
            + CASE WHEN @CorrectScoreSet3 IS NULL THEN '' ELSE ',@CorrectScoreSet3 = ' + '''' + CONVERT(NVARCHAR(50), @CorrectScoreSet3) + '''' END
            + CASE WHEN @CorrectScoreSet4 IS NULL THEN '' ELSE ',@CorrectScoreSet4 = ' + '''' + CONVERT(NVARCHAR(50), @CorrectScoreSet4) + '''' END
            + CASE WHEN @CorrectScoreSet5 IS NULL THEN '' ELSE ',@CorrectScoreSet5 = ' + '''' + CONVERT(NVARCHAR(50), @CorrectScoreSet5) + '''' END
            + CASE WHEN @SetxGameyHomeWON IS NULL THEN '' ELSE ',@SetxGameyHomeWON = ' + '''' + @SetxGameyHomeWON + '''' END    
            + CASE WHEN @SetxGameyAwayWON IS NULL THEN '' ELSE ',@SetxGameyAwayWON = ' + '''' + @SetxGameyAwayWON + '''' END    
            + CASE WHEN @SetxGameyDRAW IS NULL THEN '' ELSE ',@SetxGameyDRAW = ' + '''' + @SetxGameyDRAW + '''' END
            + CASE WHEN @SetxGameyREFUND IS NULL THEN '' ELSE ',@SetxGameyREFUND = ' + '''' + @SetxGameyREFUND + '''' END
            + CASE WHEN @SetxGameyFinishedGame IS NULL THEN '' ELSE ',@SetxGameyFinishedGame = ' + '''' + @SetxGameyFinishedGame + '''' END
            + CASE WHEN @ResourceIDs IS NULL THEN '' ELSE ',@ResourceIDs = ' + '''' + @ResourceIDs + '''' END
            + CASE WHEN @WinFromBehind IS NULL THEN '' ELSE ',@WinFromBehind = ' + '''' + @WinFromBehind + '''' END
            + CASE WHEN @isRefundHT IS NULL THEN '' ELSE ',@isRefundHT = ' + CONVERT(NVARCHAR(50),@isRefundHT,0) END
            + CASE WHEN @IsHTCal IS NULL THEN '' ELSE ',@IsHTCal = ' + CONVERT(NVARCHAR(50),@IsHTCal,0) END
            + CASE WHEN @betcount_1 IS NULL THEN '' ELSE ',@betcount_1 = ' + CONVERT(NVARCHAR(50),@betcount_1) END
            + CASE WHEN @betcount_2 IS NULL THEN '' ELSE ',@betcount_2 = ' + CONVERT(NVARCHAR(50), @betcount_2) END
            + CASE WHEN @betcount_3 IS NULL THEN '' ELSE ',@betcount_3 = ' + CONVERT(NVARCHAR(50), @betcount_3) END
            + CASE WHEN @betcount_20 IS NULL THEN '' ELSE ',@betcount_20 = ' + CONVERT(NVARCHAR(50), @betcount_20) END
            + CASE WHEN @betcount_153 IS NULL THEN '' ELSE ',@betcount_153 = ' + CONVERT(NVARCHAR(50),@betcount_153) END
            + CASE WHEN @betCount_154 IS NULL THEN '' ELSE ',@betCount_154 = ' + CONVERT(NVARCHAR(50), @betCount_154) END
            + CASE WHEN @betCount_155 IS NULL THEN '' ELSE ',@betCount_155 = ' + CONVERT(NVARCHAR(50), @betCount_155) END
            + CASE WHEN @betCount_156 IS NULL THEN '' ELSE ',@betCount_156 = ' + CONVERT(NVARCHAR(50), @betCount_156) END
            + CASE WHEN @betCount_1301 IS NULL THEN '' ELSE ',@betcount_1301 = ' + CONVERT(NVARCHAR(50), @betCount_1301) END
            + CASE WHEN @betCount_1302 IS NULL THEN '' ELSE ',@betCount_1302 = ' + CONVERT(NVARCHAR(50), @betCount_1302) END
            + CASE WHEN @betCount_1303 IS NULL THEN '' ELSE ',@betCount_1303 = ' + CONVERT(NVARCHAR(50), @betCount_1303) END
            + CASE WHEN @betCount_1305 IS NULL THEN '' ELSE ',@betCount_1305 = ' + CONVERT(NVARCHAR(50), @betCount_1305) END
            + CASE WHEN @betCount_1306 IS NULL THEN '' ELSE ',@betCount_1306 = ' + CONVERT(NVARCHAR(50), @betCount_1306) END
            + CASE WHEN @betCount_1308 IS NULL THEN '' ELSE ',@betCount_1308 = ' + CONVERT(NVARCHAR(50), @betCount_1308) END
            + CASE WHEN @betCount_1311 IS NULL THEN '' ELSE ',@betCount_1311 = ' + CONVERT(NVARCHAR(50), @betCount_1311) END
            + CASE WHEN @betCount_1312 IS NULL THEN '' ELSE ',@betCount_1312 = ' + CONVERT(NVARCHAR(50), @betCount_1312) END
            + CASE WHEN @betCount_1316 IS NULL THEN '' ELSE ',@betCount_1316 = ' + CONVERT(NVARCHAR(50), @betCount_1316) END
            + CASE WHEN @betCount_1317 IS NULL THEN '' ELSE ',@betCount_1317 = ' + CONVERT(NVARCHAR(50), @betCount_1317) END
            + CASE WHEN @betCount_1318 IS NULL THEN '' ELSE ',@betCount_1318 = ' + CONVERT(NVARCHAR(50), @betCount_1318) END
            + CASE WHEN @betCount_1324 IS NULL THEN '' ELSE ',@betCount_1324 = ' + CONVERT(NVARCHAR(50), @betCount_1324) END

            + CASE WHEN @IsSettleAbandonedMatch IS NULL THEN '' ELSE ',@IsSettleAbandonedMatch = ' + CONVERT(NVARCHAR(50), @IsSettleAbandonedMatch) END
            + CASE WHEN @IsSettleAbandonedMatchBetFair IS NULL THEN '' ELSE ',@IsSettleAbandonedMatchBetFair = ' + CONVERT(NVARCHAR(50), @IsSettleAbandonedMatchBetFair) END
            + CASE WHEN @IsExcludeBetdaq IS NULL THEN '' ELSE ',@IsExcludeBetdaq = ' + CONVERT(NVARCHAR(50), @IsExcludeBetdaq) END
            + CASE WHEN @IsExcludeBetfair IS NULL THEN '' ELSE ',@IsExcludeBetfair = ' + CONVERT(NVARCHAR(50), @IsExcludeBetfair) END
            + CASE WHEN @IsSettleAbandonedMatchIBC IS NULL THEN '' ELSE ',@IsSettleAbandonedMatchIBC = ' + CONVERT(NVARCHAR(50), @IsSettleAbandonedMatchIBC) END
            + CASE WHEN @LGOnly IS NULL THEN '' ELSE ',@LGOnly = ' + CONVERT(NVARCHAR(50), @LGOnly) END
            + CASE WHEN @IncludeLG IS NULL THEN '' ELSE ',@IncludeLG = ' + CONVERT(NVARCHAR(50), @IncludeLG) END
            + CASE WHEN @matchdate IS NULL THEN '' ELSE ',@matchdate = ' + '''' + CONVERT(NVARCHAR(50), @matchdate) + '''' END
            + CASE WHEN @strBettypes IS NULL THEN '' ELSE ',@strBettypes = ''' + CONVERT(VARCHAR(MAX), @strBettypes) + '''' END
            + CASE WHEN @strTransIds IS NULL THEN '' ELSE ',@strTransIds = ''' + CONVERT(VARCHAR(MAX), @strTransIds) + '''' END
            + CASE WHEN @xmlData IS NULL THEN '' ELSE ',@xmlData = ''' + @xmlData + '''' END

            + CASE WHEN @SelectedQuarter IS NULL THEN '' ELSE ',@SelectedQuarter = ' + '''' + CONVERT(NVARCHAR(50), @SelectedQuarter) + '''' END
            + CASE WHEN @IsSettingByProfile IS NULL THEN '' ELSE ',@IsSettingByProfile = ' + CONVERT(NVARCHAR(50), @IsSettingByProfile) END
			 + CASE WHEN @IsReSettledTickets IS NULL THEN '' ELSE ',@IsReSettledTickets = ' + CONVERT(NVARCHAR(50), @IsReSettledTickets) END
            + ',@CalledByBrokerService = 1'

        EXEC [sb].[SBInputMessage] @fromService = N'//Service/Calculation_send'
            ,@toService = N'//Service/Calculation_receive'
            ,@onContract = N'//Contract/Calculation'
            ,@messageType = N'//Message/Calculation'
            ,@messageBody = @sMessage

        RETURN
    END
    ELSE
    BEGIN
        DECLARE @tblBettypes TABLE (bettype SMALLINT PRIMARY KEY)
        DECLARE @xml XML

        IF @IsSettingByProfile IS NOT NULL
        BEGIN
	        IF @action LIKE 'CAL%'
	            EXEC dbo.NAP_Admin_Calculate_TransID
	                  @transIds   		= @strTransIds

            IF @action LIKE 'REFUND%'
	            EXEC dbo.NAP_Admin_Calculate_Refund_TransID
	                   @transIds   		= @strTransIds
	                  
	        IF @action LIKE 'UNDO%'
	            EXEC dbo.NAP_Admin_Calculate_Undo_TransID
	                   @transIds   		= @strTransIds
	        RETURN
        END 
 
        
        IF @action = 'CAL'
        BEGIN
            IF @Mode <> 'UNDO'
            BEGIN
                SET @xml = CONVERT(XML, REPLACE('<root><r t="' + @strBettypes + '"/></root>', ',','"/><r t="'))

                INSERT INTO @tblBettypes (bettype)
                SELECT T.c.value('./@t','SMALLINT')
                FROM @xml.nodes('/root/r') AS T(c)
                OPTION ( OPTIMIZE FOR ( @xml = NULL ) )
            END

            IF @Mode IN ('CAL-FT', 'CAL')
            BEGIN
                
                -- bettype 1 : Handicap
                -- IF @betcount_1 > 0
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 1)
                    EXEC dbo.NAP_Admin_Calculate_1 @matchid = @matchid
                        ,@bettype = 1
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                 -- bettype 16 : HT/FT
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 16)
                    EXEC dbo.NAP_Admin_Calculate_4 @matchid = @matchid
                        ,@bettype = 16
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 17)
                    EXEC dbo.NAP_Admin_Calculate_1 @matchid = @matchid
                        ,@bettype = 17
                        ,@fth = @home_2nd
                        ,@fta = @away_2nd
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 18)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 18
                        ,@totalgoal = @totalgoal_2H
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 20 : Money Line
                -- IF @betcount_20 > 0
                IF @SportType = 154
                BEGIN
                    -- for horse racing fixodds swap win positions to resuse calculating SP
                    IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 20)
                        EXEC dbo.NAP_Admin_Calculate_1 @matchid = @matchid
                            ,@bettype = 20
                            ,@fth = @fta
                            ,@fta = @fth
                            ,@betcount = 1
                END
                ELSE
                    IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 20)
                        EXEC dbo.NAP_Admin_Calculate_1 @matchid = @matchid
                            ,@bettype = 20
                            ,@fth = @fth
                            ,@fta = @fta
                            ,@betcount = 1
							,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 124: FT 1x2 HDP
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 124)
                    EXEC dbo.NAP_Admin_Calculate_1 @matchid = @matchid
                        ,@bettype = 124
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@betcount = 1 ---parametter @betcount has not used, will be removed later
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 2 : Odd/Even
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 2)
                                        EXEC dbo.NAP_Admin_Calculate_2 @matchid = @matchid
                        ,@bettype = 2
                        ,@oddeven = @oddeven
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 3 : Over/Under
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 3)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 3
                        ,@totalgoal = @totalgoal
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 4 : Correct Score
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 4)
                                        EXEC dbo.NAP_Admin_Calculate_4 @matchid = @matchid
                        ,@bettype = 4
                        ,@correctscore = @correctscore
                        ,@goaldiff = @scorediff
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@FGLG2 = NULL
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 5 : 1x2
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 5)
                                        EXEC dbo.NAP_Admin_Calculate_5 @matchid = @matchid
                        ,@bettype = 5
                        ,@whowin = @scorediff
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 6 : Total Goal
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 6)
                                        EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
                        ,@bettype = 6
                        ,@totalgoal = @totalgoal
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 13 : Clean Sheet
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 13)
                                        EXEC dbo.NAP_Admin_Calculate_13 @matchid = @matchid
                        ,@bettype = 13
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 24 : Double Chance
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 24)
                                        EXEC dbo.NAP_Admin_Calculate_24 @matchid = @matchid
                        ,@bettype = 24
                        ,@scorediff = @scorediff
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 25 : Draw no bet
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 25)
                                        EXEC dbo.NAP_Admin_Calculate_25 @matchid = @matchid
                        ,@bettype = 25
                        ,@scorediff = @scorediff
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 26 : Both/One/Neither team to score
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 26)
                                        EXEC dbo.NAP_Admin_Calculate_26 @matchid = @matchid
                        ,@bettype = 26
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 27 : To win to nil
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 27)
                    EXEC dbo.NAP_Admin_Calculate_27 @matchid = @matchid
                        ,@bettype = 27
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 28 : 3-way handicap
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 28)
                    EXEC dbo.NAP_Admin_Calculate_28 @matchid = @matchid
                        ,@bettype = 28
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 121 : Home no bet
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 121)
                                        EXEC dbo.NAP_Admin_Calculate_25 @matchid = @matchid
                        ,@bettype = 121
                        ,@scorediff = @scorediff
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 122 : Away no bet
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 122)
                                        EXEC dbo.NAP_Admin_Calculate_25 @matchid = @matchid
                        ,@bettype = 122
                        ,@scorediff = @scorediff
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 123 : Draw/No Draw
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 123)
                                        EXEC dbo.NAP_Admin_Calculate_25 @matchid = @matchid
                        ,@bettype = 123
                        ,@scorediff = @scorediff
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 133 : Home To Win Both Halves
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 133)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 133
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 134 : Away To win Both halves
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 134)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 134
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 140 : Highest scoring half
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 140)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 140
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 141 : Highest Scoring Half Home Team
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 141)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 141
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 142 : Highest Scoring Half Away Team
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 142)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 142
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 145 : Both Teams To Score
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 145)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 145
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 146 : 2nd Half Both Teams To Score
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 146)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 146
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 147 : Home To Score In Both Halves
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 147)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 147
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets


                -- bettype 148 : Away To Score In Both Halves
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 148)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 148
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 149 : Home To Win Either Half
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 149)
                                EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                    ,@bettype = 149
                    ,@fth = @fth
                    ,@fta = @fta
                    ,@hth = @hth
                    ,@hta = @hta
                    ,@betcount = 1
					,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 150 : Away To Win Either Half
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 150)
                                EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                    ,@bettype = 150
                    ,@fth = @fth
                    ,@fta = @fta
                    ,@hth = @hth
                    ,@hta = @hta
                    ,@betcount = 1
					,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 152 : Half time/Fulltime Correct Score
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 152)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 152
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 128 : HT/FT Odd/Even
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 128)
                                        EXEC dbo.NAP_Admin_Calculate_2 @matchid = @matchid
                        ,@bettype = 128
                        ,@oddeven = @oddeven
                        ,@oddevenht = @oddevenht
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 130 : Exact Goal
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 130)
                                        EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
                        ,@bettype = 130
                        ,@totalgoal = @totalgoal
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 131 : Home Team Total Goal
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 131)
                                        EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
                        ,@bettype = 131
                        ,@totalgoal = @totalhome
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 132 : Away Team Total Goal
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 132)
                                        EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
                        ,@bettype = 132
                        ,@totalgoal = @totalaway
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 137 : Home Team Odd/Even
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 137)
                                        EXEC dbo.NAP_Admin_Calculate_2 @matchid = @matchid
                        ,@bettype = 137
                        ,@oddeven = @oddevenhome
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 139 : Away Team Odd/Even
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 139)
                                        EXEC dbo.NAP_Admin_Calculate_2 @matchid = @matchid
                        ,@bettype = 139
                        ,@oddeven = @oddevenaway
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 144 : Result/Total Goals
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 144)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 144
                        ,@totalgoal = @totalgoal
                        ,@scorediff = @scorediff
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

            --*** Betradar 2: START *****
                -- bettype 157: Odd/Even(3rd)
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 157)
                                        EXEC dbo.NAP_Admin_Calculate_2
                         @matchid = @matchid
                        ,@bettype = 157
                        ,@oddeven = @oddeven
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 159: Exact Total Goals
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 159)
                                        EXEC dbo.NAP_Admin_Calculate_6
                         @matchid = @matchid
                        ,@bettype = 159
                        ,@totalgoal = @totalgoal
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 161:Exact Home Team Goals
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 161)
                                        EXEC dbo.NAP_Admin_Calculate_6
                         @matchid = @matchid
                        ,@bettype = 161
                        ,@totalgoal = @totalhome
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 162:Exact Away Team Goals
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 162)
                                        EXEC dbo.NAP_Admin_Calculate_6
                         @matchid = @matchid
                        ,@bettype = 162
                        ,@totalgoal = @totalaway
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 163:Result/Total Goals (3rd)
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 163)
                    EXEC dbo.NAP_Admin_Calculate_3
                         @matchid = @matchid
                        ,@bettype = 163
                        ,@totalgoal = @totalgoal
                        ,@scorediff = @scorediff
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 166: Extra time correct score
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 166)
                                        EXEC dbo.NAP_Admin_Calculate_4
                         @matchid = @matchid
                        ,@bettype = 166
                        ,@correctscore = @correctscore
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets


                -- bettype 170: Team to Score
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 170)
                                        EXEC dbo.NAP_Admin_Calculate_26
                         @matchid = @matchid
                        ,@bettype = 170
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 171: Winning Margin
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 171)
                    EXEC dbo.NAP_Admin_Calculate_3
                         @matchid = @matchid
                        ,@bettype = 171
                        ,@scorediff = @scorediff
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 172: Result and First Team to Score
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 172)
                                        EXEC dbo.NAP_Admin_Calculate_13
                         @matchid = @matchid
                        ,@bettype = 172
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@ResultString = @ft_fg
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 177 : 2nd Half 1x2
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 177)
                                        EXEC dbo.NAP_Admin_Calculate_5
                         @matchid = @matchid
                        ,@bettype = 177
                        ,@whowin = @scorediff_2H
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 178 : 2nd Over/Under(3rd)
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 178)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 178
                        ,@totalgoal = @totalgoal_2H
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 183 : 2nd Handicap (3rd)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 183)
                    EXEC dbo.NAP_Admin_Calculate_1 @matchid = @matchid
                        ,@bettype = 183
                        ,@fth = @home_2nd
                        ,@fta = @away_2nd
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 184 : 2H Odd/Even
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 184)
                                        EXEC dbo.NAP_Admin_Calculate_2 @matchid = @matchid
                        ,@bettype = 184
                        ,@oddeven = @oddeven_2H
                        ,@oddevenht = NULL
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 185 : 2H Draw No Bet
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 185)
                                        EXEC dbo.NAP_Admin_Calculate_25
                         @matchid = @matchid
                        ,@bettype = 185
                        ,@scorediff = @scorediff_2H
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 186 : 2H Double Chance
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 186)
                                        EXEC dbo.NAP_Admin_Calculate_24
                         @matchid = @matchid
                        ,@bettype = 186
                        ,@scorediff = @scorediff_2H
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 187 : Exact 2H Goals
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 187)
                                        EXEC dbo.NAP_Admin_Calculate_6
                         @matchid = @matchid
                        ,@bettype = 187
                        ,@totalgoal = @totalgoal_2H
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 189 : Both Halves Over 1.5 Yes/No  [189]
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 189)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 189
                        ,@fth = @home_2nd
                        ,@fta = @away_2nd
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 190 : Both Halves Under 1.5 Yes/No
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 190)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 190
                        ,@fth = @home_2nd
                        ,@fta = @away_2nd
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets        
            --*** Betradar 2: END *****

            --Bettrade
                EXEC dbo.NAP_Admin_Calculate_901
                     @matchid = @matchid
                    ,@action = @action
                    ,@mode = @mode
                    ,@isRefundHT = @isRefundHT

                /* FT Myanmar odds*/
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 301)
                    EXEC dbo.NAP_Admin_Calculate_1 @matchid = @matchid
                        ,@bettype = 301
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 302)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 302
                        ,@totalgoal = @totalgoal
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets
            /*END FT Myanmar odds*/

                --Home Team Over/Under
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 401)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 401
                        ,@totalgoal = @totalhome
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                --Home Team Over/Under (dec)
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 461)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 461
                        ,@totalgoal = @totalhome
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                --Away Team Over/Under
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 402)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 402
                        ,@totalgoal = @totalaway
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                --Away Team Over/Under (dec)
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 462)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 462
                        ,@totalgoal = @totalaway
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                --2H Correct Score
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 405)
                                EXEC dbo.NAP_Admin_Calculate_4 @matchid = @matchid
                    ,@bettype = 405
                    ,@correctscore = @correctscore_2h
                    ,@goaldiff = NULL
                    ,@hth = @hth
                    ,@hta = @hta
                    ,@fth = @fth
                    ,@fta = @fta
                    ,@FGLG2 = NULL
                    ,@betcount = 1
					,@IsReSettledTickets = @IsReSettledTickets

                --Exact Total Goals
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 406)
                                        EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
                        ,@bettype = 406
                        ,@totalgoal = @totalgoal
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                --Exact Home Team Goals
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 407)
                                        EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
                        ,@bettype = 407
                        ,@totalgoal = @totalhome
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                --Winning Margin
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 408)
                    EXEC dbo.NAP_Admin_Calculate_3
                         @matchid = @matchid
                        ,@bettype = 408
                        ,@scorediff = @scorediff
                        ,@totalgoal = @totalgoal
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                --Exact Away Team Goals
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 409)
                                        EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
                        ,@bettype = 409
                        ,@totalgoal = @totalaway
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                --Correct Score (aos)
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 413)
                                        EXEC dbo.NAP_Admin_Calculate_4 @matchid = @matchid
                        ,@bettype = 413
                        ,@correctscore = @correctscore
                        ,@goaldiff = @scorediff
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@FGLG2 = NULL
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 415: Result and First Team To Score (own)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 415)
                                        EXEC dbo.NAP_Admin_Calculate_13
                         @matchid = @matchid
                        ,@bettype = 415
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@ResultString = @ft_fg
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 416 : Half Time/Full Time Correct Score (own)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 416)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 416
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 417 : Both Team Score / Result
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 417)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 417
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 418 : Both Teams to Score/ Total Goal
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 418)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 418
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 419 : Which Half First Goal
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 419)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 419
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 420 : Home Team Which Half First Goal
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 420)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 420
                        ,@fth = @fth
                        ,@hth = @hth
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 421 : Away Team Which Half First Goal
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 421)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 421
                        ,@fta = @fta
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 422 : First Team 2 Goals
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 422)
                                        EXEC dbo.NAP_Admin_Calculate_13 @matchid = @matchid
                        ,@bettype = 422
                        ,@ResultString = @GoalRecord
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 423 : First Team 3 Goals
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 423)
                                        EXEC dbo.NAP_Admin_Calculate_13 @matchid = @matchid
                        ,@bettype = 423
                        ,@ResultString = @GoalRecord
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 425 : To Win From Behind
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 425)
                                        EXEC dbo.NAP_Admin_Calculate_13 @matchid = @matchid
                        ,@bettype = 425
                        ,@ResultString = @WinFromBehind
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 428 : 2H Odd/Even (own)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 428)
                                        EXEC dbo.NAP_Admin_Calculate_2 @matchid = @matchid
                        ,@bettype = 428
                        ,@oddeven = @oddeven_2H
                        ,@oddevenht = NULL
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 429 : Exact 2nd Half Goal
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 429)
                                        EXEC dbo.NAP_Admin_Calculate_6
                         @matchid = @matchid
                        ,@bettype = 429
                        ,@totalgoal = @totalgoal_2H
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 430 : 2H 1X2 (own)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 430)
                                        EXEC dbo.NAP_Admin_Calculate_5
                         @matchid = @matchid
                        ,@bettype = 430
                        ,@whowin = @scorediff_2H
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets


                -- bettype 431 : 2H Double Chance (own)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 431)
                                        EXEC dbo.NAP_Admin_Calculate_24
                         @matchid = @matchid
                        ,@bettype = 431
                        ,@scorediff = @scorediff_2H
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 432 : 2H Draw No Bet (own)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 432)
                                        EXEC dbo.NAP_Admin_Calculate_25
                         @matchid = @matchid
                        ,@bettype = 432
                        ,@scorediff = @scorediff_2H
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 433 : 2H Both Teams To Score (own)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 433)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 433
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 434 : Both Halves Over 1.5 Yes/No (own)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 434)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 434
                        ,@fth = @home_2nd
                        ,@fta = @away_2nd
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 435 : Both Halves Under 1.5 Yes/No (own)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 435)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 435
                        ,@fth = @home_2nd
                        ,@fta = @away_2nd
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                 -- bettype 436 : Home To Score In Both Halves (own)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 436)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 436
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 437 : Away To Score In Both Halves (own)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 437)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 437
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 438 : Home To Win Both Halves (own)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 438)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 438
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 439 : Away To Win Both Halves (own)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 439)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 439
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 440 : Home To Win Either Half (own)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 440)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 440
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 441 : Away To Win Either Half (own)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 441)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 441
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 442 : Highest Scoring Half (own)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 442)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 442
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 443 : Highest Scoring Half Home Team (own)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 443)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 443
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 444 : Highest Scoring Half Away Team (own)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 444)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 444
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 445 : Both Team To Score in 1H/ 2H
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 445)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 445
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 446 : Home 1H to Score/ 2H To Score
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 446)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 446
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 447 : Away 1H to Score/ 2H To Score
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 447)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 447
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 501)
                    EXEC dbo.NAP_Admin_Calculate_501 @matchid = @matchid
                        ,@bettype = 501
                        ,@betcount = 1
                        ,@ScoreDiff = @ScoreDiff						

                -- bettype 14 : FT-FGLG
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 14)
                    EXEC dbo.NAP_Admin_Calculate_4 @matchid = @matchid
                        ,@bettype = 14
                        ,@correctscore = @ft_fg
                        ,@FGLG2 = @ft_lg
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- FT Winning Margin 14 Way
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 601)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 601
                        ,@scorediff = @scorediff
                        ,@betcount = 1

                -- FT Winning Margin 12 Way
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 602)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 602
                        ,@scorediff = @scorediff
                        ,@betcount = 1
                -- 458: FT  Asia 1X2
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 458)
                    EXEC dbo.NAP_Admin_Calculate_5 @matchid = @matchid
                        ,@bettype = 458
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- 448: Last Team To Score
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 448)
                    EXEC dbo.NAP_Admin_Calculate_4 @matchid = @matchid
                        ,@bettype = 448
                        ,@FGLG2 = @ft_lg
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- 449: Double Chance & Total Goals
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 449)
                    EXEC dbo.NAP_Admin_Calculate_24 @matchid = @matchid
                        ,@bettype = 449
                        ,@scorediff = @scorediff
                        ,@totalgoal=@totalgoal
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- 450: Odd/Even & Total Goals
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 450)
                    EXEC dbo.NAP_Admin_Calculate_2 @matchid = @matchid
                        ,@bettype = 450
                        ,@oddeven = @oddeven
                        ,@totalgoal = @totalgoal
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- 451: Both Teams To Score / Double Chance
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 451)
                    EXEC dbo.NAP_Admin_Calculate_24 @matchid = @matchid
                        ,@bettype = 451
                        ,@scorediff = @scorediff
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                 -- 452:    Highest Scoring Half (2 Way)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 452)
                    EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 452
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@totalht = @totalht
                        ,@totalgoal_2H = @totalgoal_2H
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                 -- 460: Which Team Will Win By 5+ Goals
                 IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 460)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 460
                        ,@scorediff = @scorediff
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- 454: Double Chance & First Team To Score
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 454)
                    EXEC dbo.NAP_Admin_Calculate_24 @matchid = @matchid
                        ,@bettype = 454
                        ,@scorediff = @scorediff
                        ,@FGLG2 = @ft_fg
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- 465: Asian 1X2 HDP
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 465)
                    EXEC dbo.NAP_Admin_Calculate_1 @matchid = @matchid
                        ,@bettype = 465
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

				-- 467: HT/FT Exact Total Goals	
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 467)
                    EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 467
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@fth = @fth
                        ,@fta = @fta
						,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

				-- 468: Score Box Handicap
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 468)
                    EXEC dbo.NAP_Admin_Calculate_468 @matchid = @matchid
                        ,@bettype = 468
                        ,@fth = @fth
                        ,@fta = @fta
						,@IsReSettledTickets = @IsReSettledTickets

				-- 469: Score Box Over/Under
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 469)
                    EXEC dbo.NAP_Admin_Calculate_468 @matchid = @matchid
                        ,@bettype = 469
                        ,@fth = @fth
                        ,@fta = @fta
						,@IsReSettledTickets = @IsReSettledTickets

				-- Start - Incorporate PHAIO 4b - 27 Corners Bet Types [Redmine:#115232]
				-- bettype 470: Corners Odd/Even (own)
				IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 470)
					EXEC dbo.NAP_Admin_Calculate_2 @matchid = @matchid
						,@bettype = 470
						,@oddeven = @oddeven
						,@oddevenht = NULL
						,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

				-- bettype 472: 2H Corners Odd/Even
				IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 472)
					EXEC dbo.NAP_Admin_Calculate_2 @matchid = @matchid
						,@bettype = 472
						,@oddeven = @oddeven_2H
						,@oddevenht = NULL
						,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

				-- bettype 473: Total Corners
				IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 473)
					EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
						,@bettype = 473
                        ,@totalgoal = @totalgoal
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

				-- bettype 475: Alternative Corners
				IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 475)
					EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
						,@bettype = 475
                        ,@totalgoal = @totalgoal
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets
				
				-- bettype 477 : Corner 3-way handicap
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 477)
                    EXEC dbo.NAP_Admin_Calculate_28 @matchid = @matchid
                        ,@bettype = 477
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

				-- bettype 482: Home Team Corners Over/Under
				IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 482)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 482
                        ,@totalgoal = @totalhome
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

				-- bettype 483: Away Team Corners Over/Under
				IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 483)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 483
                        ,@totalgoal = @totalaway
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

				-- bettype 486	Corners Race
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 486)
					EXEC dbo.NAP_Admin_Calculate_13
                         @matchid = @matchid
                        ,@bettype = 486
                        ,@ResultString = @goalsequenceFT
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

				-- bettype 488	First Corner
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 488)
					EXEC dbo.NAP_Admin_Calculate_13
                         @matchid = @matchid
                        ,@bettype = 488
                        ,@ResultString = @goalsequenceFT
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

				-- bettype 490	2H First Corner
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 490)
					EXEC dbo.NAP_Admin_Calculate_13
                         @matchid = @matchid
                        ,@bettype = 490
                        ,@ResultString = @goalsequenceFT
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

				-- bettype 491	Last Corner
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 491)
					EXEC dbo.NAP_Admin_Calculate_13
                         @matchid = @matchid
                        ,@bettype = 491
                        ,@ResultString = @goalsequenceFT
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

				-- bettype 493: HT/FT Total Corners	
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 493)
                    EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 493
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@fth = @fth
                        ,@fta = @fta
						,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

				-- bettype 495 : 2H Correct Corners
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 495)
                    EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 495
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

				-- bettype 496 : Corner Highest Scoring Half
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 496)
					EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 496
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

				-- bettype 497 : Corner Highest Scoring Half
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 497)
					EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 497
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

				-- bettype 22: Next Goal
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 22)
					EXEC dbo.NAP_Admin_Calculate_13
                         @matchid = @matchid
                        ,@bettype = 22
                        ,@ResultString = @goalsequenceFT
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

				-- End - Incorporate PHAIO 4b - 27 Corners Bet Types [Redmine:#115232]

				-- ##Start - Incorporate PHAIO 5 [Redmine:#121681]

				-- bettype 400: Extra Time Odd/Even
				IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 400)
                        EXEC dbo.NAP_Admin_Calculate_2 @matchid = @matchid
                        ,@bettype = 400
                        ,@oddeven = @oddeven
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

				-- bettype 394: Penalty Shootout Odd/Even (Final Result)
				IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 394)
						EXEC dbo.NAP_Admin_Calculate_2 @matchid = @matchid
						,@bettype = 394
						,@oddeven = @oddeven
						,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

				-- bettype 398: Extra Time Double Chance
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 398)
                        EXEC dbo.NAP_Admin_Calculate_24 @matchid = @matchid
                        ,@bettype = 398
                        ,@scorediff = @scorediff
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

				-- bettype 399: Extra time correct score
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 399)
                         EXEC dbo.NAP_Admin_Calculate_4
                         @matchid = @matchid
                        ,@bettype = 399
                        ,@correctscore = @correctscore
						,@fth = @fth
						,@fta = @fta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

				-- bettype 397: Extra Time Winning Margin
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 397)
                    EXEC dbo.NAP_Admin_Calculate_3
                         @matchid = @matchid
                        ,@bettype = 397
                        ,@scorediff = @scorediff
                        ,@totalgoal = @totalgoal
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

				-- bettype 396: Extra Time Next Goal
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 396)
					EXEC dbo.NAP_Admin_Calculate_13
                         @matchid = @matchid
                        ,@bettype = 396
                        ,@ResultString = @goalsequenceFT
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

				-- bettype 392: Penalty Shootout Correct Score
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 392)
                         EXEC dbo.NAP_Admin_Calculate_4
                         @matchid = @matchid
                        ,@bettype = 392
                        ,@correctscore = @correctscore
						,@fth = @fth
						,@fta = @fta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

				-- bettype 389: Home Penalty Shootout Over/Under (Final Result)
				IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 389)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 389
                        ,@totalgoal = @totalhome
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

				-- bettype 388: Away Penalty Shootout Over/Under (Final Result)
				IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 388)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 388
                        ,@totalgoal = @totalaway
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

				-- ##End - Incorporate PHAIO 5 [Redmine:#121681]

            END -- END CAL/CAL-FT

            IF @Mode IN ('CAL-HT', 'CAL')
                AND @SportType NOT IN (180, 181, 182, 183, 184, 185, 186)
            BEGIN
                -- exec in all cases, both 'FT' and 'HT'
                -- bettype 7 : 1st Handicap
                -- IF @betcount_7 > 0
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 7)
                    EXEC dbo.NAP_Admin_Calculate_7 @matchid = @matchid
                        ,@bettype = 7
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 21: 1st moneyline
                -- IF @betcount_21 > 0
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 21)
                    EXEC dbo.NAP_Admin_Calculate_7 @matchid = @matchid
                        ,@bettype = 21
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 125 : 1st 1x2 Handicap
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 125)
                    EXEC dbo.NAP_Admin_Calculate_7 @matchid = @matchid
                        ,@bettype = 125
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1 ---parametter @betcount has not used, will be removed later
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 8 : 1st Over/Under
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 8)
                                        EXEC dbo.NAP_Admin_Calculate_8 @matchid = @matchid
                        ,@bettype = 8
                        ,@totalht = @totalht
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 12 : 1st Odd/Even
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 12)
                                        EXEC dbo.NAP_Admin_Calculate_2 @matchid = @matchid
                        ,@bettype = 12
                        ,@oddeven = @oddevenht
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 15 : 1st 1x2
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 15)
                                        EXEC dbo.NAP_Admin_Calculate_5 @matchid = @matchid
                        ,@bettype = 15
                        ,@whowin = @scorediff_ht
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 30: 1st Correct Score (Reuse with bettype 4)
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 30)
                                        EXEC dbo.NAP_Admin_Calculate_4 @matchid = @matchid
                        ,@bettype = 30
                        ,@correctscore = @correctscore_ht
                        ,@goaldiff = @scorediff_ht
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@FGLG2 = NULL
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 126 : 1H Total Goal
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 126)
                                        EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
                        ,@bettype = 126
                        ,@totalgoal = @totalht
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 151 : 1st Half Double Chance
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 151)
                                        EXEC dbo.NAP_Admin_Calculate_24 @matchid = @matchid
                        ,@bettype = 151
                        ,@scorediff = @scorediff_ht
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 129 : 1H Exact Goal
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 129)
                                        EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
                        ,@bettype = 129
                        ,@totalgoal = @totalht
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 136 : 1H Home Team Odd/Even
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 136)
                                        EXEC dbo.NAP_Admin_Calculate_2 @matchid = @matchid
                        ,@bettype = 136
                        ,@oddevenht = @oddevenhome_ht
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 138 : 1H Away Team Odd/Even
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 138)
                                        EXEC dbo.NAP_Admin_Calculate_2 @matchid = @matchid
                        ,@bettype = 138
                        ,@oddevenht = @oddevenaway_ht
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 143 : 1H Result/Total Goals
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 143)
                                        EXEC dbo.NAP_Admin_Calculate_8 @matchid = @matchid
                        ,@bettype = 143
                        ,@totalht = @totalht
                        ,@scorediff_ht = @scorediff_ht
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

            --*** Betradar 2: START ****
                -- bettype 165: Extra time 1H correct score
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 165)
                                        EXEC dbo.NAP_Admin_Calculate_4
                         @matchid = @matchid
                        ,@bettype = 165
                        ,@correctscore = @correctscore_ht
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 167 : Extra Time 1H 1X2
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 167)
                                        EXEC dbo.NAP_Admin_Calculate_5 @matchid = @matchid
                        ,@bettype = 167
                        ,@whowin = @scorediff_ht
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 179 : Exact 1H Goal
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 179)
                                        EXEC dbo.NAP_Admin_Calculate_6
                         @matchid = @matchid
                        ,@bettype = 179
                        ,@totalgoal = @totalht
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 181 : 1H Exact Home Team Goals
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 181)
                                        EXEC dbo.NAP_Admin_Calculate_6
                         @matchid = @matchid
                        ,@bettype = 181
                        ,@totalgoal = @hth
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 182 : 1H Exact Away Team Goals
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 182)
                                        EXEC dbo.NAP_Admin_Calculate_6
                         @matchid = @matchid
                        ,@bettype = 182
                        ,@totalgoal = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 188: 1H Both Teams to Score
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 188)
                                        EXEC dbo.NAP_Admin_Calculate_26
                         @matchid = @matchid
                        ,@bettype = 188
                        ,@fth = @hth
                        ,@fta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 191 : 1H Draw no bet
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 191)
                                        EXEC dbo.NAP_Admin_Calculate_25 @matchid = @matchid
                        ,@bettype = 191
                        ,@scorediff = @scorediff_ht
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets
             
            --*** Betradar 2: END ****

                --Bettrade
                EXEC dbo.NAP_Admin_Calculate_901
                     @matchid = @matchid
                    ,@action = @action
                    ,@mode = @mode

                /*HT Myanmar Odds*/
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 303)
                    EXEC dbo.NAP_Admin_Calculate_7 @matchid = @matchid
                        ,@bettype = 303
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 304)
                                        EXEC dbo.NAP_Admin_Calculate_8 @matchid = @matchid
                        ,@bettype = 304
                        ,@totalht = @totalht
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

            /*END HT Myanmar Odds*/

                --1H Home Team Over/Under
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 403)
                                        EXEC dbo.NAP_Admin_Calculate_8 @matchid = @matchid
                        ,@bettype = 403
                        ,@totalht = @hth
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                --1H Home Team Over/Under (dec)
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 463)
                                        EXEC dbo.NAP_Admin_Calculate_8 @matchid = @matchid
                        ,@bettype = 463
                        ,@totalht = @hth
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                --1H Away Team Over/Under
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 404)
                                        EXEC dbo.NAP_Admin_Calculate_8 @matchid = @matchid
                        ,@bettype = 404
                        ,@totalht = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                --1H Away Team Over/Under (dec)
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 464)
                                        EXEC dbo.NAP_Admin_Calculate_8 @matchid = @matchid
                        ,@bettype = 464
                        ,@totalht = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                --1H Double Chance
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 410)
                                        EXEC dbo.NAP_Admin_Calculate_24 @matchid = @matchid
                        ,@bettype = 410
                        ,@scorediff = @scorediff_ht
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                --1H Draw No Bet
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 411)
                                        EXEC dbo.NAP_Admin_Calculate_25 @matchid = @matchid
                        ,@bettype = 411
                        ,@scorediff = @scorediff_ht
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                --Exact 1st Half Goal
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 412)
                                        EXEC dbo.NAP_Admin_Calculate_6
                         @matchid = @matchid
                        ,@bettype = 412
                        ,@totalgoal = @totalht
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                --1H Correct Score (aos)
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 414)
                                        EXEC dbo.NAP_Admin_Calculate_4 @matchid = @matchid
                        ,@bettype = 414
                        ,@correctscore = @correctscore_ht
                        ,@goaldiff = @scorediff_ht
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@FGLG2 = NULL
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets


             -- bettype 426: 1H Winning Margin
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 426)
                                        EXEC dbo.NAP_Admin_Calculate_8
                         @matchid = @matchid
                        ,@bettype = 426
                        ,@scorediff_ht = @scorediff_ht
                        ,@totalht = @totalht
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 427: 1H Both Teams To Score (own)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 427)
                                        EXEC dbo.NAP_Admin_Calculate_26
                         @matchid = @matchid
                        ,@bettype = 427
                        ,@fth = @hth
                        ,@fta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 127: HT-FGLG
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 127)
                    EXEC dbo.NAP_Admin_Calculate_4 @matchid = @matchid
                        ,@bettype = 127
                        ,@correctscore = @ht_fg
                        ,@FGLG2 = @ht_lg
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- 1H Winning Margin 12 Way
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 608)
                    EXEC dbo.NAP_Admin_Calculate_8
                         @matchid = @matchid
                        ,@totalht = NULL
                        ,@bettype = 608
                        ,@scorediff_ht = @scorediff_ht
                        ,@betcount = 1

                 -- bettype 453 : 1H 3-way handicap
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 453)
                    EXEC dbo.NAP_Admin_Calculate_28 @matchid = @matchid
                        ,@bettype = 453
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                 -- bettype 456 : 1H Both Teams To Score / Result
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 456)
                    EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 456
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                 -- bettype 457 : 1H Both Teams To Score / Total Goals
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 457)
                    EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 457
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                 -- bettype 459: 1H Asian 1X2
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 459)
                    EXEC dbo.NAP_Admin_Calculate_5 @matchid = @matchid
                        ,@bettype = 459
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

                -- bettype 466: 1H Asian 1X2 HDP
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 466)
                    EXEC dbo.NAP_Admin_Calculate_7 @matchid = @matchid
                        ,@bettype = 466
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

				-- Start - Incorporate PHAIO 4b - 27 Corners Bet Types [Redmine:#115232]
				-- bettype 471: 1H Corners Odd/Even
				IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 471)
					EXEC dbo.NAP_Admin_Calculate_2 @matchid = @matchid
                        ,@bettype = 471
                        ,@oddeven = NULL
                        ,@oddevenht = @oddevenht
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

				-- bettype 474: 1H Total Corners
				IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 474)
					EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
						,@bettype = 474
                        ,@totalgoal = @totalht
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

				-- bettype 476: 1H Alternative Corners
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 476)
					EXEC dbo.NAP_Admin_Calculate_8 @matchid = @matchid
                        ,@bettype = 476
                        ,@totalht = @totalht
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

				-- bettype 478: 1H 3-way handicap
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 478)
                    EXEC dbo.NAP_Admin_Calculate_28 @matchid = @matchid
                        ,@bettype = 478
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

				-- bettype 484: 1H Home Team Corners Over/Under
				IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 484)
					EXEC dbo.NAP_Admin_Calculate_8 @matchid = @matchid
						,@bettype = 484
						,@totalht = @hth
						,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

				-- bettype 485: 1H Away Team Corners Over/Under
				IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 485)
					EXEC dbo.NAP_Admin_Calculate_8 @matchid = @matchid
						,@bettype = 485
						,@totalht = @hta
						,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets
				
				-- bettype 487	1H Corners Race
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 487)
					EXEC dbo.NAP_Admin_Calculate_13
                         @matchid = @matchid
                        ,@bettype = 487
                        ,@ResultString = @goalsequenceHT
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets
						
				-- bettype 489	1H First Corner
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 489)
					EXEC dbo.NAP_Admin_Calculate_13
                         @matchid = @matchid
                        ,@bettype = 489
                        ,@ResultString = @goalsequenceHT
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets
						
						
				-- bettype 492	1H Last Corner
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 492)
					EXEC dbo.NAP_Admin_Calculate_13
                         @matchid = @matchid
                        ,@bettype = 492
                        ,@ResultString = @goalsequenceHT
						,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets

				-- bettype 494 : 1H Correct Corners
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 494)
                    EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 494
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsReSettledTickets = @IsReSettledTickets
				-- End - Incorporate PHAIO 4b - 27 Corners Bet Types [Redmine:#115232]

            END

            IF @Mode = 'CAL' AND @sporttype = 2
            BEGIN
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 603)
                    EXEC dbo.NAP_Admin_Calculate_603
                        @matchid            = @matchid
                        ,@bettype           = 603
                        ,@result            = @xmlData
                        ,@Action            = @Action

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 604)
                    EXEC dbo.NAP_Admin_Calculate_603
                        @matchid            = @matchid
                        ,@bettype           = 604
                        ,@result            = @xmlData
                        ,@strResourceIds    = @ResourceIds
                        ,@Action            = @Action

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 605)
                    EXEC dbo.NAP_Admin_Calculate_603
                        @matchid            = @matchid
                        ,@bettype           = 605
                        ,@result            = @xmlData
                        ,@strResourceIds    = @ResourceIds
                        ,@Action            = @Action

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 606)
                    EXEC dbo.NAP_Admin_Calculate_603
                        @matchid            = @matchid
                        ,@bettype           = 606
                        ,@result            = @xmlData
                        ,@strResourceIds    = @ResourceIds
                        ,@Action            = @Action

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 607)
                    EXEC dbo.NAP_Admin_Calculate_603
                        @matchid            = @matchid
                        ,@bettype           = 607
                        ,@result            = @xmlData
                        ,@strResourceIds    = @ResourceIds
                        ,@Action            = @Action

                -- Settle selected quarter of Basketball
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 609)
                    EXEC dbo.NAP_Admin_Calculate_603
                        @matchid            = @matchid
                        ,@bettype           = 609
                        ,@result            = @xmlData
                        ,@strResourceIds    = @ResourceIds
                        ,@Action            = @Action

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 610)
                    EXEC dbo.NAP_Admin_Calculate_603
                        @matchid            = @matchid
                        ,@bettype           = 610
                        ,@result            = @xmlData
                        ,@strResourceIds    = @ResourceIds
                        ,@Action            = @Action

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 611)
                    EXEC dbo.NAP_Admin_Calculate_603
                        @matchid            = @matchid
                        ,@bettype           = 611
                        ,@result            = @xmlData
                        ,@strResourceIds    = @ResourceIds
                        ,@Action            = @Mode

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 612)
                    EXEC dbo.NAP_Admin_Calculate_603
                        @matchid            = @matchid
                        ,@bettype           = 612
                        ,@result            = @xmlData
                        ,@strResourceIds    = @ResourceIds
                        ,@Action            = @Action

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 613)
                    EXEC dbo.NAP_Admin_Calculate_603
                        @matchid            = @matchid
                        ,@bettype           = 613
                        ,@result            = @xmlData
                        ,@strResourceIds    = @ResourceIds
                        ,@Action            = @Action

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 614)
                    EXEC dbo.NAP_Admin_Calculate_603
                        @matchid            = @matchid
                        ,@bettype           = 614
                        ,@result            = @xmlData
                        ,@strResourceIds    = @ResourceIds
                        ,@Action            = @Action

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 615)
                    EXEC dbo.NAP_Admin_Calculate_603
                        @matchid            = @matchid
                        ,@bettype           = 615
                        ,@result            = @xmlData
                        ,@strResourceIds    = @ResourceIds
                        ,@Action            = @Action

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 616)
                    EXEC dbo.NAP_Admin_Calculate_603
                        @matchid            = @matchid
                        ,@bettype           = 616
                        ,@result            = @xmlData
                        ,@strResourceIds    = @ResourceIds
                        ,@Action            = @Action

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 617)
                    EXEC dbo.NAP_Admin_Calculate_603
                        @matchid            = @matchid
                        ,@bettype           = 617
                        ,@result            = @xmlData
                        ,@strResourceIds    = @ResourceIds
                        ,@Action            = @Action

            END

            IF @Mode = 'UNDO'
            BEGIN
                EXEC dbo.NAP_Admin_Calculate_Undo
                    @matchid       = @matchid
                    ,@SelectedSet   = @SelectedSet
                    ,@strBettypes   = @strBettypes
                    ,@SelectedQuarter = @SelectedQuarter

                EXEC dbo.NAP_Admin_Calculate_901
                    @matchid = @matchid
                    ,@action = @action
                    ,@mode = @mode
            END
        END

        IF @action = 'CAL-FGLG'
        BEGIN
            SET @xml = CONVERT(XML, REPLACE('<root><r t="' + @strBettypes + '"/></root>', ',','"/><r t="'))

            INSERT INTO @tblBettypes (bettype)
            SELECT T.c.value('./@t','SMALLINT')
            FROM @xml.nodes('/root/r') AS T(c)
            OPTION ( OPTIMIZE FOR ( @xml = NULL ) )

            IF @Mode = 'CAL-HT'
            BEGIN
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 127)
                BEGIN
                    EXEC dbo.NAP_Admin_Calculate_4 @matchid = @matchid
                        ,@bettype = 127
                        ,@correctscore = @ht_fg
                        ,@FGLG2 = @ht_lg

                    EXEC dbo.NAP_Admin_Calculate_901
                         @matchid = @matchid
                        ,@action = @action
                        ,@mode = @mode
                END
            END

            IF @mode = 'CAL-FT'
            BEGIN
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 14)
                    EXEC dbo.NAP_Admin_Calculate_4 @matchid = @matchid
                        ,@bettype = 14
                        ,@correctscore = @ft_fg
                        ,@FGLG2 = @ft_lg

                -- bettype 172: Result and First Team to Score
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 172)
                    EXEC dbo.NAP_Admin_Calculate_13 @matchid = @matchid
                        , @bettype = 172
                        , @fth = @fth
                        , @fta = @fta
                        , @ResultString = @ft_fg
                        , @betcount = 1

                 -- bettype 415: Result and First Team To Score (own)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 415)
                    EXEC dbo.NAP_Admin_Calculate_13
                         @matchid = @matchid
                        ,@bettype = 415
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@ResultString = @ft_fg
                        ,@betcount = 1

                -- bettype 422 : First Team 2 Goals
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 422)
                    EXEC dbo.NAP_Admin_Calculate_13 @matchid = @matchid
                        ,@bettype = 422
                        ,@ResultString = @GoalRecord
                        ,@betcount = 1

                -- bettype 423 : First Team 3 Goals
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 423)
                    EXEC dbo.NAP_Admin_Calculate_13 @matchid = @matchid
                        ,@bettype = 423
                        ,@ResultString = @GoalRecord
                        ,@betcount = 1

                -- bettype 425 : To Win From Behind
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 425)
                    EXEC dbo.NAP_Admin_Calculate_13 @matchid = @matchid
                        ,@bettype = 425
                        ,@ResultString = @WinFromBehind
                        ,@betcount = 1

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes)
                    EXEC dbo.NAP_Admin_Calculate_901
                         @matchid = @matchid
                        ,@action = @action
                        ,@mode = @mode

                -- 448: Last Team To Score
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 448)
                    EXEC dbo.NAP_Admin_Calculate_4 @matchid = @matchid
                        ,@bettype = 448
                        ,@FGLG2 = @ft_lg
                        ,@betcount = 1

                -- 454: Double Chance & First Team To Score
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 454)
                    EXEC dbo.NAP_Admin_Calculate_24 @matchid = @matchid
                        ,@bettype = 454
                        ,@scorediff = @scorediff
                        ,@FGLG2 = @ft_fg
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@betcount = 1

            END
        END

        IF @action = 'CAL-FM'
        BEGIN
            EXEC dbo.NAP_Admin_Calculate_221 @matchid = @matchid
                , @result = @xmlData
                , @action = @Mode -- CAL, REFUND, UNDO
				, @IsReSettledTickets = @IsReSettledTickets
        END

        IF @action ='CAL-SET'  --Tennis including Sportting Solution
        BEGIN
            IF @SelectedSet LIKE '%6%' -- Match Scope
            BEGIN
                IF @betcount_1 > 0  -- Handicap ~ Set Handicap
                    EXEC dbo.NAP_Admin_Calculate_1
                         @matchid = @matchid
                        ,@bettype = 1
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@SelectedSet = @SelectedSet
                        ,@betcount = @betcount_1
                IF @betCount_2 > 0 -- Odd/Even
                                        EXEC dbo.NAP_Admin_Calculate_2
                         @matchid            = @matchid
                        ,@bettype            = 2
                        ,@oddeven            = @oddeven
                        ,@OddEvenSetMatch    = @OddEvenSetMatch
                        ,@totalgoal            = @totalgoal
                        ,@SelectedSet        = @SelectedSet
                        ,@betcount            = @betCount_2
                IF @betCount_3 > 0 -- Match Total Games Over/Under
                    EXEC dbo.NAP_Admin_Calculate_3
                         @matchid        = @matchid
                        ,@bettype        = 3
                        ,@totalgoal        = @totalgoal
                        ,@TotalSetMatch    = @TotalSetMatch
                        ,@SelectedSet    = @SelectedSet
                        ,@betcount        = @betCount_3

                IF @betcount_20 > 0  -- Set Handicap
                    EXEC dbo.NAP_Admin_Calculate_1
                         @matchid = @matchid
                        ,@bettype = 20
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@SelectedSet = @SelectedSet
                        ,@betcount = @betcount_20

                IF @betCount_153 > 0 -- Game Handicap
                    EXEC dbo.NAP_Admin_Calculate_1
                         @matchid = @matchid
                        ,@bettype = 153
                        ,@fth = @TotalGameHomeMatch
                        ,@fta = @TotalGameAwayMatch
                        ,@SelectedSet = @SelectedSet
                        ,@betcount = @betCount_153

                IF @betcount_1301 > 0  -- Match Winner
                    EXEC dbo.NAP_Admin_Calculate_1
                         @matchid = @matchid
                        ,@bettype = 1301
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@SelectedSet = @SelectedSet
                        ,@betcount = @betcount_1301
                IF @betCount_1302 > 0  -- Match Correct Score - Decimal
                                        EXEC dbo.NAP_Admin_Calculate_4
                         @matchid = @matchid
                        ,@bettype = 1302
                        ,@correctscore = @correctscore
                        ,@SelectedSet = @SelectedSet
                        ,@betcount = @betcount_1302

                IF @betcount_1303 > 0  -- Set Handicap
                    EXEC dbo.NAP_Admin_Calculate_1
                         @matchid = @matchid
                        ,@bettype = 1303
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@SelectedSet = @SelectedSet
                        ,@betcount = @betcount_1303

                IF @betCount_1305 > 0 -- Match Total Games Odd/Even
                                        EXEC dbo.NAP_Admin_Calculate_2
                         @matchid    = @matchid
                        ,@bettype    = 1305
                        ,@oddeven    = @oddeven
                        ,@SelectedSet = @SelectedSet
                        ,@betcount = @betcount_1305
                IF @betCount_1306 > 0 -- Match Total Games Over/Under
                    EXEC dbo.NAP_Admin_Calculate_3
                         @matchid = @matchid
                        ,@bettype = 1306
                        ,@totalgoal        = @totalgoal
                        ,@SelectedSet = @SelectedSet
                        ,@betcount = @betCount_1306

                IF @betCount_1308 > 0 -- Game Handicap (3rd)
                    EXEC dbo.NAP_Admin_Calculate_1
                         @matchid = @matchid
                        ,@bettype = 1308
                        ,@fth = @TotalGameHomeMatch
                        ,@fta = @TotalGameAwayMatch
                        ,@SelectedSet = @SelectedSet
                        ,@betcount = @betcount_1308
            END
            ---- END: Match Scope

            --- START: Set(s) Scope
            IF @SelectedSet LIKE '%[1-5]%'
            BEGIN
                IF @betCount_154 > 0 -- Set x Winner
                    EXEC dbo.NAP_Admin_Calculate_1
                                 @matchid            = @matchid
                                ,@bettype            = 154
                                ,@fth                = @fth
                                ,@fta                = @fta
                                ,@SelectedSet        = @SelectedSet
                                ,@TotalGameHomeSet1 = @TotalGameHomeSet1
                                ,@TotalGameHomeSet2 = @TotalGameHomeSet2
                                ,@TotalGameHomeSet3 = @TotalGameHomeSet3
                                ,@TotalGameHomeSet4 = @TotalGameHomeSet4
                                ,@TotalGameHomeSet5 = @TotalGameHomeSet5
                                ,@TotalGameAwaySet1    = @TotalGameAwaySet1
                                ,@TotalGameAwaySet2    = @TotalGameAwaySet2
                                ,@TotalGameAwaySet3    = @TotalGameAwaySet3
                                ,@TotalGameAwaySet4    = @TotalGameAwaySet4
                                ,@TotalGameAwaySet5    = @TotalGameAwaySet5
                                ,@betcount            = @betCount_154

                IF @betCount_155 > 0 -- Set x Game Handicap
                    EXEC dbo.NAP_Admin_Calculate_1
                             @matchid            = @matchid
                            ,@bettype            = 155
                            ,@fth                = @fth
                            ,@fta                = @fta
                            ,@SelectedSet        = @SelectedSet
                            ,@TotalGameHomeSet1 = @TotalGameHomeSet1
                            ,@TotalGameHomeSet2 = @TotalGameHomeSet2
                            ,@TotalGameHomeSet3 = @TotalGameHomeSet3
                            ,@TotalGameHomeSet4 = @TotalGameHomeSet4
                            ,@TotalGameHomeSet5 = @TotalGameHomeSet5
                            ,@TotalGameAwaySet1    = @TotalGameAwaySet1
                            ,@TotalGameAwaySet2    = @TotalGameAwaySet2
                            ,@TotalGameAwaySet3    = @TotalGameAwaySet3
                            ,@TotalGameAwaySet4    = @TotalGameAwaySet4
                            ,@TotalGameAwaySet5    = @TotalGameAwaySet5
                            ,@betcount            = @betCount_155

                IF @betCount_156 > 0 -- Set x Total Games Over/Under
                    EXEC dbo.NAP_Admin_Calculate_3
                             @matchid        = @matchid
                            ,@bettype        = 156
                            ,@SelectedSet    = @SelectedSet
                            ,@TotalGameSet1    = @TotalGameSet1
                            ,@TotalGameSet2    = @TotalGameSet2
                            ,@TotalGameSet3    = @TotalGameSet3
                            ,@TotalGameSet4    = @TotalGameSet4
                            ,@TotalGameSet5    = @TotalGameSet5
                            ,@betcount        = @betCount_156

                IF @betCount_1311 > 0 -- Set x Winner (3rd)
                    EXEC dbo.NAP_Admin_Calculate_1
                             @matchid            = @matchid
                            ,@bettype            = 1311
                            ,@fth                = @fth
                            ,@fta                = @fta
                            ,@SelectedSet        = @SelectedSet
                            ,@TotalGameHomeSet1 = @TotalGameHomeSet1
                            ,@TotalGameHomeSet2 = @TotalGameHomeSet2
                            ,@TotalGameHomeSet3 = @TotalGameHomeSet3
                            ,@TotalGameHomeSet4 = @TotalGameHomeSet4
                            ,@TotalGameHomeSet5 = @TotalGameHomeSet5
                            ,@TotalGameAwaySet1    = @TotalGameAwaySet1
                            ,@TotalGameAwaySet2    = @TotalGameAwaySet2
                            ,@TotalGameAwaySet3    = @TotalGameAwaySet3
                            ,@TotalGameAwaySet4    = @TotalGameAwaySet4
                            ,@TotalGameAwaySet5    = @TotalGameAwaySet5
                            ,@betcount            = @betcount_1311

                IF @betCount_1312 > 0 -- Set x Total Games Over/Under (3rd)
                    EXEC dbo.NAP_Admin_Calculate_3
                             @matchid        = @matchid
                            ,@bettype        = 1312
                            ,@SelectedSet    = @SelectedSet
                            ,@TotalGameSet1    = @TotalGameSet1
                            ,@TotalGameSet2    = @TotalGameSet2
                            ,@TotalGameSet3    = @TotalGameSet3
                            ,@TotalGameSet4    = @TotalGameSet4
                            ,@TotalGameSet5    = @TotalGameSet5
                            ,@betcount        = @betCount_1312
                IF @betCount_1316 > 0 -- Set x Game Handicap (3rd)
                    EXEC dbo.NAP_Admin_Calculate_1
                             @matchid            = @matchid
                            ,@bettype            = 1316
                            ,@SelectedSet        = @SelectedSet
                            ,@TotalGameHomeSet1 = @TotalGameHomeSet1
                            ,@TotalGameHomeSet2 = @TotalGameHomeSet2
                            ,@TotalGameHomeSet3 = @TotalGameHomeSet3
                            ,@TotalGameHomeSet4 = @TotalGameHomeSet4
                            ,@TotalGameHomeSet5 = @TotalGameHomeSet5
                            ,@TotalGameAwaySet1    = @TotalGameAwaySet1
                            ,@TotalGameAwaySet2    = @TotalGameAwaySet2
                            ,@TotalGameAwaySet3    = @TotalGameAwaySet3
                            ,@TotalGameAwaySet4    = @TotalGameAwaySet4
                            ,@TotalGameAwaySet5    = @TotalGameAwaySet5
                            ,@betcount = @betCount_1316
                IF @betCount_1317 > 0 -- Set x Correct Score - - Decimal
                                        EXEC dbo.NAP_Admin_Calculate_4
                         @matchid            = @matchid
                        ,@bettype            = 1317
                        ,@SelectedSet        = @SelectedSet
                        ,@CorrectScoreSet1    = @CorrectScoreSet1
                        ,@CorrectScoreSet2    = @CorrectScoreSet2
                        ,@CorrectScoreSet3    = @CorrectScoreSet3
                        ,@CorrectScoreSet4    = @CorrectScoreSet4
                        ,@CorrectScoreSet5    = @CorrectScoreSet5
                        ,@betcount            = @betCount_1317

                IF @betCount_1318 > 0 -- Set x Total Games Odd/Even
                                        EXEC dbo.NAP_Admin_Calculate_2
                         @matchid            = @matchid
                        ,@bettype            = 1318
                        ,@oddeven            = @oddeven
                        ,@oddevenht            = NULL
                        ,@SelectedSet        = @SelectedSet
                        ,@OddEvenGameSet1    = @OddEvenGameSet1
                        ,@OddEvenGameSet2    = @OddEvenGameSet2
                        ,@OddEvenGameSet3    = @OddEvenGameSet3
                        ,@OddEvenGameSet4    = @OddEvenGameSet4
                        ,@OddEvenGameSet5    = @OddEvenGameSet5
                        ,@betcount            = @betCount_1318

                IF @betCount_1324 > 0 -- Set x Game y Winner
                    EXEC dbo.NAP_Admin_Calculate_1324
                         @matchid            = @matchid
                        ,@bettype            = 1324
                        ,@SelectedSet        = @SelectedSet
                        ,@SetxGameyHomeWON    = @SetxGameyHomeWON
                        ,@SetxGameyAwayWON    = @SetxGameyAwayWON
                        ,@SetxGameyDRAW        = @SetxGameyDRAW
                        ,@SetxGameyREFUND    = @SetxGameyREFUND
                        ,@betcount            = @betCount_1324

            END
        END

        IF @action = 'REFUND'
        BEGIN
            -- For bettype FT ONLY (SDT)
            IF @mode = 'ABANDONED-FT'
            BEGIN
                SET @xml = CONVERT(XML, REPLACE('<root><r t="' + @strBettypes + '"/></root>', ',','"/><r t="'))

                INSERT INTO @tblBettypes (bettype)
                SELECT T.c.value('./@t','SMALLINT')
                FROM @xml.nodes('/root/r') AS T(c)
                OPTION ( OPTIMIZE FOR ( @xml = NULL ) )

                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 128)
                                        EXEC dbo.NAP_Admin_Calculate_2 @matchid = @matchid
                        ,@bettype = 128
                        ,@oddevenht = @oddevenht
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 4)
                                        EXEC dbo.NAP_Admin_Calculate_4 @matchid = @matchid
                        ,@bettype = 4
                        ,@correctscore = NULL
                        ,@goaldiff = NULL
                        ,@FGLG2 = NULL
                        ,@betcount = 1
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 6)
                                        EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
                        ,@bettype = 6
                        ,@totalgoal = @totalgoal
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 3)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 3
                        ,@totalgoal = @totalgoal
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 13)
                                        EXEC dbo.NAP_Admin_Calculate_13 @matchid = @matchid
                        ,@bettype = 13
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                -- Half Time/ Full Time
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 16)
                                        EXEC dbo.NAP_Admin_Calculate_4 @matchid = @matchid
                        ,@bettype = 16
                        ,@betcount = 1
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 26)
                                        EXEC dbo.NAP_Admin_Calculate_26 @matchid = @matchid
                        ,@bettype = 26
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 27)
                    EXEC dbo.NAP_Admin_Calculate_27 @matchid = @matchid
                        ,@bettype = 27
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 130)
                                        EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
                        ,@bettype = 130
                        ,@totalgoal = @totalgoal
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 131)
                                        EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
                        ,@bettype = 131
                        ,@totalgoal = @fth
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 132)
                                        EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
                        ,@bettype = 132
                        ,@totalgoal = @fta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 133)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 133
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 134)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 134
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 140)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 140
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 141)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 141
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 142)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 142
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 144)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 144
                        ,@totalgoal = @totalgoal
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 145)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 145
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 146)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 146
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 147)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 147
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 148)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 148
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 149)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 149
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 150)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 150
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 152)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 152
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal

                -- Betradar 2
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 159)
                                        EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
                        ,@bettype = 159
                        ,@totalgoal = @totalgoal
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 161)
                                        EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
                        ,@bettype = 161
                        ,@totalgoal = @fth
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 162)
                                        EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
                        ,@bettype = 162
                        ,@totalgoal = @fta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 163)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 163
                        ,@totalgoal = @totalgoal
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair


                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 170)
                                        EXEC dbo.NAP_Admin_Calculate_26 @matchid = @matchid
                        ,@bettype = 170
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 172)
                                        EXEC dbo.NAP_Admin_Calculate_13
                            @matchid = @matchid
                        ,@bettype = 172
                        ,@fth = NULL
                        ,@fta = NULL
                        ,@ResultString = @ft_fg
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                --Exact 2nd Half Goals [187]
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 187)
                                        EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
                        ,@bettype = 187
                        ,@totalgoal = @totalgoal_2H
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsHTCal = @IsHTCal

                /* Myanmar odds*/
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 302)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 302
                        ,@totalgoal = @totalgoal
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                --Home Team Over/Under
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 401)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 401
                        ,@totalgoal = @fth
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                --Home Team Over/Under (dec)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 461)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 461
                        ,@totalgoal = @fth
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                --Away Team Over/Under
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 402)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 402
                        ,@totalgoal = @fta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                --Away Team Over/Under (dec)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 462)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 462
                        ,@totalgoal = @fta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                --2H Correct Score
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 405)
                                        EXEC dbo.NAP_Admin_Calculate_4 @matchid = @matchid
                        ,@bettype = 405
                        ,@correctscore = NULL
                        ,@goaldiff = NULL
                        ,@FGLG2 = NULL
                        ,@betcount = 1
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                --Exact Total Goals
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 406)
                                        EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
                        ,@bettype = 406
                        ,@totalgoal = @totalgoal
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                --Exact Home Team Goals
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 407)
                                        EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
                        ,@bettype = 407
                        ,@totalgoal = @fth
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                --Winning Margin
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 408)
                    EXEC dbo.NAP_Admin_Calculate_3
                            @matchid = @matchid
                        ,@bettype = 408
                        ,@scorediff = @scorediff
                        ,@totalgoal = @totalgoal
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                --Exact Away Team Goals
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 409)
                                        EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
                        ,@bettype = 409
                        ,@totalgoal = @fta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                --Correct Score (aos)
                    IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 413)
                                        EXEC dbo.NAP_Admin_Calculate_4 @matchid = @matchid
                        ,@bettype = 413
                        ,@correctscore = NULL
                        ,@goaldiff = NULL
                        ,@FGLG2 = NULL
                        ,@betcount = 1
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                -- Result And First Team To Score (own)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 415)
                                        EXEC dbo.NAP_Admin_Calculate_13
                            @matchid = @matchid
                        ,@bettype = 415
                        ,@fth = NULL
                        ,@fta = NULL
                        ,@ResultString = @ft_fg
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                -- Half Time/Full Time Correct Score (own)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 416)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 416
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal

                -- Both Team Score / Result
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 417)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 417
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                -- Both Teams to Score/ Total Goal
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 418)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 418
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                -- Which Half First Goal
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 419)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 419
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal

                -- Home Team Which Half First Goal
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 420)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 420
                        ,@fth = @fth
                        ,@hth = @hth
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal

                -- Away Team Which Half First Goal
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 421)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 421
                        ,@fta = @fta
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal

                -- First Team 2 Goals
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 422)
                                        EXEC dbo.NAP_Admin_Calculate_13 @matchid = @matchid
                        ,@bettype = 422
                        ,@ResultString = @GoalRecord
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                -- First Team 3 Goals
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 423)
                                        EXEC dbo.NAP_Admin_Calculate_13 @matchid = @matchid
                        ,@bettype = 423
                        ,@ResultString = @GoalRecord
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                -- Exact 2nd Half Goal
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 429)
                                        EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
                        ,@bettype = 429
                        ,@totalgoal = @totalgoal_2H
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsHTCal = @IsHTCal

                -- 2H Both Teams To Score (own)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 433)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 433
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal

                -- Home To Score In Both Halves (own)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 436)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 436
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal


                -- Away To Score In Both Halves (own)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 437)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 437
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal

                -- Home To Win Both Halves (own)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 438)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 438
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal

                -- Away To Win Both Halves (own)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 439)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 439
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal

                -- Home To Win Either Half (own)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 440)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 440
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal

                -- Away To Win Either Half (own)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 441)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 441
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal

                -- Highest Scoring Half (own)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 442)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 442
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal

                -- Highest Scoring Half Home Team (own)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 443)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 443
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal

                -- Highest Scoring Half Away Team (own)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 444)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 444
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal

                -- Both Team To Score in 1H / 2H
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 445)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 445
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal

                -- Home 1H to Score/ 2H To Score
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 446)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 446
                        ,@fth = @fth
                        ,@hth = @hth
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal


                -- Away 1H to Score/ 2H To Score
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 447)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 447
                        ,@fta = @fta
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal

                -- 14: FT-FGLG
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 14)
                    EXEC dbo.NAP_Admin_Calculate_4 @matchid = @matchid
                    ,@bettype = 14
                    ,@correctscore = @ft_fg
                    ,@FGLG2 = @ft_lg
                    ,@betcount = 1
                    ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                    ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                    ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                BEGIN --#67462-Implement SDT for over/under full WL
                --18: 2H Over/Under
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 18)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 18
                        ,@totalgoal = @totalgoal_2H
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                --178: 2H Over/Under (3rd)
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 178)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 178
                        ,@totalgoal = @totalgoal_2H
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                --189: Both Halves Over 1.5 Yes/No
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 189)
                    EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 189
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                --190: Both Halves Under 1.5 Yes/No
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 190)
                    EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 190
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                --434: Both Halves Over 1.5 Yes/No (own)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 434)
                    EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 434
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                --435: Both Halves Under 1.5 Yes/No (own)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 435)
                    EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 435
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                --449: Double Chance & Total Goals
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 449)
                    EXEC dbo.NAP_Admin_Calculate_24 @matchid = @matchid
                        ,@bettype = 449
                        ,@scorediff = @scorediff
                        ,@totalgoal=@totalgoal
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                -- 450: Odd/Even & Total Goals
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 450)
                    EXEC dbo.NAP_Admin_Calculate_2 @matchid = @matchid
                        ,@bettype = 450
                        ,@oddeven = @oddeven
                        ,@totalgoal = @totalgoal
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                -- 451: Both Teams To Score / Double Chance
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 451)
                    EXEC dbo.NAP_Admin_Calculate_24 @matchid = @matchid
                        ,@bettype = 451
                        ,@scorediff = @scorediff
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                -- 452: Highest Scoring Half (2 Way)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 452)
                    EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 452
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@totalht = @totalht
                        ,@totalgoal_2H = @totalgoal_2H
                        ,@betcount = 1
                        ,@IsHTCal = @IsHTCal
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                -- 454: Double Chance & First Team To Score
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 454)
                    EXEC dbo.NAP_Admin_Calculate_24 @matchid = @matchid
                        ,@bettype = 454
                        ,@scorediff = @scorediff
                        ,@FGLG2 = @ft_fg
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                -- 448: Last Team To Score
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 448)
                    EXEC dbo.NAP_Admin_Calculate_4 @matchid = @matchid
                        ,@bettype = 448
                        ,@FGLG2 = @ft_lg
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                END --#67462
                --END OF REFUND: ABANDONED-FT

				-- Half Time/Full Time Exact Total Goals
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 467)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 467
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal

				-- 469: Score Box Over/Under
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 469)
                    EXEC dbo.NAP_Admin_Calculate_468 @matchid = @matchid
                        ,@bettype = 469
                        ,@fth = @fth
                        ,@fta = @fta
						,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
						
				-- Start - Incorporate PHAIO 4b - 27 Corners Bet Types [Redmine:#115232]
				-- bettype 473: Total Corners
				IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 473)
						EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
					,@bettype = 473
								,@totalgoal = @totalgoal
								,@betcount = 1
					,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
					,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
					,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
	
				-- bettype 475: Alternative Corners
				IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 475)
					EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
					,@bettype = 475
								,@totalgoal = @totalgoal
								,@betcount = 1
					,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
					,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
					,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
				
				-- bettype 482: Home Team Over/Under
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 482)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 482
                        ,@totalgoal = @fth
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

				-- bettype 483: Away Team Over/Under
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 483)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 483
                        ,@totalgoal = @fta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

				-- 486	Corners Race
				IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 486)
					EXEC dbo.NAP_Admin_Calculate_13 @matchid = @matchid
                        ,@bettype = 486
						,@ResultString = @goalsequenceFT
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

				-- 488	First Corner
				IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 488)
					EXEC dbo.NAP_Admin_Calculate_13 @matchid = @matchid
                        ,@bettype = 488
                        ,@ResultString = @goalsequenceFT
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

				-- 490	2H First Corner
				IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 490)
					EXEC dbo.NAP_Admin_Calculate_13 @matchid = @matchid
                        ,@bettype = 490
                        ,@ResultString = @goalsequenceFT
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

				-- bettype 493: HT/FT Total Corners	
				IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 493)
					EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 493
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal

				-- bettype 495 : 2H Correct Corners
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 495)
                    EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 495
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@betcount = 1
						,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal

				-- bettype 496: Corner Highest Scoring Half
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 496)
					EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 496
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal

				-- bettype 497: Corner Highest Scoring Half
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 497)
					EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 497
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal

				-- bettype 22: Next Goal
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 22)
					EXEC dbo.NAP_Admin_Calculate_13
                         @matchid = @matchid
                        ,@bettype = 22
                        ,@ResultString = @goalsequenceFT
                        ,@betcount = 1
						,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
				-- End - Incorporate PHAIO 4b - 27 Corners Bet Types [Redmine:#115232]

				-- ##Start - Incorporate PHAIO 5 [Redmine:#121681]

				-- bettype 399: Extra time correct score
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 399)
                         EXEC dbo.NAP_Admin_Calculate_4
                         @matchid = @matchid
                        ,@bettype = 399
                        ,@correctscore = @correctscore
						,@fth = @fth
						,@fta = @fta
                        ,@betcount = 1
						,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

				-- bettype 397: Extra Time Winning Margin
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 397)
                    EXEC dbo.NAP_Admin_Calculate_3
                         @matchid = @matchid
                        ,@bettype = 397
                        ,@scorediff = @scorediff
                        ,@totalgoal = @totalgoal
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

				-- bettype 396: Extra Time Next Goal
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 396)
					EXEC dbo.NAP_Admin_Calculate_13
                         @matchid = @matchid
                        ,@bettype = 396
                        ,@ResultString = @goalsequenceFT
                        ,@betcount = 1
						,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

				-- bettype 392: Penalty Shootout Correct Score
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 392)
                         EXEC dbo.NAP_Admin_Calculate_4
                         @matchid = @matchid
                        ,@bettype = 392
                        ,@correctscore = @correctscore
						,@fth = @fth
						,@fta = @fta
                        ,@betcount = 1
						,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

				-- bettype 389: Home Penalty Shootout Over/Under (Final Result)
				IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 389)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 389
                        ,@totalgoal = @totalhome
                        ,@betcount = 1
						,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

				-- bettype 388: Away Penalty Shootout Over/Under (Final Result)
				IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 388)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 388
                        ,@totalgoal = @totalaway
                        ,@betcount = 1
						,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

				-- ##End - Incorporate PHAIO 5 [Redmine:#121681]

            END

            IF @mode = 'REFUND-FT'
            BEGIN
                EXEC dbo.NAP_Admin_Calculate_RefundFT @matchid = @matchid
                    ,@IsExcludeBetdaq = @IsExcludeBetdaq
                    ,@IsExcludeBetfair = @IsExcludeBetfair
                    ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                    ,@strBettypes = @strBettypes

                EXEC dbo.NAP_Admin_Calculate_Refund_901
                    @matchid                    = @matchid
                    ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                    ,@action                    = @action
                    ,@mode                      = @mode
            END

            -- Only for match 3x30, bettype = 8: Betdaq & Betfairs
            IF @mode = 'ABANDONED-HT'
            BEGIN
                EXEC dbo.NAP_Admin_Calculate_8 @matchid = @matchid
                    ,@bettype = 8
                    ,@totalht = @totalht
                    ,@betcount = 1
                    ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                    ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                    ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
            END

            IF @mode = 'REFUND-HT'
            BEGIN
                EXEC dbo.NAP_Admin_Calculate_RefundHT @matchid = @matchid
                    ,@IsExcludeBetdaq = @IsExcludeBetdaq
                    ,@IsExcludeBetfair = @IsExcludeBetfair
                    ,@strBettypes = @strBettypes

                EXEC dbo.NAP_Admin_Calculate_Refund_901
                    @matchid = @matchid
                    ,@action = @action
                    ,@mode   = @mode
            END

            --For bettype 1H & Refund All (SDT)
            IF @mode = 'ABANDONED'
            BEGIN
                SET @xml = CONVERT(XML, REPLACE('<root><r t="' + @strBettypes + '"/></root>', ',','"/><r t="'))

                INSERT INTO @tblBettypes (bettype)
                SELECT T.c.value('./@t','SMALLINT')
                FROM @xml.nodes('/root/r') AS T(c)
                OPTION ( OPTIMIZE FOR ( @xml = NULL ) )

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 3) AND (@SelectedSet IS NULL OR @SelectedSet LIKE '%6%')
                    EXEC dbo.NAP_Admin_Calculate_3
                         @matchid = @matchid
                        ,@bettype = 3
                        ,@totalgoal = @totalgoal
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 4)
                                        EXEC dbo.NAP_Admin_Calculate_4
                         @matchid = @matchid
                        ,@bettype = 4
                        ,@correctscore = NULL
                        ,@goaldiff = NULL
                        ,@FGLG2 = NULL
                        ,@betcount = 1
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 6)
                                        EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
                        ,@bettype = 6
                        ,@totalgoal = @totalgoal
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 8)
                    EXEC dbo.NAP_Admin_Calculate_8 @matchid = @matchid
                        ,@bettype = 8
                        ,@totalht = @totalht
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 13)
                                        EXEC dbo.NAP_Admin_Calculate_13 @matchid = @matchid
                        ,@bettype = 13
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 26)
                                        EXEC dbo.NAP_Admin_Calculate_26 @matchid = @matchid
                        ,@bettype = 26
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 27)
                    EXEC dbo.NAP_Admin_Calculate_27 @matchid = @matchid
                        ,@bettype = 27
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 30)
                                        EXEC dbo.NAP_Admin_Calculate_4 @matchid = @matchid
                        ,@bettype = 30
                        ,@correctscore = NULL
                        ,@goaldiff = NULL
                        ,@FGLG2 = NULL
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 126)
                                        EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
                        ,@bettype = 126
                        ,@totalgoal = @totalht
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 129)
                                        EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
                        ,@bettype = 129
                        ,@totalgoal = @totalht
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 130)
                                        EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
                        ,@bettype = 130
                        ,@totalgoal = @totalgoal
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 131)
                                        EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
                        ,@bettype = 131
                        ,@totalgoal = @fth
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 132)
                                        EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
                        ,@bettype = 132
                        ,@totalgoal = @fta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 143)
                                        EXEC dbo.NAP_Admin_Calculate_8 @matchid = @matchid
                        ,@bettype = 143
                        ,@totalht = @totalht
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 144)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 144
                        ,@totalgoal = @totalgoal
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 145)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 145
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 152)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 152
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal


                -- Betradar 2
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 159)
                                        EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
                        ,@bettype = 159
                        ,@totalgoal = @totalgoal
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 161)
                                        EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
                        ,@bettype = 161
                        ,@totalgoal = @fth
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 162)
                                        EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
                        ,@bettype = 162
                        ,@totalgoal = @fta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 163)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 163
                        ,@totalgoal = @totalgoal
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 170)
                                        EXEC dbo.NAP_Admin_Calculate_26 @matchid = @matchid
                        ,@bettype = 170
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 172)
                                        EXEC dbo.NAP_Admin_Calculate_13
                         @matchid = @matchid
                        ,@bettype = 172
                        ,@fth = NULL
                        ,@fta = NULL
                        ,@ResultString = @ft_fg
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 179)
                                        EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
                        ,@bettype = 179
                        ,@totalgoal = @totalht
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 181)
                                        EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
                        ,@bettype = 181
                        ,@totalgoal = @hth
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 182)
                                        EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
                        ,@bettype = 182
                        ,@totalgoal = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 188)
                                        EXEC dbo.NAP_Admin_Calculate_26 @matchid = @matchid
                        ,@bettype = 188
                        ,@fth = @hth
                        ,@fta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                -- Set x Game y Winner
                IF @betcount_1324 > 0
                    EXEC dbo.NAP_Admin_Calculate_1324
                         @matchid                        = @matchid
                        ,@bettype                        = 1324
                        ,@SelectedSet                    = @SelectedSet
                        ,@SelectedSettleFinishedGame    = @SelectedSettleFinishedGame
                        ,@SetxGameyHomeWON                = @SetxGameyHomeWON
                        ,@SetxGameyAwayWON                = @SetxGameyAwayWON
                        ,@SetxGameyDRAW                    = @SetxGameyDRAW
                        ,@SetxGameyFinishedGame            = @SetxGameyFinishedGame
                        ,@betcount                        = 1

                /*Myanmar odds*/
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 302)
                    EXEC dbo.NAP_Admin_Calculate_3
                         @matchid = @matchid
                        ,@bettype = 302
                        ,@totalgoal = @totalgoal
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 304)
                                        EXEC dbo.NAP_Admin_Calculate_8 @matchid = @matchid
                        ,@bettype = 304
                        ,@totalht = @totalht
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                --Home Team Over/Under
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 401)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 401
                        ,@totalgoal = @fth
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                --Home Team Over/Under (dec)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 461)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 461
                        ,@totalgoal = @fth
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                --Away Team Over/Under
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 402)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 402
                        ,@totalgoal = @fta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                --Away Team Over/Under (dec)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 462)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 462
                        ,@totalgoal = @fta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                --1H Home Team Over/Under
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 403)
                                        EXEC dbo.NAP_Admin_Calculate_8 @matchid = @matchid
                        ,@bettype = 403
                        ,@totalht = @hth
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                --1H Home Team Over/Under (dec)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 463)
                                        EXEC dbo.NAP_Admin_Calculate_8 @matchid = @matchid
                        ,@bettype = 463
                        ,@totalht = @hth
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                --1H Away Team Over/Under
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 404)
                                        EXEC dbo.NAP_Admin_Calculate_8 @matchid = @matchid
                        ,@bettype = 404
                        ,@totalht = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                --1H Away Team Over/Under (dec)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 464)
                                        EXEC dbo.NAP_Admin_Calculate_8 @matchid = @matchid
                        ,@bettype = 464
                        ,@totalht = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                --Exact Total Goals
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 406)
                                        EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
                        ,@bettype = 406
                        ,@totalgoal = @totalgoal
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                --Exact Home Team Goals
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 407)
                                        EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
                        ,@bettype = 407
                        ,@totalgoal = @fth
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                --Winning Margin
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 408)
                    EXEC dbo.NAP_Admin_Calculate_3
                         @matchid = @matchid
                        ,@bettype = 408
                        ,@scorediff = @scorediff
                        ,@totalgoal = @totalgoal
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                --Exact Away Team Goals
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 409)
                                        EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
                        ,@bettype = 409
                        ,@totalgoal = @fta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                --Exact 1st Half Goal
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 412)
                                        EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
                        ,@bettype = 412
                        ,@totalgoal = @totalht
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                --Correct Score (aos)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 413)
                                        EXEC dbo.NAP_Admin_Calculate_4
                         @matchid = @matchid
                        ,@bettype = 413
                        ,@correctscore = NULL
                        ,@goaldiff = NULL
                        ,@FGLG2 = NULL
                        ,@betcount = 1
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                --1H Correct Score (aos)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 414)
                                        EXEC dbo.NAP_Admin_Calculate_4 @matchid = @matchid
                        ,@bettype = 414
                        ,@correctscore = NULL
                        ,@goaldiff = NULL
                        ,@FGLG2 = NULL
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                -- Result And First Team To Score (own)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 415)
                                        EXEC dbo.NAP_Admin_Calculate_13
                         @matchid = @matchid
                        ,@bettype = 415
                        ,@fth = NULL
                        ,@fta = NULL
                        ,@ResultString = @ft_fg
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                -- Half Time/Full Time Correct Score (own)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 416)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 416
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal

                -- Both Team Score / Result
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 417)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 417
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                -- Both Teams to Score/ Total Goal
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 418)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 418
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                -- Which Half First Goal
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 419)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 419
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                -- Home Team Which Half First Goal
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 420)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 420
                        ,@fth = @fth
                        ,@hth = @hth
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                -- Away Team Which Half First Goal
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 421)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 421
                        ,@fta = @fta
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                -- First Team 2 Goals
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 422)
                                        EXEC dbo.NAP_Admin_Calculate_13 @matchid = @matchid
                        ,@bettype = 422
                        ,@ResultString = @GoalRecord
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                -- First Team 3 Goals
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 423)
                                        EXEC dbo.NAP_Admin_Calculate_13 @matchid = @matchid
                        ,@bettype = 423
                        ,@ResultString = @GoalRecord
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                -- 1H Winning Margin
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 426)
                                        EXEC dbo.NAP_Admin_Calculate_8 @matchid = @matchid
                        ,@bettype = 426
                        ,@totalht = @totalht
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                 -- 1H Both Team to Score (own)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 427)
                                        EXEC dbo.NAP_Admin_Calculate_26 @matchid = @matchid
                        ,@bettype = 427
                        ,@fth = @hth
                        ,@fta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

                -- Both Team To Score in 1H / 2H
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 445)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 445
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal

                -- Home 1H to Score/ 2H To Score
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 446)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 446
                        ,@fth = @fth
                        ,@hth = @hth
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal

                -- Away 1H to Score/ 2H To Score
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 447)
                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 447
                        ,@fta = @fta
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal

                -- 14: FT-FGLG
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 14)
                    EXEC dbo.NAP_Admin_Calculate_4 @matchid = @matchid
                    ,@bettype = 14
                    ,@correctscore = @ft_fg
                    ,@FGLG2 = @ft_lg
                    ,@betcount = 1
                    ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                    ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                    ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                -- 127: HT-FGLG
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 127)
                    EXEC dbo.NAP_Admin_Calculate_4 @matchid = @matchid
                    ,@bettype = 127
                    ,@correctscore = @ht_fg
                    ,@FGLG2 = @ht_lg
                    ,@betcount = 1
                    ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                    ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                    ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                BEGIN --#67462-Implement SDT for over/under full WL
                --190: Both Halves Under 1.5 Yes/No
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 190)
                    EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 190
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair 
            
                --435: Both Halves Under 1.5 Yes/No (own)
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 435)
                    EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 435
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                 -- 456: 1H Both Teams To Score / Result
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 456)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 456
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                 -- 456: 1H Both Teams To Score / Total Goals
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 457)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 457
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                --449: Double Chance & Total Goals
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 449)
                    EXEC dbo.NAP_Admin_Calculate_24 @matchid = @matchid
                        ,@bettype = 449
                        ,@scorediff = @scorediff
                        ,@totalgoal=@totalgoal
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                -- 450: Odd/Even & Total Goals
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 450)
                    EXEC dbo.NAP_Admin_Calculate_2 @matchid = @matchid
                        ,@bettype = 450
                        ,@oddeven = @oddeven
                        ,@totalgoal = @totalgoal
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                -- 451: Both Teams To Score / Double Chance
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 451)
                    EXEC dbo.NAP_Admin_Calculate_24 @matchid = @matchid
                        ,@bettype = 451
                        ,@scorediff = @scorediff
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                -- 454: Double Chance & First Team To Score
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 454)
                    EXEC dbo.NAP_Admin_Calculate_24 @matchid = @matchid
                        ,@bettype = 454
                        ,@scorediff = @scorediff
                        ,@FGLG2 = @ft_fg
                        ,@betcount = 1
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                -- 448: Last Team To Score
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 448)
                    EXEC dbo.NAP_Admin_Calculate_4 @matchid = @matchid
                        ,@bettype = 448
                        ,@FGLG2 = @ft_lg
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

                END --#67462
                -- END of mode = 'ABANDONED': For bettype 1H & Refund All (SDT)

				-- Half Time/Full Time Exact Total Goals
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 467)
                                        EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 467
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal
				
				-- 469: Score Box Over/Under
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 469)
                    EXEC dbo.NAP_Admin_Calculate_468 @matchid = @matchid
                        ,@bettype = 469
                        ,@fth = @fth
                        ,@fta = @fta
						,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
				
				-- Start - Incorporate PHAIO 4b - 27 Corners Bet Types [Redmine:#115232]
				-- bettype 473: Total Corners
				IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 473)
					EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
						,@bettype = 473
						,@totalgoal = @totalgoal
						,@betcount = 1
						,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
						,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
						,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
						,@IsReSettledTickets = @IsReSettledTickets

				-- bettype 474: 1H Total Corners
	  			IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 474)
	  				EXEC dbo.NAP_Admin_Calculate_6 @matchid = @matchid
						,@bettype = 474
						,@totalgoal = @totalht
						,@betcount = 1
						,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
						,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
						,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

				-- bettype 475: Alternative Corners
				IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 475)				
					EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
						,@bettype = 475
						,@totalgoal = @totalht
						,@betcount = 1
						,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
						,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
						,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

				-- bettype 476 : 1H Alternative Corners
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 476)
					EXEC dbo.NAP_Admin_Calculate_8 @matchid = @matchid
                        ,@bettype = 476
                        ,@totalht = @totalht
                        ,@betcount = 1
						,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
						,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
						,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

				-- bettype 482: Home Team Over/Under
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 482)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 482
                        ,@totalgoal = @fth
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

				-- bettype 483: Away Team Over/Under
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 483)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 483
                        ,@totalgoal = @fta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

				-- bettype 484: 1H Home Team Corners Over/Under
				IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 484)
					EXEC dbo.NAP_Admin_Calculate_8 @matchid = @matchid
						,@bettype = 484
						,@totalht = @hth
						,@betcount = 1
						,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

				-- bettype 485: 1H Away Team Corners Over/Under
				IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 485)
					EXEC dbo.NAP_Admin_Calculate_8 @matchid = @matchid
						,@bettype = 485
						,@totalht = @hta
						,@betcount = 1
						,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
				
				-- 486	Corners Race
				IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 486)
					EXEC dbo.NAP_Admin_Calculate_13 @matchid = @matchid
                        ,@bettype = 486
                        ,@ResultString = @goalsequenceFT
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

				-- 487	1H Corners Race
				IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 487)
					EXEC dbo.NAP_Admin_Calculate_13 @matchid = @matchid
                        ,@bettype = 487
                        ,@ResultString = @goalsequenceHT
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

				-- 488	First Race
				IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 488)
					EXEC dbo.NAP_Admin_Calculate_13 @matchid = @matchid
                        ,@bettype = 488
                        ,@ResultString = @goalsequenceFT
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

				-- 489	1H First Corner
				IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 489)
					EXEC dbo.NAP_Admin_Calculate_13 @matchid = @matchid
                        ,@bettype = 489
                        ,@ResultString = @goalsequenceHT
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

				-- bettype 493: HT/FT Total Corners	
				IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 493)
					EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 493
                        ,@fth = @fth
                        ,@fta = @fta
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsHTCal = @IsHTCal

				-- bettype 494 : 1H Correct Corners
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 494)
                    EXEC dbo.NAP_Admin_Calculate_9999 @matchid = @matchid
                        ,@bettype = 494
                        ,@hth = @hth
                        ,@hta = @hta
                        ,@betcount = 1
						,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
						,@IsHTCal = @IsHTCal

				-- bettype 22: Next Goal
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 22)
					EXEC dbo.NAP_Admin_Calculate_13
                         @matchid = @matchid
                        ,@bettype = 22
                        ,@ResultString = @goalsequenceFT
                        ,@betcount = 1
						,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

				-- End - Incorporate PHAIO 4b - 27 Corners Bet Types [Redmine:#115232]

				-- ##Start - Incorporate PHAIO 5 [Redmine:#121681]

				-- bettype 399: Extra time correct score
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 399)
                         EXEC dbo.NAP_Admin_Calculate_4
                         @matchid = @matchid
                        ,@bettype = 399
						,@fth = @fth
						,@fta = @fta
                        ,@betcount = 1
						,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

				-- bettype 397: Extra Time Winning Margin
                IF EXISTS (SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 397)
                    EXEC dbo.NAP_Admin_Calculate_3
                         @matchid = @matchid
                        ,@bettype = 397
                        ,@scorediff = @scorediff
                        ,@totalgoal = @totalgoal
                        ,@betcount = 1
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                        ,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair

				-- bettype 396: Extra Time Next Goal
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 396)
					EXEC dbo.NAP_Admin_Calculate_13
                         @matchid = @matchid
                        ,@bettype = 396
                        ,@ResultString = @goalsequenceFT
                        ,@betcount = 1
						,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

				-- bettype 392: Penalty Shootout Correct Score
                IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 392)
                         EXEC dbo.NAP_Admin_Calculate_4
                         @matchid = @matchid
                        ,@bettype = 392
						,@fth = @fth
						,@fta = @fta
                        ,@betcount = 1
						,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

				-- bettype 389: Home Penalty Shootout Over/Under (Final Result)
				IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 389)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 389
                        ,@totalgoal = @fth
                        ,@betcount = 1
						,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

				-- bettype 388: Away Penalty Shootout Over/Under (Final Result)
				IF EXISTS(SELECT TOP 1 1 FROM @tblBettypes WHERE bettype = 388)
                    EXEC dbo.NAP_Admin_Calculate_3 @matchid = @matchid
                        ,@bettype = 388
                        ,@totalgoal = @fta
                        ,@betcount = 1
						,@IsSettleAbandonedMatch = @IsSettleAbandonedMatch
                        ,@IsSettleAbandonedMatchBetFair = @IsSettleAbandonedMatchBetFair
                        ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

				-- ##End - Incorporate PHAIO 5 [Redmine:#121681]

            END

            IF @mode = 'REFUND'
            BEGIN
                
                    EXEC dbo.NAP_Admin_Calculate_RefundAll
                     @matchid                    = @matchid
                    ,@IsExcludeBetdaq            = @IsExcludeBetdaq
                    ,@IsExcludeBetfair            = @IsExcludeBetfair
                    ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                    ,@SelectedSet                = @SelectedSet
                    ,@SelectedSettleFinishedGame= @SelectedSettleFinishedGame
                    ,@SetxGameyFinishedGame        = @SetxGameyFinishedGame
                    ,@strBettypes                   = @strBettypes
                    ,@SelectedQuarter           = @SelectedQuarter

                EXEC dbo.NAP_Admin_Calculate_Refund_901
                    @matchid                    = @matchid
                    ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC
                    ,@action                    = @action
                    ,@mode                      = @mode
                

            END

            IF @mode = 'BetDaq'
            BEGIN
                EXEC dbo.NAP_Admin_Calculate_Refund_BetDaq @matchid = @matchid
            END

            IF @mode = 'BetFair'
            BEGIN
                EXEC dbo.NAP_Admin_Calculate_Refund_BetFair @matchid = @matchid
            END

            IF @mode = 'REFUND-EARLY'
            BEGIN
                EXEC [dbo].[NAP_Admin_Calculate_603]
                    @matchid            = @MatchId
                    ,@strResourceIds    = @ResourceIds
                    ,@Action            = @Action
            END
        END

        IF @action = 'REFUND-FGLG'
        BEGIN
            EXEC dbo.NAP_Admin_Calculate_RefundFGLG @matchid = @matchid
                ,@action = @mode
                ,@LGOnly = @LGOnly
                ,@matchdate = @matchdate
                ,@IsExcludeBetdaq   = @IsExcludeBetdaq
                ,@IsExcludeBetfair  = @IsExcludeBetfair
                ,@IsSettleAbandonedMatchIBC = @IsSettleAbandonedMatchIBC

            EXEC dbo.NAP_Admin_Calculate_Refund_901
                @matchid = @matchid
                ,@action = @action
                ,@mode   = @mode
                ,@LGOnly = @LGOnly
        END

        IF @action IN ('CAL-INST', 'UNDO-INST')
        BEGIN
             EXEC dbo.NAP_Admin_InstantCalculate_3
                @matchid        = @matchid
                ,@action        = @action
                ,@strTransIds   = @strTransIds
                ,@strTransCashout = @strTransCashout OUTPUT
        END

        IF @Action = 'UNDO'
        BEGIN
            IF @Mode = 'UNDO-EARLY'
            BEGIN
                EXEC [dbo].[NAP_Admin_Calculate_603]
                    @matchid            = @MatchId
                    ,@strResourceIds    = @ResourceIds
                    ,@Action            = @Action
            END

        END
        -- CashOut integration
        IF (
            (@Action IN ('CAL') AND @Mode IN ('CAL-FT', 'CAL-HT', 'CAL', 'UNDO'))
            OR (@Action IN ('REFUND') AND @Mode IN ('REFUND-HT', 'REFUND-FT', 'REFUND'))
        )
        BEGIN
            EXEC dbo.NAP_Admin_Calculate_911
                @matchid        = @matchid
                ,@action        = @action
                ,@mode          = @mode
                ,@strBettypes   = @strBettypes
                ,@ResourceIDs   = @ResourceIDs
        END
    END
    
END
GO