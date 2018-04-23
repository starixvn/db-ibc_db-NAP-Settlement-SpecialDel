USE [bodb02]
GO
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_7] @matchid INT
    ,@bettype SMALLINT
    ,@hth SMALLMONEY
    ,@hta SMALLMONEY
    ,@betcount INT = 0
    -- add any params, please modify script in 'special section'
AS
/*
    Created by: Kathy
    Date: 20140213
    Task: Settlement 
    DB: DBTRANS.BODB02
    
    Revisions:
        - 20140610@Kathy: Using clustered index(CIX_recommend_matchid_bettype) in DB052, DB053, DB054        
        - 20150909@Kathy: Intergrate Myanmar Odds ( 4 new bettypes: 301->304): add bettype 303
        - 20151026@Kathy: Change Myanmar Odds commision formula [Redmine:#46284]
		- 20151210@Patrick: Database - Change datatype [Redmine: #48660]
		- 20160425@Patrick: Reduce escalation lock when updating large amount of data [Redmine: #56550]
		- 20160507@Patrick: Use Option Force Order & limit scanning on bettrans table incase merge join for batchNo n > 1 to reduce lock escalation [Redmine: #58464]
		- 20180419@Benjamin: Adding New Bettypes: 466 for Asian 1x2 [Redmine:#93654]

*/
BEGIN
    IF @betcount = 0 AND @@SERVERNAME NOT LIKE N'DBIOM%' RETURN

    IF @@SERVERNAME IN ('DB04', 'DB042', 'DB043', 'DB044') RETURN

    SET NOCOUNT ON

    DECLARE @modds MONEY
        ,@commWinRate SMALLMONEY
        ,@commLostRate SMALLMONEY
        ,@RemoteCount INT

    ----- LAS settlement 
    --IF @@SERVERNAME IN ('DB052', 'DB054', 'DB231') AND EXISTS (
    --        SELECT *
    --        FROM sys.databases
    --        WHERE NAME = 'LASDB'
    --        )
    --BEGIN
    --    DECLARE @LASCommand NVARCHAR(1000)
    --        ,@createdDate DATETIME

    --    SELECT @LASCommand = 'EXEC [dbo].[Admin_Calculate_7] @matchid = ' + CONVERT(NVARCHAR(10), @matchid) + ', @bettype = ' + CONVERT(NVARCHAR(10), @bettype) + ', @hth = ' + CONVERT(NVARCHAR(10), @hth) + ', @hta = ' + CONVERT(NVARCHAR(10), @hta) + ', @betcount = ' + CONVERT(NVARCHAR(10), @betcount)
    --        ,@createdDate = GETDATE()

    --    EXEC LASDB.[dbo].[Las_GeneratingSettlementCommand] @SPName = 'Admin_Calculate_7'
    --        ,@SQLCommand = @LASCommand
    --        ,@CreatedDate = @createdDate
    --        ,@StatusID = 0 -- waiting
    --        ,@MatchID = @matchid
    --        ,@Bettype = @bettype
    --        ,@Status = 'waiting'
    --        ,@BetCount = @betcount
    --END

    IF @@SERVERNAME IN ('DB052', 'DB053', 'DB054','DB231', 'DB215')
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
            SET @modds = CASE betteam
                WHEN 'h' THEN (hdp2-hdp1) + (@hth - livehomescore) - (@hta - liveawayscore) 
                WHEN 'a' THEN (hdp1-hdp2) - (@hth - livehomescore) + (@hta - liveawayscore)
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
                WHEN @modds >  0.25    THEN actual_stake + stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,466) then odds-1 else odds end) end)
                WHEN @modds =  0.25    THEN actual_stake + stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,466) then odds-1 else odds end) end) * 0.5
                WHEN @modds =  0 AND bettype <> 303    THEN actual_stake
                WHEN @modds =  0 AND bettype = 303    THEN CASE 
                                                            WHEN oddsspread = 0 THEN actual_stake
                                                            WHEN oddsspread > 0 THEN actual_stake + stake * odds * (oddsspread/100) -- oddsspread > 0: WON
                                                            ELSE actual_stake * (1 - ABS(oddsspread/100))  -- oddsspread < 0: LOSE
                                                            END
                WHEN @modds = -0.25    THEN actual_stake * 0.5
                WHEN @modds < -0.25    THEN 0
                END, 
            
            aWinLost = CASE
                WHEN @modds >  0.25    THEN stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,466) then odds-1 else odds end) end) * -apositiontaking
                WHEN @modds =  0.25    THEN stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,466) then odds-1 else odds end) end) * -apositiontaking * 0.5
                WHEN @modds =  0 AND bettype <> 303    THEN 0
                WHEN @modds =  0 AND bettype = 303    THEN CASE 
                                                            WHEN oddsspread = 0 THEN 0
                                                            WHEN oddsspread > 0 THEN stake * odds * (oddsspread/100) * -apositiontaking -- oddsspread > 0: WON
                                                            ELSE actual_stake * ABS(oddsspread/100) * apositiontaking -- oddsspread < 0: LOSE
                                                            END
                WHEN @modds = -0.25    THEN actual_stake * apositiontaking * 0.5
                WHEN @modds < -0.25    THEN actual_stake * apositiontaking
                END,
            mWinLost = CASE
                WHEN @modds >  0.25     THEN stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,466) then odds-1 else odds end) end) * -mpositiontaking
                WHEN @modds =  0.25     THEN stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,466) then odds-1 else odds end) end) * -mpositiontaking * 0.5
                WHEN @modds =  0 AND bettype <> 303        THEN 0
                WHEN @modds =  0 AND bettype = 303        THEN CASE 
                                                                WHEN oddsspread = 0 THEN 0
                                                                WHEN oddsspread > 0 THEN stake * odds * (oddsspread/100) * -mpositiontaking -- oddsspread > 0: WON
                                                                ELSE actual_stake * ABS(oddsspread/100) * mpositiontaking -- oddsspread < 0: LOSE
                                                                END
                WHEN @modds = -0.25     THEN actual_stake * mpositiontaking * 0.5
                WHEN @modds < -0.25     THEN actual_stake * mpositiontaking
                END,
            sWinLost = CASE
                WHEN @modds >  0.25     THEN stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,466) then odds-1 else odds end) end) * -spositiontaking
                WHEN @modds =  0.25     THEN stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,466) then odds-1 else odds end) end) * -spositiontaking * 0.5
                WHEN @modds =  0 AND bettype <> 303       THEN 0
                WHEN @modds =  0 AND bettype = 303       THEN CASE 
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
                WHEN @modds =  0 AND bettype <> 303        THEN 0
                WHEN @modds =  0 AND bettype = 303        THEN CASE
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
                WHEN @modds =  0 AND bettype <> 303       THEN 0
                WHEN @modds =  0 AND bettype = 303       THEN CASE 
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
                WHEN @modds =  0 AND bettype <> 303        THEN 0
                WHEN @modds =  0 AND bettype = 303        THEN CASE
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
                WHEN @modds =  0 AND bettype <> 303        THEN 0
                WHEN @modds =  0 AND bettype = 303        THEN CASE
                                                                WHEN oddsspread = 0 THEN 0
                                                                WHEN oddsspread > 0 THEN @commWinRate * sdiscount * stake * (oddsspread/100) * (1-(spositiontaking+mpositiontaking+apositiontaking))
                                                                ELSE @commLostRate * sdiscount * stake * ABS(oddsspread/100) * (1-(spositiontaking+mpositiontaking+apositiontaking))
                                                                END
                WHEN @modds = -0.25     THEN @commLostRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking)) * 0.5
                WHEN @modds < -0.25     THEN @commLostRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking))
                END,

            [status] = CASE
                WHEN @modds > 0 THEN 'WON'
                WHEN @modds = 0 AND bettype <> 303 THEN 'DRAW'
                WHEN @modds = 0 AND bettype = 303 THEN CASE WHEN oddsspread = 0 THEN 'DRAW' 
                                                            WHEN oddsspread > 0 THEN 'WON'
                                                            ELSE 'LOSE'
                                                            END
                WHEN @modds < 0 THEN 'LOSE'
                END,
            StatusID = CASE
                WHEN @modds > 0 THEN 112 --WON
                WHEN @modds = 0 AND bettype <> 303 THEN 111 --DRAW
                WHEN @modds = 0 AND bettype = 303 THEN CASE WHEN oddsspread = 0 THEN 111 
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
			SET @modds = CASE betteam
					WHEN 'h' THEN (hdp2 - hdp1) + (@hth - livehomescore) - (@hta - liveawayscore)
					WHEN 'a' THEN (hdp1 - hdp2) - (@hth - livehomescore) + (@hta - liveawayscore)
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
									WHEN bettype IN (4, 5, 6,466) THEN odds - 1
									ELSE odds END
									) END
							)
					WHEN @modds = 0.25 THEN actual_stake + stake * (CASE 
							WHEN odds < 0 THEN 1
							ELSE (CASE 
									WHEN bettype IN (4, 5, 6,466) THEN odds - 1
									ELSE odds END
									) END
							) * 0.5
					WHEN @modds =  0 AND bettype <> 303    THEN actual_stake
					WHEN @modds =  0 AND bettype = 303    THEN CASE 
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
									WHEN bettype IN (4, 5, 6,466) THEN odds - 1
									ELSE odds END
									) END
							) * - apositiontaking
					WHEN @modds = 0.25 THEN stake * (CASE 
							WHEN odds < 0 THEN 1
							ELSE (CASE 
									WHEN bettype IN (4, 5, 6,466) THEN odds - 1
									ELSE odds END
									) END
							) * - apositiontaking * 0.5
					WHEN @modds =  0 AND bettype <> 303    THEN 0
					WHEN @modds =  0 AND bettype = 303    THEN CASE 
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
									WHEN bettype IN (4, 5, 6,466) THEN odds - 1
									ELSE odds END
									) END
							) * - mpositiontaking
					WHEN @modds = 0.25 THEN stake * (CASE 
							WHEN odds < 0 THEN 1
							ELSE (CASE 
									WHEN bettype IN (4, 5, 6,466) THEN odds - 1
									ELSE odds END
									) END
							) * - mpositiontaking * 0.5
					WHEN @modds =  0 AND bettype <> 303        THEN 0
					WHEN @modds =  0 AND bettype = 303        THEN CASE 
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
									WHEN bettype IN (4, 5, 6,466) THEN odds - 1
									ELSE odds END
									) END
							) * - spositiontaking
					WHEN @modds = 0.25 THEN stake * (CASE 
							WHEN odds < 0 THEN 1
							ELSE (CASE 
									WHEN bettype IN (4, 5, 6,466) THEN odds - 1
									ELSE odds END
									) END
							) * - spositiontaking * 0.5
					WHEN @modds =  0 AND bettype <> 303       THEN 0
					WHEN @modds =  0 AND bettype = 303       THEN CASE 
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
					WHEN @modds =  0 AND bettype <> 303        THEN 0
					WHEN @modds =  0 AND bettype = 303        THEN CASE
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
					WHEN @modds =  0 AND bettype <> 303       THEN 0
					WHEN @modds =  0 AND bettype = 303       THEN CASE 
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
					WHEN @modds =  0 AND bettype <> 303        THEN 0
					WHEN @modds =  0 AND bettype = 303        THEN CASE
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
					WHEN @modds =  0 AND bettype <> 303        THEN 0
					WHEN @modds =  0 AND bettype = 303        THEN CASE
																	WHEN oddsspread = 0 THEN 0
																	WHEN oddsspread > 0 THEN @commWinRate * sdiscount * stake * (oddsspread/100) * (1-(spositiontaking+mpositiontaking+apositiontaking))
																	ELSE @commLostRate * sdiscount * stake * ABS(oddsspread/100) * (1-(spositiontaking+mpositiontaking+apositiontaking))
																	END
					WHEN @modds = - 0.25 THEN @commLostRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking)) * 0.5
					WHEN @modds < - 0.25 THEN @commLostRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
					END
				,[status] = CASE 
					WHEN @modds > 0 THEN 'WON'
					WHEN @modds = 0 AND bettype <> 303 THEN 'DRAW'
					WHEN @modds = 0 AND bettype = 303 THEN CASE WHEN oddsspread = 0 THEN 'DRAW' 
																WHEN oddsspread > 0 THEN 'WON'
																ELSE 'LOSE'
																END
					WHEN @modds < 0 THEN 'LOSE'
					END
				,StatusID = CASE 
					WHEN @modds > 0 THEN 112 --WON
					WHEN @modds = 0 AND bettype <> 303 THEN 111 --DRAW
					WHEN @modds = 0 AND bettype = 303 THEN CASE WHEN oddsspread = 0 THEN 111 
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
				AND statusID NOT IN (101, 102)--[status] NOT IN (N'VOID', N'REJECT')
			OPTION (FORCE ORDER)

			WAITFOR DELAY '00:00:00:010'

			--PRINT @@ROWCOUNT
		END
		DROP TABLE #currList
		DROP TABLE #tempCust
    END
END

GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Admin_Calculate_7] TO [vnteam] AS [dbo]