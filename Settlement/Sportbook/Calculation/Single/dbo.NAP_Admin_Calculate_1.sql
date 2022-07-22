/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_1] 
     @matchid INT
    ,@bettype				SMALLINT
    ,@fth					SMALLMONEY		= NULL
    ,@fta					SMALLMONEY		= NULL 
    ,@SelectedSet			VARCHAR(50)		= NULL 
    ,@TotalGameHomeSet1		SMALLMONEY		= NULL 
    ,@TotalGameHomeSet2		SMALLMONEY		= NULL 
    ,@TotalGameHomeSet3		SMALLMONEY		= NULL 
    ,@TotalGameHomeSet4		SMALLMONEY		= NULL 
    ,@TotalGameHomeSet5		SMALLMONEY		= NULL 
    ,@TotalGameAwaySet1		SMALLMONEY		= NULL 
    ,@TotalGameAwaySet2		SMALLMONEY		= NULL 
    ,@TotalGameAwaySet3		SMALLMONEY		= NULL 
    ,@TotalGameAwaySet4		SMALLMONEY		= NULL 
    ,@TotalGameAwaySet5		SMALLMONEY		= NULL 
    ,@betcount              INT				= 0
	,@IsReSettledTickets	BIT				= 1
	,@Sporttype				SMALLINT		= NULL
    -- add any params, please modify script in 'special section'
