USE [bodb02]
GO
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_2] @matchid INT
	,@bettype						SMALLINT
	,@oddeven						SMALLMONEY = NULL
	,@oddevenht						SMALLMONEY = NULL
	,@totalgoal						SMALLMONEY = NULL 
	,@SelectedSet					VARCHAR(50) = NULL
	,@OddEvenSetMatch				SMALLMONEY	= NULL	
	,@OddEvenGameSet1				SMALLMONEY	= NULL
	,@OddEvenGameSet2				SMALLMONEY	= NULL
	,@OddEvenGameSet3				SMALLMONEY	= NULL
	,@OddEvenGameSet4				SMALLMONEY	= NULL
	,@OddEvenGameSet5				SMALLMONEY	= NULL
	,@betcount						INT = 0
	,@IsSettleAbandonedMatchIBC		BIT = 0
	,@IsSettleAbandonedMatch		BIT = 0
	,@IsSettleAbandonedMatchBetFair BIT = 0
	,@isExcludeCorner				BIT = 0 
	-- add any params, please modify script in 'special section'
AS
/*
	Created by:Kathy
	Date:20140211
	Task: Settlement 
	DB: DBTRANS.BODB02
	
	Revisions:
		- 20140610@Kathy: Using clustered index(CIX_recommend_matchid_bettype) in DB052, DB053, DB054	
		- 20140808@Kathy: Support new 11 bettypes: 128, 136, 137, 138, 139 [Redmine:#19667]	
		- 20141020@Jamie: Sporting Solution for Tennis [Redmine:#23034]
		- 20150415@Jamie: Settlement Betradar phase 2 [Redmine: #27212]
		- 20150618@Jamie: Offer the option Exclude Corner tickets [Feature #38099]
		- 20151209@Patrick: Database - Change datatype [Redmine: #48660]
		- 20160705@Kathy: PH-AIO phase 2 (67 bettypes ) [Redmine:#53154]

*/
BEGIN
	SET NOCOUNT ON

	IF @betcount = 0
		AND @@SERVERNAME NOT LIKE N'DBIOM%' RETURN

	IF @@SERVERNAME IN ('DB04', 'DB042', 'DB043', 'DB044') RETURN

	DECLARE @modds MONEY
		,@commWinRate SMALLMONEY
		,@commLostRate SMALLMONEY

	IF @@SERVERNAME IN ('DB052', 'DB053', 'DB054', 'DB231','DB215')
	BEGIN
		DECLARE @affectedagents INT

		CREATE TABLE #tmpRecommend (recommend INT PRIMARY KEY)

		INSERT INTO #tmpRecommend (recommend)
		SELECT DISTINCT recommend
		FROM dbo.bettrans(NOLOCK)
		WHERE matchid = @matchid
			AND bettype = @bettype

		DECLARE @currecommend TABLE (recommend INT PRIMARY KEY)

		WHILE 1 = 1
		BEGIN
			DELETE
			FROM @currecommend

			DELETE TOP (100)
			FROM #tmpRecommend
			OUTPUT DELETED.recommend
			INTO @currecommend

			SET @affectedagents = @@rowcount

			UPDATE b
			SET 
				@oddeven	= CASE	WHEN bettype = 2 AND @SelectedSet LIKE '%6%' AND @TotalGoal = 0 THEN @OddEvenSetMatch  
									WHEN bettype = 1318 AND @SelectedSet LIKE '%1%' AND BetID = 801 THEN @OddEvenGameSet1
									WHEN bettype = 1318 AND @SelectedSet LIKE '%2%' AND BetID = 802 THEN @OddEvenGameSet2
									WHEN bettype = 1318 AND @SelectedSet LIKE '%3%' AND BetID = 803 THEN @OddEvenGameSet3
									WHEN bettype = 1318 AND @SelectedSet LIKE '%4%' AND BetID = 804 THEN @OddEvenGameSet4
									WHEN bettype = 1318 AND @SelectedSet LIKE '%5%' AND BetID = 805 THEN @OddEvenGameSet5
									ELSE @oddeven END 
			
				,@modds = CASE 
					WHEN @IsSettleAbandonedMatchIBC = 1 OR @IsSettleAbandonedMatch = 1 OR @IsSettleAbandonedMatchBetFair = 1  -- determined tickets
							THEN CASE 
									WHEN b.betteam IN ('oo', 'oe') AND @oddevenht = 0 THEN - 1
									WHEN b.betteam IN ('eo', 'ee') AND @oddevenht = 1 THEN - 1
									ELSE NULL
								END
					ELSE CASE -- normal settlement
							WHEN betteam = 'h' AND @oddeven = 1 THEN 1
							WHEN betteam = 'a' AND @oddeven = 0 THEN 1
							WHEN betteam = 'o' AND @oddeven = 1 AND @oddevenht IS NULL THEN 1 --184, 194, 1318, 428
							WHEN betteam = 'e' AND @oddeven = 0 AND @oddevenht IS NULL THEN 1 --184, 194, 1318, 428
							WHEN b.betteam = 'oo' AND @oddevenht = 1 AND @oddeven = 1 THEN 1 -- 128
							WHEN b.betteam = 'oe' AND @oddevenht = 1 AND @oddeven = 0 THEN 1 -- 128
							WHEN b.betteam = 'eo' AND @oddevenht = 0 AND @oddeven = 1 THEN 1 -- 128
							WHEN b.betteam = 'ee' AND @oddevenht = 0 AND @oddeven = 0 THEN 1 -- 128
							WHEN b.betteam = 'o' AND (@oddevenht = 1 OR @oddeven = 1) THEN 1 -- 136, 137, 138, 139
							WHEN b.betteam = 'e' AND (@oddevenht = 0 OR @oddeven = 0 ) THEN 1 -- 136, 137, 138, 139
							ELSE - 1
							END
					END
				,modds = @modds
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
				,--'s','m'
				WinLost = CASE 
					WHEN @modds > 0.25 THEN actual_stake + stake * (CASE 
							WHEN odds < 0 THEN 1
							ELSE (CASE 
									WHEN bettype IN (4, 5, 6, 128, 136, 137, 138, 139) THEN odds - 1
									ELSE odds END
									) END
							)
					WHEN @modds = 0.25 THEN actual_stake + stake * (CASE 
							WHEN odds < 0 THEN 1
							ELSE (CASE 
									WHEN bettype IN (4, 5, 6, 128, 136, 137, 138, 139) THEN odds - 1
									ELSE odds END
									) END
							) * 0.5
					WHEN @modds = 0 THEN actual_stake
					WHEN @modds = - 0.25 THEN actual_stake * 0.5
					WHEN @modds < - 0.25 THEN 0
					WHEN @modds IS NULL THEN b.winlost
					END
				,aWinLost = CASE 
					WHEN @modds > 0.25 THEN stake * (CASE 
							WHEN odds < 0 THEN 1
							ELSE (CASE 
									WHEN bettype IN (4, 5, 6, 128, 136, 137, 138, 139) THEN odds - 1
									ELSE odds END
									) END
							) * - apositiontaking
					WHEN @modds = 0.25 THEN stake * (CASE 
							WHEN odds < 0 THEN 1
							ELSE (CASE 
									WHEN bettype IN (4, 5, 6, 128, 136, 137, 138, 139) THEN odds - 1
									ELSE odds END
									) END
							) * - apositiontaking * 0.5
					WHEN @modds = 0 THEN 0
					WHEN @modds = - 0.25 THEN actual_stake * apositiontaking * 0.5
					WHEN @modds < - 0.25 THEN actual_stake * apositiontaking
					WHEN @modds IS NULL THEN b.awinlost
					END
				,mWinLost = CASE 
					WHEN @modds > 0.25 THEN stake * (CASE 
							WHEN odds < 0 THEN 1
							ELSE (CASE 
									WHEN bettype IN (4, 5, 6, 128, 136, 137, 138, 139) THEN odds - 1
									ELSE odds END
									) END
							) * - mpositiontaking
					WHEN @modds = 0.25 THEN stake * (CASE 
							WHEN odds < 0 THEN 1
							ELSE (CASE 
									WHEN bettype IN (4, 5, 6, 128, 136, 137, 138, 139) THEN odds - 1
									ELSE odds END
									) END
							) * - mpositiontaking * 0.5
					WHEN @modds = 0 THEN 0
					WHEN @modds = - 0.25 THEN actual_stake * mpositiontaking * 0.5
					WHEN @modds < - 0.25 THEN actual_stake * mpositiontaking
					WHEN @modds IS NULL THEN b.mwinlost
					END
				,sWinLost = CASE 
					WHEN @modds > 0.25 THEN stake * (CASE 
							WHEN odds < 0 THEN 1
							ELSE (CASE 
									WHEN bettype IN (4, 5, 6, 128, 136, 137, 138, 139) THEN odds - 1
									ELSE odds END
									) END
							) * - spositiontaking
					WHEN @modds = 0.25 THEN stake * (CASE 
							WHEN odds < 0 THEN 1
							ELSE (CASE 
									WHEN bettype IN (4, 5, 6, 128, 136, 137, 138, 139) THEN odds - 1
									ELSE odds END
									) END
							) * - spositiontaking * 0.5
					WHEN @modds = 0 THEN 0
					WHEN @modds = - 0.25 THEN actual_stake * spositiontaking * 0.5
					WHEN @modds < - 0.25 THEN actual_stake * spositiontaking
					WHEN @modds IS NULL THEN b.swinlost
					END
				,PlayerComm = CASE 
					WHEN @modds > 0.25 THEN @commWinRate * playerdiscount * stake
					WHEN @modds = 0.25 THEN @commWinRate * playerdiscount * stake * 0.5
					WHEN @modds = 0 THEN 0
					WHEN @modds = - 0.25 THEN @commLostRate * playerdiscount * stake * 0.5
					WHEN @modds < - 0.25 THEN @commLostRate * playerdiscount * stake
					WHEN @modds IS NULL THEN b.playercomm
					END
				,Comm = CASE 
					WHEN @modds > 0.25 THEN @commWinRate * discount * stake * (1 - apositiontaking)
					WHEN @modds = 0.25 THEN @commWinRate * discount * stake * (1 - apositiontaking) * 0.5
					WHEN @modds = 0 THEN 0
					WHEN @modds = - 0.25 THEN @commLostRate * discount * stake * (1 - apositiontaking) * 0.5
					WHEN @modds < - 0.25 THEN @commLostRate * discount * stake * (1 - apositiontaking)
					WHEN @modds IS NULL THEN b.comm
					END
				,aComm = CASE 
					WHEN @modds > 0.25 THEN @commWinRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking))
					WHEN @modds = 0.25 THEN @commWinRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking)) * 0.5
					WHEN @modds = 0 THEN 0
					WHEN @modds = - 0.25 THEN @commLostRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking)) * 0.5
					WHEN @modds < - 0.25 THEN @commLostRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking))
					WHEN @modds IS NULL THEN b.acomm
					END
				,sComm = CASE 
					WHEN @modds > 0.25 THEN @commWinRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
					WHEN @modds = 0.25 THEN @commWinRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking)) * 0.5
					WHEN @modds = 0 THEN 0
					WHEN @modds = - 0.25 THEN @commLostRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking)) * 0.5
					WHEN @modds < - 0.25 THEN @commLostRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
					WHEN @modds IS NULL THEN b.scomm
					END
				,STATUS = CASE 
					WHEN @modds > 0 THEN 'WON'
					WHEN @modds = 0 THEN 'DRAW'
					WHEN @modds < 0 THEN 'LOSE'
					WHEN @modds IS NULL THEN b.STATUS
					END
				,StatusID = CASE 
					WHEN @modds > 0 THEN 112 --WON
					WHEN @modds = 0 THEN 111 --DRAW
					WHEN @modds < 0 THEN 113 --LOSE
					WHEN @modds IS NULL THEN b.statusID
					END
				,ruben = CASE 
					WHEN @modds IS NULL THEN b.ruben
					ELSE 1
					END
			FROM dbo.bettrans b WITH (ROWLOCK, UPDLOCK)
				INNER JOIN @currecommend ag ON b.recommend = ag.recommend
			WHERE matchid = @matchid
				AND bettype = @bettype
				AND 1 = CASE WHEN @Bettype <> 1318  THEN 1 
							 WHEN @bettype = 1318 AND @SelectedSet LIKE '%1%' AND BetID = 801 THEN 1 
							 WHEN @bettype = 1318 AND @SelectedSet LIKE '%2%' AND BetID = 802 THEN 1
							 WHEN @bettype = 1318 AND @SelectedSet LIKE '%3%' AND BetID = 803 THEN 1
							 WHEN @bettype = 1318 AND @SelectedSet LIKE '%4%' AND BetID = 804 THEN 1 
							 WHEN @bettype = 1318 AND @SelectedSet LIKE '%5%' AND BetID = 805 THEN 1 
							 ELSE 0 END 
				AND 1 = CASE WHEN @isExcludeCorner = 1 AND @bettype IN (194,203) THEN 0 ELSE 1 END 
				AND statusID NOT IN (101, 102)
				AND 1 = CASE 
							WHEN @IsSettleAbandonedMatch = 1 OR @IsSettleAbandonedMatchBetFair = 1 OR @IsSettleAbandonedMatchIBC = 1 
								THEN CASE 
										WHEN @IsSettleAbandonedMatch = 1
											AND (custid IN (50057, 879241, 103873, 78761, 851668, 878902) OR b.recommend = 1688156) THEN 1
										WHEN @IsSettleAbandonedMatchBetFair = 1 AND b.custid IN (2331, 1077687, 115770, 15523642) THEN 1
										WHEN @IsSettleAbandonedMatchIBC = 1 
											AND (custid NOT IN (50057, 879241, 103873, 78761, 851668, 878902, 2331, 1077687, 115770, 15523642) 
													AND b.recommend <> 1688156) THEN 1
										ELSE 0
									 END
							ELSE 1
							END

			IF @affectedagents <> 100
				BREAK
		END

		DROP TABLE #tmpRecommend
	END
	ELSE
	BEGIN
		UPDATE bettrans WITH (ROWLOCK, UPDLOCK)
		SET 
			@oddeven	= CASE	WHEN bettype = 2 AND @SelectedSet LIKE '%6%' AND @TotalGoal = 0 THEN @OddEvenSetMatch  
									WHEN bettype = 1318 AND @SelectedSet LIKE '%1%' AND BetID = 801 THEN @OddEvenGameSet1
									WHEN bettype = 1318 AND @SelectedSet LIKE '%2%' AND BetID = 802 THEN @OddEvenGameSet2
									WHEN bettype = 1318 AND @SelectedSet LIKE '%3%' AND BetID = 803 THEN @OddEvenGameSet3
									WHEN bettype = 1318 AND @SelectedSet LIKE '%4%' AND BetID = 804 THEN @OddEvenGameSet4
									WHEN bettype = 1318 AND @SelectedSet LIKE '%5%' AND BetID = 805 THEN @OddEvenGameSet5
									ELSE @oddeven END 
			,@modds = CASE 
					WHEN @IsSettleAbandonedMatchIBC = 1 OR @IsSettleAbandonedMatch = 1 OR @IsSettleAbandonedMatchBetFair = 1  -- determined tickets
							THEN CASE 
									WHEN betteam IN ('oo', 'oe') AND @oddevenht = 0 THEN - 1
									WHEN betteam IN ('eo', 'ee') AND @oddevenht = 1 THEN - 1
									ELSE NULL
								END
					ELSE CASE -- normal settlement
							WHEN betteam = 'h' AND @oddeven = 1 THEN 1
							WHEN betteam = 'a' AND @oddeven = 0 THEN 1
							WHEN betteam = 'o' AND @oddeven = 1 AND @oddevenht IS NULL THEN 1 --184, 194, 203, 1318, 428
							WHEN betteam = 'e' AND @oddeven = 0 AND @oddevenht IS NULL THEN 1 --184, 194, 203, 1318, 428 
							WHEN betteam = 'oo' AND @oddevenht = 1 AND @oddeven = 1 THEN 1 -- 128
							WHEN betteam = 'oe' AND @oddevenht = 1 AND @oddeven = 0 THEN 1 -- 128
							WHEN betteam = 'eo' AND @oddevenht = 0 AND @oddeven = 1 THEN 1 -- 128
							WHEN betteam = 'ee' AND @oddevenht = 0 AND @oddeven = 0 THEN 1 -- 128
							WHEN betteam = 'o' AND (@oddevenht = 1 OR @oddeven = 1) THEN 1 -- 136, 137, 138, 139
							WHEN betteam = 'e' AND (@oddevenht = 0 OR @oddeven = 0 ) THEN 1 -- 136, 137, 138, 139
							ELSE - 1
							END
					END
			,modds =  @modds
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
			,--'s','m'
			WinLost = CASE 
				WHEN @modds > 0.25 THEN actual_stake + stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (4, 5, 6, 128, 136, 137, 138, 139) THEN odds - 1
								ELSE odds END
								) END
						)
				WHEN @modds = 0.25 THEN actual_stake + stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (4, 5, 6, 128, 136, 137, 138, 139) THEN odds - 1
								ELSE odds END
								) END
						) * 0.5
				WHEN @modds = 0 THEN actual_stake
				WHEN @modds = - 0.25 THEN actual_stake * 0.5
				WHEN @modds < - 0.25 THEN 0
				WHEN @modds IS NULL THEN winlost
				END
			,aWinLost = CASE 
				WHEN @modds > 0.25 THEN stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (4, 5, 6, 128, 136, 137, 138, 139) THEN odds - 1
								ELSE odds END
								) END
						) * - apositiontaking
				WHEN @modds = 0.25 THEN stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (4, 5, 6, 128, 136, 137, 138, 139) THEN odds - 1
								ELSE odds END
								) END
						) * - apositiontaking * 0.5
				WHEN @modds = 0 THEN 0
				WHEN @modds = - 0.25 THEN actual_stake * apositiontaking * 0.5
				WHEN @modds < - 0.25 THEN actual_stake * apositiontaking
				WHEN @modds IS NULL THEN awinlost
				END
			,mWinLost = CASE 
				WHEN @modds > 0.25 THEN stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (4, 5, 6, 128, 136, 137, 138, 139) THEN odds - 1
								ELSE odds END
								) END
						) * - mpositiontaking
				WHEN @modds = 0.25 THEN stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (4, 5, 6, 128, 136, 137, 138, 139) THEN odds - 1
								ELSE odds END
								) END
						) * - mpositiontaking * 0.5
				WHEN @modds = 0 THEN 0
				WHEN @modds = - 0.25 THEN actual_stake * mpositiontaking * 0.5
				WHEN @modds < - 0.25 THEN actual_stake * mpositiontaking
				WHEN @modds IS NULL THEN mwinlost
				END
			,sWinLost = CASE 
				WHEN @modds > 0.25 THEN stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (4, 5, 6, 128, 136, 137, 138, 139) THEN odds - 1
								ELSE odds END
								) END
						) * - spositiontaking
				WHEN @modds = 0.25 THEN stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (4, 5, 6, 128, 136, 137, 138, 139) THEN odds - 1
								ELSE odds END
								) END
						) * - spositiontaking * 0.5
				WHEN @modds = 0 THEN 0
				WHEN @modds = - 0.25 THEN actual_stake * spositiontaking * 0.5
				WHEN @modds < - 0.25 THEN actual_stake * spositiontaking
				WHEN @modds IS NULL THEN swinlost
				END
			,PlayerComm = CASE 
				WHEN @modds > 0.25 THEN @commWinRate * playerdiscount * stake
				WHEN @modds = 0.25 THEN @commWinRate * playerdiscount * stake * 0.5
				WHEN @modds = 0 THEN 0
				WHEN @modds = - 0.25 THEN @commLostRate * playerdiscount * stake * 0.5
				WHEN @modds < - 0.25 THEN @commLostRate * playerdiscount * stake
				WHEN @modds IS NULL THEN playercomm
				END
			,Comm = CASE 
				WHEN @modds > 0.25 THEN @commWinRate * discount * stake * (1 - apositiontaking)
				WHEN @modds = 0.25 THEN @commWinRate * discount * stake * (1 - apositiontaking) * 0.5
				WHEN @modds = 0 THEN 0
				WHEN @modds = - 0.25 THEN @commLostRate * discount * stake * (1 - apositiontaking) * 0.5
				WHEN @modds < - 0.25 THEN @commLostRate * discount * stake * (1 - apositiontaking)
				WHEN @modds IS NULL THEN comm
				END
			,aComm = CASE 
				WHEN @modds > 0.25 THEN @commWinRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking))
				WHEN @modds = 0.25 THEN @commWinRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking)) * 0.5
				WHEN @modds = 0 THEN 0
				WHEN @modds = - 0.25 THEN @commLostRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking)) * 0.5
				WHEN @modds < - 0.25 THEN @commLostRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking))
				WHEN @modds IS NULL THEN acomm
				END
			,sComm = CASE 
				WHEN @modds > 0.25 THEN @commWinRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
				WHEN @modds = 0.25 THEN @commWinRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking)) * 0.5
				WHEN @modds = 0 THEN 0
				WHEN @modds = - 0.25 THEN @commLostRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking)) * 0.5
				WHEN @modds < - 0.25 THEN @commLostRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
				WHEN @modds IS NULL THEN scomm
				END
			,STATUS = CASE 
				WHEN @modds > 0 THEN 'WON'
				WHEN @modds = 0 THEN 'DRAW'
				WHEN @modds < 0 THEN 'LOSE'
				WHEN @modds IS NULL THEN status
				END
			,StatusID = CASE 
				WHEN @modds > 0 THEN 112 --WON
				WHEN @modds = 0 THEN 111 --DRAW
				WHEN @modds < 0 THEN 113 --LOSE
				WHEN @modds IS NULL THEN statusID
				END
			,ruben = CASE WHEN @modds IS NULL THEN ruben
						  ELSE 1
					 END
		WHERE matchid = @matchid
			AND bettype = @bettype
			AND statusID NOT IN (101, 102)
			AND 1 = CASE WHEN @Bettype <> 1318  THEN 1 
							 WHEN @bettype = 1318 AND @SelectedSet LIKE '%1%' AND BetID = 801 THEN 1 
							 WHEN @bettype = 1318 AND @SelectedSet LIKE '%2%' AND BetID = 802 THEN 1
							 WHEN @bettype = 1318 AND @SelectedSet LIKE '%3%' AND BetID = 803 THEN 1
							 WHEN @bettype = 1318 AND @SelectedSet LIKE '%4%' AND BetID = 804 THEN 1 
							 WHEN @bettype = 1318 AND @SelectedSet LIKE '%5%' AND BetID = 805 THEN 1 
							 ELSE 0 END
			AND 1 = CASE WHEN @isExcludeCorner = 1 AND  @bettype IN (194,203) THEN 0 ELSE 1 END 
	END
END
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Admin_Calculate_2] TO [vnteam] AS [dbo]