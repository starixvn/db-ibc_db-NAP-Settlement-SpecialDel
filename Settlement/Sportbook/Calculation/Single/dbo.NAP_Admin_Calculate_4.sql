/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_4] @matchid INT
	,@bettype						SMALLINT
	,@correctscore					NVARCHAR(10) = NULL
	,@goaldiff						SMALLMONEY	 = NULL 
	,@FGLG2							NVARCHAR(10) = NULL
	,@hth							INT = 0
	,@hta							INT = 0
	,@fth							INT = 0
	,@fta							INT = 0
	,@SelectedSet					VARCHAR(50) = NULL
	,@CorrectScoreSet1				NVARCHAR(10)= NULL 
	,@CorrectScoreSet2				NVARCHAR(10)= NULL 
	,@CorrectScoreSet3				NVARCHAR(10)= NULL 
	,@CorrectScoreSet4				NVARCHAR(10)= NULL 
	,@CorrectScoreSet5				NVARCHAR(10)= NULL 
	,@betcount						INT = 0
	,@IsSettleAbandonedMatch		BIT = 0
	,@IsSettleAbandonedMatchIBC		BIT = 0
	,@IsSettleAbandonedMatchBetFair BIT = 0
	,@IsHTCal						BIT = 0
	
AS
/*
	Created by:Kathy
	Date: 20140211
	Task: Settlement 
	DB: DBTRANS.BODB02
	
	Revisions:
		- 20140426@Kathy: Add 1H FGLG (127) [Redmine:#14449]
		- 20140610@Kathy: Using clustered index(CIX_recommend_matchid_bettype) in DB052, DB053, DB054	
		- 20140725@Kathy: Settle determined tickets for Correct Score(4,30)[Redmine:#19310]
		- 20140822@Jamie: Check @correctscore and @goaldiff NULL 
		- 20141017@Jamie: Sporting Solution for Tennis [Redmine:#23034]
		- 20150413@Jamie: Settlement Betradar phase 2 [Redmine: #27212]
		- 20151019@Kathy: Refund HT/FT & 2nd FT bettypes in case of match 3x30 [Redmine:#45626]
		- 20151123@Patrick: Apply 28 Live Bettypes for Settlement [Redmine:#47843]
		- 20151210@Patrick: Database - Change datatype [Redmine: #48660]
		- 20160120@Patrick: PH-AiO - Change request [Redmine: #51116]
		- 20160613@Patrick: Reduce escalation lock when updating large amount of data [Redmine: #56550]
		- 20160705@Kathy: PH-AIO phase 2 (67 bettypes ) [Redmine:#53154]
		- 20160824@Bobby: #62921 - Include FGLG (14,127) bet types into settle determindable
		- 20161021@Kathy: Using new non-clustered index (match_bettype) to update BetParlayDetail [Redmine:#65990]
		- 20161025@Kathy:  Avoid deadlock issue [Redmine:#65990]
		- 20161121@Bobby: #67462 - Remove code SDT for parlay bet types 14,127 when doing refund single SDT
		- 20170815@Kathy: Using table ResultDetail to store FGLG result instead of betstatus [Redmine:#81308]
		- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
		- 20180122@Kathy: Prevent lock escalation on Bettrans [Redmine:#89132]
		
	Param's Explanation:
		
		
*/
BEGIN
	SET NOCOUNT ON

	--IF @betcount = 0 AND @@SERVERNAME NOT LIKE N'DBIOM%' RETURN

	IF @@SERVERNAME IN ('DB04', 'DB042', 'DB043', 'DB044') RETURN	

	DECLARE @modds				MONEY
		,@commWinRate			SMALLMONEY
		,@commLostRate			SMALLMONEY
		,@matchdate				DATETIME
		,@result				NVARCHAR(10)

		,@BatchCount			INT
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

	SET @correctscore = CASE 
							WHEN @bettype IN (14) 
								THEN CASE 
										WHEN @correctscore = 'N' THEN '0:0'
										WHEN @correctscore = 'H' THEN '1:1'
										WHEN @correctscore = 'A' THEN '2:1'
										ELSE ''
									END
								ELSE @correctscore
						END		
											
	SET @FGLG2  = CASE 
					WHEN  @bettype IN (14)  
						THEN CASE 
								WHEN @FGLG2 = 'N' THEN '0:0'
								WHEN @FGLG2 = 'H' THEN '1:2'
								WHEN @FGLG2 = 'A' THEN '2:2'
								ELSE ''
							END
					WHEN @bettype = 448 
						THEN CASE 
								WHEN @FGLG2 = 'N' THEN 'NG'
								ELSE @FGLG2
								END
					ELSE @FGLG2 
				END
				
	IF @@SERVERNAME IN ('DB052', 'DB053', 'DB054', 'SITDB052', 'SITDB053', 'SITDB054', 'DB231', 'DB215')
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

		IF @IsSettleAbandonedMatchIBC = 1 OR @IsSettleAbandonedMatch = 1 OR @IsSettleAbandonedMatchBetFair = 1
		BEGIN
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

				UPDATE 	b
					SET @modds = CASE
										
						WHEN (@bettype IN (14, 127) AND RIGHT(betteam, 1) IN ('0', '1' )  AND @correctscore <> '')  THEN --just for betchoice FG and NG
							CASE WHEN (betteam = @correctscore OR betteam = @FGLG2)	THEN 1 ELSE -1 END
						WHEN b.betteam NOT IN ('0:4', '4:0')
							AND @bettype = 30 --1H Correct Score
							AND (@hth > LEFT(b.betteam,1) OR @hta > RIGHT(b.betteam,1)) THEN -1
						WHEN b.betteam NOT IN ('0:5', '5:0')
							AND @bettype = 4 --Correct Score
							AND (@fth > LEFT(b.betteam,1) OR @fta > RIGHT(b.betteam,1)) THEN -1
					
						WHEN b.betteam NOT IN ('AOS')
							AND @bettype = 405 --2H Correct Score
							AND ((@fth-@hth) > LEFT(b.betteam,1) OR (@fta-@hta) > RIGHT(b.betteam,1)) THEN -1
						WHEN b.betteam = 'AOS' --Any Other Scores
							AND @bettype = 405 --2H Correct Score
							AND CHARINDEX(CAST(@fth-@hth AS VARCHAR) + ':' + CAST(@fta-@hta AS VARCHAR), b.transdesc) = 0 THEN 1
					
						WHEN b.betteam NOT IN ('AOS')
							AND @bettype = 413 --Correct Score (aos)
							AND (@fth > LEFT(b.betteam,1) OR @fta > RIGHT(b.betteam,1)) THEN -1
						WHEN b.betteam = 'AOS'
							AND @bettype = 413
							AND CHARINDEX(CAST(@fth AS VARCHAR) + ':' + CAST(@fta AS VARCHAR), b.transdesc) = 0 THEN 1
					
						WHEN b.betteam NOT IN ('AOS')
							AND @bettype = 414 --1H Correct Score (aos)
							AND (@hth > LEFT(b.betteam,1) OR @hta > RIGHT(b.betteam,1)) THEN -1
						WHEN b.betteam = 'AOS'
							AND @bettype = 414
							AND CHARINDEX(CAST(@hth AS VARCHAR) + ':' + CAST(@hta AS VARCHAR), b.transdesc) = 0 THEN 1
						WHEN b.bettype = 16 THEN CASE
													WHEN @IsHTCal = 1 THEN CASE
																				WHEN @hth > @hta AND LEFT(betteam,1) IN ('0','2') THEN -1
																				WHEN @hth = @hta AND LEFT(betteam,1) IN ('1','2') THEN -1
																				WHEN @hth < @hta AND LEFT(betteam,1) IN ('0','1') THEN -1
																				ELSE NULL
																		   END
													ELSE NULL
												 END
					
						WHEN @bettype = 448 THEN CASE WHEN (@fth + @fta > 0) AND betteam = 'NG' THEN -1 ELSE NULL END
											 
						ELSE NULL
						END,
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
							WHEN @modds >  0.25	THEN actual_stake + stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,14,15,16,30,127,165,166,1204,1235,1302,1317,405,413,414,448) then odds-1 else odds end) end)
							WHEN @modds =  0.25	THEN actual_stake + stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,14,15,16,30,127,165,166,1204,1235,1302,1317,405,413,414,448) then odds-1 else odds end) end) * 0.5
							WHEN @modds =  0	THEN actual_stake
							WHEN @modds = -0.25	THEN actual_stake * 0.5
							WHEN @modds < -0.25	THEN 0
							WHEN @modds IS NULL then winlost
							END,

						aWinLost = CASE
							WHEN @modds >  0.25	THEN stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,14,15,16,30,127,165,166,1204,1235,1302,1317,405,413,414,448) then odds-1 else odds end) end) * -apositiontaking
							WHEN @modds =  0.25	THEN stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,14,15,16,30,127,165,166,1204,1235,1302,1317,405,413,414,448) then odds-1 else odds end) end) * -apositiontaking * 0.5
							WHEN @modds =  0	THEN 0
							WHEN @modds = -0.25	THEN actual_stake * apositiontaking * 0.5
							WHEN @modds < -0.25	THEN actual_stake * apositiontaking
							WHEN @modds IS NULL then aWinLost
							END,
						mWinLost = CASE
							WHEN @modds >  0.25 	THEN stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,14,15,16,30,127,165,166,1204,1235,1302,1317,405,413,414,448) then odds-1 else odds end) end) * -mpositiontaking
							WHEN @modds =  0.25 	THEN stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,14,15,16,30,127,165,166,1204,1235,1302,1317,405,413,414,448) then odds-1 else odds end) end) * -mpositiontaking * 0.5
							WHEN @modds =  0    	THEN 0
							WHEN @modds = -0.25 	THEN actual_stake * mpositiontaking * 0.5
							WHEN @modds < -0.25 	THEN actual_stake * mpositiontaking
							WHEN @modds IS NULL then mWinLost
							END,
						sWinLost = CASE
							WHEN @modds >  0.25 	THEN stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,14,15,16,30,127,165,166,1204,1235,1302,1317,405,413,414,448) then odds-1 else odds end) end) * -spositiontaking
							WHEN @modds =  0.25 	THEN stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,14,15,16,30,127,165,166,1204,1235,1302,1317,405,413,414,448) then odds-1 else odds end) end) * -spositiontaking * 0.5
							WHEN @modds =  0    	THEN 0
							WHEN @modds = -0.25 	THEN actual_stake * spositiontaking * 0.5
							WHEN @modds < -0.25 	THEN actual_stake * spositiontaking
							WHEN @modds IS NULL then sWinLost
							END,

						PlayerComm = CASE
							WHEN @modds >  0.25 	THEN @commWinRate * playerdiscount * stake
							WHEN @modds =  0.25 	THEN @commWinRate * playerdiscount * stake * 0.5
							WHEN @modds =  0    	THEN 0
							WHEN @modds = -0.25 	THEN @commLostRate * playerdiscount * stake * 0.5
							WHEN @modds < -0.25 	THEN @commLostRate * playerdiscount * stake
							WHEN @modds IS NULL then PlayerComm
							END,
						Comm = CASE
							WHEN @modds >  0.25 	THEN @commWinRate * discount * stake * (1-apositiontaking)
							WHEN @modds =  0.25 	THEN @commWinRate * discount * stake * (1-apositiontaking) * 0.5
							WHEN @modds =  0    	THEN 0
							WHEN @modds = -0.25 	THEN @commLostRate * discount * stake * (1-apositiontaking) * 0.5
							WHEN @modds < -0.25 	THEN @commLostRate * discount * stake * (1-apositiontaking)
							WHEN @modds IS NULL then Comm
							END,
						aComm = CASE
							WHEN @modds >  0.25 	THEN @commWinRate * adiscount * stake * (1-(mpositiontaking+apositiontaking))
							WHEN @modds =  0.25 	THEN @commWinRate * adiscount * stake * (1-(mpositiontaking+apositiontaking)) * 0.5
							WHEN @modds =  0    	THEN 0
							WHEN @modds = -0.25 	THEN @commLostRate * adiscount * stake * (1-(mpositiontaking+apositiontaking)) * 0.5
							WHEN @modds < -0.25 	THEN @commLostRate * adiscount * stake * (1-(mpositiontaking+apositiontaking))
							WHEN @modds IS NULL then aComm
							END,
						sComm = CASE
							WHEN @modds >  0.25 	THEN @commWinRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking))
							WHEN @modds =  0.25 	THEN @commWinRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking)) * 0.5
							WHEN @modds =  0    	THEN 0
							WHEN @modds = -0.25 	THEN @commLostRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking)) * 0.5
							WHEN @modds < -0.25 	THEN @commLostRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking))
							WHEN @modds IS NULL then sComm
							END,

						Status = CASE
							WHEN @modds > 0 THEN 'WON'
							WHEN @modds = 0 THEN 'DRAW'
							WHEN @modds < 0 THEN 'LOSE'
							WHEN @modds IS NULL then Status
							END,
						StatusID = CASE
							WHEN @modds > 0 THEN 112 --WON
							WHEN @modds = 0 THEN 111 --DRAW
							WHEN @modds < 0 THEN 113 --LOSE
							WHEN @modds IS NULL then StatusID
							END,
						ruben= CASE when @modds IS NULL THEN ruben
									ELSE 1
							   END
				FROM	@tmpBatch r
					INNER JOIN dbo.bettrans b --WITH (ROWLOCK, UPDLOCK)
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
				WHERE	matchid=@matchid 
						AND bettype=@bettype 
						AND statusID NOT IN (101,102)
						AND i.IsCalculated = 1
						AND 1 = CASE 
									WHEN @IsSettleAbandonedMatch = 1 AND (b.custid IN (50057, 879241, 103873, 78761, 851668, 878902) OR b.recommend = 1688156) THEN 1
									WHEN @IsSettleAbandonedMatchBetFair = 1 AND b.custid IN (2331, 1077687, 115770, 15523642) THEN 1
									WHEN @IsSettleAbandonedMatchIBC = 1 AND (b.custid NOT IN (50057, 879241, 103873, 78761, 851668, 878902, 2331, 1077687, 115770, 15523642) AND b.recommend <> 1688156) THEN 1
									ELSE 0
								END

				SET @BatchNo = @BatchNo - 1

				WAITFOR DELAY '00:00:00:010'
			END
		END
		ELSE
		BEGIN
			SET @result = CASE @bettype 
							WHEN 16 THEN CASE
											WHEN @hth > @hta THEN '1:' + CASE
																			WHEN @fth > @fta THEN '1'
																			WHEN @fth = @fta THEN '0'
																			WHEN @fth < @fta THEN '2'
																			ELSE NULL
																		END
											WHEN @hth = @hta THEN '0:' + CASE
																			WHEN @fth > @fta THEN '1'
																			WHEN @fth = @fta THEN '0'
																			WHEN @fth < @fta THEN '2'
																			ELSE NULL
																		END
											WHEN @hth < @hta THEN '2:' + CASE
																			WHEN @fth > @fta THEN '1'
																			WHEN @fth = @fta THEN '0'
																			WHEN @fth < @fta THEN '2'
																			ELSE NULL
																		END
									END
							ELSE NULL
						END
			
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

				UPDATE 	b
					SET @correctscore	= CASE  WHEN bettype = 1317 AND @SelectedSet LIKE '%1%' AND BetID = 801 THEN @CorrectScoreSet1
											WHEN bettype = 1317 AND @SelectedSet LIKE '%2%' AND BetID = 802 THEN @CorrectScoreSet2
											WHEN bettype = 1317 AND @SelectedSet LIKE '%3%' AND BetID = 803 THEN @CorrectScoreSet3
											WHEN bettype = 1317 AND @SelectedSet LIKE '%4%' AND BetID = 804 THEN @CorrectScoreSet4
											WHEN bettype = 1317 AND @SelectedSet LIKE '%5%' AND BetID = 805 THEN @CorrectScoreSet5
											ELSE @correctscore END 					
						,@modds = CASE
							--448:	Last Team To Score
							WHEN @bettype = 448 THEN CASE WHEN betteam = @FGLG2 THEN 1 ELSE -1 END
						
							WHEN (betteam = @correctscore OR betteam = @FGLG2) AND bettype <> 16 THEN 1
							WHEN betteam = '4:0' AND @goaldiff >= 4 and @bettype = 30 THEN 1 -- 4UP for 1st Correct Score
							WHEN betteam = '0:4' AND @goaldiff <= -4 and @bettype = 30 THEN 1 -- 4UP for 1st Correct Score
							WHEN betteam = '5:0' AND @goaldiff >= 5 THEN 1
							WHEN betteam = '0:5' AND @goaldiff <= -5 THEN 1
							WHEN b.betteam = 'AOS' --Any Other Scores
								AND @bettype = 405 --2H Correct Score
								AND CHARINDEX(CAST(@fth-@hth AS VARCHAR) + ':' + CAST(@fta-@hta AS VARCHAR), b.transdesc) = 0 THEN 1
							WHEN b.betteam = 'AOS'
								AND @bettype = 413
								AND CHARINDEX(CAST(@fth AS VARCHAR) + ':' + CAST(@fta AS VARCHAR), b.transdesc) = 0 THEN 1
							WHEN b.betteam = 'AOS'
								AND @bettype = 414
								AND CHARINDEX(CAST(@hth AS VARCHAR) + ':' + CAST(@hta AS VARCHAR), b.transdesc) = 0 THEN 1
							WHEN bettype = 16 THEN CASE
														WHEN betteam = @result THEN 1
														ELSE -1
													END
							ELSE -1
							END,
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
							WHEN @modds >  0.25	THEN actual_stake + stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,14,15,16,30,127,165,166,1204,1235,1302,1317,405,413,414,448) then odds-1 else odds end) end)
							WHEN @modds =  0.25	THEN actual_stake + stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,14,15,16,30,127,165,166,1204,1235,1302,1317,405,413,414,448) then odds-1 else odds end) end) * 0.5
							WHEN @modds =  0	THEN actual_stake
							WHEN @modds = -0.25	THEN actual_stake * 0.5
							WHEN @modds < -0.25	THEN 0
							END,

						aWinLost = CASE
							WHEN @modds >  0.25	THEN stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,14,15,16,30,127,165,166,1204,1235,1302,1317,405,413,414,448) then odds-1 else odds end) end) * -apositiontaking
							WHEN @modds =  0.25	THEN stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,14,15,16,30,127,165,166,1204,1235,1302,1317,405,413,414,448) then odds-1 else odds end) end) * -apositiontaking * 0.5
							WHEN @modds =  0	THEN 0
							WHEN @modds = -0.25	THEN actual_stake * apositiontaking * 0.5
							WHEN @modds < -0.25	THEN actual_stake * apositiontaking
							END,
						mWinLost = CASE
							WHEN @modds >  0.25 	THEN stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,14,15,16,30,127,165,166,1204,1235,1302,1317,405,413,414,448) then odds-1 else odds end) end) * -mpositiontaking
							WHEN @modds =  0.25 	THEN stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,14,15,16,30,127,165,166,1204,1235,1302,1317,405,413,414,448) then odds-1 else odds end) end) * -mpositiontaking * 0.5
							WHEN @modds =  0    	THEN 0
							WHEN @modds = -0.25 	THEN actual_stake * mpositiontaking * 0.5
							WHEN @modds < -0.25 	THEN actual_stake * mpositiontaking
							END,
						sWinLost = CASE
							WHEN @modds >  0.25 	THEN stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,14,15,16,30,127,165,166,1204,1235,1302,1317,405,413,414,448) then odds-1 else odds end) end) * -spositiontaking
							WHEN @modds =  0.25 	THEN stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,14,15,16,30,127,165,166,1204,1235,1302,1317,405,413,414,448) then odds-1 else odds end) end) * -spositiontaking * 0.5
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
				FROM	@tmpBatch r
					INNER JOIN dbo.bettrans b --WITH (ROWLOCK, UPDLOCK)
						ON	r.BatchNo = @BatchNo
							AND r.custId = b.recommend
					CROSS APPLY (
						SELECT CASE
									WHEN r.CustId = @MinCustId AND transId < @TransIdOfMinCust THEN 0
									WHEN r.CustId = @MaxCustId AND transId > @TransIdOfMaxCust THEN 0
									WHEN b.transId BETWEEN @MinTransId AND @MaxTransId THEN 1 
									ELSE 0
								END AS IsCalculated
					)i
				WHERE	matchid=@matchid 
						AND bettype=@bettype 
						AND statusID NOT IN (101,102)
						AND i.IsCalculated = 1
						AND 1 = CASE 
									 WHEN @bettype <> 1317 THEN 1 
									 WHEN @bettype = 1317 AND @SelectedSet LIKE '%1%' AND BetID = 801 THEN 1
									 WHEN @bettype = 1317 AND @SelectedSet LIKE '%2%' AND BetID = 802 THEN 1
									 WHEN @bettype = 1317 AND @SelectedSet LIKE '%3%' AND BetID = 803 THEN 1
									 WHEN @bettype = 1317 AND @SelectedSet LIKE '%4%' AND BetID = 804 THEN 1
									 WHEN @bettype = 1317 AND @SelectedSet LIKE '%5%' AND BetID = 805 THEN 1
									 ELSE 0 
								END 

				SET @BatchNo = @BatchNo - 1

				WAITFOR DELAY '00:00:00:010'
			END
		END
	END
	ELSE -- DBTrans
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

		IF @IsSettleAbandonedMatchIBC = 1 OR @IsSettleAbandonedMatch = 1 OR @IsSettleAbandonedMatchBetFair = 1
		BEGIN
			WHILE (@BatchNo > 0)
			BEGIN
				SELECT	@MinCustId = MAX(MinCustId)
						,@MaxCustId = MAX(MaxCustId)
						,@MinTransId = MAX(MinTransId)
						,@MaxTransId = MAX(MaxTransId)
						,@TransIdOfMinCust = MAX(TransIdOfMinCust)
						,@TransIdOfMaxCust = MAX(TransIdOfMaxCust)
				FROM	@tmpBatch
				WHERE	BatchNo = @BatchNo

				UPDATE 	b
					SET @modds = CASE 
							WHEN (@bettype IN (14, 127) AND RIGHT(betteam, 1) IN ('0', '1' )  AND @correctscore <> '') THEN --just for betchoice FG and NG
								CASE WHEN (betteam = @correctscore OR betteam = @FGLG2)	THEN 1 ELSE -1 END
							WHEN betteam NOT IN ('0:4', '4:0') 
								AND @bettype = 30 
								AND (@hth > LEFT(betteam,1) OR @hta > RIGHT(betteam,1) ) THEN -1
							WHEN betteam NOT IN ('0:5', '5:0') 
								AND @bettype = 4 
								AND (@fth > LEFT(betteam,1) OR @fta > RIGHT(betteam,1) ) THEN -1
							WHEN betteam NOT IN ('AOS')
								AND @bettype = 405 --2H Correct Score
								AND ((@fth-@hth) > LEFT(betteam,1) OR (@fta-@hta) > RIGHT(betteam,1)) THEN -1
							WHEN betteam = 'AOS' --Any Other Scores
								AND @bettype = 405 --2H Correct Score
								AND CHARINDEX(CAST(@fth-@hth AS VARCHAR) + ':' + CAST(@fta-@hta AS VARCHAR), transdesc) = 0 THEN 1

							WHEN betteam NOT IN ('AOS')
								AND @bettype = 413 --2H Correct Score
								AND (@fth > LEFT(betteam,1) OR @fta > RIGHT(betteam,1)) THEN -1
							WHEN betteam = 'AOS'
								AND @bettype = 413
								AND CHARINDEX(CAST(@fth AS VARCHAR) + ':' + CAST(@fta AS VARCHAR), transdesc) = 0 THEN 1

							WHEN betteam NOT IN ('AOS')
								AND @bettype = 414 --2H Correct Score
								AND (@hth > LEFT(betteam,1) OR @hta > RIGHT(betteam,1)) THEN -1
							WHEN betteam = 'AOS'
								AND @bettype = 414
								AND CHARINDEX(CAST(@hth AS VARCHAR) + ':' + CAST(@hta AS VARCHAR), transdesc) = 0 THEN 1
							WHEN @bettype = 16 THEN CASE
														WHEN @IsHTCal = 1 THEN CASE
																					WHEN @hth > @hta AND LEFT(betteam,1) IN ('0','2') THEN -1
																					WHEN @hth = @hta AND LEFT(betteam,1) IN ('1','2') THEN -1
																					WHEN @hth < @hta AND LEFT(betteam,1) IN ('0','1') THEN -1
																					ELSE NULL
																			   END
														ELSE NULL
													 END
					
							WHEN @bettype = 448 THEN CASE WHEN (@fth + @fta > 0) AND betteam = 'NG' THEN -1 ELSE NULL END
					
							--WHEN bettype IN (14,127) AND 
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
							WHEN @modds > 0.25 THEN actual_stake + stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (4, 5, 6, 14, 15, 16, 30, 127,165,166, 1204, 1235,1302,1317,405,413,414,448) THEN odds - 1 ELSE odds END	) END )
							WHEN @modds = 0.25 THEN actual_stake + stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (4, 5, 6, 14, 15, 16, 30, 127,165,166, 1204, 1235,1302,1317,405,413,414,448) THEN odds - 1 ELSE odds END	) END ) * 0.5
							WHEN @modds = 0 THEN actual_stake WHEN @modds = - 0.25 THEN actual_stake * 0.5
							WHEN @modds < - 0.25 THEN 0
							WHEN @modds IS NULL THEN winlost
							END
						,aWinLost = CASE 
							WHEN @modds > 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (4, 5, 6, 14, 15, 16, 30, 127,165,166, 1204, 1235,1302,1317,405,413,414,448) THEN odds - 1 ELSE odds END ) END ) * - apositiontaking
							WHEN @modds = 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (4, 5, 6, 14, 15, 16, 30, 127,165,166, 1204, 1235,1302,1317,405,413,414,448) THEN odds - 1 ELSE odds END ) END ) * - apositiontaking * 0.5
							WHEN @modds = 0 THEN 0
							WHEN @modds = - 0.25 THEN actual_stake * apositiontaking * 0.5
							WHEN @modds < - 0.25 THEN actual_stake * apositiontaking
							WHEN @modds IS NULL THEN awinlost
							END
						,mWinLost = CASE 
							WHEN @modds > 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (4, 5, 6, 14, 15, 16, 30,127,165,166, 1204, 1235,1302,1317,405,413,414,448) THEN odds - 1 ELSE odds END ) END ) * - mpositiontaking
							WHEN @modds = 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (4, 5, 6, 14, 15, 16, 30, 127,165,166, 1204, 1235,1302,1317,405,413,414,448) THEN odds - 1 ELSE odds END ) END ) * - mpositiontaking * 0.5
							WHEN @modds = 0 THEN 0
							WHEN @modds = - 0.25 THEN actual_stake * mpositiontaking * 0.5
							WHEN @modds < - 0.25 THEN actual_stake * mpositiontaking
							WHEN @modds IS NULL THEN mwinlost
							END
						,sWinLost = CASE 
							WHEN @modds > 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (4, 5, 6, 14, 15, 16, 30, 127,165,166, 1204, 1235,1302,1317,405,413,414,448) THEN odds - 1 ELSE odds END ) END ) * - spositiontaking
							WHEN @modds = 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (4, 5, 6, 14, 15, 16, 30, 127,165,166, 1204, 1235,1302,1317,405,413,414,448) THEN odds - 1 ELSE odds END ) END ) * - spositiontaking * 0.5
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
						,ruben = CASE when @modds IS NULL THEN ruben
									ELSE 1
								 END
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
				WHERE	b.matchid = @matchid 
						AND b.bettype = @bettype 
						AND	b.statusID NOT IN (101, 102)
						AND i.IsCalculated = 1
						AND 1 = CASE WHEN @IsSettleAbandonedMatch = 1 AND (b.custid IN (50057, 879241, 103873, 78761, 851668, 878902) OR b.recommend = 1688156) THEN 1
									 WHEN @IsSettleAbandonedMatchBetFair = 1 AND b.custid IN (2331, 1077687, 115770, 15523642) THEN 1
									 WHEN @IsSettleAbandonedMatchIBC = 1 AND (b.custid NOT IN (50057, 879241, 103873, 78761, 851668, 878902, 2331, 1077687, 115770, 15523642) AND b.recommend <> 1688156) THEN 1							
									 ELSE 0
								END

				SET @BatchNo = @BatchNo - 1
				
				WAITFOR DELAY '00:00:00:010'
			END
		END
		ELSE
		BEGIN
			SET @result = CASE @bettype 
							WHEN 16 THEN CASE
											WHEN @hth > @hta THEN '1:' + CASE
																			WHEN @fth > @fta THEN '1'
																			WHEN @fth = @fta THEN '0'
																			WHEN @fth < @fta THEN '2'
																			ELSE NULL
																		END
											WHEN @hth = @hta THEN '0:' + CASE
																			WHEN @fth > @fta THEN '1'
																			WHEN @fth = @fta THEN '0'
																			WHEN @fth < @fta THEN '2'
																			ELSE NULL
																		END
											WHEN @hth < @hta THEN '2:' + CASE
																			WHEN @fth > @fta THEN '1'
																			WHEN @fth = @fta THEN '0'
																			WHEN @fth < @fta THEN '2'
																			ELSE NULL
																		END
									END
							ELSE NULL
						END
					
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

				UPDATE  b
					SET 
						@correctscore	= CASE  WHEN bettype = 1317 AND @SelectedSet LIKE '%1%' AND BetID = 801 THEN @CorrectScoreSet1
												WHEN bettype = 1317 AND @SelectedSet LIKE '%2%' AND BetID = 802 THEN @CorrectScoreSet2
												WHEN bettype = 1317 AND @SelectedSet LIKE '%3%' AND BetID = 803 THEN @CorrectScoreSet3
												WHEN bettype = 1317 AND @SelectedSet LIKE '%4%' AND BetID = 804 THEN @CorrectScoreSet4
												WHEN bettype = 1317 AND @SelectedSet LIKE '%5%' AND BetID = 805 THEN @CorrectScoreSet5
												ELSE @correctscore END
						,@modds = CASE 
							--448:	Last Team To Score
							WHEN @bettype = 448 THEN CASE WHEN betteam = @FGLG2 THEN 1 ELSE -1 END
							WHEN (betteam = @correctscore OR betteam = @FGLG2 AND bettype <> 16) THEN 1
							WHEN betteam = '4:0' AND @goaldiff >= 4 AND @bettype = 30 THEN 1 -- 4UP for 1st Correct Score
							WHEN betteam = '0:4' AND @goaldiff <= - 4 AND @bettype = 30 THEN 1 -- 4UP for 1st Correct Score
							WHEN betteam = '5:0' AND @goaldiff >= 5 THEN 1
							WHEN betteam = '0:5' AND @goaldiff <= - 5 THEN 1
							WHEN betteam = 'AOS' --Any Other Scores
								AND @bettype = 405 --2H Correct Score
								AND CHARINDEX(CAST(@fth-@hth AS VARCHAR) + ':' + CAST(@fta-@hta AS VARCHAR), transdesc) = 0 THEN 1
							WHEN betteam = 'AOS'
								AND @bettype = 413
								AND CHARINDEX(CAST(@fth AS VARCHAR) + ':' + CAST(@fta AS VARCHAR), transdesc) = 0 THEN 1
							WHEN betteam = 'AOS'
								AND @bettype = 414
								AND CHARINDEX(CAST(@hth AS VARCHAR) + ':' + CAST(@hta AS VARCHAR), transdesc) = 0 THEN 1
							WHEN bettype = 16 THEN CASE
													WHEN betteam = @result THEN 1
													ELSE -1
												END
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
							WHEN @modds > 0.25 THEN actual_stake + stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (4, 5, 6, 14, 15, 16, 30, 127,165,166, 1204, 1235,1302,1317,405,413,414,448) THEN odds - 1 ELSE odds END	) END )
							WHEN @modds = 0.25 THEN actual_stake + stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (4, 5, 6, 14, 15, 16, 30, 127,165,166, 1204, 1235,1302,1317,405,413,414,448) THEN odds - 1 ELSE odds END	) END ) * 0.5
							WHEN @modds = 0 THEN actual_stake WHEN @modds = - 0.25 THEN actual_stake * 0.5
							WHEN @modds < - 0.25 THEN 0
							END
						,aWinLost = CASE 
							WHEN @modds > 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (4, 5, 6, 14, 15, 16, 30, 127, 1204, 1235,165,166,1302,1317,405,413,414,448) THEN odds - 1 ELSE odds END ) END ) * - apositiontaking
							WHEN @modds = 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (4, 5, 6, 14, 15, 16, 30, 127, 1204, 1235,165,166,1302,1317,405,413,414,448) THEN odds - 1 ELSE odds END ) END ) * - apositiontaking * 0.5
							WHEN @modds = 0 THEN 0
							WHEN @modds = - 0.25 THEN actual_stake * apositiontaking * 0.5
							WHEN @modds < - 0.25 THEN actual_stake * apositiontaking
							END
						,mWinLost = CASE 
							WHEN @modds > 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (4, 5, 6, 14, 15, 16, 30,127,165,166, 1204, 1235,1302,1317,405,413,414,448) THEN odds - 1 ELSE odds END ) END ) * - mpositiontaking
							WHEN @modds = 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (4, 5, 6, 14, 15, 16, 30, 127,165,166, 1204, 1235,1302,1317,405,413,414,448) THEN odds - 1 ELSE odds END ) END ) * - mpositiontaking * 0.5
							WHEN @modds = 0 THEN 0
							WHEN @modds = - 0.25 THEN actual_stake * mpositiontaking * 0.5
							WHEN @modds < - 0.25 THEN actual_stake * mpositiontaking
							END
						,sWinLost = CASE 
							WHEN @modds > 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (4, 5, 6, 14, 15, 16, 30, 127,165,166, 1204, 1235,1302,1317,405,413,414,448) THEN odds - 1 ELSE odds END ) END ) * - spositiontaking
							WHEN @modds = 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (4, 5, 6, 14, 15, 16, 30, 127,165,166, 1204, 1235,1302,1317,405,413,414,448) THEN odds - 1 ELSE odds END ) END ) * - spositiontaking * 0.5
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
					INNER JOIN dbo.bettrans b -- WITH (ROWLOCK, UPDLOCK)
						ON 	c.batchNo = @batchNo
							AND c.custid = b.custId
					CROSS APPLY (
						SELECT CASE
									WHEN c.CustId = @MinCustId AND b.transId < @TransIdOfMinCust THEN 0
									WHEN c.CustId = @MaxCustId AND b.transId > @TransIdOfMaxCust THEN 0
									WHEN b.transId BETWEEN @MinTransId AND @MaxTransId THEN 1 
									ELSE 0
								END As IsCalculated
					) i
				WHERE	matchid = @matchid 						
						AND bettype = @bettype						
						AND statusID NOT IN (101,102)
						AND i.IsCalculated = 1
						AND 1 = CASE 
										WHEN @bettype <> 1317  THEN 1 
										WHEN @bettype = 1317 AND @SelectedSet LIKE '%1%' AND BetID = 801 THEN 1
										WHEN @bettype = 1317 AND @SelectedSet LIKE '%2%' AND BetID = 802 THEN 1
										WHEN @bettype = 1317 AND @SelectedSet LIKE '%3%' AND BetID = 803 THEN 1
										WHEN @bettype = 1317 AND @SelectedSet LIKE '%4%' AND BetID = 804 THEN 1
										WHEN @bettype = 1317 AND @SelectedSet LIKE '%5%' AND BetID = 805 THEN 1
										ELSE 0 END
			
				SET @BatchNo = @BatchNo - 1
				
				WAITFOR DELAY '00:00:00:010'
			END
		END
	END

	RETURN
END
GO