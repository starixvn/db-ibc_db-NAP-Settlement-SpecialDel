/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0"></info>*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_5] @matchid INT
	,@bettype SMALLINT
	,@whowin SMALLMONEY = 0
	,@hth SMALLMONEY = 0
	,@hta SMALLMONEY = 0
	,@fth SMALLMONEY = 0
	,@fta SMALLMONEY = 0
	,@betcount INT = 0
AS
/*
	Created by: Kathy
	Date: 20140211
	Task: Settlement 
	DB: DBO2.BODB02
	
	Revisions:
		- 20140610@Kathy: Using clustered index(CIX_recommend_matchid_bettype) in DB052, DB053, DB054		
		- 20150413@Jamie: Settlement Betradar phase 2 [Redmine: #27212]
		- 20151210@Patrick: Database - Change datatype [Redmine: #48660]
		- 20160613@Patrick: Reduce escalation lock when updating large amount of data [Redmine: #56550]
		- 20160705@Kathy: PH-AIO phase 2 (67 bettypes ) [Redmine:#53154]
		- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]

*/
BEGIN
	SET NOCOUNT ON

	IF @betcount = 0 AND @@SERVERNAME NOT LIKE N'DBIOM%' RETURN

	IF @@SERVERNAME IN ('DB04', 'DB042', 'DB043', 'DB044') RETURN

	DECLARE @modds MONEY
		,@commWinRate SMALLMONEY
		,@commLostRate SMALLMONEY

	IF @@SERVERNAME IN ('DB052', 'DB053', 'DB054','DB231','DB215')
	BEGIN
		DECLARE @affectedagents INT

		CREATE TABLE #tmpRecommend(recommend INT  PRIMARY KEY)

		INSERT INTO #tmpRecommend(recommend)
		SELECT DISTINCT recommend
		FROM dbo.bettrans WITH(NOLOCK) WHERE matchid = @matchid and bettype = @bettype
	
		DECLARE @currecommend TABLE(recommend INT PRIMARY KEY)

		WHILE 1=1
		BEGIN
			DELETE 
			FROM @currecommend

			DELETE TOP(100) 
			FROM #tmpRecommend OUTPUT DELETED.recommend INTO @currecommend
	
			SET @affectedagents = @@rowcount

			UPDATE b WITH(ROWLOCK, UPDLOCK)
			SET @modds = CASE 
							WHEN bettype = 459 THEN CASE
														WHEN betteam = '1' AND @hth - livehomescore > @hta - liveawayscore THEN 1
														WHEN betteam = '2' AND @hth - livehomescore < @hta - liveawayscore THEN 1
														WHEN betteam = 'X' AND @hth - livehomescore = @hta - liveawayscore THEN 1
														ELSE -1
													END
							  WHEN bettype = 458 THEN CASE
														WHEN betteam = '1' AND @fth - livehomescore > @fta - liveawayscore THEN 1
														WHEN betteam = '2' AND @fth - livehomescore < @fta - liveawayscore THEN 1
														WHEN betteam = 'X' AND @fth - livehomescore = @fta - liveawayscore THEN 1
														ELSE -1
													END
							  ELSE 	
								CASE
									WHEN betteam = '1' AND @whowin > 0 THEN 1
									WHEN betteam = '2' AND @whowin < 0 THEN 1
									WHEN betteam = 'X' AND @whowin = 0 THEN 1
									ELSE -1
								END
						END		
				,
				
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
					WHEN @modds >  0.25	THEN actual_stake + stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,15,16,167,177,1205,430,459,458) then odds-1 else odds end) end)
					WHEN @modds =  0.25	THEN actual_stake + stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,15,16,167,177,1205,430,459,458) then odds-1 else odds end) end) * 0.5
					WHEN @modds =  0	THEN actual_stake
					WHEN @modds = -0.25	THEN actual_stake * 0.5
					WHEN @modds < -0.25	THEN 0
					END,

				aWinLost = CASE
					WHEN @modds >  0.25	THEN stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,15,16,167,177,1205,430,459,458) then odds-1 else odds end) end) * -apositiontaking
					WHEN @modds =  0.25	THEN stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,15,16,167,177,1205,430,459,458) then odds-1 else odds end) end) * -apositiontaking * 0.5
					WHEN @modds =  0	THEN 0
					WHEN @modds = -0.25	THEN actual_stake * apositiontaking * 0.5
					WHEN @modds < -0.25	THEN actual_stake * apositiontaking
					END,
				mWinLost = CASE
					WHEN @modds >  0.25 	THEN stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,15,16,167,177,1205,430,459,458) then odds-1 else odds end) end) * -mpositiontaking
					WHEN @modds =  0.25 	THEN stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,15,16,167,177,1205,430,459,458) then odds-1 else odds end) end) * -mpositiontaking * 0.5
					WHEN @modds =  0    	THEN 0
					WHEN @modds = -0.25 	THEN actual_stake * mpositiontaking * 0.5
					WHEN @modds < -0.25 	THEN actual_stake * mpositiontaking
					END,
				sWinLost = CASE
					WHEN @modds >  0.25 	THEN stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,15,16,167,177,1205,430,459,458) then odds-1 else odds end) end) * -spositiontaking
					WHEN @modds =  0.25 	THEN stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,15,16,167,177,1205,430,459,458) then odds-1 else odds end) end) * -spositiontaking * 0.5
					WHEN @modds =  0    	THEN 0
					WHEN @modds = -0.25 	THEN actual_stake * spositiontaking * 0.5
					WHEN @modds < -0.25 	THEN actual_stake * spositiontaking
					END,

				PlayerComm = CASE
					WHEN @modds >  0.25 	THEN @commWinRate * playerdiscount * stake
					WHEN @modds =  0.25 	THEN @commWinRate * playerdiscount * stake * 0.5
					WHEN @modds =  0    	THEN 0
					WHEN @modds = -0.25 	THEN @commLostRate * playerdiscount * stake * 0.5
					WHEN @modds < -0.25 	THEN @commLostRate * playerdiscount * stake
					END,
				Comm = CASE
					WHEN @modds >  0.25 	THEN @commWinRate * discount * stake * (1-apositiontaking)
					WHEN @modds =  0.25 	THEN @commWinRate * discount * stake * (1-apositiontaking) * 0.5
					WHEN @modds =  0    	THEN 0
					WHEN @modds = -0.25 	THEN @commLostRate * discount * stake * (1-apositiontaking) * 0.5
					WHEN @modds < -0.25 	THEN @commLostRate * discount * stake * (1-apositiontaking)
					END,
				aComm = CASE
					WHEN @modds >  0.25 	THEN @commWinRate * adiscount * stake * (1-(mpositiontaking+apositiontaking))
					WHEN @modds =  0.25 	THEN @commWinRate * adiscount * stake * (1-(mpositiontaking+apositiontaking)) * 0.5
					WHEN @modds =  0    	THEN 0
					WHEN @modds = -0.25 	THEN @commLostRate * adiscount * stake * (1-(mpositiontaking+apositiontaking)) * 0.5
					WHEN @modds < -0.25 	THEN @commLostRate * adiscount * stake * (1-(mpositiontaking+apositiontaking))
					END,
				sComm = CASE
					WHEN @modds >  0.25 	THEN @commWinRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking))
					WHEN @modds =  0.25 	THEN @commWinRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking)) * 0.5
					WHEN @modds =  0    	THEN 0
					WHEN @modds = -0.25 	THEN @commLostRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking)) * 0.5
					WHEN @modds < -0.25 	THEN @commLostRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking))
					END,

				Status = CASE
					WHEN @modds > 0 THEN 'WON'
					WHEN @modds = 0 THEN 'DRAW'
					WHEN @modds < 0 THEN 'LOSE'
					END,
				StatusID = CASE
					WHEN @modds > 0 THEN 112 --WON
					WHEN @modds = 0 THEN 111 --DRAW
					WHEN @modds < 0 THEN 113 --LOSE
					END,
				ruben=1
			FROM bettrans b 
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

			DELETE TOP (800)
			FROM #tempCust OUTPUT DELETED.custid INTO #currList
			IF @@ROWCOUNT = 0 BREAK

			SELECT @MinCustId = MIN(CustId) FROM #currList

			UPDATE b
			SET @modds = CASE 
							WHEN bettype = 459 THEN CASE
														WHEN betteam = '1' AND @hth - livehomescore > @hta - liveawayscore THEN 1
														WHEN betteam = '2' AND @hth - livehomescore < @hta - liveawayscore THEN 1
														WHEN betteam = 'X' AND @hth - livehomescore = @hta - liveawayscore THEN 1
														ELSE -1
													END
							  WHEN bettype = 458 THEN CASE
														WHEN betteam = '1' AND @fth - livehomescore > @fta - liveawayscore THEN 1
														WHEN betteam = '2' AND @fth - livehomescore < @fta - liveawayscore THEN 1
														WHEN betteam = 'X' AND @fth - livehomescore = @fta - liveawayscore THEN 1
														ELSE -1
													END
							  ELSE 	
								CASE
									WHEN betteam = '1' AND @whowin > 0 THEN 1
									WHEN betteam = '2' AND @whowin < 0 THEN 1
									WHEN betteam = 'X' AND @whowin = 0 THEN 1
									ELSE -1
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
				,WinLost = CASE 
					WHEN @modds > 0.25 THEN actual_stake + stake * (CASE 
							WHEN odds < 0 THEN 1
							ELSE (CASE 
									WHEN bettype IN (4, 5, 6, 15, 16,167,177, 1205,430,459,458) THEN odds - 1
									ELSE odds END
									) END
							)
					WHEN @modds = 0.25 THEN actual_stake + stake * (CASE 
							WHEN odds < 0 THEN 1
							ELSE (CASE 
									WHEN bettype IN (4, 5, 6, 15, 16,167,177, 1205,430,459,458) THEN odds - 1
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
									WHEN bettype IN (4, 5, 6, 15, 16,167,177, 1205,430,459,458) THEN odds - 1
									ELSE odds END
									) END
							) * - apositiontaking
					WHEN @modds = 0.25 THEN stake * (CASE 
							WHEN odds < 0 THEN 1
							ELSE (CASE 
									WHEN bettype IN (4, 5, 6, 15, 16,167,177, 1205,430,459,458) THEN odds - 1
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
									WHEN bettype IN (4, 5, 6, 15, 16,167,177, 1205,430,459,458) THEN odds - 1
									ELSE odds END
									) END
							) * - mpositiontaking
					WHEN @modds = 0.25 THEN stake * (CASE 
							WHEN odds < 0 THEN 1
							ELSE (CASE 
									WHEN bettype IN (4, 5, 6, 15, 16,167,177, 1205,430,459,458) THEN odds - 1
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
									WHEN bettype IN (4, 5, 6, 15, 16,167,177, 1205,430,459,458) THEN odds - 1
									ELSE odds END
									) END
							) * - spositiontaking
					WHEN @modds = 0.25 THEN stake * (CASE 
							WHEN odds < 0 THEN 1
							ELSE (CASE 
									WHEN bettype IN (4, 5, 6, 15, 16,167,177, 1205,430,459,458) THEN odds - 1
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
			FROM #currList t 
				INNER JOIN dbo.bettrans b WITH (ROWLOCK, UPDLOCK) ON t.custid = b.custid
			WHERE matchid = @matchid 
				AND b.custid >= @MinCustId
				AND bettype = @bettype 
				AND statusID NOT IN (101, 102)
			OPTION (FORCE ORDER)
			--PRINT @@ROWCOUNT

			WAITFOR DELAY '00:00:00:010'
		END
		DROP TABLE #currList
		DROP TABLE #tempCust
	END
END
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Admin_Calculate_5] TO [vnteam] AS [dbo]
GO