AS
/*
    Created by: Kathy
    Date:20140211
    Task: Settlement 
    DB: DBTRANS.BODB02
    
    Revisions:
        - 20140610@Kathy: Using clustered index(CIX_recommend_matchid_bettype) in DB052, DB053, DB054        
        - 20141017@Jamie: Sporting Solution for Tennis [Redmine:#23034]
        - 20150415@Jamie: Settlement Betradar phase 2 [Redmine: #27212]
        - 20150909@Kathy: Intergrate Myanmar Odds ( 4 new bettypes: 301->304): add bettype 301
        - 20151026@Kathy: Change Myanmar Odds commision formula [Redmine:#46284]
		- 20151207@Patrick: Database - Change datatype [Redmine: #48660]
		- 20160425@Patrick: Reduce escalation lock when updating large amount of data [Redmine: #56550]
		- 20160507@Patrick: Use Option Force Order & limit scanning on bettrans table incase merge join for batchNo n > 1 to reduce lock escalation [Redmine: #58464]
		- 20160705@Kathy: PH-AIO phase 2 (67 bettypes ) [Redmine:#53154]
		- 20180904@Kathy: Change CIX on DB054 [Redmine:#100828]
		- 20181004@Kathy: Change CIX on DB053 [Redmine:#102594]
		- 20181030@Kathy: Change CIX on DB052 [Redmine:#103985]
        - 20181129@Kathy: Do not settle ticket on DB04x [Redmine:#105327]
		- 20190225@Sol:  New Formula for Comm [Redmine:#109007]
		- 20190320@Kathy: Settlement with Tickets Exclusion [Redmine:#106823]
		- 20190408@Sol: Settlement Time [Redmine:#99638] 
		- 20190715@Helen: Recover/Void tickets in Bet 14 - Update statuswinlost for VOID Tickets [Redmine:115377]
		- 20200901@Kathy: Change Calculate Formula for HDP Bet Types of Football [Redmine:#140769]
		- 20200921@Louisa: Implement for Myanmar odds (apply bettype 1,3,7,8 remove 301->304) [Redmine:#141824]
		- 20201027@Kathy: - Change Calculate Formula for HDP Bet Types of Baseball
						  - Exclude livescore for bettype moneyline [Redmine:#144297]
		- 20210303@Kathy: Exclude LiveScores When Calculate HDP Bet Types [Redmine:#150198]
		- 20210922@Louisa: Exclude LiveScores HDP for Ice Hockey and Rugby [Redmine:#159903]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
		
*/
BEGIN
	SET NOCOUNT ON
	
	-- CHECK SERVER BEFORE CALCULATING
	DECLARE @ServerName			SYSNAME 
			,@AllowCalculation	BIT
			,@CutOffDate		DATETIME = '2021-10-07 00:00:00.000'
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
        ,@RemoteCount INT
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
		INSERT INTO #tempCust (custid, srecommend)
		SELECT	b.custid, b.srecommend
		FROM	dbo.bettrans b WITH(NOLOCK)
		WHERE	b.matchid = @matchid
				AND b.bettype = @bettype
				AND b.statusID IN (0,102)
		GROUP BY b.custid, b.srecommend
	END
	ELSE
	BEGIN
		INSERT INTO #tempCust(custid, sRecommend)
		SELECT	b.custid, b.srecommend
		FROM	dbo.bettrans b WITH(NOLOCK) 
		WHERE	b.matchid = @matchid 
				AND b.bettype = @bettype
		GROUP BY b.custid, b.srecommend
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

	WHILE 1 = 1
    BEGIN
        DELETE FROM #currList

        DELETE TOP (1000)
        FROM #tempCust OUTPUT DELETED.custid, DELETED.isCN88 INTO #currList

        IF @@ROWCOUNT = 0 BREAK

		SELECT @MinCustId = MIN(CustId) FROM #currList

		SET @settlementTime = GETDATE();

		UPDATE b
		SET @fth = CASE WHEN bettype IN (154,155,1311, 1316) AND BetID = 801 AND @SelectedSet LIKE '%1%' THEN @TotalGameHomeSet1 
						WHEN bettype IN (154,155,1311, 1316) AND BetID = 802 AND @SelectedSet LIKE '%2%' THEN @TotalGameHomeSet2 
						WHEN bettype IN (154,155,1311, 1316) AND BetID = 803 AND @SelectedSet LIKE '%3%' THEN @TotalGameHomeSet3 
						WHEN bettype IN (154,155,1311, 1316) AND BetID = 804 AND @SelectedSet LIKE '%4%' THEN @TotalGameHomeSet4 
						WHEN bettype IN (154,155,1311, 1316) AND BetID = 805 AND @SelectedSet LIKE '%5%' THEN @TotalGameHomeSet5
						ELSE @fth END 
			,@fta = CASE WHEN bettype IN (154,155,1311, 1316) AND BetID = 801 AND @SelectedSet LIKE '%1%' THEN @TotalGameAwaySet1 
							WHEN bettype IN (154,155,1311, 1316) AND BetID = 802 AND @SelectedSet LIKE '%2%' THEN @TotalGameAwaySet2
							WHEN bettype IN (154,155,1311, 1316) AND BetID = 803 AND @SelectedSet LIKE '%3%' THEN @TotalGameAwaySet3 
							WHEN bettype IN (154,155,1311, 1316) AND BetID = 804 AND @SelectedSet LIKE '%4%' THEN @TotalGameAwaySet4 
							WHEN bettype IN (154,155,1311, 1316) AND BetID = 805 AND @SelectedSet LIKE '%5%' THEN @TotalGameAwaySet5
							ELSE @fta END        
			,@modds = CASE betteam
				WHEN N'h' THEN (hdp2 - hdp1) + (@fth - @fta) - CASE 
																	WHEN @Sporttype IN (4,26) AND b.transdate >= @CutOffDate THEN 0
																	WHEN (@Sporttype BETWEEN 2 AND 56 AND @Sporttype NOT IN (4,26,28,43,49,51))
																		OR @Sporttype = 99
																		OR @bettype = 20 THEN 0
																	ELSE (livehomescore - liveawayscore) 
																END
				WHEN N'a' THEN (hdp1 - hdp2) - (@fth - @fta) + CASE 
																	WHEN @Sporttype IN (4,26) AND b.transdate >= @CutOffDate THEN 0
																	WHEN (@Sporttype BETWEEN 2 AND 56 AND @Sporttype NOT IN (4,26,28,43,49,51))
																		OR @Sporttype = 99
																		OR @bettype = 20 THEN 0 
																	ELSE (livehomescore - liveawayscore) 
																END
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
			,--'s','m'
			@winlost = CASE 
				WHEN @modds > 0.25 THEN actual_stake + stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (4, 5, 6, 1201) THEN odds - 1
								ELSE odds END
								) END
						)
				WHEN @modds = 0.25 THEN actual_stake + stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (4, 5, 6, 1201) THEN odds - 1
								ELSE odds END
								) END
						) * 0.5
				WHEN @modds =  0 AND b.oddstype <> 6    THEN actual_stake
				WHEN @modds =  0 AND b.oddstype = 6    THEN CASE 
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
				WHEN @modds = 0 AND b.oddstype = 6 THEN CASE WHEN oddsspread = 0 THEN 111 
															WHEN oddsspread > 0 THEN 112
															ELSE 113
															END
				WHEN @modds < 0 THEN 113 --LOSE
				END
			,SettlementTime = CASE 
								WHEN @IsUpd_Void = 0  THEN SettlementTime 
								ELSE CASE WHEN winlost <> @winlost OR statusID <> @statusId THEN @settlementTime ELSE SettlementTime END
							END
			,WinLost = 	CASE 
							WHEN @IsUpd_Void = 0  THEN WinLost 
							ELSE @winlost
						END
			,aWinLost = CASE 
							WHEN @IsUpd_Void = 0  THEN aWinLost
							ELSE CASE 
									WHEN @modds > 0.25 THEN stake * (CASE 
											WHEN odds < 0 THEN 1
											ELSE (CASE 
													WHEN bettype IN (4, 5, 6, 1201) THEN odds - 1
													ELSE odds END
													) END
											) * - apositiontaking
									WHEN @modds = 0.25 THEN stake * (CASE 
											WHEN odds < 0 THEN 1
											ELSE (CASE 
													WHEN bettype IN (4, 5, 6, 1201) THEN odds - 1
													ELSE odds END
													) END
											) * - apositiontaking * 0.5
									WHEN @modds =  0 AND b.oddstype <> 6    THEN 0
									WHEN @modds =  0 AND b.oddstype = 6    THEN CASE 
																				WHEN oddsspread = 0 THEN 0
																				WHEN oddsspread > 0 THEN stake * odds * (oddsspread/100) * -apositiontaking -- oddsspread > 0: WON
																				ELSE actual_stake * ABS(oddsspread/100) * apositiontaking -- oddsspread < 0: LOSE
																				END
									WHEN @modds = - 0.25 THEN actual_stake * apositiontaking * 0.5
									WHEN @modds < - 0.25 THEN actual_stake * apositiontaking
								END
						END
			,mWinLost = CASE 
							WHEN @IsUpd_Void = 0  THEN mWinLost 
							ELSE CASE 
									WHEN @modds > 0.25 THEN stake * (CASE 
											WHEN odds < 0 THEN 1
											ELSE (CASE 
													WHEN bettype IN (4, 5, 6, 1201) THEN odds - 1
													ELSE odds END
													) END
											) * - mpositiontaking
									WHEN @modds = 0.25 THEN stake * (CASE 
											WHEN odds < 0 THEN 1
											ELSE (CASE 
													WHEN bettype IN (4, 5, 6, 1201) THEN odds - 1
													ELSE odds END
													) END
											) * - mpositiontaking * 0.5
									WHEN @modds =  0 AND b.oddstype <> 6        THEN 0
									WHEN @modds =  0 AND b.oddstype = 6        THEN CASE 
																					WHEN oddsspread = 0 THEN 0
																					WHEN oddsspread > 0 THEN stake * odds * (oddsspread/100) * -mpositiontaking -- oddsspread > 0: WON
																					ELSE actual_stake * ABS(oddsspread/100) * mpositiontaking -- oddsspread < 0: LOSE
																					END
									WHEN @modds = - 0.25 THEN actual_stake * mpositiontaking * 0.5
									WHEN @modds < - 0.25 THEN actual_stake * mpositiontaking
								END
						END
			,sWinLost = CASE 
							WHEN @IsUpd_Void = 0  THEN sWinLost 
							ELSE CASE 
									WHEN @modds > 0.25 THEN stake * (CASE 
											WHEN odds < 0 THEN 1
											ELSE (CASE 
													WHEN bettype IN (4, 5, 6, 1201) THEN odds - 1
													ELSE odds END
													) END
											) * - spositiontaking
									WHEN @modds = 0.25 THEN stake * (CASE 
											WHEN odds < 0 THEN 1
											ELSE (CASE 
													WHEN bettype IN (4, 5, 6, 1201) THEN odds - 1
													ELSE odds END
													) END
											) * - spositiontaking * 0.5
									WHEN @modds =  0 AND b.oddstype <> 6       THEN 0
									WHEN @modds =  0 AND b.oddstype = 6       THEN CASE 
																					WHEN oddsspread = 0 THEN 0
																					WHEN oddsspread > 0 THEN stake * odds * (oddsspread/100) * -spositiontaking
																					ELSE actual_stake * ABS(oddsspread/100) * spositiontaking 
																					END
									WHEN @modds = - 0.25 THEN actual_stake * spositiontaking * 0.5
									WHEN @modds < - 0.25 THEN actual_stake * spositiontaking
								END
							END
			
			
			,PlayerComm = CASE 
							WHEN @IsUpd_Void = 0  THEN PlayerComm 
							ELSE CASE 
									WHEN @modds > 0.25 THEN @commWinRate * playerdiscount * @stake
									WHEN @modds = 0.25 THEN @commWinRate * playerdiscount * @stake * @commHalfWLRate
									WHEN @modds =  0 AND b.oddstype <> 6        THEN 0
									WHEN @modds =  0 AND b.oddstype = 6        THEN CASE
																					WHEN oddsspread = 0 THEN 0
																					WHEN oddsspread > 0 THEN @commWinRate * playerdiscount * stake * (oddsspread/100)
																					ELSE @commLostRate * playerdiscount * stake * ABS(oddsspread/100)
																					END
									WHEN @modds = - 0.25 THEN @commLostRate * playerdiscount * @stake * @commHalfWLRate
									WHEN @modds < - 0.25 THEN @commLostRate * playerdiscount * @stake
								END
						END
			
			,Comm = CASE 
						WHEN @IsUpd_Void = 0  THEN Comm 
						ELSE CASE 
								WHEN @modds > 0.25 THEN @commWinRate * discount * @stake * (1 - apositiontaking)
								WHEN @modds = 0.25 THEN @commWinRate * discount * @stake * (1 - apositiontaking) * @commHalfWLRate
								WHEN @modds =  0 AND b.oddstype <> 6       THEN 0
								WHEN @modds =  0 AND b.oddstype = 6       THEN CASE 
																				WHEN oddsspread = 0 THEN 0
																				WHEN oddsspread > 0 THEN @commWinRate * discount * stake * (oddsspread/100) * (1-apositiontaking)
																				ELSE @commLostRate * discount * stake * ABS(oddsspread/100) * (1-apositiontaking)
																				END
								WHEN @modds = - 0.25 THEN @commLostRate * discount * @stake * (1 - apositiontaking) * @commHalfWLRate
								WHEN @modds < - 0.25 THEN @commLostRate * discount * @stake * (1 - apositiontaking)
								END
						END
			
			,aComm = CASE 
						WHEN @IsUpd_Void = 0  THEN aComm 
						ELSE CASE 
								WHEN @modds > 0.25 THEN @commWinRate * adiscount * @stake * (1 - (mpositiontaking + apositiontaking))
								WHEN @modds = 0.25 THEN @commWinRate * adiscount * @stake * (1 - (mpositiontaking + apositiontaking)) * @commHalfWLRate
								WHEN @modds =  0 AND b.oddstype <> 6        THEN 0
								WHEN @modds =  0 AND b.oddstype = 6        THEN CASE
																				WHEN oddsspread = 0 THEN 0
																				WHEN oddsspread > 0 THEN @commWinRate * adiscount * stake * (oddsspread/100) * (1-(mpositiontaking+apositiontaking))
																				ELSE @commLostRate * adiscount * stake * ABS(oddsspread/100) * (1-(mpositiontaking+apositiontaking))
																				END
								WHEN @modds = - 0.25 THEN @commLostRate * adiscount * @stake * (1 - (mpositiontaking + apositiontaking)) * @commHalfWLRate
								WHEN @modds < - 0.25 THEN @commLostRate * adiscount * @stake * (1 - (mpositiontaking + apositiontaking))
							END
						END
			
			,sComm = CASE 
						WHEN @IsUpd_Void = 0  THEN sComm 
						ELSE CASE 
								WHEN @modds > 0.25 THEN @commWinRate * sdiscount * @stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
								WHEN @modds = 0.25 THEN @commWinRate * sdiscount * @stake * (1 - (spositiontaking + mpositiontaking + apositiontaking)) * @commHalfWLRate
								WHEN @modds =  0 AND b.oddstype <> 6        THEN 0
								WHEN @modds =  0 AND b.oddstype = 6        THEN CASE
																				WHEN oddsspread = 0 THEN 0
																				WHEN oddsspread > 0 THEN @commWinRate * sdiscount * stake * (oddsspread/100) * (1-(spositiontaking+mpositiontaking+apositiontaking))
																				ELSE @commLostRate * sdiscount * stake * ABS(oddsspread/100) * (1-(spositiontaking+mpositiontaking+apositiontaking))
																				END
								WHEN @modds = - 0.25 THEN @commLostRate * sdiscount * @stake * (1 - (spositiontaking + mpositiontaking + apositiontaking)) * @commHalfWLRate
								WHEN @modds < - 0.25 THEN @commLostRate * sdiscount * @stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
							END
						END
			
			,STATUS = CASE 
						WHEN @IsUpd_Void = 0  THEN b.[status] 
						ELSE CASE 
								WHEN @modds > 0 THEN N'WON'
								WHEN @modds = 0 AND b.oddstype <> 6 THEN 'DRAW'
								WHEN @modds = 0 AND b.oddstype = 6 THEN CASE WHEN oddsspread = 0 THEN 'DRAW' 
																			WHEN oddsspread > 0 THEN 'WON'
																			ELSE 'LOSE'
																			END
								WHEN @modds < 0 THEN N'LOSE'
							END
						END
			
			,StatusID =CASE 
							WHEN @IsUpd_Void = 0  THEN StatusID 
							ELSE @statusId
						END
			
			,ruben = CASE 
						WHEN @IsUpd_Void = 0   THEN ruben 
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
		FROM #currList t 
			INNER JOIN dbo.bettrans b WITH (ROWLOCK, UPDLOCK) 
				ON	t.custid = b.custid
			OUTER APPLY (
				SELECT TOP (1) mt.TransId
				FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
				WHERE	mt.TransId = b.transId
						AND mt.CustId = t.custid
			)mt
		WHERE matchid = @matchid 
			AND b.custid >= @MinCustId
			AND b.bettype = @bettype 
			AND b.statusID NOT IN (101) -- REJECT  	
			AND 1 = CASE WHEN @Bettype NOT IN (154,155,1311, 1316) THEN 1
							WHEN @Bettype IN (154,155,1311, 1316) AND @SelectedSet LIKE '%1%' AND BetID = 801 THEN 1
							WHEN @Bettype IN (154,155,1311, 1316) AND @SelectedSet LIKE '%2%' AND BetID = 802 THEN 1
							WHEN @Bettype IN (154,155,1311, 1316) AND @SelectedSet LIKE '%3%' AND BetID = 803 THEN 1
							WHEN @Bettype IN (154,155,1311, 1316) AND @SelectedSet LIKE '%4%' AND BetID = 804 THEN 1
							WHEN @Bettype IN (154,155,1311, 1316) AND @SelectedSet LIKE '%5%' AND BetID = 805 THEN 1
							ELSE 0 END
			
			AND 1 = CASE WHEN @IsReSettledTickets = 0 AND statusID IN (0,102) THEN 1
						 WHEN @IsReSettledTickets = 1 THEN 1
						 ELSE 0
					END
			
		OPTION (FORCE ORDER)

		IF OBJECT_ID('Service_SiteDB_CalculationLog','U') IS NOT NULL 
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

			INSERT INTO dbo.Service_SiteDB_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo)
			VALUES ('Settlement', 'CalculateOtherSport', 'bettrans', @MatchId, @transInfo)		
			
		END

		WAITFOR DELAY '00:00:00:010'
	END

	DROP TABLE #currList
	DROP TABLE #tempCust
END
GO