/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_3] 
	@matchid 							INT
    ,@bettype							SMALLINT
    ,@totalgoal							SMALLMONEY    = NULL 
    ,@scorediff							SMALLMONEY  = NULL
    ,@SelectedSet						VARCHAR(50) = NULL 
    ,@TotalSetMatch						SMALLMONEY  = NULL 
    ,@TotalGameSet1						SMALLMONEY    = NULL
    ,@TotalGameSet2						SMALLMONEY    = NULL
    ,@TotalGameSet3						SMALLMONEY    = NULL
    ,@TotalGameSet4						SMALLMONEY    = NULL
    ,@TotalGameSet5						SMALLMONEY    = NULL
    ,@betcount							INT = 0
    ,@IsSettleAbandonedMatch			BIT = 0
    ,@IsSettleAbandonedMatchBetFair		BIT = 0
    ,@IsSettleAbandonedMatchIBC			BIT = 0
	,@IsReSettledTickets				BIT	= 1
    -- add any params, please modify script in 'special section'
AS
/*
    Created by:Kathy
    Date:
    Task: Settlement 
    DB: DBTXN/BODB02
    Original: Admin_Calculate_3

    Revisions:
        - 20140610@Kathy: Using clustered index(CIX_recommend_matchid_bettype) in DB052, DB053, DB054                
        - 20140729@Kathy: Add one more account(BF3) into BetFair's group [Redmine:#19665]
        - 20140808@Kathy: Support new 11 bettypes: 144 [Redmine:#19667]
        - 20140818@Jamie: Correct settle  determined ticket 144
        - 20141020@Jamie: Sporting Solution for Tennis [Redmine:#23034]
        - 20150413@Jamie: Settlement Betradar phase 2 [Redmine: #27212]
        - 20150618@Jamie: Offer the option Exclude Corner tickets [Feature #38099]
        - 20150909@Kathy: Integrate Myanmar Odds ( 4 new bettypes: 301->304): add bettype 302
        - 20151026@Kathy: Change Myanmar Odds commision formula [Redmine:#46284]
		- 20151125@Patrick: Apply 28 Live Bettypes for Settlement [Redmine:#47843]
		- 20151210@Patrick: Database - Change datatype [Redmine: #48660]
		- 20160425@Patrick: Reduce escalation lock when updating large amount of data [Redmine: #56550]
		- 20160507@Patrick: Use Option Force Order & limit scanning on bettrans table incase merge join for batchNo n > 1 to reduce lock escalation [Redmine: #58464]
		- 20160705@Kathy: PH-AIO phase 2 (67 bettypes ) [Redmine:#53154]
		- 20141003@Bobby: #65026 - Correct SDT for bettype OU[3,8]
		- 20161118@Bobby: #67462 - Implement SDT for Over/Under bettypes full winlost
		- 20170227@Bobby: #72205 - Implement SDT half WON-LOSE for bettype Over/Under
		- 20170215@Kathy: Basketball All-in-One [Redmine:#71372]
		- 20170919@Kathy: Offer new 4 bettypes (461, 462, 463, 464) [Redmine:#83261]
		- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
		- 20180904@Kathy: Change CIX on DB054 [Redmine:#100828]
		- 20181004@Kathy: Change CIX on DB053 [Redmine:#102594]
		- 20181030@Kathy: Change CIX on DB052 [Redmine:#103985]
		- 20181129@Kathy: Do not settle ticket on DB04x [Redmine:#105327]
		- 20190225@Sol:  New Formula for Comm [Redmine:#109007]
		- 20190320@Kathy: Settlement with Tickets Exclusion [Redmine:#106823]
		- 20190409@Sol: Settlement Time [Redmine:#99638]
		- 20190620@Kathy: Remove betradar corner bettypes [Redmine:#109584]
		- 20190626@Sol: Incorporate PHAIO 4b - 27 Corners Bet Types [Redmine:#115232]
		- 20190715@Helen: Recover/Void tickets in Bet 14 - Update statuswinlost for VOID Tickets [Redmine:115377]
		- 20191112@Sol: Incorporate PHAIO 5 [Redmine:#121681]
		- 20200921@Louisa: Implement for Myanmar odds (apply bettype 1,3,7,8 remove 301->304) [Redmine:#141824]
		- 20211129@Kathy: New Cashout model [Redmine:#164838]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
		
    Param's Explanation:
        + @IsSettleAbandonedMatch: Settle determined tickets for Abandoned/Postponed Match
        + @IsSettleAbandonedMatchBetFair: Is Settlement for Betfair ticket of Abandoned/postponed match or not
        

*/
BEGIN
    SET NOCOUNT ON

	-- CHECK SERVER BEFORE CALCULATING
	DECLARE @ServerName			SYSNAME 
			,@AllowCalculation	BIT
			,@transInfo	XML

	SET @ServerName = @@SERVERNAME

    IF @betcount = 0 AND @ServerName NOT LIKE N'DBIOM%' RETURN

	IF OBJECT_ID('NAP_Set_ServerAction', 'P') IS NOT NULL
	BEGIN
		EXEC [dbo].[NAP_Set_ServerAction]
			@ServerName			= @ServerName
			,@AllowCalculation	= @AllowCalculation	OUTPUT

		IF @AllowCalculation = 0
			RETURN
	END
	-- END CHECK

    DECLARE @modds MONEY
        ,@commWinRate SMALLMONEY
        ,@commLostRate SMALLMONEY
		,@commHalfWLRate SMALLMONEY
		,@winlost MONEY
		,@stake MONEY
		,@commBettypeGroupId SMALLINT
		,@statusId TINYINT
		,@IsUpd_Void BIT = 0
	
	DECLARE @tmpTransInfo TABLE (transId BIGINT
			,modds MONEY, statuswinlost TINYINT,SettlementTime DATETIME
			,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
			,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
			,Status NVARCHAR(10),StatusID TINYINT,ruben TINYINT
		)

	CREATE TABLE #tempCust(custid INT PRIMARY KEY, sRecommend int, isCN88 bit)

	IF @IsReSettledTickets = 0
	BEGIN
		INSERT INTO #tempCust(custid, sRecommend)
		SELECT	custid, srecommend
		FROM	dbo.bettrans bt WITH(NOLOCK) 
		WHERE	matchid = @matchid 
				AND bettype = @bettype
				AND statusID IN (0,102)
		GROUP BY custid, bt.srecommend
	END
	ELSE
	BEGIN
		INSERT INTO #tempCust(custid, sRecommend)
		SELECT	custid, srecommend
		FROM	dbo.bettrans bt WITH(NOLOCK) 
		WHERE	matchid = @matchid 
				AND bettype = @bettype
		GROUP BY custid, bt.srecommend
	END

	-- update if bettype belongs to the CN88 site or not
	UPDATE tmp
	  SET  isCN88 = CASE WHEN cs.CustId IS NULL THEN 0 ELSE 1 END
	FROM   #tempCust tmp
			   LEFT JOIN dbo.CS_CustSuper cs WITH(NOLOCK)
				   ON tmp.srecommend = cs.CustId;

	-- get CommBettypeGroupId 
	SELECT @commBettypeGroupId = CommBettypeGroupId FROM dbo.f_Set_GetGroupBettypes() AS f WHERE BetType = @bettype
        
	CREATE TABLE #currList (custid INT PRIMARY KEY, isCN88 bit)
	DECLARE @MinCustId INT
	
	DECLARE @settlementTime DATETIME

    IF @IsSettleAbandonedMatch = 1 OR @IsSettleAbandonedMatchBetFair = 1 or @IsSettleAbandonedMatchIBC = 1
    BEGIN
        DECLARE    @comparedValue SMALLMONEY    --@totalgoal - 0.5 -- Get tickets had result 
        SELECT    @comparedValue = CASE 
										WHEN @bettype IN (3,18,178,401,402,461,462,482,483,389,388) THEN @totalgoal - 0.25 -- Apply half WON|LOSE 
										WHEN @bettype = 475 THEN @totalgoal
										ELSE @totalgoal - 0.5 --full Winloss
									END
		WHILE 1 = 1
		BEGIN 
			DELETE FROM #currList

			DELETE TOP (1000)
			FROM #tempCust OUTPUT DELETED.custid, DELETED.isCN88 INTO #currList
			IF @@ROWCOUNT = 0 BREAK

			SELECT @MinCustId = MIN(CustId) FROM #currList

			SET @settlementTime = GETDATE();

			UPDATE b 
			SET 
				 @totalgoal = CASE WHEN bettype = 3 AND @totalgoal = 0 AND @SelectedSet LIKE '%6%' THEN ISNULL(@TotalSetMatch,0) ELSE @totalgoal END 
				,@modds = CASE 
							WHEN bettype = 475 THEN CASE WHEN betteam = 'o' AND @totalgoal > hdp1 THEN 1
														WHEN betteam = 'u' AND @totalgoal >= hdp1 THEN -1
														WHEN betteam = 'e' AND @totalgoal > hdp1 THEN -1
														ELSE NULL
													END
							WHEN betteam IN ('h', 'o') THEN @totalgoal - hdp1
							WHEN betteam IN ('a', 'u') THEN hdp1 - @totalgoal
							WHEN RIGHT(betteam,1) = 'u' THEN hdp1 - @totalgoal    -- 144 ,163
							WHEN bettype IN (408, 397) AND betteam = 'NG' AND @totalgoal > 0 THEN -1 -- No Goal
							ELSE NULL 
						END
				,@IsUpd_Void = CASE WHEN statusID = 102 THEN 0 ELSE 1 END
				,modds = @modds
				,statuswinlost = CASE WHEN @modds > 0.25 THEN 2
								WHEN @modds = 0.25 THEN 1
								WHEN @modds = - 0.25 THEN 3
								WHEN @modds < - 0.25 THEN 4
								WHEN @modds IS NULL THEN 6
							END  
				,@commWinRate = CASE comstatus -- 0 : pay normal, both win/lost -- 1 : pay 'double' ONLY on lost
					WHEN '0' THEN 1
					WHEN '1' THEN 0
					ELSE 1
					END
				,@commLostRate = CASE comstatus
					WHEN '0' THEN 1
					WHEN '1' THEN 2
					ELSE 1
					END
				,@commHalfWLRate = CASE WHEN t.isCN88 = 1 AND @commBettypeGroupId = 1 THEN 1
							ELSE 0.5
						END	
				,@winlost = CASE 
					WHEN @modds > 0.25 THEN actual_stake + stake * (CASE 
							WHEN odds < 0 THEN 1
							ELSE (CASE 
									WHEN bettype IN (144,163,461,462,475,482,483,397) THEN odds - 1
									ELSE odds END
									) END
							) -- WON                
					WHEN @modds = 0.25 THEN actual_stake + stake * (CASE 
							WHEN odds < 0 THEN 1
							ELSE (CASE 
									WHEN bettype IN (144,163,461,462,475,482,483,397) THEN odds - 1
									ELSE odds END
									) END
							) * 0.5 -- half WON                
					WHEN @modds = - 0.25 THEN actual_stake * 0.5 -- half LOSE    
					WHEN @modds < - 0.25 THEN 0 -- LOSE    
					WHEN @modds IS NULL THEN winlost
					END 
				-- check if bettype belongs to major comm group (CommBettypeGroupId = 1) and calc comm with new formula
				,@stake = CASE WHEN t.isCN88 = 1 AND @commBettypeGroupId = 1 THEN ABS(@winlost - actual_stake)
								ELSE stake 
							END 
				-- check winlost or status change to update SettlementTime
				,@statusId = CASE 
					WHEN @modds > 0 THEN 112 --WON
					WHEN @modds < 0 THEN 113 --LOSE
					WHEN @modds IS NULL THEN statusID
					END
				,SettlementTime = CASE 
								WHEN @IsUpd_Void = 0 THEN SettlementTime 
								ELSE CASE WHEN winlost <> @winlost OR statusID <> @statusId THEN @settlementTime ELSE SettlementTime END
							END
							
				,WinLost = CASE 
								WHEN @IsUpd_Void = 0 THEN WinLost 
								ELSE @winlost
							END
				,aWinLost = CASE 
								WHEN @IsUpd_Void = 0 THEN aWinLost 
								ELSE CASE 
										WHEN  @modds > 0.25 THEN stake * (CASE 
												WHEN odds < 0 THEN 1
												ELSE (CASE 
									WHEN bettype IN (144,163,461,462,475,482,483,397) THEN odds - 1
														ELSE odds END
														) END
												) * - apositiontaking
										WHEN  @modds = 0.25 THEN stake * (CASE 
												WHEN odds < 0 THEN 1
												ELSE (CASE 
									WHEN bettype IN (144,163,461,462,475,482,483,397) THEN odds - 1
														ELSE odds END
														) END
												) * - apositiontaking * 0.5
										WHEN @modds = - 0.25 THEN actual_stake * apositiontaking * 0.5
										WHEN @modds < - 0.25 THEN actual_stake * apositiontaking
										WHEN @modds IS NULL THEN awinlost
									END
							END
							
				,mWinLost = CASE 
								WHEN @IsUpd_Void = 0 THEN mWinLost 
								ELSE CASE 
										WHEN @modds > 0.25 THEN stake * (CASE 
												WHEN odds < 0 THEN 1
												ELSE (CASE 
									WHEN bettype IN (144,163,461,462,475,482,483,397) THEN odds - 1
														ELSE odds END
														) END
												) * - mpositiontaking
										WHEN @modds = 0.25 THEN stake * (CASE 
												WHEN odds < 0 THEN 1
												ELSE (CASE 
									WHEN bettype IN (144,163,461,462,475,482,483,397) THEN odds - 1
														ELSE odds END
														) END
												) * - mpositiontaking * 0.5
										WHEN @modds = - 0.25 THEN actual_stake * mpositiontaking * 0.5
										WHEN @modds < - 0.25 THEN actual_stake * mpositiontaking
										WHEN @modds IS NULL THEN mwinlost
									END
							END
							
				,sWinLost = CASE 
								WHEN @IsUpd_Void = 0 THEN sWinLost 
								ELSE CASE 
										WHEN @modds > 0.25 THEN stake * (CASE 
												WHEN odds < 0 THEN 1
												ELSE (CASE 
									WHEN bettype IN (144,163,461,462,475,482,483,397) THEN odds - 1
														ELSE odds END
														) END
												) * - spositiontaking
										WHEN @modds = 0.25 THEN stake * (CASE 
												WHEN odds < 0 THEN 1
												ELSE (CASE 
									WHEN bettype IN (144,163,461,462,475,482,483,397) THEN odds - 1
														ELSE odds END
														) END
												) * - spositiontaking * 0.5
										WHEN @modds = - 0.25 THEN actual_stake * spositiontaking * 0.5
										WHEN @modds < - 0.25 THEN actual_stake * spositiontaking
										WHEN @modds IS NULL THEN swinlost
									END
							END
							
				,PlayerComm = CASE 
								WHEN @IsUpd_Void = 0 THEN PlayerComm 
								ELSE CASE 
										WHEN @modds > 0.25 THEN @commWinRate * playerdiscount * @stake
										WHEN @modds = 0.25 THEN @commWinRate * playerdiscount * @stake * @commHalfWLRate
										WHEN @modds = - 0.25 THEN @commLostRate * playerdiscount * @stake * @commHalfWLRate
										WHEN @modds < - 0.25 THEN @commLostRate * playerdiscount * @stake
										WHEN @modds IS NULL THEN playercomm
									END
							END
							
				,Comm = CASE 
								WHEN @IsUpd_Void = 0 THEN Comm 
								ELSE CASE 
										WHEN @modds > 0.25 THEN @commWinRate * discount * @stake * (1 - apositiontaking)
										WHEN @modds = 0.25 THEN @commWinRate * discount * @stake * (1 - apositiontaking) * @commHalfWLRate
										WHEN @modds = - 0.25 THEN @commLostRate * discount * @stake * (1 - apositiontaking) * @commHalfWLRate
										WHEN @modds < - 0.25 THEN @commLostRate * discount * @stake * (1 - apositiontaking)
										WHEN @modds IS NULL THEN comm
									END
							END
							
				,aComm = CASE 
								WHEN @IsUpd_Void = 0 THEN aComm 
								ELSE CASE 
										WHEN @modds > 0.25 THEN @commWinRate * adiscount * @stake * (1 - (mpositiontaking + apositiontaking))
										WHEN @modds = 0.25 THEN @commWinRate * adiscount * @stake * (1 - (mpositiontaking + apositiontaking)) * @commHalfWLRate
										WHEN @modds = - 0.25 THEN @commLostRate * adiscount * @stake * (1 - (mpositiontaking + apositiontaking)) * @commHalfWLRate
										WHEN @modds < - 0.25 THEN @commLostRate * adiscount * @stake * (1 - (mpositiontaking + apositiontaking))
										WHEN @modds IS NULL THEN acomm
									END
							END
							
				,sComm = CASE 
								WHEN @IsUpd_Void = 0 THEN sComm 
								ELSE CASE 
										WHEN @modds > 0.25 THEN @commWinRate * sdiscount * @stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
										WHEN @modds = 0.25 THEN @commWinRate * sdiscount * @stake * (1 - (spositiontaking + mpositiontaking + apositiontaking)) * @commHalfWLRate
										WHEN @modds = - 0.25 THEN @commLostRate * sdiscount * @stake * (1 - (spositiontaking + mpositiontaking + apositiontaking)) * @commHalfWLRate
										WHEN @modds < - 0.25 THEN @commLostRate * sdiscount * @stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
										WHEN @modds IS NULL THEN scomm
									END
							END
							
				,STATUS = CASE 
								WHEN @IsUpd_Void = 0 THEN [status] 
								ELSE CASE 
										WHEN @modds > 0 THEN N'WON'
										WHEN @modds < 0 THEN N'LOSE'
										WHEN @modds IS NULL THEN status
									END
							END
							
				,StatusID = CASE 
								WHEN @IsUpd_Void = 0 THEN StatusID 
								ELSE @statusId
							END
							
				,ruben = CASE 
								WHEN @IsUpd_Void = 0 THEN ruben 
								ELSE CASE WHEN @modds IS NULL THEN ruben
										  ELSE 1
									 END
							END
			OUTPUT	inserted.transid
				,inserted.modds, inserted.statuswinlost
				,CASE WHEN inserted.SettlementTime <> deleted.SettlementTime THEN inserted.SettlementTime ELSE NULL END
				,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
				,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm
				,inserted.Status,inserted.StatusID,inserted.ruben		
			INTO @tmpTransInfo (
				transId
				,modds, statuswinlost,SettlementTime,WinLost,aWinLost
				,mWinLost,sWinLost,PlayerComm,Comm,aComm,sComm,Status,StatusID,ruben
			)				
			FROM #currList t
				INNER JOIN dbo.bettrans b WITH (ROWLOCK, UPDLOCK) ON t.custid = b.custid
			WHERE matchid = @matchid AND bettype = @bettype 
				AND b.custid >= @MinCustId
				AND statusID NOT IN (101)         
				AND 1 = CASE 
						WHEN @IsSettleAbandonedMatch = 1 AND (b.custid IN (50057, 879241, 103873, 78761, 851668, 878902) OR recommend = 1688156) THEN 1
						WHEN @IsSettleAbandonedMatchBetFair = 1 AND b.custid IN (2331, 1077687, 115770, 15523642) THEN 1
						WHEN @IsSettleAbandonedMatchIBC = 1 AND (b.custid NOT IN (50057, 879241, 103873, 78761, 851668, 878902, 2331, 1077687, 115770, 15523642) AND recommend <> 1688156) THEN 1
						ELSE 0
					END 
				AND hdp1 <= @comparedValue
				AND ISNULL(b.betdaqid,0) <> -2

			IF OBJECT_ID('Service_Settlement_SiteDB_CalculationLog','U') IS NOT NULL 
			BEGIN
				SET @transInfo = (
					SELECT	transId AS '@t'
							,modds AS '@m'				
							,statuswinlost AS '@statuswl' 
							,SettlementTime AS '@st' 
							,WinLost AS '@w' 
							,aWinLost AS '@aw' 
							,mWinLost AS '@mw' 
							,sWinLost AS '@sw' 
							,PlayerComm AS '@pc' 
							,Comm AS '@c' 
							,aComm AS '@ac' 
							,sComm AS '@sc' 
							,Status AS '@s' 
							,StatusID AS '@sid' 
							,ruben AS '@r'				
					FROM	@tmpTransInfo
					FOR XML PATH('r'),ROOT('root'), TYPE
				)

				INSERT INTO dbo.Service_Settlement_SiteDB_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo)
				VALUES ('Settlement', 'CalculateOtherSport', 'bettrans', @MatchId, @transInfo)		
			END	
		END 
		
    END-- END settle determined ticket
    ELSE
    BEGIN
		WHILE 1 = 1
		BEGIN
			DELETE FROM #currList

			DELETE TOP (1000)
			FROM #tempCust OUTPUT DELETED.custid, DELETED.isCN88 INTO #currList
			IF @@ROWCOUNT = 0 BREAK

			SELECT @MinCustId = MIN(CustId) FROM #currList

			SET @settlementTime = GETDATE();

			UPDATE b
			SET 
				@totalgoal = CASE WHEN bettype = 3 AND @totalgoal = 0 AND @SelectedSet LIKE '%6%' THEN ISNULL(@TotalSetMatch ,0)
									WHEN bettype IN (156,1312) AND betID = 801 AND @SelectedSet LIKE '%1%' THEN @TotalGameSet1
									WHEN bettype IN (156,1312) AND betID = 802 AND @SelectedSet LIKE '%2%' THEN @TotalGameSet2
									WHEN bettype IN (156,1312) AND betID = 803 AND @SelectedSet LIKE '%3%' THEN @TotalGameSet3
									WHEN bettype IN (156,1312) AND betID = 804 AND @SelectedSet LIKE '%4%' THEN @TotalGameSet4
									WHEN bettype IN (156,1312) AND betID = 805 AND @SelectedSet LIKE '%5%' THEN @TotalGameSet5
									ELSE @totalgoal END
				,@modds = CASE
						WHEN @bettype = 397 THEN 
												CASE WHEN betteam = 'H1' AND @scorediff = 1 THEN 1
													WHEN betteam = 'H2' AND @scorediff = 2 THEN 1 
													WHEN betteam = 'H3+' AND @scorediff >=3 THEN 1
													WHEN betteam = 'D' AND @scorediff = 0 AND @totalgoal <> 0 THEN 1
													WHEN betteam = 'NG' AND @totalgoal = 0 THEN 1
													WHEN betteam = 'A1' AND @scorediff = -1 THEN 1 
													WHEN betteam = 'A2' AND @scorediff = -2 THEN 1 
													WHEN betteam = 'A3+' AND @scorediff <= -3 THEN 1
													ELSE -1
												END
						WHEN @bettype = 460 THEN CASE
											WHEN betteam = 'H' AND @ScoreDiff >= 5  THEN 1
											WHEN betteam = 'A' AND @ScoreDiff <= -5 THEN 1
											ELSE -1
										END	 
						WHEN bettype = 475 THEN 
											CASE WHEN betteam = 'o' AND @totalgoal > hdp1 THEN 1
												WHEN betteam = 'u' AND @totalgoal < hdp1 THEN 1
												WHEN betteam = 'e' AND @totalgoal = hdp1 THEN 1
												ELSE -1
											END
						WHEN betteam = N'h' THEN @totalgoal - hdp1
						WHEN betteam = N'a' THEN hdp1 - @totalgoal
						WHEN betteam = N'o' THEN @totalgoal-hdp1    -- 156,178,1312,401,402,461,462,482,483,389,388
						WHEN betteam = N'u' THEN hdp1-@totalgoal    -- 156,178,1312,401,402,461,462,482,483,389,388
						WHEN betteam = 'ho' AND @scorediff > 0 THEN @totalgoal - hdp1
						WHEN betteam = 'hu' AND @scorediff > 0 THEN hdp1 - @totalgoal
						WHEN betteam = 'ao' AND @scorediff < 0 THEN @totalgoal - hdp1
						WHEN betteam = 'au' AND @scorediff < 0 THEN hdp1 - @totalgoal
						WHEN betteam = 'do' AND @scorediff = 0 THEN @totalgoal - hdp1
						WHEN betteam = 'du' AND @scorediff = 0 THEN hdp1 - @totalgoal        
						WHEN betteam = 'h1' AND @scorediff = 1 THEN 1        --171,408 
						WHEN betteam = 'h2' AND @scorediff = 2 THEN 1 
						WHEN betteam = 'h3' AND @scorediff >=3 THEN 1
						WHEN betteam = 'd' AND ((@scorediff = 0 AND bettype <> 408) OR (bettype = 408 AND @scorediff = 0 AND @totalgoal <> 0)) THEN 1
						WHEN betteam = 'NG' AND @totalgoal = 0 THEN 1 --No Goal
						WHEN betteam = 'a1' AND @scorediff =-1 THEN 1 
						WHEN betteam = 'a2' AND @scorediff =-2 THEN 1 
						WHEN betteam = 'a3' AND @scorediff<=-3 THEN 1
						WHEN bettype = 601 THEN CASE 
												WHEN betteam = 'H1-2' AND @scorediff BETWEEN 1 AND 2 THEN 1
												WHEN betteam = 'H3-6' AND @scorediff BETWEEN 3 AND 6 THEN 1
												WHEN betteam = 'H7-9' AND @scorediff BETWEEN 7 AND 9 THEN 1
												WHEN betteam = 'H10-13' AND @scorediff BETWEEN 10 AND 13 THEN 1
												WHEN betteam = 'H14-16' AND @scorediff BETWEEN 14 AND 16 THEN 1
												WHEN betteam = 'H17-20' AND @scorediff BETWEEN 17 AND 20 THEN 1
												WHEN betteam = 'H21+' AND @scorediff >= 21 THEN 1
												WHEN betteam = 'A1-2' AND @scorediff BETWEEN -2 AND -1 THEN 1
												WHEN betteam = 'A3-6' AND @scorediff BETWEEN -6 AND -3 THEN 1
												WHEN betteam = 'A7-9' AND @scorediff BETWEEN -9 AND -7 THEN 1
												WHEN betteam = 'A10-13' AND @scorediff BETWEEN -13 AND -10 THEN 1
												WHEN betteam = 'A14-16' AND @scorediff BETWEEN -16 AND -14 THEN 1
												WHEN betteam = 'A17-20' AND @scorediff BETWEEN -20 AND -17 THEN 1
												WHEN betteam = 'A21+' AND @scorediff <= -21 THEN 1
												ELSE -1
											END		
						WHEN bettype = 602 THEN CASE
												WHEN betteam = 'H1-5' AND @scorediff BETWEEN 1 AND 5 THEN 1
												WHEN betteam = 'H6-10' AND @scorediff BETWEEN 6 AND 10 THEN 1
												WHEN betteam = 'H11-15' AND @scorediff BETWEEN 11 AND 15 THEN 1
												WHEN betteam = 'H16-20' AND @scorediff BETWEEN 16 AND 20 THEN 1
												WHEN betteam = 'H21-25' AND @scorediff BETWEEN 21 AND 25 THEN 1
												WHEN betteam = 'H26+' AND @scorediff >= 26 THEN 1
												WHEN betteam = 'A1-5' AND @scorediff BETWEEN -5 AND -1 THEN 1
												WHEN betteam = 'A6-10' AND @scorediff BETWEEN -10 AND -6 THEN 1
												WHEN betteam = 'A11-15' AND @scorediff BETWEEN -15 AND -11 THEN 1
												WHEN betteam = 'A16-20' AND @scorediff BETWEEN -20 AND -16 THEN 1
												WHEN betteam = 'A21-25' AND @scorediff BETWEEN -25 AND -21 THEN 1
												WHEN betteam = 'A26+' AND @scorediff <= -26 THEN 1	
												ELSE -1
											END
						ELSE - 1                    
					END
				,@IsUpd_Void = CASE WHEN (statusID = 102) OR (mt.TransId IS NOT NULL) THEN 0 ELSE 1 END
				,modds = @modds
				,statuswinlost = CASE WHEN @modds > 0.25 THEN 2
								WHEN @modds = 0.25 THEN 1 
								WHEN @modds = 0 AND b.oddstype <> 6 THEN 0 
								WHEN @modds = 0 AND b.oddstype = 6 THEN CASE WHEN oddsspread = 0 THEN 0 
																			WHEN oddsspread > 0 THEN 2
																			ELSE 4
																		END	
								WHEN @modds = - 0.25 THEN 3
								WHEN @modds < - 0.25 THEN 4
								WHEN @modds IS NULL THEN 6
							END
				,@commWinRate = CASE comstatus -- 0 : pay normal, both win/lost -- 1 : pay 'double' ONLY on lost
					WHEN '0' THEN 1
					WHEN '1' THEN 0
					ELSE 1
					END
				,@commLostRate = CASE comstatus
					WHEN '0' THEN 1
					WHEN '1' THEN 2
					ELSE 1
					END
				,@commHalfWLRate = CASE WHEN t.isCN88 = 1 AND @commBettypeGroupId = 1 THEN 1
							ELSE 0.5
						END	
				,@winlost = CASE 
								WHEN @modds > 0.25 THEN actual_stake + stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (144,163,171,1203,408,601,602,461,462,460,475,482,483,397) THEN odds - 1 ELSE odds END ) END )
								WHEN @modds = 0.25 THEN actual_stake + stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (144,163,171,1203,408,601,602,461,462,460,475,482,483,397) THEN odds - 1 ELSE odds END ) END ) * 0.5
								WHEN @modds =  0 AND b.oddstype <> 6    THEN actual_stake
								WHEN @modds =  0 AND b.oddstype = 6     THEN CASE 
																		WHEN oddsspread = 0 THEN actual_stake
																		WHEN oddsspread > 0 THEN actual_stake + stake * odds * (oddsspread/100) -- oddsspread > 0: WON
																		ELSE actual_stake * (1 - ABS(oddsspread/100))  -- oddsspread < 0: LOSE
																		END
								WHEN @modds = - 0.25 THEN actual_stake * 0.5
								WHEN @modds < - 0.25 THEN 0
							END 
				-- check if bettype belongs to major comm group (CommBettypeGroupId = 1) and calc comm with new formula
				,@stake = CASE WHEN t.isCN88 = 1 AND @commBettypeGroupId = 1 THEN ABS(@winlost - actual_stake)
								ELSE stake 
							END
				-- check winlost or status change to update SettlementTime
				,@statusId = CASE 
								WHEN @modds > 0 THEN 112 --WON
								WHEN @modds = 0 AND b.oddstype <> 6 THEN 111 --DRAW
								WHEN @modds = 0 AND b.oddstype = 6  THEN CASE WHEN oddsspread = 0 THEN 111 
																		WHEN oddsspread > 0 THEN 112
																		ELSE 113
																		END
								WHEN @modds < 0 THEN 113 --LOSE
							END
				,SettlementTime = CASE 
								WHEN @IsUpd_Void = 0 THEN SettlementTime 
								ELSE CASE WHEN winlost <> @winlost OR statusID <> @statusId THEN @settlementTime ELSE SettlementTime END
							END
							
				,WinLost = CASE 
								WHEN @IsUpd_Void = 0 THEN WinLost 
								ELSE @winlost
							END
				,aWinLost = CASE 
								WHEN @IsUpd_Void = 0 THEN aWinLost 
								ELSE CASE
								
									WHEN @modds > 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (144,163,171,1203,408,601,602,461,462,460,475,482,483,397) THEN odds - 1 ELSE odds END ) END ) * - apositiontaking 
									WHEN @modds = 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (144,163,171,1203,408,601,602,461,462,460,475,482,483,397) THEN odds - 1 ELSE odds END ) END ) * - apositiontaking * 0.5
									WHEN @modds =  0 AND b.oddstype <> 6    THEN 0
									WHEN @modds =  0 AND b.oddstype = 6     THEN CASE 
																			WHEN oddsspread = 0 THEN 0
																			WHEN oddsspread > 0 THEN stake * odds * (oddsspread/100) * -apositiontaking -- oddsspread > 0: WON
																			ELSE actual_stake * ABS(oddsspread/100) * apositiontaking -- oddsspread < 0: LOSE
																			END
									WHEN @modds = - 0.25 THEN actual_stake * apositiontaking * 0.5
									WHEN @modds < - 0.25 THEN actual_stake * apositiontaking
								END
							END
							
				,mWinLost = CASE 
								WHEN @IsUpd_Void = 0 THEN mWinLost 
								ELSE
									CASE 
										WHEN @modds > 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (144,163,171,1203,408,601,602,461,462,460,475,482,483,397) THEN odds - 1 ELSE odds END ) END ) * - mpositiontaking
										WHEN @modds = 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (144,163,171,1203,408,601,602,461,462,460,475,482,483,397) THEN odds - 1 ELSE odds END ) END ) * - mpositiontaking * 0.5
										WHEN @modds =  0 AND b.oddstype <> 6        THEN 0
										WHEN @modds =  0 AND b.oddstype = 6         THEN CASE 
																					WHEN oddsspread = 0 THEN 0
																					WHEN oddsspread > 0 THEN stake * odds * (oddsspread/100) * -mpositiontaking -- oddsspread > 0: WON
																					ELSE actual_stake * ABS(oddsspread/100) * mpositiontaking -- oddsspread < 0: LOSE
																					END
										WHEN @modds = - 0.25 THEN actual_stake * mpositiontaking * 0.5
										WHEN @modds < - 0.25 THEN actual_stake * mpositiontaking
									END
							END
							
				,sWinLost = CASE 
								WHEN @IsUpd_Void = 0 THEN sWinLost 
								ELSE
									CASE 
										WHEN @modds > 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (144,163,171,1203,408,601,602,461,462,460,475,482,483,397) THEN odds - 1 ELSE odds END ) END    ) * - spositiontaking
										WHEN @modds = 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (144,163,171,1203,408,601,602,461,462,460,475,482,483,397) THEN odds - 1    ELSE odds END ) END    ) * - spositiontaking * 0.5
										WHEN @modds =  0 AND b.oddstype <> 6       THEN 0
										WHEN @modds =  0 AND b.oddstype = 6        THEN CASE 
																					WHEN oddsspread = 0 THEN 0
																					WHEN oddsspread > 0 THEN stake * odds * (oddsspread/100) * -spositiontaking
																					ELSE actual_stake * ABS(oddsspread/100) * spositiontaking 
																					END
										WHEN @modds = - 0.25 THEN actual_stake * spositiontaking * 0.5
										WHEN @modds < - 0.25 THEN actual_stake * spositiontaking
									END
							END
							
				,PlayerComm = CASE 
								WHEN @IsUpd_Void = 0 THEN PlayerComm 
								ELSE CASE 
										WHEN @modds > 0.25 THEN @commWinRate * playerdiscount * @stake
										WHEN @modds = 0.25 THEN @commWinRate * playerdiscount * @stake * @commHalfWLRate
										WHEN @modds =  0 AND b.oddstype <> 6        THEN 0
										WHEN @modds =  0 AND b.oddstype = 6         THEN CASE
																					WHEN oddsspread = 0 THEN 0
																					WHEN oddsspread > 0 THEN @commWinRate * playerdiscount * stake * (oddsspread/100) 
																					ELSE @commLostRate * playerdiscount * stake * ABS(oddsspread/100)
																					END
										WHEN @modds = - 0.25 THEN @commLostRate * playerdiscount * @stake * @commHalfWLRate
										WHEN @modds < - 0.25 THEN @commLostRate * playerdiscount * @stake
									END
							END
							
				,Comm = CASE 
							WHEN @IsUpd_Void = 0 THEN Comm 
							ELSE CASE 
									WHEN @modds > 0.25 THEN @commWinRate * discount * @stake * (1 - apositiontaking)
									WHEN @modds = 0.25 THEN @commWinRate * discount * @stake * (1 - apositiontaking) * @commHalfWLRate
									WHEN @modds =  0 AND b.oddstype <> 6       THEN 0
									WHEN @modds =  0 AND b.oddstype = 6        THEN CASE 
																				WHEN oddsspread = 0 THEN 0
																				WHEN oddsspread > 0 THEN @commWinRate * discount * stake * (oddsspread/100) * (1-apositiontaking)
																				ELSE @commLostRate * discount * stake * ABS(oddsspread/100) * (1-apositiontaking)
																				END
									WHEN @modds = - 0.25 THEN @commLostRate * discount * @stake * (1 - apositiontaking) * @commHalfWLRate
									WHEN @modds < - 0.25 THEN @commLostRate * discount * @stake * (1 - apositiontaking)
								END
							END
							
				,aComm = CASE 
							WHEN @IsUpd_Void = 0 THEN aComm 
							ELSE CASE 
									WHEN @modds > 0.25 THEN @commWinRate * adiscount * @stake * (1 - (mpositiontaking + apositiontaking))
									WHEN @modds = 0.25 THEN @commWinRate * adiscount * @stake * (1 - (mpositiontaking + apositiontaking)) * @commHalfWLRate
									WHEN @modds =  0 AND b.oddstype <> 6        THEN 0
									WHEN @modds =  0 AND b.oddstype = 6         THEN CASE
																				WHEN oddsspread = 0 THEN 0
																				WHEN oddsspread > 0 THEN @commWinRate * adiscount * stake * (oddsspread/100) * (1-(mpositiontaking+apositiontaking))
																				ELSE @commLostRate * adiscount * stake * ABS(oddsspread/100) * (1-(mpositiontaking+apositiontaking))
																				END
									WHEN @modds = - 0.25 THEN @commLostRate * adiscount * @stake * (1 - (mpositiontaking + apositiontaking)) * @commHalfWLRate
									WHEN @modds < - 0.25 THEN @commLostRate * adiscount * @stake * (1 - (mpositiontaking + apositiontaking))
								END
							END
							
				,sComm = CASE 
							WHEN @IsUpd_Void = 0 THEN sComm 
							ELSE CASE 
									WHEN @modds > 0.25 THEN @commWinRate * sdiscount * @stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
									WHEN @modds = 0.25 THEN @commWinRate * sdiscount * @stake * (1 - (spositiontaking + mpositiontaking + apositiontaking)) * @commHalfWLRate
									WHEN @modds =  0 AND b.oddstype <> 6        THEN 0
									WHEN @modds =  0 AND b.oddstype = 6         THEN CASE
																				WHEN oddsspread = 0 THEN 0
																				WHEN oddsspread > 0 THEN @commWinRate * sdiscount * stake * (oddsspread/100) * (1-(spositiontaking+mpositiontaking+apositiontaking))
																				ELSE @commLostRate * sdiscount * stake * ABS(oddsspread/100) * (1-(spositiontaking+mpositiontaking+apositiontaking))
																				END
									WHEN @modds = - 0.25 THEN @commLostRate * sdiscount * @stake * (1 - (spositiontaking + mpositiontaking + apositiontaking)) * @commHalfWLRate
									WHEN @modds < - 0.25 THEN @commLostRate * sdiscount * @stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
								END
							END
							
				,STATUS = CASE 
							WHEN @IsUpd_Void = 0 THEN b.[status]
							ELSE CASE 
									WHEN @modds > 0 THEN N'WON'
									WHEN @modds = 0 AND b.oddstype <> 6 THEN 'DRAW'
									WHEN @modds = 0 AND b.oddstype = 6  THEN CASE WHEN oddsspread = 0 THEN 'DRAW'
																			WHEN oddsspread > 0 THEN 'WON'
																			ELSE 'LOSE'
																			END
									WHEN @modds < 0 THEN N'LOSE'
								END
							END
							
				,StatusID = CASE 
								WHEN @IsUpd_Void = 0 THEN StatusID 
								ELSE @statusId
							END
							
				,ruben = CASE 
							WHEN @IsUpd_Void = 0 THEN ruben 
							ELSE 1
						END
			OUTPUT	inserted.transid
				,inserted.modds, inserted.statuswinlost
				,CASE WHEN inserted.SettlementTime <> deleted.SettlementTime THEN inserted.SettlementTime ELSE NULL END
				,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
				,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm
				,inserted.Status,inserted.StatusID,inserted.ruben		
			INTO @tmpTransInfo (
				transId
				,modds, statuswinlost,SettlementTime,WinLost,aWinLost
				,mWinLost,sWinLost,PlayerComm,Comm,aComm,sComm,Status,StatusID,ruben
			)				
			FROM	#currList t
				INNER JOIN dbo.bettrans b WITH (ROWLOCK, UPDLOCK) 
					ON	t.custid = b.custid
				OUTER APPLY (
					SELECT TOP (1) mt.TransId
					FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
					WHERE	mt.TransId = b.transid
							AND mt.CustId = t.custid
				)mt
			WHERE	matchid = @matchid 
					AND b.custid >= @MinCustId
					AND bettype = @bettype 
					AND statusID NOT IN (101)						
					AND 1 = CASE WHEN @bettype NOT IN (156,1312) THEN 1 
									WHEN @Bettype IN (156,1312) AND @SelectedSet LIKE '%1%' AND BetID = 801 THEN 1 
									WHEN @Bettype IN (156,1312) AND @SelectedSet LIKE '%2%' AND BetID = 802 THEN 1 
									WHEN @Bettype IN (156,1312) AND @SelectedSet LIKE '%3%' AND BetID = 803 THEN 1 
									WHEN @Bettype IN (156,1312) AND @SelectedSet LIKE '%4%' AND BetID = 804 THEN 1
									WHEN @Bettype IN (156,1312) AND @SelectedSet LIKE '%5%' AND BetID = 805 THEN 1 
									ELSE 0 END
					AND 1 = CASE WHEN @IsReSettledTickets = 0 AND statusID IN (0,102) THEN 1
								 WHEN @IsReSettledTickets = 1 THEN 1
								 ELSE 0
							END 
			OPTION (FORCE ORDER)

			IF OBJECT_ID('Service_Settlement_SiteDB_CalculationLog','U') IS NOT NULL 
			BEGIN
				SET @transInfo = (
					SELECT	transId AS '@t'
							,modds AS '@m'				
							,statuswinlost AS '@statuswl' 
							,SettlementTime AS '@st' 
							,WinLost AS '@w' 
							,aWinLost AS '@aw' 
							,mWinLost AS '@mw' 
							,sWinLost AS '@sw' 
							,PlayerComm AS '@pc' 
							,Comm AS '@c' 
							,aComm AS '@ac' 
							,sComm AS '@sc' 
							,Status AS '@s' 
							,StatusID AS '@sid' 
							,ruben AS '@r'				
					FROM	@tmpTransInfo
					FOR XML PATH('r'),ROOT('root'), TYPE
				)

				INSERT INTO dbo.Service_Settlement_SiteDB_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo)
				VALUES ('Settlement', 'CalculateOtherSport', 'bettrans', @MatchId, @transInfo)		
			END	

			WAITFOR DELAY '00:00:00:010'

			--PRINT @@ROWCOUNT
		END

    END

	DROP TABLE #currList
	DROP TABLE #tempCust
END
GO