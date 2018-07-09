/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_27] @matchid INT
	,@bettype SMALLINT
	,@fth SMALLMONEY
	,@fta SMALLMONEY
	,@betcount INT = 0
	,@IsSettleAbandonedMatch BIT = 0
	,@IsSettleAbandonedMatchBetFair BIT = 0
	,@IsSettleAbandonedMatchIBC BIT = 0
AS
/*
	Created by: Kathy
	Date: 20140211
	Task: Settlement - To Win to nil
	DB: DBTXN.BODB02
	
	Revisions:
		- 20140304@Kathy: Execute settlement for abandoned/postponed matches- Clean Sheet, Both/One/Neither team to score, To Win To Nil 
		- 20140729@Kathy: Add one more account(BF3) into BetFair's group [Redmine:#19665]
		- 20151209@Patrick: Database - Change datatype [Redmine: #48660]
		- 20180704@Helen: Prevent lock escalation on Bettrans [Redmine:#89132]
*/
BEGIN
	IF @betcount = 0 AND @@SERVERNAME NOT LIKE N'DBIOM%' RETURN

	IF @@SERVERNAME IN ('DB04', 'DB042', 'DB043', 'DB044', 'SITDB04', 'SITDB042','SITDB043', 'SITDB044') RETURN

	SET NOCOUNT ON

	DECLARE @modds MONEY
		,@commWinRate SMALLMONEY
		,@commLostRate SMALLMONEY

	DECLARE 
		 @BatchCount			INT
		,@BatchNo				INT
		,@MinCustId				INT
		,@MaxCustId				INT
		,@MinTransId			BIGINT
		,@MaxTransId			BIGINT
		,@TransIdOfMinCust		BIGINT
		,@TransIdOfMaxCust		BIGINT
		

	DECLARE @tmpBatch AS TABLE (
		BatchNo					INT
		,CustId					INT
		,MinCustId				INT
		,MaxCustId				INT
		,MinTransId				BIGINT
		,MaxTransId				BIGINT
		,TransIdOfMinCust		BIGINT
		,TransIdOfMaxCust		BIGINT
		,UNIQUE CLUSTERED (BatchNo, CustId)
	)
		
	SET	@BatchCount = 2000
	
	IF @IsSettleAbandonedMatch = 1 OR @IsSettleAbandonedMatchBetfair = 1 OR @IsSettleAbandonedMatchIBC = 1
	BEGIN
		UPDATE bettrans WITH (ROWLOCK, UPDLOCK)
		SET @modds = CASE 
				WHEN betteam = 'a' AND @fth > 0 THEN - 1
				WHEN betteam = 'h' AND @fta > 0 THEN - 1
				WHEN @fth > 0 AND @fta > 0 THEN - 1
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
								WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28) THEN odds - 1
								ELSE odds END
								) END
						)
				WHEN @modds = 0.25 THEN actual_stake + stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28) THEN odds - 1
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
								WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28) THEN odds - 1
								ELSE odds END
								) END
						) * - apositiontaking
				WHEN @modds = 0.25 THEN stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28) THEN odds - 1
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
								WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28) THEN odds - 1
								ELSE odds END
								) END
						) * - mpositiontaking
				WHEN @modds = 0.25 THEN stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28) THEN odds - 1
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
								WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28) THEN odds - 1
								ELSE odds END
								) END
						) * - spositiontaking
				WHEN @modds = 0.25 THEN stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28) THEN odds - 1
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
		WHERE matchid = @matchid AND bettype = @bettype 
		AND statusID NOT IN (101, 102) 
		AND 1 = CASE 
					WHEN @IsSettleAbandonedMatch = 1 AND (custid IN (50057, 879241, 103873, 78761, 851668, 878902) OR recommend = 1688156) THEN 1
					WHEN @IsSettleAbandonedMatchBetFair = 1 AND custid IN (2331, 1077687, 115770, 15523642) THEN 1
					WHEN @IsSettleAbandonedMatchIBC = 1 AND (custid NOT IN (50057, 879241, 103873, 78761, 851668, 878902, 2331, 1077687, 115770, 15523642) and recommend <> 1688156) THEN 1
					ELSE 0
				END 
	END
	ELSE
	BEGIN
		IF @@SERVERNAME IN ('DB052', 'DB053', 'DB054', 'SITDB052', 'SITDB053', 'SITDB054', 'DB231','DB231\SQLSERVER2008R2', 'DB215','DB215\SQLSERVER2008R2')
		BEGIN	
			INSERT INTO @tmpBatch (BatchNo, CustId, MinCustId, MaxCustId, MinTransId, MaxTransId, TransIdOfMinCust, TransIdOfMaxCust)
			SELECT	BatchNo
					,recommend
					,MAX(CASE WHEN MinRn = 0 THEN recommend ELSE 0 END) AS MinCustId
					,MAX(CASE WHEN MaxRn = 1 THEN recommend ELSE 0 END) AS MaxCustId
					,MAX(CASE WHEN TransIdAsc = 1 THEN transId ELSE 0 END ) AS MinTransId	
					,MAX(CASE WHEN TransIdDesc = 1 THEN transId ELSE 0 END ) AS MaxTransId			
					,MAX(CASE WHEN MinRn = 0 THEN transid ELSE 0 END) AS TransIdOfMinCust
					,MAX(CASE WHEN MaxRn = 1 THEN transid ELSE 0 END) AS TransIdOfMaxCust
			FROM (
				SELECT	n.BatchNo
						,b.recommend
						,b.transid
						,(rn - 1)%@BatchCount AS MinRn
						,ROW_NUMBER() OVER (PARTITION BY n.BatchNo ORDER BY b.rn DESC) MaxRn
						,ROW_NUMBER() OVER (PARTITION BY n.BatchNo ORDER BY transid DESC) TransIdDesc
						,ROW_NUMBER() OVER (PARTITION BY n.BatchNo ORDER BY transid) TransIdAsc
				FROM	(
					SELECT	transid
							,recommend
							,ROW_NUMBER() OVER (ORDER BY recommend, transid) AS rn
					FROM	dbo.bettrans WITH(NOLOCK)
					WHERE	matchid = @matchid
							AND bettype = @bettype
				)b
				CROSS APPLY (	
					SELECT	((b.rn - 1) /@BatchCount) + 1 AS BatchNo
				)n
			)b
			GROUP BY BatchNo, recommend
			
			SELECT @BatchNo = MAX(BatchNo)
			FROM @tmpBatch
			
			WHILE @BatchNo > 0
			BEGIN	
				SELECT	@MinCustId = MAX(MinCustId)
					,@MaxCustId = MAX(MaxCustId)
					,@MinTransId = MAX(MinTransId)
					,@MaxTransId = MAX(MaxTransId)
					,@TransIdOfMinCust = MAX(TransIdOfMinCust)
					,@TransIdOfMaxCust = MAX(TransIdOfMaxCust)
				FROM	@tmpBatch
				WHERE	BatchNo = @BatchNo
			
				UPDATE b
					SET @modds = CASE 
							WHEN betteam = 'h' AND (@fth > @fta AND @fta = 0) THEN 1
							WHEN betteam = 'a' AND (@fta > @fth AND @fth = 0) THEN 1
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
						,WinLost = CASE 
							WHEN @modds > 0.25 THEN actual_stake + stake * (CASE 
									WHEN odds < 0 THEN 1
									ELSE (CASE 
											WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28) THEN odds - 1
											ELSE odds END
											) END
									)
							WHEN @modds = 0.25 THEN actual_stake + stake * (CASE 
									WHEN odds < 0 THEN 1
									ELSE (CASE 
											WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28) THEN odds - 1
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
											WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28) THEN odds - 1
											ELSE odds END
											) END
									) * - apositiontaking
							WHEN @modds = 0.25 THEN stake * (CASE 
									WHEN odds < 0 THEN 1
									ELSE (CASE 
											WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28) THEN odds - 1
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
											WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28) THEN odds - 1
											ELSE odds END
											) END
									) * - mpositiontaking
							WHEN @modds = 0.25 THEN stake * (CASE 
									WHEN odds < 0 THEN 1
									ELSE (CASE 
											WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28) THEN odds - 1
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
											WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28) THEN odds - 1
											ELSE odds END
											) END
									) * - spositiontaking
							WHEN @modds = 0.25 THEN stake * (CASE 
									WHEN odds < 0 THEN 1
									ELSE (CASE 
											WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28) THEN odds - 1
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
				FROM	@tmpBatch r
						INNER JOIN dbo.bettrans b 
							ON	r.BatchNo = @BatchNo
								AND r.CustId = b.recommend
						CROSS APPLY (
							SELECT CASE
										WHEN r.CustId = @MinCustId AND transId < @TransIdOfMinCust THEN 0
										WHEN r.CustId = @MaxCustId AND transId > @TransIdOfMaxCust THEN 0
										WHEN b.transId BETWEEN @MinTransId AND @MaxTransId THEN 1 
										ELSE 0
									END AS IsCalculated
						)i			
				WHERE matchid = @matchid AND bettype = @bettype 
					AND statusID NOT IN (101, 102) --status NOT IN ('VOID', 'REJECT')
					AND i.IsCalculated = 1
					
				SET @BatchNo = @BatchNo - 1

				WAITFOR DELAY '00:00:00:010'	
					
			END		
		END
		ELSE
		BEGIN
			INSERT INTO @tmpBatch (BatchNo, CustId, MinCustId, MaxCustId, MinTransId, MaxTransId, TransIdOfMinCust, TransIdOfMaxCust)
			SELECT	BatchNo
					,custid
					,MAX(CASE WHEN MinRn = 0 THEN CustId ELSE 0 END) AS MinCustId
					,MAX(CASE WHEN MaxRn = 1 THEN CustId ELSE 0 END) AS MaxCustId
					,MAX(CASE WHEN TransIdAsc = 1 THEN transId ELSE 0 END ) AS MinTransId	
					,MAX(CASE WHEN TransIdDesc = 1 THEN transId ELSE 0 END ) AS MaxTransId			
					,MAX(CASE WHEN MinRn = 0 THEN transid ELSE 0 END) AS TransIdOfMinCust
					,MAX(CASE WHEN MaxRn = 1 THEN transid ELSE 0 END) AS TransIdOfMaxCust
			FROM (
				SELECT	n.BatchNo
						,b.custid
						,b.transid
						,(rn - 1)%@BatchCount AS MinRn
						,ROW_NUMBER() OVER (PARTITION BY n.BatchNo ORDER BY b.rn DESC) MaxRn
						,ROW_NUMBER() OVER (PARTITION BY n.BatchNo ORDER BY transid DESC) TransIdDesc
						,ROW_NUMBER() OVER (PARTITION BY n.BatchNo ORDER BY transid) TransIdAsc
				FROM	(
					SELECT	transid
							,custid
							,ROW_NUMBER() OVER (ORDER BY custid, transid) AS rn
					FROM	dbo.bettrans WITH(NOLOCK)
					WHERE	matchid = @matchid
							AND bettype = @bettype
				)b
				CROSS APPLY (	
					SELECT	((b.rn - 1) /@BatchCount) + 1 AS BatchNo
				)n
			)b
			GROUP BY BatchNo, CustId
				
			SELECT @BatchNo = MAX(BatchNo)
			FROM @tmpBatch
		
			WHILE @BatchNo > 0
			BEGIN
				SELECT	@MinCustId = MAX(MinCustId)
						,@MaxCustId = MAX(MaxCustId)
						,@MinTransId = MAX(MinTransId)
						,@MaxTransId = MAX(MaxTransId)
						,@TransIdOfMinCust = MAX(TransIdOfMinCust)
						,@TransIdOfMaxCust = MAX(TransIdOfMaxCust)
				FROM	@tmpBatch
				WHERE	BatchNo = @BatchNo
				
				UPDATE b
					SET @modds = CASE 
							WHEN betteam = 'h' AND (@fth > @fta AND @fta = 0) THEN 1
							WHEN betteam = 'a' AND (@fta > @fth AND @fth = 0) THEN 1
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
						,WinLost = CASE 
							WHEN @modds > 0.25 THEN actual_stake + stake * (CASE 
									WHEN odds < 0 THEN 1
									ELSE (CASE 
											WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28) THEN odds - 1
											ELSE odds END
											) END
									)
							WHEN @modds = 0.25 THEN actual_stake + stake * (CASE 
									WHEN odds < 0 THEN 1
									ELSE (CASE 
											WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28) THEN odds - 1
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
											WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28) THEN odds - 1
											ELSE odds END
											) END
									) * - apositiontaking
							WHEN @modds = 0.25 THEN stake * (CASE 
									WHEN odds < 0 THEN 1
									ELSE (CASE 
											WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28) THEN odds - 1
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
											WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28) THEN odds - 1
											ELSE odds END
											) END
									) * - mpositiontaking
							WHEN @modds = 0.25 THEN stake * (CASE 
									WHEN odds < 0 THEN 1
									ELSE (CASE 
											WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28) THEN odds - 1
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
											WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28) THEN odds - 1
											ELSE odds END
											) END
									) * - spositiontaking
							WHEN @modds = 0.25 THEN stake * (CASE 
									WHEN odds < 0 THEN 1
									ELSE (CASE 
											WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28) THEN odds - 1
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
				FROM	@tmpBatch c
						INNER JOIN dbo.bettrans b
							ON	c.BatchNo = @BatchNo
								AND c.CustId = b.custid
						CROSS APPLY (
							SELECT CASE
										WHEN c.CustId = @MinCustId AND transId < @TransIdOfMinCust THEN 0
										WHEN c.CustId = @MaxCustId AND transId > @TransIdOfMaxCust THEN 0
										WHEN b.transId BETWEEN @MinTransId AND @MaxTransId THEN 1 
										ELSE 0
									END AS IsCalculated
						)i	
				WHERE matchid = @matchid AND bettype = @bettype 
					AND statusID NOT IN (101, 102) --status NOT IN ('VOID', 'REJECT')
					AND i.IsCalculated = 1
				
				SET @BatchNo = @BatchNo - 1

				WAITFOR DELAY '00:00:00:010'	
					
			END
		END	
	END
END
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Admin_Calculate_27] TO [vnteam] AS [dbo]
GO