/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchSelDetail]
	@matchid 				INT
    , @IsRefundPage 		BIT = 0
AS
/*
    Created by: 20120913
    Task: Update score 
    DB: DBTXN/BODB02 
    Original: [Acc_Set_MatchSelScore], Acc_Set_MatchSelForBill
    
    Revisions:            
        - 20140304@Kathy: Execute settlement for abandoned/postponed matches- Clean Sheet, Both/One/Neither team to score, To Win To Nil 
        - 20140423@Kathy: Remove check weekend peak-hour
        - 20140506@Kathy: Add IsExistHTFGLG, IsExistHTLG column. Offer new bettype 126, 127 (1H total goal, 1H FGLG) [Redmine:#14449]
        - 20140729@Kathy: Add one more account(BF3) into BetFair's group [Redmine:#19665]
        - 20140623@Kathy: Apply BetRadar - Add new bettype 151 (1st Half Double Chance) [Redmine:#17142]
        - 20140710@Kathy: Apply BetRadar - bettype 135 (PenaltyShootout) - check PS status [Redmine:#17142]
        - 20140725@Kathy: Settle determined tickets for Correct Score(4,30)[Redmine:#19310]
        - 20140811@Kathy: Support new 11 bettypes [Redmine:#19667]
        - 20140905@Kathy: exclude virtual racing bettype 1231,1232,1233
        - 20140909@Kathy: Exclude virtual racing (bettype 1237, 1238), outright (bettype 10, 31, 32, 33),
                         sportting solution (from 1301 -> 1334), keno (1501 -> 1599)
        - 20141008@Jamie: Sportting Solution settlement [Redmine: #23034]
        - 20141204@Jamie: Sportting Solution settlement - GameSession to indicate the type of league [Redmine:#27027]
        - 20150401@Jamie: Auto Settlement Betradar phase 2 [Redmine: #27212]
        - 20150406@Jamie: Manual Settlement Betradar phase 2 [Redmine: #27212]
        - 20150602@Jamie: DisplayCat = 8 ExtraTime 
        - 20150611@Jamie: Remove the contrainst  DisplayCat = 8 ExtraTime 
        - 20150618@Jamie: Offer the option Exclude Corner tickets [Feature #38099]
        - 20150811@Johnson: exclude bettrade tickets from sportbook [Redmine: #35921]
		- 20150727@Johnson: Exclude range bettype of Metric Gaming from SB settlement [RedmineID: #37688]
		- 20150918@Johnson: Check existing bettrade tickets [Redmined: #43234]
		- 20150919@Kathy: Intergrate Myanmar Odds ( 4 new bettypes: 301->304)
		- 20151127@Patrick: Apply 28 Live Bettypes for Settlement [Redmine:#47843]
		- 20151207@Patrick: Database - Change datatype [Redmine: #48660]
		- 20160120@Patrick: PH-AiO - Change request [Redmine: #51116]
		- 20160315@Patrick: Auto payout [Redmine: #53262]
		- 20160705@Kathy: PH-AIO phase 2 (67 bettypes ) [Redmine:#53154]
		- 20160808@Kathy: BetTrade - changes for new commercial terms - add bettype 904 [Redmine:#61905]
		- 20160823@Bobby: #62870 - Include FGLG bet types into HT/FT match status
		- 20161006@Bobby: #65001 - Update changes for implementing instant calculation 
		- 20160428@Kathy: Exclude Fast Market bettypes [Redmine:#56367]
		- 20161006@Bobby: #61352 - Implement SDT for parlay tickets
		- 20170329@Kathy: Change refer score from DBTRANS to DBPRO [Redmine:#74259]
		- 20170215@Kathy: Basketball All-in-One [Redmine:#71372]
		- 20170525@Kathy: Not allow to cal FT basketball when have tickets of bettype 603 and quarters has not been calculated [Redmine:#77046]
		- 20170609@Kathy: Remove "early settled" bettypes from Calculation popup [Redmine:#77835]
		- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
		- 20171201@Kathy: Remove the checkbox "Settle determined tickets" on Refund popup page [Redmine:#86890]
		- 20180801@Vicky: Incorporate eSports 2.0 [Redmine #95874]
		- 20190320@Kathy: Settlement with Tickets Exclusion [Redmine:#106823]
		- 20190509@Kathy: Add group 0 for default if match do not have any ticket [Redmine:#99638]
		- 20190523@Sol: Auto Payout Phase 3 - Removed @IsAutoCalculatePage param [Redmine:#116073]
		- 20190620@Kathy: Remove betradar corner bettypes [Redmine:#109584]
		- 20200120@Sol:	Settlement with Ticket Exclusion for Other Sports - [Redmine:#126963]
		- 20200227@Sol: Show Result of SBO on Main Calculate & Main Popup for Soccer - [Redmine:#129780]
		- 20200417@Sol: Ticket Exclusion for Other Sports - Phase 4: Remaining Sports of Other Sports [Redmine:#131765]
		- 20200701@Kathy: get all ticket instead of exclude status Refund in Refund popup [Redmine:#134840]
		- 20200901@Louisa: get calculated score in the second dataset [Redmine:#139979]
		- 20200908@Louisa: get ResultDetail at DBPRO [Redmine:#139979]
		- 20201209@Kathy: Add 10 Upcoming Sports for OS [Redmine:#145816]
		- 20201211@Louisa: remove unused code [Redmine:#146239]
		- 20201208@Louisa: Child match: get ET and PEN matches [Redmine:#145597]
		- 20210514@Kathy: Incorporate Saba Soccer PinGoal [Redmine:#155052]
		- 20210524@Louisa: SOP for Badminton, Basketball [Redmine:#155361,#155360]
		- 20211108@Louisa: In-house Replicator: Delete Action [Redmine:#164393] 

*/
BEGIN
    SET NOCOUNT ON

    DECLARE @IsExistFGLG			BIT
        ,@IsHTOnly					BIT
        ,@IsLive					BIT
		,@SettleAbandonedMatchIBCParlay TINYINT
        ,@sporttype					SMALLINT
        ,@IsExistHTFGLG				BIT
        ,@FTStatus					NVARCHAR(50)
        ,@HTStatus					NVARCHAR(50)
        ,@2HStatus					NVARCHAR(50)
        ,@FGLGStatus				NVARCHAR(50)
        ,@HTFGLGStatus				NVARCHAR(50)
        ,@LeagueID					INT
		,@LeagueGroupID				SMALLINT
        
        -- Tennis Settlement 
        ,@TennisStatusSet1			NVARCHAR(20)
        ,@TennisStatusSet2			NVARCHAR(20)
        ,@TennisStatusSet3			NVARCHAR(20)
        ,@TennisStatusSet4			NVARCHAR(20)
        ,@TennisStatusSet5			NVARCHAR(20)
        ,@TennisStatusMatch			NVARCHAR(20)    -- Match Scope 

        ,@isExistResultandFirstTeamScore    BIT
				
		--Bettrade
		,@isExistBettrade			BIT
		
		,@IsEnabledGoalRecordHT		BIT
		,@IsEnabledGoalRecordFT		BIT
		,@eventstatus				VARCHAR(20)
		
		-- Basketball
		,@StatusQuarter1	NVARCHAR(20)
		,@StatusQuarter2	NVARCHAR(20)
		,@StatusQuarter3	NVARCHAR(20)
		,@StatusQuarter4	NVARCHAR(20)
		
		,@isExistFTHighestQuarter BIT
	
	--- Get ET  match and PEN match for soccer
	DECLARE @tmp_ChildMatch TABLE (Matchid	INT, matchcode	NVARCHAR(100),	eventstatus	NVARCHAR(100),	SettlementStatus TINYINT, BetStatus NVARCHAR(100), IsExistMarkedTicket BIT, IsExistRunningTicket BIT)
		
	DECLARE @tmpBettypes TABLE (bettype SMALLINT, GroupId TINYINT, IsUsedGoalRecordValue BIT, IsDetermined BIT, GroupName VARCHAR(50), IsFGLG BIT)
	INSERT INTO @tmpBettypes (bettype, GroupId, IsUsedGoalRecordValue, IsDetermined, GroupName, IsFGLG)
	SELECT	BetType, GroupId, IsUsedGoalRecordValue, IsDetermined, GroupName, IsFGLG
	FROM	dbo.[f_Set_GetGroupBettypes]()
	WHERE	IsAuto = 0

    SELECT 
         @IsExistFGLG = 0
        ,@IsHTOnly = 0
        ,@IsLive = 0
		,@SettleAbandonedMatchIBCParlay = 0
        ,@IsExistHTFGLG = 0
        ,@isExistResultandFirstTeamScore = 0 
		,@isExistBettrade		= 0
		,@IsEnabledGoalRecordHT = 0
		,@IsEnabledGoalRecordFT = 0
		,@isExistFTHighestQuarter = 0

    SELECT @sporttype 	= m.sporttype
		,@LeagueID    	= m.leagueid
		,@eventstatus	= m.eventstatus
		,@LeagueGroupID = ISNULL(l.LeagueGroupID,0)
    FROM   DBPRO.bodb02.dbo.match m WITH (NOLOCK)
	INNER JOIN  DBPRO.bodb02.dbo.League l WITH(NOLOCK) ON m.leagueid = l.leagueid
    WHERE  m.matchid = @matchid
	
	DECLARE @tmpMarkedTransaction TABLE (
		bettype SMALLINT
		,betMarkedCount INT
	)

	CREATE TABLE #Data (
		bettype			SMALLINT 
		,isParlay		BIT 
		,InRunning		INT
		,Waiting_cnt	INT
		,betcount		INT
		,betRunningCount INT
		,betSettledCount INT
		,betMarkedCount INT 
		,InRunningParlay INT
		,WaitingParlay_cnt INT
		,betcountParlay	INT
		,ExistLG		BIT
		,ExistHTLG		BIT
		,IsLive			BIT
		
		-- Tennis, Basketball: Q1, Q2, Q3, Q4
		,InRunningSet1 	INT
		,InRunningSet2 	INT
		,InRunningSet3 	INT
		,InRunningSet4 	INT
		,InRunningSet5 	INT
		
		,BetCountSet1 	INT
		,BetCountSet2 	INT
		,BetCountSet3 	INT
		,BetCountSet4 	INT
		,BetCountSet5 	INT

		,BetMarkedCountSet1 INT
		,BetMarkedCountSet2 INT
		,BetMarkedCountSet3 INT
		,BetMarkedCountSet4 INT
		,BetMarkedCountSet5 INT

		, PRIMARY KEY (bettype,isParlay)
	)
	
	INSERT INTO #Data (bettype, isParlay
		, InRunning,Waiting_cnt, betcount, betRunningCount, betSettledCount, betMarkedCount
		, InRunningParlay,WaitingParlay_cnt, betcountParlay
		, IsLive		
		, InRunningSet1, InRunningSet2, InRunningSet3, InRunningSet4, InRunningSet5
		, BetCountSet1, BetCountSet2, BetCountSet3, BetCountSet4, BetCountSet5
		, BetMarkedCountSet1 ,BetMarkedCountSet2 ,BetMarkedCountSet3 ,BetMarkedCountSet4 ,BetMarkedCountSet5
		)
	SELECT	b.bettype, 0 isParlay
			,MAX(CASE WHEN b.statusID = 0 AND mt.TransId IS NULL THEN 1 ELSE 0 END) AS InRunning
			,SUM(CASE WHEN b.statusID = 1 THEN 1 ELSE 0 END) AS Waiting_cnt
			,COUNT(1) AS betcount
			,SUM(CASE WHEN b.statusID = 0 AND mt.TransId IS NULL THEN 1 ELSE 0 END) AS betRunningCount
			,SUM(CASE WHEN b.statusID BETWEEN 111 AND 113 OR b.statusID = 103 THEN 1 ELSE 0 END) AS betSettledCount
			,SUM(CASE WHEN b.statusID BETWEEN 0 AND 1 AND mt.TransId IS NOT NULL THEN 1 ELSE 0 END) AS betMarkedCount
			,0 InRunningParlay,0 WaitingParlay_cnt, 0 betcountParlay
			,MAX(CASE WHEN b.liveindicator = 1 THEN 1 ELSE 0 END) AS IsLive
			
			,MAX(CASE WHEN (@sporttype = 5 OR (@sporttype = 2 AND b.bettype BETWEEN 609 AND 616 AND mt.TransId IS NULL)) AND CAST(betid AS VARCHAR(20)) LIKE '801%' AND statusID = 0 THEN 1 ELSE 0 END) AS InRunningSet1
			,MAX(CASE WHEN (@sporttype = 5 OR (@sporttype = 2 AND b.bettype BETWEEN 609 AND 616 AND mt.TransId IS NULL)) AND CAST(betid AS VARCHAR(20)) LIKE '802%' AND statusID = 0 THEN 1 ELSE 0 END) AS InRunningSet2
			,MAX(CASE WHEN (@sporttype = 5 OR (@sporttype = 2 AND b.bettype BETWEEN 609 AND 616 AND mt.TransId IS NULL)) AND CAST(betid AS VARCHAR(20)) LIKE '803%' AND statusID = 0 THEN 1 ELSE 0 END) AS InRunningSet3
			,MAX(CASE WHEN (@sporttype = 5 OR (@sporttype = 2 AND b.bettype BETWEEN 609 AND 616 AND mt.TransId IS NULL)) AND CAST(betid AS VARCHAR(20)) LIKE '804%' AND statusID = 0 THEN 1 ELSE 0 END) AS InRunningSet4
			,MAX(CASE WHEN @sporttype = 5 AND CAST(betid AS VARCHAR(20)) LIKE '805%' AND statusID = 0 THEN 1 ELSE 0 END) AS InRunningSet5		
			,SUM(CASE WHEN (@sporttype = 5 OR (@sporttype = 2 AND b.bettype BETWEEN 609 AND 616)) AND CAST(betid AS VARCHAR(20)) LIKE '801%' THEN 1 ELSE 0 END) AS BetCountSet1
			,SUM(CASE WHEN (@sporttype = 5 OR (@sporttype = 2 AND b.bettype BETWEEN 609 AND 616)) AND CAST(betid AS VARCHAR(20)) LIKE '802%' THEN 1 ELSE 0 END) AS BetCountSet2
			,SUM(CASE WHEN (@sporttype = 5 OR (@sporttype = 2 AND b.bettype BETWEEN 609 AND 616)) AND CAST(betid AS VARCHAR(20)) LIKE '803%' THEN 1 ELSE 0 END) AS BetCountSet3
			,SUM(CASE WHEN (@sporttype = 5 OR (@sporttype = 2 AND b.bettype BETWEEN 609 AND 616)) AND CAST(betid AS VARCHAR(20)) LIKE '804%' THEN 1 ELSE 0 END) AS BetCountSet4
			,SUM(CASE WHEN CAST(betid AS VARCHAR(20)) LIKE '805%' THEN 1 ELSE 0 END) AS BetCountSet5

			,SUM(CASE WHEN (@sporttype = 5 OR (@sporttype = 2 AND b.bettype BETWEEN 609 AND 616)) AND CAST(betid AS VARCHAR(20)) LIKE '801%' AND statusID BETWEEN 0 AND 1 AND mt.TransId IS NOT NULL THEN 1 ELSE 0 END) AS BetMarkedCountSet1
			,SUM(CASE WHEN (@sporttype = 5 OR (@sporttype = 2 AND b.bettype BETWEEN 609 AND 616)) AND CAST(betid AS VARCHAR(20)) LIKE '802%' AND statusID BETWEEN 0 AND 1 AND mt.TransId IS NOT NULL THEN 1 ELSE 0 END) AS BetMarkedCountSet2
			,SUM(CASE WHEN (@sporttype = 5 OR (@sporttype = 2 AND b.bettype BETWEEN 609 AND 616)) AND CAST(betid AS VARCHAR(20)) LIKE '803%' AND statusID BETWEEN 0 AND 1 AND mt.TransId IS NOT NULL THEN 1 ELSE 0 END) AS BetMarkedCountSet3
			,SUM(CASE WHEN (@sporttype = 5 OR (@sporttype = 2 AND b.bettype BETWEEN 609 AND 616)) AND CAST(betid AS VARCHAR(20)) LIKE '804%' AND statusID BETWEEN 0 AND 1 AND mt.TransId IS NOT NULL THEN 1 ELSE 0 END) AS BetMarkedCountSet4
			,SUM(CASE WHEN @sporttype = 5 AND CAST(betid AS VARCHAR(20)) LIKE '805%' AND statusID BETWEEN 0 AND 1 AND mt.TransId IS NOT NULL THEN 1 ELSE 0 END) AS BetMarkedCountSet5
	FROM	dbo.bettrans b WITH(NOLOCK)
				OUTER APPLY (
					SELECT TOP 1 mt.TransId
					FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
					WHERE	mt.TransId = b.transId
				)mt
	WHERE	b.matchid = @matchid
			AND b.statusID NOT IN (101, 102)
			--AND 1 = CASE 
			--			WHEN @IsRefundPage = 1 AND b.statusID = 103 THEN 0
			--			ELSE 1
			--		END
	GROUP BY b.bettype
	
	UNION ALL
	
	SELECT	bm.bettype, 1 isParlay
			,0 AS InRunning
			,0 AS Waiting_cnt
			,0 AS betcount
			,0 AS betRunningCount
			,0 AS betSettledCount
			,0 AS betMarkedCount
			,MAX(CASE WHEN statusID = 0 THEN 1 ELSE 0 END) InRunningParlay
			,SUM(CASE WHEN statusID = 1 THEN 1 ELSE 0 END) WaitingParlay_cnt
			,COUNT(1) betcountParlay
			,MAX(CASE WHEN liveindicator = 1 THEN 1 ELSE 0 END) AS IsLive
			,0 AS InRunningSet1
			,0 AS InRunningSet2
			,0 AS InRunningSet3
			,0 AS InRunningSet4
			,0 AS InRunningSet5		
			,0 AS BetCountSet1
			,0 AS BetCountSet2
			,0 AS BetCountSet3
			,0 AS BetCountSet4
			,0 AS BetCountSet5

			,0 AS BetMarkedCountSet1
			,0 AS BetMarkedCountSet2
			,0 AS BetMarkedCountSet3
			,0 AS BetMarkedCountSet4
			,0 AS BetMarkedCountSet5
	FROM	dbo.bettransm bm WITH(NOLOCK)
	WHERE	matchid = @matchid
			AND statusID NOT IN (101, 102)
			--AND 1 = CASE 
			--			WHEN @IsRefundPage = 1 AND statusID = 103 THEN 0
			--			ELSE 1
			--		END
	GROUP BY bm.bettype
	
	SELECT	
			 -- 14F, 14L; GroupID = 4: bettype 14; -- 127F, 127L; GroupID = 3: bettype 127
			 @IsExistFGLG =  MAX(CASE WHEN f.GroupId IN (2,4) AND f.IsFGLG = 1 THEN 1 ELSE 0 END)
			,@IsExistHTFGLG = MAX(CASE WHEN f.GroupId IN (1,3) AND f.IsFGLG = 1 THEN 1 ELSE 0 END)
			
			,@isExistResultandFirstTeamScore = MAX(CASE WHEN f.BetType = 172 THEN 1 ELSE 0 END)
		
			,@IsEnabledGoalRecordHT = MAX(CASE WHEN f.GroupId IN (1,3) AND f.IsUsedGoalRecordValue = 1 THEN 1 ELSE 0 END)
			,@IsEnabledGoalRecordFT = MAX(CASE WHEN f.GroupId IN (2,4) AND f.IsUsedGoalRecordValue = 1 THEN 1 ELSE 0 END) 
			
			,@isExistBettrade = MAX(CASE WHEN b.bettype BETWEEN 901 AND 910 THEN 1 ELSE 0 END) 
			,@IsLive = MAX(CASE WHEN b.IsLive = 1 THEN 1 ELSE 0 END)
			
			,@isExistFTHighestQuarter = MAX(CASE WHEN f.BetType = 603 THEN 1 ELSE 0 END)
	FROM	#Data b
		LEFT JOIN @tmpBettypes f
			ON b.bettype = f.BetType

	SELECT	@IsExistFGLG = CASE WHEN @IsExistFGLG > 0 THEN @IsExistFGLG ELSE MAX(CASE WHEN f.GroupId = 4 THEN 1 ELSE 0 END) END
			,@IsExistHTFGLG = CASE WHEN @IsExistHTFGLG > 0 THEN @IsExistHTFGLG ELSE MAX(CASE WHEN f.GroupId = 3 THEN 1 ELSE 0 END) END
			,@isExistResultandFirstTeamScore = CASE WHEN @isExistResultandFirstTeamScore > 0 THEN @isExistResultandFirstTeamScore ELSE MAX(CASE WHEN f.BetType = 172 THEN 1 ELSE 0 END) END
			
			,@IsEnabledGoalRecordHT = CASE WHEN @IsEnabledGoalRecordHT > 0 THEN @IsEnabledGoalRecordHT ELSE MAX(CASE WHEN f.GroupId IN (1,3) AND f.IsUsedGoalRecordValue = 1 THEN 1 ELSE 0 END) END
			,@IsEnabledGoalRecordFT = CASE WHEN @IsEnabledGoalRecordFT > 0 THEN @IsEnabledGoalRecordFT ELSE MAX(CASE WHEN f.GroupId IN (2,4) AND f.IsUsedGoalRecordValue = 1 THEN 1 ELSE 0 END) END		
			,@isExistFTHighestQuarter = CASE WHEN @isExistFTHighestQuarter > 0 THEN @isExistFTHighestQuarter ELSE MAX(CASE WHEN f.BetType = 603 THEN 1 ELSE 0 END) END
	FROM	dbo.bettransm bm WITH(NOLOCK)
		INNER JOIN @tmpBettypes f
			ON	bm.bettype = f.bettype
	WHERE	matchid = @matchid
			AND statusID NOT IN (101, 102)
			--AND 1 = CASE 
			--			WHEN @IsRefundPage = 1 AND statusID = 103 THEN 0
			--			ELSE 1
			--		END
	
    IF @IsRefundPage = 0 -- Calculate page
    BEGIN	
		DECLARE @status TABLE (GroupId TINYINT, BetCount INT, betRunningCount INT, betSettledCount INT, betMarkedCount INT
			, InRunning INT, Waiting_cnt INT, BetCountParlay INT, InRunningParlay INT, WaitingParlay_cnt INT
			, InRunningSet1 INT, InRunningSet2 	INT, InRunningSet3 	INT, InRunningSet4 	INT, InRunningSet5 	INT	
			, BetCountSet1 	INT, BetCountSet2 	INT, BetCountSet3 	INT, BetCountSet4 	INT, BetCountSet5 	INT
			, BetMarkedCountSet1 INT, BetMarkedCountSet2 INT, BetMarkedCountSet3 INT, BetMarkedCountSet4 INT, BetMarkedCountSet5 INT
		)
		
        -- check match status
		INSERT INTO @status (GroupId, BetCount, betRunningCount, betSettledCount, betMarkedCount
			,InRunning, Waiting_cnt, BetCountParlay, InRunningParlay, WaitingParlay_cnt
			,InRunningSet1, InRunningSet2, InRunningSet3, InRunningSet4, InRunningSet5
			,BetCountSet1, BetCountSet2, BetCountSet3, BetCountSet4, BetCountSet5
			,BetMarkedCountSet1, BetMarkedCountSet2, BetMarkedCountSet3, BetMarkedCountSet4, BetMarkedCountSet5
		)
		SELECT	CASE 
					WHEN g.groupId = 1 THEN 1 -- HT
					WHEN g.groupId = 4 OR (g.GroupId = 2 AND g.IsUsedGoalRecordValue =1) THEN 2 -- FGLG
					WHEN g.groupId = 3 THEN 3 -- HT FGLG
					
					WHEN g.GroupId = 7 THEN 7 -- SS
					WHEN g.GroupId = 10 THEN 9 -- All quaters of Basketball
					ELSE 0
				END AS GroupId
			,SUM(b.betcount) AS betcount
			,SUM(b.betRunningCount) AS betRunningCount
			,SUM(b.betSettledCount) AS betSettledCount
			,SUM(b.betMarkedCount) AS betMarkedCount
			,MAX(b.InRunning) AS InRunning
			,SUM(b.Waiting_cnt)	AS Waiting_cnt	
			
			,SUM(b.betcountParlay) AS betcountParlay
			,MAX(b.InRunningParlay) AS InRunningParlay
			,SUM(b.WaitingParlay_cnt)AS WaitingParlay_cnt	
				
			,MAX(b.InRunningSet1)
			,MAX(b.InRunningSet2)
			,MAX(b.InRunningSet3)
			,MAX(b.InRunningSet4)
			,MAX(b.InRunningSet5)
			,SUM(b.BetCountSet1)
			,SUM(b.BetCountSet2)
			,SUM(b.BetCountSet3)
			,SUM(b.BetCountSet4)
			,SUM(b.BetCountSet5)

			,SUM(b.BetMarkedCountSet1)
			,SUM(b.BetMarkedCountSet2)
			,SUM(b.BetMarkedCountSet3)
			,SUM(b.BetMarkedCountSet4)
			,SUM(b.BetMarkedCountSet5)
		FROM	#Data b
			INNER JOIN @tmpBettypes g
				ON	b.bettype = g.BetType
		GROUP BY CASE 
					WHEN g.groupId = 1 THEN 1 -- HT
					WHEN g.groupId = 4 OR (g.GroupId = 2 AND g.IsUsedGoalRecordValue =1) THEN 2 -- FT FGLG
					WHEN g.groupId = 3 THEN 3 -- HT FGLG
					WHEN g.GroupId = 7 THEN 7 -- SS
					WHEN g.GroupId = 10 THEN 9 -- All quaters of Basketball
					ELSE 0
				END

		INSERT INTO @status (GroupId, BetCount, InRunning, Waiting_cnt, BetCountParlay, InRunningParlay, WaitingParlay_cnt)
		SELECT t.GroupId, 0, 0, 0, 0, 0, 0
		FROM (VALUES (0),(1),(2),(3),(7),(9)) AS t (GroupId)
		WHERE	NOT EXISTS (SELECT TOP 1 1 FROM @status s WHERE s.GroupId = t.GroupId)

        SELECT @FTStatus = CASE 
								WHEN t.betcount = 0 AND t.betcountParlay = 0 THEN 'No Ticket'
								WHEN t.InRunning > 0 THEN 'Running'
								WHEN t.betMarkedCount > 0 THEN 'Marked'
								WHEN t.Waiting_cnt > 0 AND t.Waiting_cnt = t.BetCount THEN 'Waiting'
								WHEN ISNULL(t.BetCount,0) = 0 AND t.InRunningParlay > 0 THEN 'Parlay Running'
								WHEN ISNULL(t.BetCount,0) = 0 AND t.WaitingParlay_cnt > 0 AND t.betcountParlay = t.WaitingParlay_cnt THEN 'Parlay Waiting'
                                ELSE 'Calculated'
                            END
        FROM (
			SELECT ISNULL(SUM(betcount),0) AS betcount, ISNULL(MAX(inRunning),0) AS inRunning, ISNULL(SUM(Waiting_cnt),0) AS Waiting_cnt
					,ISNULL(SUM(BetCountParlay),0) AS betcountParlay, ISNULL(MAX(InRunningParlay),0) AS InRunningParlay, ISNULL(SUM(WaitingParlay_cnt),0) AS WaitingParlay_cnt
					,ISNULL(SUM(betMarkedCount),0) AS betMarkedCount
			FROM @status
			WHERE 1 = CASE WHEN GroupId IN (0,2) THEN 1 ELSE 0 END --include FT-FGLG
					
		) AS t				

        SELECT @HTStatus = CASE 
								WHEN t.betcount = 0 AND t.betcountParlay = 0 THEN 'No Ticket'
								WHEN t.InRunning > 0 THEN 'Running'
								WHEN t.betMarkedCount > 0 THEN 'Marked'
								WHEN t.Waiting_cnt > 0 AND t.Waiting_cnt = t.BetCount THEN 'Waiting'
								WHEN ISNULL(t.BetCount,0) = 0 AND t.InRunningParlay > 0 THEN 'Parlay Running'
								WHEN ISNULL(t.BetCount,0) = 0 AND t.WaitingParlay_cnt > 0 AND t.betcountParlay = t.WaitingParlay_cnt THEN 'Parlay Waiting'
                                ELSE 'Calculated'
                            END
        FROM (
			SELECT ISNULL(MAX(betcount),0) AS betcount, ISNULL(MAX(inRunning),0) AS inRunning, ISNULL(SUM(Waiting_cnt),0) AS Waiting_cnt
					,ISNULL(SUM(BetCountParlay),0) AS betcountParlay, ISNULL(MAX(InRunningParlay),0) AS InRunningParlay, ISNULL(SUM(WaitingParlay_cnt),0) AS WaitingParlay_cnt
					,ISNULL(SUM(betMarkedCount),0) AS betMarkedCount
			FROM @status
			WHERE 1 = CASE WHEN GroupId IN(1,3) THEN 1 ELSE 0 END --include HT-FGLG
		) AS t
	
        --- Tennis Ticket Status 
        SELECT    @TennisStatusSet1 = CASE    
										WHEN ISNULL(BetCountSet1,0) = 0 THEN N'No Ticket'
                                        WHEN ISNULL(InRunningSet1,0) = 0 THEN N'Calculated'
                                        ELSE N'Running'
                                    END
				,@TennisStatusSet2 = CASE    
										WHEN ISNULL(BetCountSet2,0) = 0 THEN N'No Ticket'
                                        WHEN ISNULL(InRunningSet2,0) = 0 THEN N'Calculated'
                                        ELSE N'Running'
									END
				,@TennisStatusSet3 = CASE   
										WHEN ISNULL(BetCountSet3,0) = 0 THEN N'No Ticket'
                                        WHEN ISNULL(InRunningSet3,0) = 0 THEN N'Calculated'
                                        ELSE N'Running'
                                    END	
				,@TennisStatusSet4 = CASE   
										WHEN ISNULL(BetCountSet4,0) = 0 THEN N'No Ticket'
                                        WHEN ISNULL(InRunningSet4,0) = 0 THEN N'Calculated'
                                        ELSE N'Running'
                                    END   
				,@TennisStatusSet5 = CASE    
										WHEN ISNULL(BetCountSet5,0) = 0 THEN N'No Ticket'
                                        WHEN ISNULL(InRunningSet5,0) = 0 THEN N'Calculated'
                                        ELSE N'Running'
                                    END                                                                  								
        FROM    @Status 
        WHERE    GroupId = 7 

        SELECT    @TennisStatusMatch = CASE    
										WHEN betcount = 0 THEN N'No Ticket'
                                        WHEN inRunning = 0 THEN N'Calculated'
                                        ELSE N'Running'
                                       END
        FROM    @Status 
        WHERE    GroupId = 0
                AND @Sporttype = 5    
		
		SELECT	@StatusQuarter1 = CASE
									WHEN ISNULL(BetCountSet1,0) = 0 THEN N'No Ticket'
									WHEN ISNULL(InRunningSet1,0) = 0 AND ISNULL(BetMarkedCountSet1,0) = 0 THEN N'Calculated'
									WHEN ISNULL(InRunningSet1,0) = 0 AND ISNULL(BetMarkedCountSet1,0) > 0 THEN 'Marked'
									ELSE N'Running'
								END
				,@StatusQuarter2 = CASE
									WHEN ISNULL(BetCountSet2,0) = 0 THEN N'No Ticket'
									WHEN ISNULL(InRunningSet2,0) = 0 AND ISNULL(BetMarkedCountSet2,0) = 0 THEN N'Calculated'
									WHEN ISNULL(InRunningSet2,0) = 0 AND ISNULL(BetMarkedCountSet2,0) > 0 THEN 'Marked'
									ELSE N'Running'
								END
				,@StatusQuarter3 = CASE
									WHEN ISNULL(BetCountSet3,0) = 0 THEN N'No Ticket'
									WHEN ISNULL(InRunningSet3,0) = 0 AND ISNULL(BetMarkedCountSet3,0) = 0 THEN N'Calculated'
									WHEN ISNULL(InRunningSet3,0) = 0 AND ISNULL(BetMarkedCountSet3,0) > 0 THEN 'Marked'
									ELSE N'Running'
								END
				,@StatusQuarter4 = CASE
									WHEN ISNULL(BetCountSet4,0) = 0 THEN N'No Ticket'
									WHEN ISNULL(InRunningSet4,0) = 0 AND ISNULL(BetMarkedCountSet4,0) = 0 THEN N'Calculated'
									WHEN ISNULL(InRunningSet4,0) = 0 AND ISNULL(BetMarkedCountSet4,0) > 0 THEN 'Marked'
									ELSE N'Running'
								END
		FROM	@status
		WHERE	GroupId = 9
    END

    IF (
            EXISTS (
                --HT Soccer
                SELECT    TOP 1 1
                FROM    DBPRO.bodb02.dbo.match m WITH (NOLOCK)
                    INNER JOIN DBPRO.bodb02.dbo.match_remark mr WITH (NOLOCK) ON m.matchid = mr.matchid
                WHERE    m.matchid = @matchid 
                        AND sporttype = 1 
                        AND datediff(minute, kickofftime, CURRENT_TIMESTAMP) < 100 
                        AND (datediff(minute, kickofftime, CURRENT_TIMESTAMP) > 45 OR isnull(ConfirmHT, 0) > 0) 
                        AND isnull(ConfirmFT, 0) = 0
                )
            )
    BEGIN
        SELECT @IsHTOnly = 1
        
    END
    
	IF @IsRefundPage = 1
	BEGIN
		-- Check for SDT parlay bettype
		IF(EXISTS (
				SELECT TOP 1 1 
				FROM DBPRO.bodb02.dbo.ResultDetail rs WITH(NOLOCK)
				WHERE rs.matchid 			= @matchid
				AND rs.SettlementStatusID	IN (5,6) --abandoned match
			)
		)
		BEGIN
			SELECT 
				@SettleAbandonedMatchIBCParlay = CASE 
													WHEN ResourceId = '00' THEN 2 --2H 
													WHEN ResourceId = '01' THEN 1 --1H
													ELSE @SettleAbandonedMatchIBCParlay 
												END
			FROM DBPRO.bodb02.dbo.ResultDetail rs WITH(NOLOCK)
				CROSS APPLY
				(
					SELECT CAST(SUBSTRING(OtherInfo,CHARINDEX('SDT:',OtherInfo) + 4, 1) AS TINYINT) AS SDTRecord
				) AS sdt
			WHERE rs.matchid 			= @matchid
				AND rs.ResourceID 		IN ('00', '01')
				AND 4 & sdt.SDTRecord 	= 4
		END

	END 
	
    SELECT match.sporttype
        ,match.betstatus
        ,hthomescore AS HalfTimeHomeScore
        ,htawayscore AS HalfTimeAwayScore
        ,datediff(minute, kickofftime, CURRENT_TIMESTAMP) playtime
        ,match.leagueid
        ,match.matchid
        ,match.homeid
        ,match.awayid
        ,match.matchcode
        ,match.kickofftime
        ,match.finalhomescore
        ,match.finalawayscore
        ,match.eventstatus
        ,isnull(mr.refund, 0) IsRefund
        ,isnull(mr.calrefund, 0) IsCalRefund
        ,isnull(mr.calculate, 0) IsCalculated
        ,isnull(mr.multiple, 0) IsMultiCaled
        ,isnull(match.isNeutral, CONVERT(BIT, 0)) AS IsNeutral
        ,mr.ishtcal AS IsHalfTimeCal   
        ,match.GoalRecord
        ,mr.ConfirmHT
        ,mr.ConfirmFT
        ,@HTStatus HTStatus
        ,@FTStatus FTStatus
        ,ISNULL(@IsExistFGLG,0) AS IsExistFGLG
        ,ISNULL(@IsExistHTFGLG,0) AS IsExistHTFGLG
        ,ISNULL(@IsEnabledGoalRecordHT,0) AS IsEnabledGoalRecordHT
        ,ISNULL(@IsEnabledGoalRecordFT,0) AS IsEnabledGoalRecordFT
        ,ISNULL(@IsHTOnly,0) AS IsHTOnly
		,ISNULL(@isExistBettrade,0)  AS IsExistBettrade
        ,ISNULL(@IsLive,0) AS IsLive
        ,@TennisStatusSet1    AS TennisStatusSet1
        ,@TennisStatusSet2    AS TennisStatusSet2
        ,@TennisStatusSet3    AS TennisStatusSet3
        ,@TennisStatusSet4    AS TennisStatusSet4
        ,@TennisStatusSet5    AS TennisStatusSet5
        ,@TennisStatusMatch    AS TennisStatusMatch
        ,@StatusQuarter1 AS StatusQuarter1
        ,@StatusQuarter2 AS StatusQuarter2
        ,@StatusQuarter3 AS StatusQuarter3
        ,@StatusQuarter4 AS StatusQuarter4
        ,ISNULL(@isExistResultandFirstTeamScore,0) AS isExistResultandFirstTeamScore
		,ISNULL(match.AutoSetting, ISNULL(l.AutoSetting,0)) AS AutoSetting
		,ISNULL(aps.HasInstantCompleted,0) AS HasInstantCompleted
		, @SettleAbandonedMatchIBCParlay AS SettleAbandonedMatchIBCParlay
		,l.LeagueGroupID 
		,@isExistFTHighestQuarter AS isExistFTHighestQuarter
     FROM DBPRO.bodb02.dbo.match WITH (NOLOCK)
        LEFT OUTER JOIN DBPRO.bodb02.dbo.match_remark mr WITH (NOLOCK) ON match.matchid = mr.matchid
		INNER JOIN DBPRO.bodb02.dbo.league l WITH (NOLOCK) ON match.leagueid = l.leagueid
		OUTER APPLY (
			SELECT TOP(1) CAST(1 AS BIT) AS HasInstantCompleted
			FROM DBPRO.BODB02.dbo.AutoPayoutResult WITH(NOLOCK)
			WHERE matchid = match.matchid
			AND CalculationType IN (101, 102) -- Instant Calculation
			AND StatusId = 2 --completed
			
		) AS aps
    WHERE match.matchid = @matchid

   -- Get TENNIS, CORNER, BASKETBALL RESULT 
	BEGIN
		DECLARE @matchidList  VARCHAR(MAX) = CAST(@MatchId AS VARCHAR )
		EXEC DBPRO.bodb02.dbo.NAP_Set_ResultDetailSel @matchidList = @matchidList
	END

	-- Get number of ticket
	
	IF @sporttype = 1
	BEGIN
		SELECT t.GroupId
				,SUM(t.betRunningCount) AS betRunningCount
				,SUM(t.betSettledCount) AS betSettledCount
				,SUM(t.betMarkedCount) AS betMarkedCount
		FROM(
			SELECT	CASE WHEN GroupId IN (1,3) THEN 1 ELSE 2 END AS GroupId
					,betRunningCount
					,betSettledCount
					,betMarkedCount
			FROM	@status
			WHERE	GroupId IN (0,1,2,3)
		) t
		GROUP BY t.GroupId
		ORDER BY t.GroupId
	END
	ELSE IF @sporttype = 2
	BEGIN
		SELECT 0 AS groupid
				,SUM(t.betRunningCount) AS betRunningCount
				,SUM(t.betSettledCount) AS betSettledCount
				,SUM(t.betMarkedCount) AS betMarkedCount
		FROM(
			SELECT	
					betRunningCount
					,betSettledCount
					,betMarkedCount
			FROM	@status
			WHERE GroupId IN (0,1,9)
		) t
	END
	ELSE IF EXISTS
				(
					SELECT TOP 1 1
					FROM Sports WITH (NOLOCK)
					WHERE (SportType <= 99 AND SportType NOT IN (27,46,1,2,5,9,43)) --,56,57,58,59,60,61,62,63,64,65,66)) 
							AND SportType = @sporttype
				)
	BEGIN
		SELECT 0 AS groupid
				,SUM(t.betRunningCount) AS betRunningCount
				,SUM(t.betSettledCount) AS betSettledCount
				,SUM(t.betMarkedCount) AS betMarkedCount
		FROM(
			SELECT	betRunningCount
					,betSettledCount
					,betMarkedCount
			FROM	@status
			WHERE	GroupId IN (0,1,2,3)
		) t
	END
	ELSE
	BEGIN
		SELECT	0 AS GroupId
				,0 AS betRunningCount
				,0 AS betSettledCount
				,0 AS betMarkedCount
		WHERE	1 = 0
	END
	
	IF @sporttype = 1 AND @LeagueGroupID IN (42,74,108)
	BEGIN
		INSERT INTO @tmp_ChildMatch ( Matchid, matchcode, eventstatus, SettlementStatus, BetStatus, IsExistMarkedTicket, IsExistRunningTicket)
		SELECT	m.matchid
				, m.matchcode
				, m.eventstatus		
				, ISNULL(m.SettlementStatus,0)
				, m.betstatus
				, MAX(CASE WHEN btr.statusID BETWEEN 0 AND 1 AND mt.TransId IS NOT NULL THEN 1 ELSE 0 END) AS IsExistMarkedTicket
				, MAX(CASE WHEN btr.statusID BETWEEN 0 AND 1 AND mt.TransId IS NULL THEN 1 ELSE 0 END) AS IsExistRunningTicket		
			FROM DBPRO.bodb02.dbo.match m WITH(NOLOCK)
				LEFT JOIN dbo.bettrans btr WITH(NOLOCK)
					ON btr.matchid = m.matchid
				OUTER APPLY ( SELECT TOP 1 TransId FROM dbo.MarkedTransaction mt WITH(NOLOCK)
								WHERE btr.transID = mt.TransId AND btr.statusID IN ( 0 , 1) ) mt
			WHERE   m.ParentID =   @matchid  
				AND m.ChildMatchType IN ( 201,202,203)
				AND ISNULL(m.IsDeleted,0) = 0
			GROUP BY m.Matchid, m.matchcode, m.eventstatus, m.SettlementStatus, m.BetStatus
	END

	SELECT Matchid, matchcode, eventstatus, SettlementStatus, BetStatus, IsExistMarkedTicket, IsExistRunningTicket FROM @tmp_ChildMatch
END
GO