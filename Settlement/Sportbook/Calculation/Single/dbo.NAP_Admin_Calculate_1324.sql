/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_1324] 
     @matchid						INT
	,@bettype						SMALLINT
	,@SelectedSet					VARCHAR(50)  = NULL 
	,@SelectedSettleFinishedGame	VARCHAR(50)  = NULL 
	,@SetxGameyHomeWON				VARCHAR(MAX) = NULL
	,@SetxGameyAwayWON				VARCHAR(MAX) = NULL
	,@SetxGameyDRAW					VARCHAR(MAX) = NULL 
	,@SetxGameyREFUND				VARCHAR(MAX) = NULL 
	,@SetxGameyFinishedGame			VARCHAR(MAX) = NULL 
	,@betcount						INT = 0
	-- add any params, please modify script in 'special section'
AS
/*
	Created by: Jamie
	Date:20141020
	Task: Settlement Tennis 
	DB: DBTXN/BODB02
		
	Revisions:
		- 20151208@Patrick: Database - Change datatype [Redmine: #48660]
		- 20180904@Kathy: Change CIX on DB054 [Redmine:#100828]
		
		
*/
BEGIN
	IF @betcount = 0 AND @@SERVERNAME NOT LIKE N'DBIOM%' RETURN

	SET NOCOUNT ON

	DECLARE @modds			MONEY
		,@commWinRate		SMALLMONEY
		,@commLostRate		SMALLMONEY
		,@RemoteCount		INT
		,@isAutoRefundGame	BIT

	IF @@SERVERNAME IN ('DB04', 'DB042', 'DB043', 'DB044') RETURN

	IF @@SERVERNAME IN ('DB052', 'DB053', 'SITDB052', 'SITDB053', 'DB231', 'DB215', 'DB231\SQLSERVER2008R2', 'DB215\SQLSERVER2008R2')
	BEGIN
		DECLARE @affectedagents INT

		CREATE TABLE #tmpRecommend(recommend INT  PRIMARY KEY)

		INSERT INTO #tmpRecommend(recommend)
		SELECT DISTINCT recommend
		FROM dbo.bettrans WITH(NOLOCK) WHERE matchid = @matchid and bettype = @bettype

		DECLARE @currecommend TABLE(recommend int PRIMARY KEY)

		WHILE 1=1
		BEGIN
			DELETE 
			FROM @currecommend

			DELETE TOP (100)
			FROM #tmpRecommend OUTPUT DELETED.recommend INTO @currecommend

			SET @affectedagents = @@rowcount

			UPDATE b
			SET 
			
			@isAutoRefundGame	= CASE WHEN  CHARINDEX(SUBSTRING(CAST(BetID AS VARCHAR(10)),2,4),@SetxGameyREFUND)>0 THEN 1 ELSE 0 END -- Refund: Game no score 
			
			,@modds = CASE	WHEN betteam =N'h' AND CHARINDEX(SUBSTRING(CAST(BetID AS VARCHAR(10)),2,4),@SetxGameyHomeWON)>0 THEN 1 
									WHEN betteam =N'a' AND CHARINDEX(SUBSTRING(CAST(BetID AS VARCHAR(10)),2,4),@SetxGameyAwayWON)>0 THEN 1   
									WHEN CHARINDEX(SUBSTRING(CAST(BetID AS VARCHAR(10)),2,4),@SetxGameyDRAW)>0 THEN 0 
									WHEN CHARINDEX(SUBSTRING(CAST(BetID AS VARCHAR(10)),2,4),@SetxGameyREFUND)>0 THEN 0
									ELSE -1 END,
			modds = @modds,
			@commWinRate = CASE comstatus -- 0 : pay normal, both win/lost -- 1 : pay 'double' ONLY on lost
			WHEN '0' THEN 1
			WHEN '1' THEN 0 
			ELSE 1 END,
			@commLostRate = CASE comstatus
			WHEN '0' THEN 1
			WHEN '1' THEN 2 
			ELSE 1 END,--'s','m'
			
			WinLost = CASE
				WHEN @modds >  0.25	THEN actual_stake + stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,1201) then odds-1 else odds end) end)
				WHEN @modds =  0.25	THEN actual_stake + stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,1201) then odds-1 else odds end) end) * 0.5
				WHEN @modds =  0	THEN actual_stake
				WHEN @modds = -0.25	THEN actual_stake * 0.5
				WHEN @modds < -0.25	THEN 0
				END,

			aWinLost = CASE
				WHEN @modds >  0.25	THEN stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,1201) then odds-1 else odds end) end) * -apositiontaking
				WHEN @modds =  0.25	THEN stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,1201) then odds-1 else odds end) end) * -apositiontaking * 0.5
				WHEN @modds =  0	THEN 0
				WHEN @modds = -0.25	THEN actual_stake * apositiontaking * 0.5
				WHEN @modds < -0.25	THEN actual_stake * apositiontaking
				END,
			mWinLost = CASE
				WHEN @modds >  0.25 	THEN stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,1201) then odds-1 else odds end) end) * -mpositiontaking
				WHEN @modds =  0.25 	THEN stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,1201) then odds-1 else odds end) end) * -mpositiontaking * 0.5
				WHEN @modds =  0    	THEN 0
				WHEN @modds = -0.25 	THEN actual_stake * mpositiontaking * 0.5
				WHEN @modds < -0.25 	THEN actual_stake * mpositiontaking
				END,
			sWinLost = CASE
				WHEN @modds >  0.25 	THEN stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,1201) then odds-1 else odds end) end) * -spositiontaking
				WHEN @modds =  0.25 	THEN stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,1201) then odds-1 else odds end) end) * -spositiontaking * 0.5
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
				WHEN @modds > 0 THEN N'WON'
				WHEN @modds = 0 AND @isAutoRefundGame=0 THEN N'DRAW'
				WHEN @modds = 0 AND @isAutoRefundGame=1 THEN N'Refund'
				WHEN @modds < 0 THEN N'LOSE'
				END,
			StatusID = CASE
				WHEN @modds > 0 THEN 112 --WON
				WHEN @modds = 0 AND @isAutoRefundGame =0 THEN 111 --DRAW
				WHEN @modds = 0 AND @isAutoRefundGame =1 THEN 103 --REFUND
				WHEN @modds < 0 THEN 113 --LOSE
				END,
			ruben=1
			FROM dbo.bettrans b WITH (ROWLOCK, UPDLOCK)
				INNER JOIN @currecommend ag on b.recommend = ag.recommend
			WHERE
				matchid=@matchid 
				AND bettype=@bettype 
				AND statusID NOT IN (101, 102)
				AND 1 = CASE WHEN @SelectedSet LIKE '%1%' AND BetID BETWEEN 80101 AND 80199 THEN 1  -- CAL Set x Game y Winner 
							 WHEN @SelectedSet LIKE '%2%' AND BetID BETWEEN 80201 AND 80299 THEN 1 
							 WHEN @SelectedSet LIKE '%3%' AND BetID BETWEEN 80301 AND 80399 THEN 1 
							 WHEN @SelectedSet LIKE '%4%' AND BetID BETWEEN 80401 AND 80499 THEN 1 
							 WHEN @SelectedSet LIKE '%5%' AND BetID BETWEEN 80501 AND 80599 THEN 1 
							 ELSE 0 END 
				AND 1 = CASE WHEN @SelectedSettleFinishedGame IS NULL THEN 1 
							 WHEN @SelectedSettleFinishedGame LIKE '%1%' AND BetID BETWEEN 80101 AND 80199 AND CHARINDEX(SUBSTRING(CAST(BetID AS VARCHAR(10)),2,4),@SetxGameyFinishedGame)>0 THEN 1 
							 WHEN @SelectedSettleFinishedGame LIKE '%2%' AND BetID BETWEEN 80201 AND 80299 AND CHARINDEX(SUBSTRING(CAST(BetID AS VARCHAR(10)),2,4),@SetxGameyFinishedGame)>0 THEN 1   
							 WHEN @SelectedSettleFinishedGame LIKE '%3%' AND BetID BETWEEN 80301 AND 80399 AND CHARINDEX(SUBSTRING(CAST(BetID AS VARCHAR(10)),2,4),@SetxGameyFinishedGame)>0 THEN 1
							 WHEN @SelectedSettleFinishedGame LIKE '%4%' AND BetID BETWEEN 80401 AND 80499 AND CHARINDEX(SUBSTRING(CAST(BetID AS VARCHAR(10)),2,4),@SetxGameyFinishedGame)>0 THEN 1  
							 WHEN @SelectedSettleFinishedGame LIKE '%5%' AND BetID BETWEEN 80501 AND 80599 AND CHARINDEX(SUBSTRING(CAST(BetID AS VARCHAR(10)),2,4),@SetxGameyFinishedGame)>0 THEN 1   
							 ELSE 0 END 	

			IF @affectedagents <> 100
				BREAK
		END

		DROP TABLE #tmpRecommend
	END
	ELSE
	BEGIN
		UPDATE dbo.bettrans WITH (ROWLOCK, UPDLOCK)
		SET 
		
			@isAutoRefundGame	= CASE WHEN  CHARINDEX(SUBSTRING(CAST(BetID AS VARCHAR(10)),2,4),@SetxGameyREFUND)>0 THEN 1 ELSE 0 END -- Refund: Game no score 
			
			,@modds = CASE	WHEN betteam =N'h' AND CHARINDEX(SUBSTRING(CAST(BetID AS VARCHAR(10)),2,4),@SetxGameyHomeWON)>0 THEN 1 
									WHEN betteam =N'a' AND CHARINDEX(SUBSTRING(CAST(BetID AS VARCHAR(10)),2,4),@SetxGameyAwayWON)>0 THEN 1   
									WHEN CHARINDEX(SUBSTRING(CAST(BetID AS VARCHAR(10)),2,4),@SetxGameyDRAW)>0 THEN 0 
									WHEN CHARINDEX(SUBSTRING(CAST(BetID AS VARCHAR(10)),2,4),@SetxGameyREFUND)>0 THEN 0
									ELSE -1 END
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
				WHEN @modds = 0 THEN actual_stake
				WHEN @modds = - 0.25 THEN actual_stake * 0.5
				WHEN @modds < - 0.25 THEN 0
				END
			,aWinLost = CASE 
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
				WHEN @modds = 0 THEN 0
				WHEN @modds = - 0.25 THEN actual_stake * apositiontaking * 0.5
				WHEN @modds < - 0.25 THEN actual_stake * apositiontaking
				END
			,mWinLost = CASE 
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
				WHEN @modds = 0 THEN 0
				WHEN @modds = - 0.25 THEN actual_stake * mpositiontaking * 0.5
				WHEN @modds < - 0.25 THEN actual_stake * mpositiontaking
				END
			,sWinLost = CASE 
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
				END,
			Status = CASE
				WHEN @modds > 0 THEN N'WON'
				WHEN @modds = 0 AND @isAutoRefundGame=0 THEN N'DRAW'
				WHEN @modds = 0 AND @isAutoRefundGame=1 THEN N'Refund'
				WHEN @modds < 0 THEN N'LOSE'
				END,
			StatusID = CASE
				WHEN @modds > 0 THEN 112 --WON
				WHEN @modds = 0 AND @isAutoRefundGame =0 THEN 111 --DRAW
				WHEN @modds = 0 AND @isAutoRefundGame =1 THEN 103 --REFUND
				WHEN @modds < 0 THEN 113 --LOSE
				END,
			ruben = 1
		WHERE	matchid = @matchid 
				AND bettype = @bettype 
				AND statusID NOT IN (101, 102)
				AND 1 = CASE WHEN @SelectedSet LIKE '%1%' AND BetID BETWEEN 80101 AND 80199 THEN 1  -- CAL Set x Game y Winner 
							 WHEN @SelectedSet LIKE '%2%' AND BetID BETWEEN 80201 AND 80299 THEN 1 
							 WHEN @SelectedSet LIKE '%3%' AND BetID BETWEEN 80301 AND 80399 THEN 1 
							 WHEN @SelectedSet LIKE '%4%' AND BetID BETWEEN 80401 AND 80499 THEN 1 
							 WHEN @SelectedSet LIKE '%5%' AND BetID BETWEEN 80501 AND 80599 THEN 1 
							 ELSE 0 END 
				AND 1 = CASE WHEN @SelectedSettleFinishedGame IS NULL THEN 1 
							 WHEN @SelectedSettleFinishedGame LIKE '%1%' AND BetID BETWEEN 80101 AND 80199 AND CHARINDEX(SUBSTRING(CAST(BetID AS VARCHAR(10)),2,4),@SetxGameyFinishedGame)>0 THEN 1 
							 WHEN @SelectedSettleFinishedGame LIKE '%2%' AND BetID BETWEEN 80201 AND 80299 AND CHARINDEX(SUBSTRING(CAST(BetID AS VARCHAR(10)),2,4),@SetxGameyFinishedGame)>0 THEN 1   
							 WHEN @SelectedSettleFinishedGame LIKE '%3%' AND BetID BETWEEN 80301 AND 80399 AND CHARINDEX(SUBSTRING(CAST(BetID AS VARCHAR(10)),2,4),@SetxGameyFinishedGame)>0 THEN 1
							 WHEN @SelectedSettleFinishedGame LIKE '%4%' AND BetID BETWEEN 80401 AND 80499 AND CHARINDEX(SUBSTRING(CAST(BetID AS VARCHAR(10)),2,4),@SetxGameyFinishedGame)>0 THEN 1  
							 WHEN @SelectedSettleFinishedGame LIKE '%5%' AND BetID BETWEEN 80501 AND 80599 AND CHARINDEX(SUBSTRING(CAST(BetID AS VARCHAR(10)),2,4),@SetxGameyFinishedGame)>0 THEN 1   
							 ELSE 0 END 				
	END
END
GO