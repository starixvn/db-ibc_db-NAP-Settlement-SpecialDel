/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0"></info>*/
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_24] @matchid INT
	,@bettype SMALLINT
	,@scorediff SMALLINT = 0
	,@totalgoal SMALLINT = 0
	,@fth SMALLINT = 0
	,@fta SMALLINT = 0
	,@FGLG2	NVARCHAR(10) = NULL
	,@betcount INT = 0
	,@IsSettleAbandonedMatchIBC BIT = 0 -- IBC
    ,@IsSettleAbandonedMatch BIT = 0 -- BetDaq
    ,@IsSettleAbandonedMatchBetFair BIT = 0 -- BetFair
	
	
AS
/*
	Created by: Kathy
	Date:20140211
	Task: Settlement for Double Chance 
	DB: DB02.BODB02
	
	Revisions:
		- 20140624@Kathy: Apply BetRadar: Add new bettype 151 (1st Double Change) [Redmine:#17142]
		- 20150415@Jamie: Settlement Betradar phase 2 [Redmine: #27212]
		- 20151125@Patrick: Apply 28 Live Bettypes for Settlement [Redmine:#47843]
		- 20151209@Patrick: Database - Change datatype [Redmine: #48660]
		- 20160705@Kathy: PH-AIO phase 2 (67 bettypes ) [Redmine:#53154]
		- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]

*/
BEGIN
	IF @betcount = 0 AND @@SERVERNAME NOT LIKE N'DBIOM%' RETURN

	IF @@SERVERNAME IN ('DB04', 'DB042', 'DB043', 'DB044') RETURN

	SET NOCOUNT ON

	DECLARE @modds MONEY
		,@commWinRate SMALLMONEY
		,@commLostRate SMALLMONEY
	
	
	SET @FGLG2  = CASE 
					--454: Double Chance & First Team To Score
					WHEN @bettype = 454 
						THEN CASE 
								WHEN @FGLG2 = 'N' THEN 'NG'
								ELSE @FGLG2
								END
					ELSE @FGLG2 
				END
				
	IF @IsSettleAbandonedMatchIBC = 0 AND @IsSettleAbandonedMatchBetFair = 0 AND @IsSettleAbandonedMatch = 0
	BEGIN
		UPDATE bettrans WITH (ROWLOCK, UPDLOCK)
		SET @modds = CASE
				WHEN @bettype = 449 THEN
										CASE 
											WHEN betteam = '1XO' AND @ScoreDiff >= 0 AND @totalgoal - [hdp1] > 0 THEN 1
											WHEN betteam = '1XU' AND @ScoreDiff >= 0 AND @totalgoal - [hdp1] < 0 THEN 1
											WHEN betteam = '12O' AND @ScoreDiff <> 0 AND @totalgoal - [hdp1] > 0 THEN 1
											WHEN betteam = '12U' AND @ScoreDiff <> 0 AND @totalgoal - [hdp1] < 0 THEN 1
											WHEN betteam = '2XO' AND @ScoreDiff <= 0 AND @totalgoal - [hdp1] > 0 THEN 1
											WHEN betteam = '2XU' AND @ScoreDiff <= 0 AND @totalgoal - [hdp1] < 0 THEN 1
											ELSE -1
										END 
				--451: Both Teams To Score / Double Chance
				WHEN @bettype = 451 THEN CASE
											WHEN betteam = 'Y1X' AND (@fth > 0  AND @fta > 0) AND @ScoreDiff >= 0 THEN 1
											WHEN betteam = 'Y12' AND (@fth > 0  AND @fta > 0) AND @ScoreDiff <> 0 THEN 1
											WHEN betteam = 'Y2X' AND (@fth > 0  AND @fta > 0) AND @ScoreDiff <= 0 THEN 1

											WHEN betteam = 'N1X' AND (@fth = 0  OR @fta = 0) AND @ScoreDiff >= 0 THEN 1
											WHEN betteam = 'N12' AND (@fth = 0  OR @fta = 0) AND @ScoreDiff <> 0 THEN 1
											WHEN betteam = 'N2X' AND (@fth = 0  OR @fta = 0) AND @ScoreDiff <= 0 THEN 1
											ELSE -1
										END
				--454: Double Chance & First Team To Score
				WHEN @bettype = 454 THEN CASE
											WHEN betteam = '1XH' AND @ScoreDiff >= 0 AND @FGLG2 = 'H' THEN 1
											WHEN betteam = '12H' AND @ScoreDiff <> 0 AND @FGLG2 = 'H' THEN 1
											WHEN betteam = '2XH' AND @ScoreDiff <= 0 AND @FGLG2 = 'H' THEN 1
											WHEN betteam = '1XA' AND @ScoreDiff >= 0 AND @FGLG2 = 'A' THEN 1
											WHEN betteam = '12A' AND @ScoreDiff <> 0 AND @FGLG2 = 'A' THEN 1
											WHEN betteam = '2XA' AND @ScoreDiff <= 0 AND @FGLG2 = 'A' THEN 1
											WHEN betteam = 'NG'  AND @fth = 0 AND @fta = 0 THEN 1
											ELSE -1
										END
																	
				WHEN betteam = '1X' AND @scorediff >= 0 THEN 1
				WHEN betteam = '2X' AND @scorediff <= 0 THEN 1
				WHEN betteam = '12' AND @scorediff <> 0 THEN 1
				WHEN betteam = 'HD' AND @scorediff >= 0 THEN 1 
				WHEN betteam = 'DA' AND @scorediff <= 0 THEN 1
				WHEN betteam = 'HA' AND @scorediff <> 0 THEN 1
				ELSE - 1
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
								WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28, 1224, 151,186,410,431,449,451,454) THEN odds - 1
								ELSE odds END
								) END
						)
				WHEN @modds = 0.25 THEN actual_stake + stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28, 1224, 151,186,410,431,449,451,454) THEN odds - 1
								ELSE odds END
								) END
						) * 0.5
				WHEN @modds = 0 THEN actual_stake
				WHEN @modds = - 0.25 THEN actual_stake * 0.5
				WHEN @modds < - 0.25 THEN 0
				END
			,aWinLost = CASE 
				WHEN @modds > 0.25 THEN stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28, 1224, 151,186,410,431,449,451,454) THEN odds - 1
								ELSE odds END
								) END
						) * - apositiontaking
				WHEN @modds = 0.25 THEN stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28, 1224, 151,186,410,431,449,451,454) THEN odds - 1
								ELSE odds END
								) END
						) * - apositiontaking * 0.5
				WHEN @modds = 0 THEN 0
				WHEN @modds = - 0.25 THEN actual_stake * apositiontaking * 0.5
				WHEN @modds < - 0.25 THEN actual_stake * apositiontaking
				END
			,mWinLost = CASE 
				WHEN @modds > 0.25 THEN stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28, 1224, 151,186,410,431,449,451,454) THEN odds - 1
								ELSE odds END
								) END
						) * - mpositiontaking
				WHEN @modds = 0.25 THEN stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28, 1224, 151,186,410,431,449,451,454) THEN odds - 1
								ELSE odds END
								) END
						) * - mpositiontaking * 0.5
				WHEN @modds = 0 THEN 0
				WHEN @modds = - 0.25 THEN actual_stake * mpositiontaking * 0.5
				WHEN @modds < - 0.25 THEN actual_stake * mpositiontaking
				END
			,sWinLost = CASE 
				WHEN @modds > 0.25 THEN stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28, 1224, 151,186,410,431,449,451,454) THEN odds - 1
								ELSE odds END
								) END
						) * - spositiontaking
				WHEN @modds = 0.25 THEN stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28, 1224, 151,186,410,431,449,451,454) THEN odds - 1
								ELSE odds END
								) END
						) * - spositiontaking * 0.5
				WHEN @modds = 0 THEN 0
				WHEN @modds = - 0.25 THEN actual_stake * spositiontaking * 0.5
				WHEN @modds < - 0.25 THEN actual_stake * spositiontaking
				END
			,PlayerComm = CASE 
				WHEN @modds > 0.25 THEN @commWinRate * playerdiscount * stake
				WHEN @modds = 0.25 THEN @commWinRate * playerdiscount * stake * 0.5
				WHEN @modds = 0 THEN 0
				WHEN @modds = - 0.25 THEN @commLostRate * playerdiscount * stake * 0.5
				WHEN @modds < - 0.25 THEN @commLostRate * playerdiscount * stake
				END
			,Comm = CASE 
				WHEN @modds > 0.25 THEN @commWinRate * discount * stake * (1 - apositiontaking)
				WHEN @modds = 0.25 THEN @commWinRate * discount * stake * (1 - apositiontaking) * 0.5
				WHEN @modds = 0 THEN 0
				WHEN @modds = - 0.25 THEN @commLostRate * discount * stake * (1 - apositiontaking) * 0.5
				WHEN @modds < - 0.25 THEN @commLostRate * discount * stake * (1 - apositiontaking)
				END
			,aComm = CASE 
				WHEN @modds > 0.25 THEN @commWinRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking))
				WHEN @modds = 0.25 THEN @commWinRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking)) * 0.5
				WHEN @modds = 0 THEN 0
				WHEN @modds = - 0.25 THEN @commLostRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking)) * 0.5
				WHEN @modds < - 0.25 THEN @commLostRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking))
				END
			,sComm = CASE 
				WHEN @modds > 0.25 THEN @commWinRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
				WHEN @modds = 0.25 THEN @commWinRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking)) * 0.5
				WHEN @modds = 0 THEN 0
				WHEN @modds = - 0.25 THEN @commLostRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking)) * 0.5
				WHEN @modds < - 0.25 THEN @commLostRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
				END
			,STATUS = CASE 
				WHEN @modds > 0 THEN 'WON'
				WHEN @modds = 0 THEN 'DRAW'
				WHEN @modds < 0 THEN 'LOSE'
				END
			,StatusID = CASE 
				WHEN @modds > 0 THEN 112 --WON
				WHEN @modds = 0 THEN 111 --DRAW
				WHEN @modds < 0 THEN 113 --LOSE
				END
			,ruben = 1
		WHERE matchid = @matchid AND bettype = @bettype AND
			--status NOT IN ('VOID', 'REJECT')
			statusID NOT IN (101, 102)
	END
	ELSE
	BEGIN
		UPDATE bettrans WITH (ROWLOCK, UPDLOCK)
		SET @modds = CASE
				WHEN @bettype = 449 THEN CASE 
											WHEN RIGHT(betteam,1) = 'U' AND @totalgoal > [hdp1] THEN -1
											ELSE NULL
										END 
			
				--451: Both Teams To Score / Double Chance
				WHEN @bettype = 451 THEN CASE
											WHEN LEFT(betteam,1) = 'N' AND @fth > 0 AND @fta > 0 THEN -1
											ELSE NULL
										  END	
				--454: Double Chance & First Team To Score						
				WHEN @bettype = 454 THEN CASE
											WHEN (RIGHT(betteam,1) = 'H' OR betteam = 'NG') AND @FGLG2 = 'A' THEN -1
											WHEN (RIGHT(betteam,1) = 'A' OR betteam = 'NG') AND @FGLG2 = 'H' THEN -1
											ELSE NULL
										END	
				ELSE NULL
				END
			,modds = @modds                                    
            ,@commWinRate = CASE comstatus
                WHEN '0' THEN 1 -- 0: pay normal, both win/lost -- 1: pay 'double' ONLY on lost
                WHEN '1' THEN 0
                ELSE 1
                END
            ,@commLostRate = CASE comstatus
                WHEN '0' THEN 1
                WHEN '1' THEN 2
                ELSE 1
                END
            ,winlost = CASE 
                WHEN @modds > 0 THEN actual_stake + stake * (CASE 
                        WHEN odds < 0 THEN 1
                        ELSE CASE 
                                WHEN bettype IN (449,451,454) THEN odds - 1
                                ELSE odds 
                                END
                        END
                    )
                WHEN @modds < 0 THEN 0
                ELSE winlost
                END
            ,aWinLost = CASE 
                WHEN @modds > 0 THEN stake * (CASE 
                        WHEN odds < 0 THEN 1
                        ELSE CASE 
                                WHEN bettype IN (449,451,454) THEN odds - 1
                                ELSE odds
                                END
                        END
                        ) * - apositiontaking
                WHEN @modds < 0 THEN actual_stake * apositiontaking
                ELSE awinlost
                END
            ,mWinLost = CASE 
                WHEN @modds > 0 THEN stake * (CASE 
                        WHEN odds < 0 THEN 1
                        ELSE CASE 
                                WHEN bettype IN (449,451,454) THEN odds - 1
                                ELSE odds 
                                END
                        END
                        ) * - mpositiontaking
                WHEN @modds < 0 THEN actual_stake * mpositiontaking
                ELSE mwinlost
                END
            ,sWinLost = CASE 
                WHEN @modds > 0 THEN stake * (CASE 
                        WHEN odds < 0 THEN 1
                        ELSE CASE 
                                WHEN bettype IN (449,451,454) THEN odds - 1
                                ELSE odds 
                                END
                        END
                        ) * - spositiontaking
                WHEN @modds < 0 THEN actual_stake * spositiontaking
                ELSE swinlost
                END
            ,PlayerComm = CASE 
                WHEN @modds > 0 THEN @commWinRate * playerdiscount * stake
                WHEN @modds < 0 THEN @commLostRate * playerdiscount * stake
                ELSE playercomm
                END
            ,Comm = CASE 
                WHEN @modds > 0 THEN @commWinRate * discount * stake * (1 - apositiontaking)
                WHEN @modds < 0 THEN @commLostRate * discount * stake * (1 - apositiontaking)
                ELSE comm
                END
            ,aComm = CASE 
                WHEN @modds > 0 THEN @commWinRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking))
                WHEN @modds < 0 THEN @commLostRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking))
                ELSE acomm
                END
            ,sComm = CASE 
                WHEN @modds > 0 THEN @commWinRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
                WHEN @modds < 0 THEN @commLostRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
                ELSE scomm
                END
            ,STATUS = CASE 
                WHEN @modds > 0 THEN 'WON'
                WHEN @modds < 0 THEN 'LOSE'
                ELSE status
                END
            ,StatusID = CASE 
                WHEN @modds > 0 THEN 112 --WON
                WHEN @modds < 0 THEN 113 --LOSE
                ELSE statusID
                END
            ,ruben = CASE WHEN @modds IS NULL THEN ruben ELSE 1 END
		WHERE matchid = @matchid AND bettype = @bettype AND
			--status NOT IN ('VOID', 'REJECT')
			statusID NOT IN (101, 102)
			AND 1 = CASE 
                        -- Betdaq: Tickets 
                        WHEN @IsSettleAbandonedMatch = 1 AND (custid IN (50057, 879241, 103873, 78761, 851668, 878902) OR recommend = 1688156) THEN 1
                        -- Betfair
                        WHEN @IsSettleAbandonedMatchBetFair = 1 AND custid IN (2331, 1077687, 115770, 15523642) THEN 1
                        --OW
                        WHEN @IsSettleAbandonedMatchIBC = 1 AND (custid NOT IN (50057, 879241, 103873, 78761, 851668, 878902, 2331, 1077687, 115770, 15523642) AND recommend <> 1688156) THEN 1
                        ELSE 0
                    END
                            
	END		
END
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Admin_Calculate_24] TO [vnteam] AS [dbo]
GO