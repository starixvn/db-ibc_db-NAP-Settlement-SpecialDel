/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_8] 
	@matchid 						INT
    ,@bettype 						SMALLINT
    ,@totalht 						SMALLMONEY
    ,@scorediff_ht 					SMALLMONEY = NULL
    ,@betcount INT = 0
    ,@IsSettleAbandonedMatch 		BIT = 0
    ,@IsSettleAbandonedMatchBetFair BIT = 0
    ,@IsSettleAbandonedMatchIBC 	BIT = 0
    -- add any params, please modify script in 'special section'
AS
/*
    Created by: Kathy
    Date: 20140213
    Task: Settlement 
    DB: DBTXN/BODB02
    Original: Admin_Calculate_8

    Revisions:
        - 20140610@Kathy: Using clustered index(CIX_recommend_matchid_bettype) in DB052, DB053, DB054        
        - 20140729@Kathy: Add one more account(BF3) into BetFair's group [Redmine:#19665]
        - 20140808@Kathy: Support new 11 bettypes: 143 [Redmine:#19667]    
        - 20140818@Jamie: Correct settle  determined ticket 143 
        - 20150909@Kathy: Integrate Myanmar Odds ( 4 new bettypes: 301->304): add bettype 304
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
		- 20180904@Kathy: Change CIX on DB054 [Redmine:#100828]

    Param's Explanation:
        + @IsSettleAbandonedMatch: Settle determined tickets for Abandoned/Postponed Match
        + @IsSettleAbandonedMatchBetFair: Is Settlement for Betfair ticket of Abandoned/postponed match or not
*/
BEGIN
    IF @betcount = 0 AND @@SERVERNAME NOT LIKE N'DBIOM%' RETURN

    SET NOCOUNT ON

    IF @@SERVERNAME IN ('DB04', 'DB042', 'DB043', 'DB044') RETURN

    DECLARE @modds MONEY
        ,@commWinRate SMALLMONEY
        ,@commLostRate SMALLMONEY
    
    IF @IsSettleAbandonedMatch = 1 OR @IsSettleAbandonedMatchBetFair = 1 or @IsSettleAbandonedMatchIBC = 1
    BEGIN
        DECLARE    @comparedValue SMALLMONEY    --@totalht - 0.5 -- Get tickets had result 
        SELECT    @comparedValue = CASE 
									WHEN @bettype IN (8,403,404,463,464) THEN @totalht - 0.25 -- Apply half WON|LOSE
									ELSE @totalht - 0.5 -- full Winloss
								END

        UPDATE dbo.bettrans WITH (ROWLOCK, UPDLOCK)
        SET @modds = CASE WHEN betteam IN ('h', 'o') THEN @totalht - hdp1
                                  WHEN betteam IN ('a', 'u') THEN hdp1 - @totalht
                                  WHEN RIGHT(betteam,1) ='u' THEN hdp1 - @totalht    -- 143 
                                  WHEN bettype = 426 THEN CASE
															WHEN @totalht > 0 AND betteam = 'NG' THEN -1
															ELSE NULL
														  END
															
                                  ELSE NULL 
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
            ,WinLost = CASE 
                WHEN @modds > 0.25 THEN actual_stake + stake * (CASE 
                        WHEN odds < 0 THEN 1
                        ELSE (CASE 
                                WHEN bettype IN (143,426,608,463,464) THEN odds - 1
                                ELSE odds END
                                ) END
                        ) -- WON
				WHEN @modds = 0.25 THEN actual_stake + stake * (CASE 
                        WHEN odds < 0 THEN 1
                        ELSE (CASE 
                                WHEN bettype IN (143,426,608,463,464) THEN odds - 1
                                ELSE odds END
                                ) END
                        ) * 0.5 -- half WON
                WHEN @modds = - 0.25 THEN actual_stake * 0.5 -- half LOSE    
				WHEN @modds < - 0.25 THEN 0 -- LOSE    
                WHEN @modds IS NULL THEN winlost
                END
            ,aWinLost = CASE 
                WHEN @modds > 0.25 THEN stake * (CASE 
                        WHEN odds < 0 THEN 1
                        ELSE (CASE 
                                WHEN bettype IN (143,426,608,463,464) THEN odds - 1
                                ELSE odds END
                                ) END
                        ) * - apositiontaking
				WHEN @modds = 0.25 THEN stake * (CASE 
                        WHEN odds < 0 THEN 1
                        ELSE (CASE 
                                WHEN bettype IN (143,426,608,463,464) THEN odds - 1
                                ELSE odds END
                                ) END
                        ) * - apositiontaking * 0.5
                WHEN @modds = - 0.25 THEN actual_stake * apositiontaking * 0.5
				WHEN @modds < - 0.25 THEN actual_stake * apositiontaking
                WHEN @modds IS NULL THEN awinlost
                END
            ,mWinLost = CASE 
                WHEN @modds > 0.25 THEN stake * (CASE 
                        WHEN odds < 0 THEN 1
                        ELSE (CASE 
                                WHEN bettype IN (143,426,608,463,464) THEN odds - 1
                                ELSE odds END
                                ) END
                        ) * - mpositiontaking
				WHEN @modds = 0.25 THEN stake * (CASE 
                        WHEN odds < 0 THEN 1
                        ELSE (CASE 
                                WHEN bettype IN (143,426,608,463,464) THEN odds - 1
                                ELSE odds END
                                ) END
                        ) * - mpositiontaking * 0.5
                WHEN @modds = - 0.25 THEN actual_stake * mpositiontaking * 0.5
				WHEN @modds < - 0.25 THEN actual_stake * mpositiontaking
                WHEN @modds IS NULL THEN mwinlost
                END
            ,sWinLost = CASE 
                WHEN @modds > 0.25 THEN stake * (CASE 
                        WHEN odds < 0 THEN 1
                        ELSE (CASE 
                                WHEN bettype IN (143,426,608,463,464) THEN odds - 1
                                ELSE odds END
                                ) END
                        ) * - spositiontaking
				WHEN @modds = 0.25 THEN stake * (CASE 
                        WHEN odds < 0 THEN 1
                        ELSE (CASE 
                                WHEN bettype IN (143,426,608,463,464) THEN odds - 1
                                ELSE odds END
                                ) END
                        ) * - spositiontaking * 0.5
                WHEN @modds = - 0.25 THEN actual_stake * spositiontaking * 0.5
				WHEN @modds < - 0.25 THEN actual_stake * spositiontaking
                WHEN @modds IS NULL THEN swinlost
                END
            ,PlayerComm = CASE 
                WHEN @modds > 0.25 THEN @commWinRate * playerdiscount * stake
				WHEN @modds = 0.25 THEN @commWinRate * playerdiscount * stake * 0.5
                WHEN @modds = - 0.25 THEN @commLostRate * playerdiscount * stake * 0.5
				WHEN @modds < - 0.25 THEN @commLostRate * playerdiscount * stake
                WHEN @modds IS NULL THEN playercomm
                END
            ,Comm = CASE 
                WHEN @modds > 0.25 THEN @commWinRate * discount * stake * (1 - apositiontaking)
				WHEN @modds = 0.25 THEN @commWinRate * discount * stake * (1 - apositiontaking) * 0.5
                WHEN @modds = - 0.25 THEN @commLostRate * discount * stake * (1 - apositiontaking)  * 0.5
				WHEN @modds < - 0.25 THEN @commLostRate * discount * stake * (1 - apositiontaking)
                WHEN @modds IS NULL THEN comm
                END
            ,aComm = CASE 
                WHEN @modds > 0.25 THEN @commWinRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking))
				WHEN @modds = 0.25 THEN @commWinRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking)) * 0.5
                WHEN @modds = - 0.25 THEN @commLostRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking)) * 0.5
				WHEN @modds < - 0.25 THEN @commLostRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking)) 
                WHEN @modds IS NULL THEN acomm
                END
            ,sComm = CASE 
                WHEN @modds > 0.25 THEN @commWinRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
				WHEN @modds = 0.25 THEN @commWinRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking)) * 0.5
                WHEN @modds = - 0.25 THEN @commWinRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking)) * 0.5
				WHEN @modds < - 0.25 THEN @commWinRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
                WHEN @modds IS NULL THEN scomm
                END
            /*,STATUS = CASE 
                WHEN @modds >= 0.5 THEN N'WON'
                WHEN @modds <= - 0.5 THEN N'LOSE'
                WHEN @modds IS NULL THEN status
            END*/
			,STATUS = CASE 
                WHEN @modds > 0 THEN N'WON'
                WHEN @modds < 0 THEN N'LOSE'
                WHEN @modds IS NULL THEN status
                END
            /*,StatusID = CASE 
                WHEN @modds >= 0.5 THEN 112 --WON
                WHEN @modds <= - 0.5 THEN 113 --LOSE    
                WHEN @modds IS NULL THEN statusID
            END*/
			,StatusID = CASE 
                WHEN @modds > 0 THEN 112 --WON
                WHEN @modds < 0 THEN 113 --LOSE    
                WHEN @modds IS NULL THEN statusID
            END
            ,ruben = CASE WHEN @modds IS NULL THEN ruben
                          ELSE 1
                     END
        WHERE matchid = @matchid AND bettype = @bettype 
			AND statusID NOT IN (101, 102) 
            AND 1 = CASE 
                    WHEN @IsSettleAbandonedMatch = 1 AND (custid IN (50057, 879241, 103873, 78761, 851668, 878902) OR recommend = 1688156) THEN 1
                    WHEN @IsSettleAbandonedMatchBetFair = 1 AND custid IN (2331, 1077687, 115770, 15523642) THEN 1
                    WHEN @IsSettleAbandonedMatchIBC = 1 AND (custid NOT IN (50057, 879241, 103873, 78761, 851668, 878902, 2331, 1077687, 115770, 15523642) AND recommend <> 1688156) THEN 1
                    ELSE 0
                END 
			AND hdp1 <= @comparedValue
			
    END -- END settle determined ticket
    ELSE
    BEGIN
		DECLARE @result NVARCHAR (10)
			SET @result = CASE @bettype 
								WHEN 426 THEN CASE 
												WHEN @scorediff_ht = 1 THEN 'H1'
												WHEN @scorediff_ht >= 2 THEN 'H2+'
												WHEN @scorediff_ht = -1 THEN 'A1'
												WHEN @scorediff_ht <= -2 THEN 'A2+'
												WHEN @totalht = 0 THEN 'NG'
												WHEN @scorediff_ht = 0 THEN 'D'
												ELSE NULL
												END
								WHEN 608 THEN CASE
												WHEN @scorediff_ht BETWEEN 1 AND 5 THEN 'H1-5'
												WHEN @scorediff_ht BETWEEN 6 AND 10 THEN 'H6-10'
												WHEN @scorediff_ht BETWEEN 11 AND 15 THEN 'H11-15'
												WHEN @scorediff_ht BETWEEN 16 AND 20 THEN 'H16-20'
												WHEN @scorediff_ht BETWEEN 21 AND 25 THEN 'H21-25'
												WHEN @scorediff_ht >= 26 THEN 'H26+'
												WHEN @scorediff_ht = 0 THEN 'D'
												WHEN @scorediff_ht BETWEEN -5 AND -1 THEN 'A1-5'
												WHEN @scorediff_ht BETWEEN -10 AND -6 THEN 'A6-10'
												WHEN @scorediff_ht BETWEEN -15 AND -11 THEN 'A11-15'
												WHEN @scorediff_ht BETWEEN -20 AND -16 THEN 'A16-20'
												WHEN @scorediff_ht BETWEEN -25 AND -21 THEN 'A21-25'
												WHEN @scorediff_ht <= -26 THEN 'A26+'
												ELSE NULL
												END
						  END
						  
        IF @@SERVERNAME IN ('DB052', 'SITDB052', 'DB231', 'DB215')
        BEGIN
            DECLARE @affectedagents INT
    
            CREATE TABLE #tmpRecommend(recommend INT  PRIMARY KEY)

            INSERT INTO #tmpRecommend(recommend)
            SELECT DISTINCT recommend
            FROM dbo.bettrans (NOLOCK) WHERE matchid = @matchid and bettype = @bettype

            DECLARE @currecommend TABLE(recommend INT PRIMARY KEY)

            WHILE 1=1
            BEGIN
                DELETE
                FROM @currecommend

                DELETE TOP(100)
                FROM #tmpRecommend OUTPUT DELETED.recommend INTO @currecommend

                SET @affectedagents = @@rowcount

                UPDATE b
                SET @modds = CASE 
                    WHEN betteam IN ('h', 'o') THEN @totalht-hdp1
                    WHEN betteam IN ('a', 'u') THEN hdp1-@totalht
                    WHEN b.betteam = 'ho' AND @scorediff_ht > 0 THEN @totalht - b.hdp1
                    WHEN b.betteam = 'hu' AND @scorediff_ht > 0 THEN b.hdp1 - @totalht
                    WHEN b.betteam = 'ao' AND @scorediff_ht < 0 THEN @totalht - b.hdp1
                    WHEN b.betteam = 'au' AND @scorediff_ht < 0 THEN b.hdp1 - @totalht
                    WHEN b.betteam = 'do' AND @scorediff_ht = 0 THEN @totalht - b.hdp1
                    WHEN b.betteam = 'du' AND @scorediff_ht = 0 THEN b.hdp1 - @totalht          
                    WHEN bettype IN (426, 608) THEN CASE
														WHEN betteam = @result THEN 1
														ELSE -1
														END  												
                    ELSE - 1                    
                    END,
                    modds = @modds,                
                    @commWinRate = CASE comstatus -- 0 : pay normal, both win/lost -- 1 : pay 'double' ONLY on lost
                    WHEN '0' THEN 1
                    WHEN '1' THEN 0
                    ELSE 1 END,
                    @commLostRate = CASE comstatus
                    WHEN '0' THEN 1
                    WHEN '1' THEN 2
                    ELSE 1 END,
                
                WinLost = CASE
                    WHEN @modds >  0.25    THEN actual_stake + stake * (case when odds<0 then 1 else (case when bettype in (143,426,608,463,464) then odds-1 else odds end) end)
                    WHEN @modds =  0.25    THEN actual_stake + stake * (case when odds<0 then 1 else (case when bettype in (143,426,608,463,464) then odds-1 else odds end) end) * 0.5
                    WHEN @modds =  0 AND bettype <> 304    THEN actual_stake
                    WHEN @modds =  0 AND bettype = 304    THEN CASE 
                                                            WHEN oddsspread = 0 THEN actual_stake
                                                            WHEN oddsspread > 0 THEN actual_stake + stake * odds * (oddsspread/100) -- oddsspread > 0: WON
                                                            ELSE actual_stake * (1 - ABS(oddsspread/100))  -- oddsspread < 0: LOSE
                                                            END
                    WHEN @modds = -0.25    THEN actual_stake * 0.5
                    WHEN @modds < -0.25    THEN 0
                    END, 

                aWinLost = CASE
                    WHEN @modds >  0.25    THEN stake * (case when odds<0 then 1 else (case when bettype in (143,426,608,463,464) then odds-1 else odds end) end) * -apositiontaking
                    WHEN @modds =  0.25    THEN stake * (case when odds<0 then 1 else (case when bettype in (143,426,608,463,464) then odds-1 else odds end) end) * -apositiontaking * 0.5
                    WHEN @modds =  0 AND bettype <> 304    THEN 0
                    WHEN @modds =  0 AND bettype = 304    THEN CASE 
                                                            WHEN oddsspread = 0 THEN 0
                                                            WHEN oddsspread > 0 THEN stake * odds * (oddsspread/100) * -apositiontaking -- oddsspread > 0: WON
                                                            ELSE actual_stake * ABS(oddsspread/100) * apositiontaking -- oddsspread < 0: LOSE
                                                            END
                    WHEN @modds = -0.25    THEN actual_stake * apositiontaking * 0.5
                    WHEN @modds < -0.25    THEN actual_stake * apositiontaking
                    END,
                mWinLost = CASE
                    WHEN @modds >  0.25     THEN stake * (case when odds<0 then 1 else (case when bettype in (143,426,608,463,464) then odds-1 else odds end) end) * -mpositiontaking
                    WHEN @modds =  0.25     THEN stake * (case when odds<0 then 1 else (case when bettype in (143,426,608,463,464) then odds-1 else odds end) end) * -mpositiontaking * 0.5
                    WHEN @modds =  0 AND bettype <> 304        THEN 0
                    WHEN @modds =  0 AND bettype = 304       THEN CASE 
                                                                WHEN oddsspread = 0 THEN 0
                                                                WHEN oddsspread > 0 THEN stake * odds * (oddsspread/100) * -mpositiontaking -- oddsspread > 0: WON
                                                                ELSE actual_stake * ABS(oddsspread/100) * mpositiontaking -- oddsspread < 0: LOSE
                                                                END
                    WHEN @modds = -0.25     THEN actual_stake * mpositiontaking * 0.5
                    WHEN @modds < -0.25     THEN actual_stake * mpositiontaking
                    END,
                sWinLost = CASE
                    WHEN @modds >  0.25     THEN stake * (case when odds<0 then 1 else (case when bettype in (143,426,608,463,464) then odds-1 else odds end) end) * -spositiontaking
                    WHEN @modds =  0.25     THEN stake * (case when odds<0 then 1 else (case when bettype in (143,426,608,463,464) then odds-1 else odds end) end) * -spositiontaking * 0.5
                    WHEN @modds =  0 AND bettype <> 304       THEN 0
                    WHEN @modds =  0 AND bettype = 304       THEN CASE 
                                                                WHEN oddsspread = 0 THEN 0
                                                                WHEN oddsspread > 0 THEN stake * odds * (oddsspread/100) * -spositiontaking
                                                                ELSE actual_stake * ABS(oddsspread/100) * spositiontaking 
                                                                END
                    WHEN @modds = -0.25     THEN actual_stake * spositiontaking * 0.5
                    WHEN @modds < -0.25     THEN actual_stake * spositiontaking
                    END,

                PlayerComm = CASE
                    WHEN @modds >  0.25     THEN @commWinRate * playerdiscount * stake
                    WHEN @modds =  0.25     THEN @commWinRate * playerdiscount * stake * 0.5
                    WHEN @modds =  0 AND bettype <> 304        THEN 0
                    WHEN @modds =  0 AND bettype = 304        THEN CASE
                                                                WHEN oddsspread = 0 THEN 0
                                                                WHEN oddsspread > 0 THEN @commWinRate * playerdiscount * stake * (oddsspread/100)
                                                                ELSE @commLostRate * playerdiscount * stake * ABS(oddsspread/100)
                                                                END
                    WHEN @modds = -0.25     THEN @commLostRate * playerdiscount * stake * 0.5
                    WHEN @modds < -0.25     THEN @commLostRate * playerdiscount * stake
                    END,
                Comm = CASE
                    WHEN @modds >  0.25     THEN @commWinRate * discount * stake * (1-apositiontaking)
                    WHEN @modds =  0.25     THEN @commWinRate * discount * stake * (1-apositiontaking) * 0.5
                    WHEN @modds =  0 AND bettype <> 304       THEN 0
                    WHEN @modds =  0 AND bettype = 304       THEN CASE 
                                                                WHEN oddsspread = 0 THEN 0
                                                                WHEN oddsspread > 0 THEN @commWinRate * discount * stake * (oddsspread/100) * (1-apositiontaking)
                                                                ELSE @commLostRate * discount * stake * ABS(oddsspread/100) * (1-apositiontaking)
                                                                END
                    WHEN @modds = -0.25     THEN @commLostRate * discount * stake * (1-apositiontaking) * 0.5
                    WHEN @modds < -0.25     THEN @commLostRate * discount * stake * (1-apositiontaking)
                    END,
                aComm = CASE
                    WHEN @modds >  0.25     THEN @commWinRate * adiscount * stake * (1-(mpositiontaking+apositiontaking))
                    WHEN @modds =  0.25     THEN @commWinRate * adiscount * stake * (1-(mpositiontaking+apositiontaking)) * 0.5
                    WHEN @modds =  0 AND bettype <> 304        THEN 0
                    WHEN @modds =  0 AND bettype = 304        THEN CASE
                                                                WHEN oddsspread = 0 THEN 0
                                                                WHEN oddsspread > 0 THEN @commWinRate * adiscount * stake * (oddsspread/100) * (1-(mpositiontaking+apositiontaking))
                                                                ELSE @commLostRate * adiscount * stake * ABS(oddsspread/100) * (1-(mpositiontaking+apositiontaking))
                                                                END
                    WHEN @modds = -0.25     THEN @commLostRate * adiscount * stake * (1-(mpositiontaking+apositiontaking)) * 0.5
                    WHEN @modds < -0.25     THEN @commLostRate * adiscount * stake * (1-(mpositiontaking+apositiontaking))
                    END,
                sComm = CASE
                    WHEN @modds >  0.25     THEN @commWinRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking))
                    WHEN @modds =  0.25     THEN @commWinRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking)) * 0.5
                    WHEN @modds =  0 AND bettype <> 304        THEN 0
                    WHEN @modds =  0 AND bettype = 304        THEN CASE
                                                                WHEN oddsspread = 0 THEN 0
                                                                WHEN oddsspread > 0 THEN @commWinRate * sdiscount * stake * (oddsspread/100) * (1-(spositiontaking+mpositiontaking+apositiontaking))
                                                                ELSE @commLostRate * sdiscount * stake * ABS(oddsspread/100) * (1-(spositiontaking+mpositiontaking+apositiontaking))
                                                                END
                    WHEN @modds = -0.25     THEN @commLostRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking)) * 0.5
                    WHEN @modds < -0.25     THEN @commLostRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking))
                    END,

                Status = CASE
                    WHEN @modds > 0 THEN 'WON'
                    WHEN @modds = 0 AND bettype <> 304 THEN 'DRAW'
                    WHEN @modds = 0 AND bettype = 304 THEN CASE WHEN oddsspread = 0 THEN 'DRAW'
                                                            WHEN oddsspread > 0 THEN 'WON'
                                                            ELSE 'LOSE'
                                                            END
                    WHEN @modds < 0 THEN 'LOSE'
                    END,
                StatusID = CASE
                    WHEN @modds > 0 THEN 112 --WON
                    WHEN @modds = 0 AND bettype <> 304 THEN 111 --DRAW
                    WHEN @modds = 0 AND bettype = 304 THEN CASE WHEN oddsspread = 0 THEN 111 
                                                            WHEN oddsspread > 0 THEN 112
                                                            ELSE 113
                                                            END
                    WHEN @modds < 0 THEN 113 --LOSE
                    END,
                ruben=1
                FROM dbo.bettrans b WITH (ROWLOCK, UPDLOCK)
                    INNER JOIN @currecommend ag on b.recommend = ag.recommend
                WHERE
                    matchid=@matchid AND
                    bettype=@bettype AND
                    statusID NOT IN (101,102)

                IF @affectedagents <> 100 
                    BREAK

				WAITFOR DELAY '00:00:00:010'
            END 
            DROP TABLE #tmpRecommend
        END
        ELSE
        BEGIN
			CREATE TABLE #tempCust(custid INT PRIMARY KEY)

			INSERT INTO #tempCust(custid)
			SELECT custid
			FROM dbo.bettrans WITH(NOLOCK) 
			WHERE matchid = @matchid AND bettype = @bettype
			GROUP BY custid
			
			--PRINT @@ROWCOUNT

			CREATE TABLE #currList (custid INT PRIMARY KEY)
			DECLARE @MinCustId INT
			WHILE 1 = 1
			BEGIN
				DELETE FROM #currList

				DELETE TOP (1000)
				FROM #tempCust OUTPUT DELETED.custid INTO #currList
				IF @@ROWCOUNT = 0 BREAK

				SELECT @MinCustId = MIN(custid) FROM #currList

				UPDATE b
				SET @modds = CASE 
						WHEN betteam IN ('h', 'o') THEN @totalht - hdp1
						WHEN betteam IN ('a', 'u') THEN hdp1 - @totalht
						WHEN betteam = 'ho' AND @scorediff_ht > 0 THEN @totalht - hdp1
						WHEN betteam = 'hu' AND @scorediff_ht > 0 THEN hdp1 - @totalht
						WHEN betteam = 'ao' AND @scorediff_ht < 0 THEN @totalht - hdp1
						WHEN betteam = 'au' AND @scorediff_ht < 0 THEN hdp1 - @totalht
						WHEN betteam = 'do' AND @scorediff_ht = 0 THEN @totalht - hdp1
						WHEN betteam = 'du' AND @scorediff_ht = 0 THEN hdp1 - @totalht    
						WHEN bettype IN (426, 608) THEN CASE
													WHEN betteam = @result THEN 1
													ELSE -1
												END
						ELSE -1
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
					,WinLost = CASE 
						WHEN @modds > 0.25 THEN actual_stake + stake * (CASE 
								WHEN odds < 0 THEN 1
								ELSE (CASE 
										WHEN bettype IN (143,426,608,463,464) THEN odds - 1
										ELSE odds END
										) END
								)
						WHEN @modds = 0.25 THEN actual_stake + stake * (CASE 
								WHEN odds < 0 THEN 1
								ELSE (CASE 
										WHEN bettype IN (143,426,608,463,464) THEN odds - 1
										ELSE odds END
										) END
								) * 0.5
						WHEN @modds =  0 AND bettype <> 304    THEN actual_stake
						WHEN @modds =  0 AND bettype = 304    THEN CASE 
																WHEN oddsspread = 0 THEN actual_stake
																WHEN oddsspread > 0 THEN actual_stake + stake * odds * (oddsspread/100) -- oddsspread > 0: WON
																ELSE actual_stake * (1 - ABS(oddsspread/100))  -- oddsspread < 0: LOSE
																END
						WHEN @modds = - 0.25 THEN actual_stake * 0.5
						WHEN @modds < - 0.25 THEN 0
						END
					,aWinLost = CASE 
						WHEN @modds > 0.25 THEN stake * (CASE 
								WHEN odds < 0 THEN 1
								ELSE (CASE 
										WHEN bettype IN (143,426,608,463,464) THEN odds - 1
										ELSE odds END
										) END
								) * - apositiontaking
						WHEN @modds = 0.25 THEN stake * (CASE 
								WHEN odds < 0 THEN 1
								ELSE (CASE 
										WHEN bettype IN (143,426,608,463,464) THEN odds - 1
										ELSE odds END
										) END
								) * - apositiontaking * 0.5
						WHEN @modds =  0 AND bettype <> 304    THEN 0
						WHEN @modds =  0 AND bettype = 304    THEN CASE 
																WHEN oddsspread = 0 THEN 0
																WHEN oddsspread > 0 THEN stake * odds * (oddsspread/100) * -apositiontaking -- oddsspread > 0: WON
																ELSE actual_stake * ABS(oddsspread/100) * apositiontaking -- oddsspread < 0: LOSE
																END
						WHEN @modds = - 0.25 THEN actual_stake * apositiontaking * 0.5
						WHEN @modds < - 0.25 THEN actual_stake * apositiontaking
						END
					,mWinLost = CASE 
						WHEN @modds > 0.25 THEN stake * (CASE 
								WHEN odds < 0 THEN 1
								ELSE (CASE 
										WHEN bettype IN (143,426,608,463,464) THEN odds - 1
										ELSE odds END
										) END
								) * - mpositiontaking
						WHEN @modds = 0.25 THEN stake * (CASE 
								WHEN odds < 0 THEN 1
								ELSE (CASE 
										WHEN bettype IN (143,426,608,463,464) THEN odds - 1
										ELSE odds END
										) END
								) * - mpositiontaking * 0.5
						WHEN @modds =  0 AND bettype <> 304        THEN 0
						WHEN @modds =  0 AND bettype = 304        THEN CASE 
																	WHEN oddsspread = 0 THEN 0
																	WHEN oddsspread > 0 THEN stake * odds * (oddsspread/100) * -mpositiontaking -- oddsspread > 0: WON
																	ELSE actual_stake * ABS(oddsspread/100) * mpositiontaking -- oddsspread < 0: LOSE
																	END
						WHEN @modds = - 0.25 THEN actual_stake * mpositiontaking * 0.5
						WHEN @modds < - 0.25 THEN actual_stake * mpositiontaking
						END
					,sWinLost = CASE 
						WHEN @modds > 0.25 THEN stake * (CASE 
								WHEN odds < 0 THEN 1
								ELSE (CASE 
										WHEN bettype IN (143,426,608,463,464) THEN odds - 1
										ELSE odds END
										) END
								) * - spositiontaking
						WHEN @modds = 0.25 THEN stake * (CASE 
								WHEN odds < 0 THEN 1
								ELSE (CASE 
										WHEN bettype IN (143,426,608,463,464) THEN odds - 1
										ELSE odds END
										) END
								) * - spositiontaking * 0.5
						WHEN @modds =  0 AND bettype <> 304       THEN 0
						WHEN @modds =  0 AND bettype = 304       THEN CASE 
																	WHEN oddsspread = 0 THEN 0
																	WHEN oddsspread > 0 THEN stake * odds * (oddsspread/100) * -spositiontaking
																	ELSE actual_stake * ABS(oddsspread/100) * spositiontaking 
																	END
						WHEN @modds = - 0.25 THEN actual_stake * spositiontaking * 0.5
						WHEN @modds < - 0.25 THEN actual_stake * spositiontaking
						END
					,PlayerComm = CASE 
						WHEN @modds > 0.25 THEN @commWinRate * playerdiscount * stake
						WHEN @modds = 0.25 THEN @commWinRate * playerdiscount * stake * 0.5
						WHEN @modds =  0 AND bettype <> 304        THEN 0
						WHEN @modds =  0 AND bettype = 304        THEN CASE
																	WHEN oddsspread = 0 THEN 0
																	WHEN oddsspread > 0 THEN @commWinRate * playerdiscount * stake * (oddsspread/100)
																	ELSE @commLostRate * playerdiscount * stake * ABS(oddsspread/100)
																	END
						WHEN @modds = - 0.25 THEN @commLostRate * playerdiscount * stake * 0.5
						WHEN @modds < - 0.25 THEN @commLostRate * playerdiscount * stake
						END
					,Comm = CASE 
						WHEN @modds > 0.25 THEN @commWinRate * discount * stake * (1 - apositiontaking)
						WHEN @modds = 0.25 THEN @commWinRate * discount * stake * (1 - apositiontaking) * 0.5
						WHEN @modds =  0 AND bettype <> 304       THEN 0
						WHEN @modds =  0 AND bettype = 304       THEN CASE 
																	WHEN oddsspread = 0 THEN 0
																	WHEN oddsspread > 0 THEN @commWinRate * discount * stake * (oddsspread/100) * (1-apositiontaking)
																	ELSE @commLostRate * discount * stake * ABS(oddsspread/100) * (1-apositiontaking)
																	END
						WHEN @modds = - 0.25 THEN @commLostRate * discount * stake * (1 - apositiontaking) * 0.5
						WHEN @modds < - 0.25 THEN @commLostRate * discount * stake * (1 - apositiontaking)
						END
					,aComm = CASE 
						WHEN @modds > 0.25 THEN @commWinRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking))
						WHEN @modds = 0.25 THEN @commWinRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking)) * 0.5
						WHEN @modds =  0 AND bettype <> 304        THEN 0
						WHEN @modds =  0 AND bettype = 304        THEN CASE
																	WHEN oddsspread = 0 THEN 0
																	WHEN oddsspread > 0 THEN @commWinRate * adiscount * stake * (oddsspread/100) * (1-(mpositiontaking+apositiontaking))
																	ELSE @commLostRate * adiscount * stake * ABS(oddsspread/100) * (1-(mpositiontaking+apositiontaking))
																	END
						WHEN @modds = - 0.25 THEN @commLostRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking)) * 0.5
						WHEN @modds < - 0.25 THEN @commLostRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking))
						END
					,sComm = CASE 
						WHEN @modds > 0.25 THEN @commWinRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
						WHEN @modds = 0.25 THEN @commWinRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking)) * 0.5
						WHEN @modds =  0 AND bettype <> 304        THEN 0
						WHEN @modds =  0 AND bettype = 304        THEN CASE
																	WHEN oddsspread = 0 THEN 0
																	WHEN oddsspread > 0 THEN @commWinRate * sdiscount * stake * (oddsspread/100) * (1-(spositiontaking+mpositiontaking+apositiontaking))
																	ELSE @commLostRate * sdiscount * stake * ABS(oddsspread/100) * (1-(spositiontaking+mpositiontaking+apositiontaking))
																	END
						WHEN @modds = - 0.25 THEN @commLostRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking)) * 0.5
						WHEN @modds < - 0.25 THEN @commLostRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
						END
					,STATUS = CASE 
						WHEN @modds > 0 THEN 'WON'
						WHEN @modds = 0 AND bettype <> 304 THEN 'DRAW'
						WHEN @modds = 0 AND bettype = 304 THEN CASE WHEN oddsspread = 0 THEN 'DRAW'
																WHEN oddsspread > 0 THEN 'WON'
																ELSE 'LOSE'
																END
						WHEN @modds < 0 THEN 'LOSE'
						END
					,StatusID = CASE 
						WHEN @modds > 0 THEN 112 --WON
						WHEN @modds = 0 AND bettype <> 304 THEN 111 --DRAW
						WHEN @modds = 0 AND bettype = 304 THEN CASE WHEN oddsspread = 0 THEN 111 
																WHEN oddsspread > 0 THEN 112
																ELSE 113
																END
						WHEN @modds < 0 THEN 113 --LOSE
						END
					,ruben = 1
				FROM #currList t
					INNER JOIN dbo.bettrans b WITH (ROWLOCK, UPDLOCK) ON t.custid = b.custid
				WHERE matchid = @matchid
					AND b.custid >= @MinCustId
					AND bettype = @bettype 
					AND statusID NOT IN (101, 102)
				OPTION (FORCE ORDER)

				WAITFOR DELAY '00:00:00:010'
				--PRINT @@ROWCOUNT
			END
			DROP TABLE #currList
			DROP TABLE #tempCust
        END
    END
    
END
GO