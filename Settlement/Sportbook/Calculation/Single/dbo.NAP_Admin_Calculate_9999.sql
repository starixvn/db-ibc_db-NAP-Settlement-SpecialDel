/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
USE [bodb02]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_9999] 
    @matchid INT
    ,@bettype SMALLINT
    ,@fth    INT = NULL -- Fulltime of Home
    ,@fta    INT = NULL -- Fulltime of Away
    ,@hth    INT = NULL -- 1H of Home
    ,@hta    INT = NULL -- 1H of Away
    
    ,@totalht INT = 0
    ,@totalgoal_2H INT = 0
    
    ,@betcount INT = 0
    ,@IsSettleAbandonedMatchIBC BIT = 0 -- IBC
    ,@IsSettleAbandonedMatch BIT = 0 -- BetDaq
    ,@IsSettleAbandonedMatchBetFair BIT = 0 -- BetFair
    ,@IsHTCal BIT = 0
AS
/*
    Created by: Kathy
    Date: 20140618
    Task: Settlement for BetRadar [Redmine:#17142]
    DB: DBTXN.BODB02
    
    Revisions:
        - 20140729@Kathy: Add one more account(BF3) into BetFair's group [Redmine:#19665]
        - 20150413@Jamie: Settlement Betradar phase 2 [Redmine: #27212]
        - 20151210@Patrick: Database - Change datatype [Redmine: #48660]
        - 20160705@Kathy: PH-AIO phase 2 (67 bettypes ) [Redmine:#53154]
        - 20160830@Kathy: PH-AIO phase 2b [Redmine:#62861]
		- 20161118@Bobby: #67462 - Implement SDT for Over/Under bettypes full winlost
		- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
		- 20180705@Helen: applying batch by batch for settlement [Redmine:#97842]

        
*/
BEGIN
    SET NOCOUNT ON
    
    IF @betcount = 0 AND @@servername NOT LIKE N'DBIOM%' RETURN

    IF @@servername IN ('DB04', 'DB042', 'DB043', 'DB044') RETURN

    DECLARE @modds MONEY
        ,@commWinRate SMALLMONEY
        ,@commLostRate SMALLMONEY        
        ,@csFT NVARCHAR(10) -- FT correct score
        ,@csHT NVARCHAR(10) -- HT correct score
        ,@result NVARCHAR(10)
        ,@fth2H    INT 
        ,@fta2H    INT 
        ,@ExcludingHTChoice NVARCHAR(1000)
        ,@ExcludingFTChoice NVARCHAR(1000)
        ,@htbetteam NVARCHAR(10)
        ,@ftbetteam NVARCHAR(10)
    
    SELECT @fth2H = @fth - @hth
        ,@fta2H	= @fta - @hta
        ,@totalht = @hth + @hta
    
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
				
		IF @bettype NOT IN (133, 134, 140, 141, 142, 145, 146, 147, 148, 149, 150, 152, 189, 190, 416, 433, 434, 435, 436, 437, 438, 439, 440, 441, 442, 443, 444)
		BEGIN
			IF @IsSettleAbandonedMatchIBC = 0 AND @IsSettleAbandonedMatchBetFair = 0 AND @IsSettleAbandonedMatch = 0
			BEGIN
						
				SET @result = CASE @bettype 
							
							WHEN 456 THEN CASE 
											WHEN @hth > 0 AND @hta > 0 THEN CASE 
																				WHEN @hth > @hta THEN 'YH'
																				WHEN @hth < @hta THEN 'YA'
																				ELSE 'YD'
																			END
											ELSE CASE 
													WHEN @hth > @hta THEN 'NH'
													WHEN @hth < @hta THEN 'NA'
													ELSE 'ND'
												 END
									  END
	                                     
							 WHEN 457 THEN CASE
												WHEN @hth > 0 AND @hta > 0 THEN 'Y'
												ELSE 'N'            
										  END
	                                                                                      
							WHEN 452 THEN CASE
												WHEN @totalht > @totalgoal_2H THEN '1H'
												WHEN @totalht < @totalgoal_2H THEN '2H'
											END	

							WHEN 417 THEN CASE 
												WHEN @fth > 0 AND @fta > 0 THEN CASE 
																					WHEN @fth > @fta THEN 'YH'
																					WHEN @fth < @fta THEN 'YA'
																					ELSE 'YD'
																				END
												ELSE CASE 
														WHEN @fth > @fta THEN 'NH'
														WHEN @fth < @fta THEN 'NA'
														ELSE 'ND'
													 END
										  END
							WHEN 418 THEN CASE
												WHEN @fth > 0 AND @fta > 0 THEN 'Y'
												ELSE 'N'            
										  END
							WHEN 419 THEN CASE
												WHEN @hth + @hta > 0 THEN '1H'
												WHEN @fth + @fta - (@hth + @hta) > 0 THEN '2H'
												ELSE 'N'
										  END        
							WHEN 420 THEN CASE
												WHEN @hth > 0 THEN '1H'                
												WHEN @fth - @hth > 0 THEN '2H'
												ELSE 'N'
										  END
							WHEN 421 THEN CASE
												WHEN @hta > 0 THEN '1H'                
												WHEN @fta - @hta > 0 THEN '2H'
												ELSE 'N'
										  END
							WHEN 445 THEN CASE
												WHEN @hth > 0 AND @hta > 0 THEN CASE
																						WHEN (@fth - @hth) > 0 AND (@fta - @hta) > 0 THEN 'YY'
																						ELSE 'YN'
																				END
												ELSE CASE 
															WHEN (@fth - @hth) > 0 AND (@fta - @hta) > 0 THEN 'NY'
															ELSE 'NN'
													 END
										  END
							WHEN 446 THEN CASE
												WHEN @hth > 0 THEN CASE 
																		WHEN @fth - @hth > 0 THEN 'YY'
																		ELSE 'YN'
																   END
												ELSE CASE
															WHEN @fth - @hth > 0 THEN 'NY'
															ELSE 'NN'
													 END
										 END
							WHEN 447 THEN CASE
												WHEN @hta > 0 THEN CASE 
																		WHEN @fta - @hta > 0 THEN 'YY'
																		ELSE 'YN'
																   END
												ELSE CASE
															WHEN @fta - @hta > 0 THEN 'NY'
															ELSE 'NN'
													 END
										 END
						END
	            -- process batch by batch
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
						SET    @modds = CASE 
										WHEN bettype IN (417, 419, 420, 421, 445, 446, 447,456) THEN CASE
																									WHEN betteam = @result THEN 1
																									ELSE -1
																								 END
										WHEN bettype = 418 THEN CASE 
																	WHEN betteam = CASE 
																						WHEN @fth + @fta > hdp1 THEN @result + 'O'
																						WHEN @fth + @fta < hdp1 THEN @result + 'U'
																						ELSE NULL 
																						END THEN 1
																	ELSE -1
																END
		                                
										 --457: 1H Both Teams To Score / Total Goals
										WHEN bettype = 457 THEN CASE
																	WHEN betteam = CASE 
																						WHEN @hth + @hta > hdp1 THEN @result + 'O'
																						WHEN @hth + @hta < hdp1 THEN @result + 'U'
																						ELSE NULL 
																					END THEN 1
																	ELSE -1
																END
		                                                        
										--452: Highest Scoring Half (2 Way)
										WHEN bettype = 452 THEN CASE
																	WHEN @totalht = @totalgoal_2H THEN 0
																	WHEN betteam = @result THEN 1
																	ELSE -1
																END	
																                            
										ELSE - 1
									END
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
												WHEN bettype IN (417, 418, 419, 420, 421, 445, 446, 447,456,457,452) THEN odds - 1
												ELSE odds 
												END
										END
									)
								WHEN @modds = 0 THEN actual_stake
								WHEN @modds < 0 THEN 0
								END
							,aWinLost = CASE 
								WHEN @modds > 0 THEN stake * (CASE 
										WHEN odds < 0 THEN 1
										ELSE CASE 
												WHEN bettype IN (417, 418, 419, 420, 421, 445, 446, 447,456,457,452) THEN odds - 1
												ELSE odds
												END
										END
										) * - apositiontaking
								WHEN @modds = 0 THEN 0
								WHEN @modds < 0 THEN actual_stake * apositiontaking
								END
							,mWinLost = CASE 
								WHEN @modds > 0 THEN stake * (CASE 
										WHEN odds < 0 THEN 1
										ELSE CASE 
												WHEN bettype IN (417, 418, 419, 420, 421, 445, 446, 447,456,457,452) THEN odds - 1
												ELSE odds 
												END
										END
										) * - mpositiontaking
								WHEN @modds = 0 THEN 0
								WHEN @modds < 0 THEN actual_stake * mpositiontaking
								END
							,sWinLost = CASE 
								WHEN @modds > 0 THEN stake * (CASE 
										WHEN odds < 0 THEN 1
										ELSE CASE 
												WHEN bettype IN (417, 418, 419, 420, 421, 445, 446, 447,456,457,452) THEN odds - 1
												ELSE odds 
												END
										END
										) * - spositiontaking
								WHEN @modds = 0 THEN 0
								WHEN @modds < 0 THEN actual_stake * spositiontaking
								END
							,PlayerComm = CASE 
								WHEN @modds > 0 THEN @commWinRate * playerdiscount * stake
								WHEN @modds < 0 THEN @commLostRate * playerdiscount * stake
								WHEN @modds = 0 THEN 0
								END
							,Comm = CASE 
								WHEN @modds > 0 THEN @commWinRate * discount * stake * (1 - apositiontaking)
								WHEN @modds < 0 THEN @commLostRate * discount * stake * (1 - apositiontaking)
								WHEN @modds = 0 THEN 0
								END
							,aComm = CASE 
								WHEN @modds > 0 THEN @commWinRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking))
								WHEN @modds < 0 THEN @commLostRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking))
								WHEN @modds = 0 THEN 0
								END
							,sComm = CASE 
								WHEN @modds > 0 THEN @commWinRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
								WHEN @modds < 0 THEN @commLostRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
								WHEN @modds = 0 THEN 0
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
					
					WHERE    matchid = @matchid            
							AND bettype = @bettype  
							AND i.IsCalculated = 1  
							AND statusID NOT IN (101, 102)
							
					
					SET @BatchNo = @BatchNo - 1

					WAITFOR DELAY '00:00:00:010'
						
	             END
	                                
			END    
			ELSE
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
				
					UPDATE b
					SET @modds = CASE 
	                                
									--456: 1H Both Teams To Score / Result
									WHEN bettype = 456 THEN CASE
																WHEN LEFT(betteam,1) = 'N' THEN CASE
																									WHEN @hth > 0 AND @hta > 0 THEN -1
																									ELSE NULL
																								END
																ELSE NULL
															END
									--457: 1H Both Teams To Score / Total Goals
									WHEN bettype = 457 THEN CASE
																
																WHEN  LEFT(betteam,1) = 'N' AND @hth > 0 AND @hta > 0 THEN -1
																WHEN  RIGHT(betteam,1) = 'U' AND @hth + @hta > hdp1 THEN -1
																													
																WHEN betteam ='YO' AND @hth > 0 AND @hta > 0 AND @hth + @hta > hdp1 THEN 1
																										
																ELSE NULL
															END
																					
									--452: Highest Scoring Half (2 Way)
									WHEN bettype = 452 THEN CASE
																WHEN @IsHTCal = 1 THEN CASE
																							WHEN betteam = '1H' AND @totalht < @totalgoal_2H THEN -1
																							WHEN betteam = '2H' AND @totalht < @totalgoal_2H THEN 1
																							ELSE NULL
																						END	
																ELSE NULL
															  END  
																					
									WHEN bettype = 417 THEN CASE
																WHEN LEFT(betteam,1) = 'N' THEN CASE
																									WHEN @fth > 0 AND @fta > 0 THEN -1
																									WHEN @fth > @fta AND RIGHT(betteam,1) IN ('A','D') THEN -1
																									WHEN @fth < @fta AND RIGHT(betteam,1) IN ('H','D') THEN -1
																									ELSE NULL
																								END
																ELSE NULL
															END
									WHEN bettype = 418 THEN 
										CASE 
											/*WHEN @fth > 0 AND @fta > 0 THEN CASE
																				WHEN (LEFT(betteam,1) = 'N') THEN -1
																				WHEN (betteam = 'YU' AND (@fth + @fta) > hdp1) THEN -1
																				WHEN (betteam = 'YO' AND (@fth + @fta) > hdp1) THEN 1
																				ELSE NULL
																			END*/
											WHEN (@fth > 0 AND @fta > 0) THEN
												CASE 
													WHEN (@fth + @fta < hdp1) THEN
														CASE
															WHEN LEFT(betteam,1) = 'N' THEN -1
															ELSE NULL
														END
													WHEN (@fth + @fta > hdp1) THEN
														CASE
															WHEN betteam = 'YO' THEN 1
															WHEN betteam = 'YU' THEN -1
															WHEN betteam = 'NO' THEN -1
															WHEN betteam = 'NU' THEN -1
															ELSE NULL
														END
													ELSE NULL
												END
											WHEN (@fth > 0 OR @fta > 0) AND (@fth + @fta > hdp1) THEN 
												CASE
													WHEN RIGHT(betteam,1) = 'U' THEN -1
													ELSE NULL
												END
											ELSE NULL
										END
									WHEN bettype = 419 THEN CASE    
																WHEN @fth + @fta > 0 THEN CASE
																								WHEN betteam = '1H' AND @hth + @hta > 0 THEN 1
																								WHEN betteam = '2H' AND @hth + @hta = 0 THEN 1
																								ELSE -1
																						  END
																WHEN @IsHTCal = 1 AND @fth + @fta = 0 THEN CASE 
																										WHEN betteam = '1H' THEN -1
																										ELSE NULL
																									END                                                                                      
																ELSE NULL
															END
									WHEN bettype = 420 THEN CASE    
																WHEN @fth > 0 THEN CASE
																						WHEN betteam = '1H' AND @hth > 0 THEN 1
																						WHEN betteam = '2H' AND @hth = 0 THEN 1
																						ELSE -1
																					END
																WHEN @IsHTCal = 1 AND @fth = 0 THEN CASE 
																										WHEN betteam = '1H' THEN -1
																										ELSE NULL
																									END
	                                                    
																ELSE NULL
															END
									WHEN bettype = 421 THEN CASE    
																WHEN @fta > 0 THEN CASE
																						WHEN betteam = '1H' AND @hta > 0 THEN 1
																						WHEN betteam = '2H' AND @hta = 0 THEN 1
																						ELSE -1
																					END
																WHEN @IsHTCal = 1 AND @fta = 0 THEN CASE 
																										WHEN betteam = '1H' THEN -1
																										ELSE NULL
																									END
																ELSE NULL
															END
									WHEN bettype = 445 THEN    
										CASE @IsHTCal
										WHEN 0 THEN --abandoned 1H
											CASE 
												WHEN (@hth > 0 AND @hta > 0) THEN --both of teams have scored
													CASE
														WHEN LEFT(betteam,1) = 'N' THEN -1
														ELSE NULL
													END
												ELSE NULL
											END
										WHEN 1 THEN --abandoned 2H
											CASE 
												WHEN (@fth2H + @fta2H = 0 OR ((@fth2H + @fta2H) > 0 and (@fth2H = 0 OR @fta2H = 0) )) THEN  --not both teams haved score
													CASE 
														WHEN (@hth + @hta = 0 OR ((@hth + @hta) > 0 and (@hth = 0 OR @hta = 0) )) THEN
														CASE 
															WHEN betteam = 'YY' THEN -1
															WHEN betteam = 'YN' THEN -1
															ELSE NULL
														END
														WHEN (@hth > 0 AND @hta > 0) THEN
														CASE
															WHEN betteam = 'NY' THEN -1
															WHEN betteam = 'NN' THEN -1
															ELSE NULL
														END
														ELSE NULL
													END
												WHEN (@fth2H > 0 AND @fta2H > 0) THEN --both teams have scored
													CASE
														WHEN (@hth + @hta = 0 OR ((@hth + @hta) > 0 and (@hth = 0 OR @hta = 0) )) THEN
														CASE
															WHEN betteam = 'YY' THEN -1
															WHEN betteam = 'YN' THEN -1
															WHEN betteam = 'NY' THEN 1
															WHEN betteam = 'NN' THEN -1
															ELSE NULL
														END
														WHEN (@hth > 0 AND @hta > 0) THEN 
														CASE
															WHEN betteam = 'YY' THEN 1
															WHEN betteam = 'YN' THEN -1
															WHEN betteam = 'NY' THEN -1
															WHEN betteam = 'NN' THEN -1
															ELSE NULL
														END    
														ELSE NULL 
													END
												ELSE NULL 
	                                            
											END
										END
									WHEN bettype = 446 THEN    CASE 
																WHEN @IsHTCal = 0 AND @hth > 0 THEN CASE
																										WHEN LEFT(betteam,1) = 'N' THEN -1
																										ELSE NULL
																									END
																WHEN @IsHTCal = 1 AND @fth = 0 THEN CASE
																										WHEN LEFT(betteam,1) = 'Y' THEN -1
																										ELSE NULL
																									END
																WHEN @IsHTCal = 1 AND @fth > 0 THEN CASE
																										WHEN @hth = 0 THEN CASE
																																WHEN LEFT(betteam,1) = 'Y' THEN -1
																																WHEN betteam = 'NN' THEN -1
																																WHEN betteam = 'NY' THEN 1
																																ELSE NULL
																															END
																										WHEN @fth = @hth THEN CASE
																																	WHEN LEFT(betteam,1) = 'N' THEN -1
																																	ELSE NULL
																															  END
																										WHEN @hth > 0 AND @fth - @hth > 0 THEN CASE
																																						WHEN betteam = 'YY' THEN 1
																																						ELSE -1
																																				  END
																									END
																ELSE NULL
															END
									WHEN bettype = 447 THEN    CASE 
																WHEN @IsHTCal = 0 AND @hta > 0 THEN CASE
																										WHEN LEFT(betteam,1) = 'N' THEN -1
																										ELSE NULL
																									END
																WHEN @IsHTCal = 1 AND @fta = 0 THEN CASE
																										WHEN LEFT(betteam,1) = 'Y' THEN -1
																										ELSE NULL
																									END
																WHEN @IsHTCal = 1 AND @fta > 0 THEN CASE
																										WHEN @hta = 0 THEN CASE
																																WHEN LEFT(betteam,1) = 'Y' THEN -1
																																WHEN betteam = 'NN' THEN -1
																																WHEN betteam = 'NY' THEN 1
																																ELSE NULL
																															END
																										WHEN @fta = @hta THEN CASE
																																	WHEN LEFT(betteam,1) = 'N' THEN -1
																																	ELSE NULL
																															  END
																										WHEN @hta > 0 AND @fta - @hta > 0 THEN CASE
																																						WHEN betteam = 'YY' THEN 1
																																						ELSE -1
																																				  END
																									END
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
											WHEN bettype IN (417,418,419,420,421,445,446,447,456,452,457) THEN odds - 1
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
											WHEN bettype IN (417,418,419,420,421,445,446,447,456,452,457) THEN odds - 1
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
											WHEN bettype IN (417,418,419,420,421,445,446,447,456,452,457) THEN odds - 1
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
											WHEN bettype IN (417,418,419,420,421,445,446,447,456,452,457) THEN odds - 1
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
								
				WHERE   matchid = @matchid    
						AND bettype = @bettype
						AND statusID NOT IN (101, 102)
						AND i.IsCalculated = 1
						AND 1 = CASE 
									WHEN @IsSettleAbandonedMatch = 1 AND (b.custid IN (50057, 879241, 103873, 78761, 851668, 878902) OR recommend = 1688156) THEN 1
									WHEN @IsSettleAbandonedMatchBetFair = 1 AND b.custid IN (2331, 1077687, 115770, 15523642) THEN 1
									WHEN @IsSettleAbandonedMatchIBC = 1 AND (b.custid NOT IN (50057, 879241, 103873, 78761, 851668, 878902, 2331, 1077687, 115770, 15523642) AND recommend <> 1688156) THEN 1
									ELSE 0
								END
					
					SET @BatchNo = @BatchNo - 1

					WAITFOR DELAY '00:00:00:010'			
				END				
			END
		END
		ELSE
		BEGIN
			SELECT @csHT =  CASE WHEN @hth + @hta >= 4 THEN '4+' 
							 ELSE CAST(@hth AS nvarchar(10)) + ':' + CAST(@hta AS nvarchar(10))
						END
				  ,@csFT =  CASE WHEN @fth + @fta >=4 THEN '4+'
								 ELSE CAST(@fth AS nvarchar(10)) + ':' + CAST(@fta AS nvarchar(10))
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
				
				UPDATE b
					SET @ExcludingHTChoice = CASE WHEN bettype = 416 THEN SUBSTRING(transdesc,0, CHARINDEX('/',transdesc)) ELSE NULL END
						,@ExcludingFTChoice = CASE WHEN bettype = 416 THEN SUBSTRING(transdesc,CHARINDEX('/',transdesc)+1,LEN(transdesc)) ELSE NULL END
						,@htbetteam = CASE WHEN bettype = 416 THEN SUBSTRING(betteam,0,CHARINDEX('/',betteam)) ELSE NULL END
						,@ftbetteam = CASE WHEN bettype = 416 THEN SUBSTRING(betteam,CHARINDEX('/',betteam)+1, LEN(betteam)) ELSE NULL END
			            
						,@modds = CASE WHEN @IsSettleAbandonedMatch = 0 AND @IsSettleAbandonedMatchBetfair = 0 AND @IsSettleAbandonedMatchIBC = 0
												THEN CASE bettype
														WHEN 133 THEN -- Home To Win Both Halves
																	 CASE 
																		WHEN betteam = 'y' AND (@hth > @hta) AND ((@fth - @hth) > (@fta - @hta)) THEN 1
																		WHEN betteam = 'n' AND ((@hth <= @hta) OR ((@fth - @hth) <= (@fta - @hta))) THEN 1
																		ELSE -1
																	  END
														WHEN 134 THEN -- Away To Win Both Halves
																	 CASE 
																		WHEN betteam = 'y' AND (@hta > @hth) AND ((@fta - @hta) > (@fth - @hth)) THEN 1
																		WHEN betteam = 'n' AND ((@hta <=@hth) OR ((@fta - @hta) <= (@fth - @hth))) THEN 1
																		ELSE -1
																	  END        
														WHEN 140 THEN -- Highest Scoring Half
																	 CASE 
																		WHEN betteam = '1h' AND (@hth + @hta) > (@fth - @hth + @fta - @hta) THEN 1
																		WHEN betteam = 'tie' AND (@hth + @hta) = (@fth - @hth + @fta - @hta) THEN 1
																		WHEN betteam = '2h' AND (@hth + @hta) < (@fth - @hth + @fta - @hta) THEN 1
																		ELSE -1
																	 END        
														WHEN 141 THEN -- Highest Scoring Half Home Team
																	 CASE 
																		WHEN betteam = '1h' AND @hth > (@fth - @hth) THEN 1
																		WHEN betteam = 'tie' AND @hth = (@fth - @hth) THEN 1
																		WHEN betteam = '2h' AND @hth < (@fth - @hth) THEN 1
																		ELSE -1
																	 END            
														WHEN 142 THEN -- Highest Scoring Half Away Team
																	 CASE 
																		WHEN betteam = '1h' AND @hta > (@fta - @hta) THEN 1
																		WHEN betteam = 'tie' AND @hta = (@fta - @hta) THEN 1
																		WHEN betteam = '2h' AND @hta < (@fta - @hta) THEN 1
																		ELSE -1
																	 END  
														WHEN 145 THEN -- Both Teams To Score
																	 CASE 
																		WHEN betteam = 'y' AND (@fth > 0) AND (@fta > 0) THEN 1
																		WHEN betteam = 'n' AND ((@fth = 0) OR (@fta = 0)) THEN 1
																		ELSE -1
																	 END 
														WHEN 146 THEN -- 2nd Half Both Teams To Score
																	 CASE 
																		WHEN betteam = 'y' AND (@fth - @hth) > 0 AND (@fta - @hta) > 0 THEN 1
																		WHEN betteam = 'n' AND ((@fth - @hth) = 0 OR (@fta - @hta) = 0) THEN 1
																		ELSE -1
																	 END
														WHEN 147 THEN -- Home To Score In Both Halves 
																	 CASE 
																		WHEN betteam = 'y' AND @hth > 0 AND (@fth - @hth) > 0 THEN 1
																		WHEN betteam = 'n' AND (@hth = 0 OR (@fth - @hth) = 0) THEN 1
																		ELSE -1
																	 END
														WHEN 148 THEN -- Away To Score In Both Halves 
																	 CASE 
																		WHEN betteam = 'y' AND @hta > 0 AND (@fta - @hta) > 0 THEN 1
																		WHEN betteam = 'n' AND (@hta = 0 OR (@fta - @hta) = 0) THEN 1
																		ELSE -1
																	 END
														WHEN 149 THEN -- Home To Win Either Half 
																	 CASE 
																		WHEN betteam = 'y' AND ((@hth > @hta) OR (@fth - @hth) > (@fta - @hta)) THEN 1
																		WHEN betteam = 'n' AND (@hth <= @hta) AND (@fth - @hth) <=(@fta - @hta) THEN 1
																		ELSE -1
																	 END
														WHEN 150 THEN -- Away To Win Either Half
																	 CASE 
																		WHEN betteam = 'y' AND ((@hta > @hth) OR (@fta - @hta) > (@fth - @hth)) THEN 1
																		WHEN betteam = 'n' AND (@hta <= @hth) AND (@fta - @hta) <= (@fth - @hth) THEN 1
																		ELSE -1
																	 END 
														WHEN 152 THEN -- Half Time/Full Time Correct Score
																	 CASE 
																		WHEN betteam = @csHT + '/' + @csFT THEN 1
																		ELSE -1
																	 END     
														WHEN 189 THEN -- Both Halves Over 1.5 Yes/No
																	CASE 
																		WHEN betteam ='y' AND (@hth + @hta - 1.5) > 0 AND (@fth + @fta - 1.5)>0 THEN 1  --ftscore save 2nd half score 
																		WHEN betteam ='n' AND ((@hth + @hta - 1.5) <=0 OR (@fth + @fta - 1.5)<=0) THEN 1 
																		ELSE -1 
																	END 
														WHEN 190 THEN -- Both Halves Under 1.5 Yes/No  [190]
																	CASE 
																		WHEN betteam ='y' AND (@hth + @hta - 1.5) < 0 AND (@fth + @fta - 1.5)<0 THEN 1  --ftscore save 2nd half score 
																		WHEN betteam ='n' AND ((@hth + @hta - 1.5) >=0 OR (@fth + @fta - 1.5)>=0) THEN 1 
																		ELSE -1 
																	END        
														WHEN 416 THEN -- Half Time/Full Time Correct Score (own)
																	CASE 
																		WHEN CHARINDEX('AOS',betteam) = 0 THEN CASE
																													WHEN betteam = CAST(@hth AS NVARCHAR(10)) + ':' + CAST(@hta AS NVARCHAR(10)) + '/' + CAST(@fth AS NVARCHAR(10)) + ':' + CAST(@fta AS NVARCHAR(10)) THEN 1
																													ELSE -1
																												END
																		WHEN CHARINDEX('AOS/AOS',betteam) > 0 THEN CASE
																														WHEN CHARINDEX(CAST(@hth AS NVARCHAR(10)) + ':' + CAST(@hta AS NVARCHAR(10)),@ExcludingHTChoice) = 0 AND CHARINDEX(CAST(@fth AS NVARCHAR(10)) + ':' + CAST(@fta AS NVARCHAR(10)),@ExcludingFTChoice) = 0 THEN 1
																														ELSE -1
																													END
																		WHEN CHARINDEX('/AOS',betteam) > 0 THEN CASE
																													WHEN betteam = CAST(@hth AS NVARCHAR(10)) + ':' + CAST(@hta AS NVARCHAR(10)) + '/AOS' AND CHARINDEX(CAST(@fth AS NVARCHAR(10)) + ':' + CAST(@fta AS NVARCHAR(10)),@ExcludingFTChoice) = 0 THEN 1
																													ELSE -1
																												END
																		WHEN CHARINDEX('AOS/',betteam) > 0 THEN CASE
																													WHEN betteam = 'AOS/' + CAST(@fth AS NVARCHAR(10)) + ':' + CAST(@fta AS NVARCHAR(10)) AND CHARINDEX(CAST(@hth AS NVARCHAR(10)) + ':' + CAST(@hta AS NVARCHAR(10)),@ExcludingHTChoice) = 0 THEN 1
																													ELSE -1
																												END
																		ELSE -1
																	END
														WHEN 433 THEN -- 2H Both Teams To Score (own)
																	 CASE 
																		WHEN betteam = 'y' AND (@fth - @hth) > 0 AND (@fta - @hta) > 0 THEN 1
																		WHEN betteam = 'n' AND ((@fth - @hth) = 0 OR (@fta - @hta) = 0) THEN 1
																		ELSE -1
																	 END 
														WHEN 434 THEN -- Both Halves Over 1.5 Yes/No (own)
																	CASE 
																		WHEN betteam ='y' AND (@hth + @hta - 1.5) > 0 AND (@fth + @fta - 1.5)>0 THEN 1  --ftscore save 2nd half score 
																		WHEN betteam ='n' AND ((@hth + @hta - 1.5) <=0 OR (@fth + @fta - 1.5)<=0) THEN 1 
																		ELSE -1 
																	END     
														WHEN 435 THEN -- Both Halves Under 1.5 Yes/No (own)
																	CASE 
																		WHEN betteam ='y' AND (@hth + @hta - 1.5) < 0 AND (@fth + @fta - 1.5)<0 THEN 1  --ftscore save 2nd half score 
																		WHEN betteam ='n' AND ((@hth + @hta - 1.5) >=0 OR (@fth + @fta - 1.5)>=0) THEN 1 
																		ELSE -1 
																	END            
														WHEN 436 THEN -- Home To Score In Both Halves (own)
																	 CASE 
																		WHEN betteam = 'y' AND @hth > 0 AND (@fth - @hth) > 0 THEN 1
																		WHEN betteam = 'n' AND (@hth = 0 OR (@fth - @hth) = 0) THEN 1
																		ELSE -1
																	 END    
														WHEN 437 THEN -- Away To Score In Both Halves (own)
																	 CASE 
																		WHEN betteam = 'y' AND @hta > 0 AND (@fta - @hta) > 0 THEN 1
																		WHEN betteam = 'n' AND (@hta = 0 OR (@fta - @hta) = 0) THEN 1
																		ELSE -1
																	 END
														WHEN 438 THEN -- Home To Win Both Halves (own)
																	 CASE 
																		WHEN betteam = 'y' AND (@hth > @hta) AND ((@fth - @hth) > (@fta - @hta)) THEN 1
																		WHEN betteam = 'n' AND ((@hth <= @hta) OR ((@fth - @hth) <= (@fta - @hta))) THEN 1
																		ELSE -1
																	  END    
														WHEN 439 THEN -- Away To Win Both Halves (own)
																	 CASE 
																		WHEN betteam = 'y' AND (@hta > @hth) AND ((@fta - @hta) > (@fth - @hth)) THEN 1
																		WHEN betteam = 'n' AND ((@hta <=@hth) OR ((@fta - @hta) <= (@fth - @hth))) THEN 1
																		ELSE -1
																	  END    
														WHEN 440 THEN -- Home To Win Either Half (own)
																	 CASE 
																		WHEN betteam = 'y' AND ((@hth > @hta) OR (@fth - @hth) > (@fta - @hta)) THEN 1
																		WHEN betteam = 'n' AND (@hth <= @hta) AND (@fth - @hth) <=(@fta - @hta) THEN 1
																		ELSE -1
																	 END    
														WHEN 441 THEN -- Away To Win Either Half (own)
																	 CASE 
																		WHEN betteam = 'y' AND ((@hta > @hth) OR (@fta - @hta) > (@fth - @hth)) THEN 1
																		WHEN betteam = 'n' AND (@hta <= @hth) AND (@fta - @hta) <= (@fth - @hth) THEN 1
																		ELSE -1
																	 END         
														WHEN 442 THEN -- Highest Scoring Half (own)
																	 CASE 
																		WHEN betteam = '1h' AND (@hth + @hta) > (@fth - @hth + @fta - @hta) THEN 1
																		WHEN betteam = 'tie' AND (@hth + @hta) = (@fth - @hth + @fta - @hta) THEN 1
																		WHEN betteam = '2h' AND (@hth + @hta) < (@fth - @hth + @fta - @hta) THEN 1
																		ELSE -1
																	 END    
														WHEN 443 THEN -- Highest Scoring Half Home Team (own)
																	 CASE 
																		WHEN betteam = '1h' AND @hth > (@fth - @hth) THEN 1
																		WHEN betteam = 'tie' AND @hth = (@fth - @hth) THEN 1
																		WHEN betteam = '2h' AND @hth < (@fth - @hth) THEN 1
																		ELSE -1
																	 END
														WHEN 444 THEN -- Highest Scoring Half Away Team (own)
																	 CASE 
																		WHEN betteam = '1h' AND @hta > (@fta - @hta) THEN 1
																		WHEN betteam = 'tie' AND @hta = (@fta - @hta) THEN 1
																		WHEN betteam = '2h' AND @hta < (@fta - @hta) THEN 1
																		ELSE -1
																	 END                                                                                                                                                                                       
													 END                                            
											WHEN @IsSettleAbandonedMatch = 1 OR @IsSettleAbandonedMatchBetfair = 1 OR @IsSettleAbandonedMatchIBC = 1 
												THEN CASE bettype
														WHEN 133 THEN
																	 CASE 
																		WHEN betteam = 'y' AND @hth <= @hta THEN -1
																		WHEN betteam = 'n' AND @hth <= @hta THEN 1
																	 END
														WHEN 134 THEN
																	 CASE
																		WHEN betteam = 'y' AND @hta <= @hth THEN -1
																		WHEN betteam = 'n' AND @hta <= @hth THEN 1
																	 END
														WHEN 140 THEN 
															CASE @IsHTCal
																WHEN 0 THEN NULL --abandoned 1H
																WHEN 1 THEN --abandoned 2H
																CASE betteam
																	WHEN '1h' THEN
																		CASE 
																			WHEN ((@hth + @hta >= 0) AND ((@hth + @hta) < (@fth2H + @fta2H))) THEN -1
																			WHEN ((@hth + @hta >= 0) AND ((@hth + @hta) = (@fth2H + @fta2H))) THEN -1
																			ELSE NULL
																		END
																	WHEN '2h' THEN
																		CASE 
																			WHEN ((@hth + @hta >= 0) AND ((@hth + @hta) < (@fth2H + @fta2H))) THEN 1
																			ELSE NULL
																		END
																	WHEN 'tie' THEN
																		CASE 
																			WHEN ((@hth + @hta >= 0) AND ((@hth + @hta) < (@fth2H + @fta2H))) THEN -1
																			ELSE NULL
																		END
																	ELSE NULL
																END
															END
														WHEN 141 THEN
															CASE @IsHTCal
																WHEN 0 THEN NULL --abandoned 1H
																WHEN 1 THEN --abandoned 2H
																CASE betteam
																	WHEN '1h' THEN
																		CASE 
																			WHEN (@hth >= 0 AND @fth2H > @hth) THEN -1
																			WHEN (@hth >= 0 AND @fth2H = @hth) THEN -1
																			ELSE NULL
																		END
																	WHEN '2h' THEN
																		CASE 
																			WHEN (@hth >= 0 AND @fth2H > @hth) THEN 1
																			ELSE NULL
																		END
																	WHEN 'tie' THEN
																		CASE 
																			WHEN (@hth >= 0 AND @fth2H > @hth) THEN -1
																			ELSE NULL
																		END
																	ELSE NULL
																END
															END
														WHEN 142 THEN
															CASE @IsHTCal
																WHEN 0 THEN NULL --abandoned 1H
																WHEN 1 THEN --abandoned 2H
																CASE betteam
																	WHEN '1h' THEN
																		CASE 
																			WHEN (@hta >= 0 AND @fta2H > @hta ) THEN -1
																			WHEN (@hta >= 0 AND @fta2H = @hta ) THEN -1
																			ELSE NULL
																		END
																	WHEN '2h' THEN
																		CASE 
																			WHEN (@hta >= 0 AND @fta2H > @hta ) THEN 1
																			ELSE NULL
																		END
																	WHEN 'tie' THEN
																		CASE 
																			WHEN (@hta >= 0 AND @fta2H > @hta ) THEN -1
																			ELSE NULL
																		END
																	ELSE NULL
																END
															END
														WHEN 145 THEN 
																	 CASE 
																		WHEN @IsHTCal = 0 THEN -- suspended in 1st half
																								CASE  
																									WHEN betteam = 'y' AND @hth > 0 AND @hta > 0 THEN 1
																									WHEN betteam = 'n' AND @hth > 0 AND @hta > 0 THEN -1
																								END
																		ELSE CASE 
																				WHEN betteam = 'y' AND @fth > 0 AND @fta > 0 THEN 1
																				WHEN betteam = 'n' AND @fth > 0 AND @fta > 0 THEN -1
																			END
																	 END 
														WHEN 146 THEN 
																	 CASE 
																		WHEN betteam = 'y' AND (@fth - @hth) > 0 AND (@fta - @hta) > 0 THEN 1
																		WHEN betteam = 'n' AND (@fth - @hth) > 0 AND (@fta - @hta) > 0 THEN -1
																	 END
														WHEN 147 THEN 
																	 CASE 
																		WHEN betteam = 'y' AND @hth = 0 THEN -1
																		WHEN betteam = 'n' AND @hth = 0 THEN 1
																		WHEN betteam = 'y' AND @hth > 0 and (@fth - @hth) > 0 THEN 1
																		WHEN betteam = 'n' AND @hth > 0 and (@fth - @hth) > 0 THEN -1
																	 END
														WHEN 148 THEN 
																	 CASE
																		WHEN betteam = 'y' AND @hta = 0 THEN -1
																		WHEN betteam = 'n' AND @hta = 0 THEN 1
																		WHEN betteam = 'y' AND @hta > 0 AND (@fta - @hta) > 0 THEN 1
																		WHEN betteam = 'n' AND @hta > 0 AND (@fta - @hta) > 0 THEN -1 
																	 END
														WHEN 149 THEN 
																	 CASE 
																		WHEN betteam = 'y' AND @hth > @hta THEN 1
																		WHEN betteam = 'n' AND @hth > @hta THEN -1
																	 END
														WHEN 150 THEN 
																	 CASE 
																		WHEN betteam = 'y' AND @hta > @hth THEN 1
																		WHEN betteam = 'n' AND @hta > @hth THEN -1
																	 END
														WHEN 152 THEN
																	 CASE 
																		WHEN @IsHTCal = 0 THEN CASE
																									WHEN LEFT(betteam,2) = '4+' AND (@hth + @hta) >= 4 THEN 1
																									WHEN LEFT(betteam,2) <> '4+' AND (LEFT(LEFT(betteam,3),1) < @hth OR RIGHT(LEFT(betteam,3),1) < @hta) THEN -1
																								END
																		ELSE CASE 
																				WHEN betteam = '4+/4+' AND (@hth + @hta) >= 4 AND (@fth + @fta) >= 4 THEN 1
																				WHEN LEFT(betteam,3) <> @csHT  THEN -1        
																				WHEN RIGHT(betteam,2) = '4+' AND (@fth + @fta) >= 4 THEN 1
																				WHEN RIGHT(betteam,2) <>'4+' AND (LEFT(RIGHT(betteam,3),1) < @fth OR RIGHT(RIGHT(betteam,3),1) < @fta) THEN -1                                                                                                                                                                                                
																			 END
																	END
														WHEN 416 THEN
																	CASE
																		WHEN @IsHTCal = 0 THEN CASE 
																									WHEN @htbetteam <> 'AOS' THEN CASE
																																	WHEN CAST(LEFT(@htbetteam,1) AS INT) < @hth OR CAST(RIGHT(@htbetteam,1) AS INT) < @hta THEN -1																							
																																  END
																									ELSE  CASE
																												WHEN @ftbetteam = 'AOS' THEN CASE WHEN @hth > 4 OR @hta > 4 THEN 1 END
																												WHEN LEFT(@ftbetteam,1) < @hth OR RIGHT(@ftbetteam,1) < @hta THEN -1
																										  END
																								END
																		ELSE CASE 
																				WHEN @htbetteam <> 'AOS' THEN CASE
																													WHEN CAST(LEFT(@htbetteam,1) AS INT) <> @hth OR CAST(RIGHT(@htbetteam,1) AS INT) <> @hta THEN -1
																													WHEN @ftbetteam <> 'AOS' THEN CASE WHEN LEFT(@ftbetteam,1) < @fth OR RIGHT(@ftbetteam,1) < @fta THEN -1 END
																													WHEN CAST(LEFT(@htbetteam,1) AS INT) = @hth AND CAST(RIGHT(@htbetteam,1) AS INT) = @hta AND CHARINDEX(CAST(@fth AS NVARCHAR(10)) + ':' + CAST(@fta AS NVARCHAR(10)),@ExcludingFTChoice) = 0 THEN 1
																											  END
																				ELSE CASE 
																							WHEN CHARINDEX(CAST(@hth AS NVARCHAR(10)) + ':' + CAST(@hta AS NVARCHAR(10)),@ExcludingHTChoice) > 0 THEN -1
																							WHEN @ftbetteam <> 'AOS' THEN CASE WHEN LEFT(@ftbetteam,1) < @fth OR RIGHT(@ftbetteam,1) < @fta THEN -1 END
																							WHEN CHARINDEX(CAST(@fth AS NVARCHAR(10)) + ':' + CAST(@fta AS NVARCHAR(10)),@ExcludingFTChoice) = 0 THEN 1
																					  END
																			END	
																	END
														WHEN 433 THEN 
																	 CASE 
																		WHEN betteam = 'y' AND (@fth - @hth) > 0 AND (@fta - @hta) > 0 THEN 1
																		WHEN betteam = 'n' AND (@fth - @hth) > 0 AND (@fta - @hta) > 0 THEN -1
																	 END
														WHEN 436 THEN 
																	 CASE 
																		WHEN betteam = 'y' AND @hth = 0 THEN -1
																		WHEN betteam = 'n' AND @hth = 0 THEN 1
																		WHEN betteam = 'y' AND @hth > 0 and (@fth - @hth) > 0 THEN 1
																		WHEN betteam = 'n' AND @hth > 0 and (@fth - @hth) > 0 THEN -1
																	 END
														WHEN 437 THEN 
																	 CASE
																		WHEN betteam = 'y' AND @hta = 0 THEN -1
																		WHEN betteam = 'n' AND @hta = 0 THEN 1
																		WHEN betteam = 'y' AND @hta > 0 AND (@fta - @hta) > 0 THEN 1
																		WHEN betteam = 'n' AND @hta > 0 AND (@fta - @hta) > 0 THEN -1 
																	 END    
														WHEN 438 THEN
																	 CASE 
																		WHEN betteam = 'y' AND @hth <= @hta THEN -1
																		WHEN betteam = 'n' AND @hth <= @hta THEN 1
																	 END    
														WHEN 439 THEN
																	 CASE
																		WHEN betteam = 'y' AND @hta <= @hth THEN -1
																		WHEN betteam = 'n' AND @hta <= @hth THEN 1
																	 END
														WHEN 440 THEN 
																	 CASE 
																		WHEN betteam = 'y' AND @hth > @hta THEN 1
																		WHEN betteam = 'n' AND @hth > @hta THEN -1
																	 END
														WHEN 441 THEN 
																	 CASE 
																		WHEN betteam = 'y' AND @hta > @hth THEN 1
																		WHEN betteam = 'n' AND @hta > @hth THEN -1
																	 END
														WHEN 442 THEN 
															CASE @IsHTCal
																WHEN 0 THEN NULL --abandoned 1H
																WHEN 1 THEN --abandoned 2H
																CASE betteam
																	WHEN '1h' THEN
																		CASE 
																			WHEN ((@hth + @hta >= 0) AND ((@hth + @hta) < (@fth2H + @fta2H))) THEN -1
																			WHEN ((@hth + @hta >= 0) AND ((@hth + @hta) = (@fth2H + @fta2H))) THEN -1
																			ELSE NULL
																		END
																	WHEN '2h' THEN
																		CASE 
																			WHEN ((@hth + @hta >= 0) AND ((@hth + @hta) < (@fth2H + @fta2H))) THEN 1
																			ELSE NULL
																		END
																	WHEN 'tie' THEN
																		CASE 
																			WHEN ((@hth + @hta >= 0) AND ((@hth + @hta) < (@fth2H + @fta2H))) THEN -1
																			ELSE NULL
																		END
																	ELSE NULL
																END
															END
														WHEN 443 THEN
															CASE @IsHTCal
																WHEN 0 THEN NULL --abandoned 1H
																WHEN 1 THEN --abandoned 2H
																CASE betteam
																	WHEN '1h' THEN
																		CASE 
																			WHEN (@hth >= 0 AND @fth2H > @hth) THEN -1
																			WHEN (@hth >= 0 AND @fth2H = @hth) THEN -1
																			ELSE NULL
																		END
																	WHEN '2h' THEN
																		CASE 
																			WHEN (@hth >= 0 AND @fth2H > @hth) THEN 1
																			ELSE NULL
																		END
																	WHEN 'tie' THEN
																		CASE 
																			WHEN (@hth >= 0 AND @fth2H > @hth) THEN -1
																			ELSE NULL
																		END
																	ELSE NULL
																END
															END
														WHEN 444 THEN 
															CASE @IsHTCal
																WHEN 0 THEN NULL --abandoned 1H
																WHEN 1 THEN --abandoned 2H
																CASE betteam
																	WHEN '1h' THEN
																		CASE 
																			WHEN (@hta >= 0 AND @fta2H > @hta ) THEN -1
																			WHEN (@hta >= 0 AND @fta2H = @hta ) THEN -1
																			ELSE NULL
																		END
																	WHEN '2h' THEN
																		CASE 
																			WHEN (@hta >= 0 AND @fta2H > @hta ) THEN 1
																			ELSE NULL
																		END
																	WHEN 'tie' THEN
																		CASE 
																			WHEN (@hta >= 0 AND @fta2H > @hta ) THEN -1
																			ELSE NULL
																		END
																	ELSE NULL
																END
															END
														--#67462-Implement SDT for over/under full WL
														WHEN 189 THEN 
															CASE 
																WHEN betteam = 'y' AND @hta + @hth < 1.5 THEN -1
																WHEN betteam = 'n' AND @hta + @hth < 1.5 THEN 1
																------
																WHEN betteam = 'y' AND @hta + @hth > 1.5 AND (@fth2H + @fta2H > 1.5) THEN 1
																WHEN betteam = 'n' AND @hta + @hth > 1.5 AND (@fth2H + @fta2H > 1.5) THEN -1
															END
														WHEN 190 THEN 
															CASE 
																WHEN betteam = 'y' AND @hta + @hth > 1.5 THEN -1
																WHEN betteam = 'n' AND @hta + @hth > 1.5 THEN 1
																------
																WHEN betteam = 'y' AND @hta + @hth < 1.5 AND (@fth2H + @fta2H > 1.5) THEN -1
																WHEN betteam = 'n' AND @hta + @hth < 1.5 AND (@fth2H + @fta2H > 1.5) THEN 1
															END
														WHEN 434 THEN 
															CASE 
																WHEN betteam = 'y' AND @hta + @hth < 1.5 THEN -1
																WHEN betteam = 'n' AND @hta + @hth < 1.5 THEN 1
																------
																WHEN betteam = 'y' AND @hta + @hth > 1.5 AND (@fth2H + @fta2H > 1.5) THEN 1
																WHEN betteam = 'n' AND @hta + @hth > 1.5 AND (@fth2H + @fta2H > 1.5) THEN -1
															END
														WHEN 435 THEN 
															CASE 
																WHEN betteam = 'y' AND @hta + @hth > 1.5 THEN -1
																WHEN betteam = 'n' AND @hta + @hth > 1.5 THEN 1
																------
																WHEN betteam = 'y' AND @hta + @hth < 1.5 AND (@fth2H + @fta2H > 1.5) THEN -1
																WHEN betteam = 'n' AND @hta + @hth < 1.5 AND (@fth2H + @fta2H > 1.5) THEN 1
															END
														--#67462
													 END 

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
											WHEN bettype IN (133, 134, 140, 141, 142, 145, 146, 147, 148, 149, 150, 152,189,190,416,433,434,435,436,437,438,439,440,441,442,443,444) THEN odds - 1
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
											WHEN bettype IN (133, 134, 140, 141, 142, 145, 146, 147, 148, 149, 150, 152,189,190,416,433,434,435,436,437,438,439,440,441,442,443,444) THEN odds - 1
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
											WHEN bettype IN (133, 134, 140, 141, 142, 145, 146, 147, 148, 149, 150, 152,189,190,416,433,434,435,436,437,438,439,440,441,442,443,444) THEN odds - 1
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
											WHEN bettype IN (133, 134, 140, 141, 142, 145, 146, 147, 148, 149, 150, 152,189,190,416,433,434,435,436,437,438,439,440,441,442,443,444) THEN odds - 1
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
						,ruben = CASE WHEN @modds IS NOT NULL THEN 1 ELSE ruben END
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
					
				WHERE matchid = @matchid 
					AND bettype = @bettype 
					AND statusID NOT IN (101, 102) -- reject, void
					AND i.IsCalculated = 1
					AND 1 = CASE WHEN @IsSettleAbandonedMatch = 0 AND @IsSettleAbandonedMatchBetFair = 0 AND @IsSettleAbandonedMatchIBC = 0 THEN 1
								 WHEN (
										(@IsSettleAbandonedMatch = 1 AND (b.custid IN (50057, 879241, 103873, 78761, 851668, 878902) OR recommend = 1688156))
										OR (@IsSettleAbandonedMatchBetFair = 1 AND b.custid IN (2331, 1077687, 115770, 15523642))
										OR (@IsSettleAbandonedMatchIBC = 1 AND (b.custid NOT IN (50057, 879241, 103873, 78761, 851668, 878902, 2331, 1077687, 115770, 15523642) AND recommend <> 1688156))
									) THEN 1                       
								 ELSE 0
							END 
				
				SET @BatchNo = @BatchNo - 1

				WAITFOR DELAY '00:00:00:010'
						
			END		
		END
	END
	ELSE -- DBTRANS
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
		
		IF @bettype NOT IN (133, 134, 140, 141, 142, 145, 146, 147, 148, 149, 150, 152, 189, 190, 416, 433, 434, 435, 436, 437, 438, 439, 440, 441, 442, 443, 444)
		BEGIN
			IF @IsSettleAbandonedMatchIBC = 0 AND @IsSettleAbandonedMatchBetFair = 0 AND @IsSettleAbandonedMatch = 0
			BEGIN
						
				SET @result = CASE @bettype 
							
							WHEN 456 THEN CASE 
											WHEN @hth > 0 AND @hta > 0 THEN CASE 
																				WHEN @hth > @hta THEN 'YH'
																				WHEN @hth < @hta THEN 'YA'
																				ELSE 'YD'
																			END
											ELSE CASE 
													WHEN @hth > @hta THEN 'NH'
													WHEN @hth < @hta THEN 'NA'
													ELSE 'ND'
												 END
									  END
	                                     
							 WHEN 457 THEN CASE
												WHEN @hth > 0 AND @hta > 0 THEN 'Y'
												ELSE 'N'            
										  END
	                                                                                      
							WHEN 452 THEN CASE
												WHEN @totalht > @totalgoal_2H THEN '1H'
												WHEN @totalht < @totalgoal_2H THEN '2H'
											END	

							WHEN 417 THEN CASE 
												WHEN @fth > 0 AND @fta > 0 THEN CASE 
																					WHEN @fth > @fta THEN 'YH'
																					WHEN @fth < @fta THEN 'YA'
																					ELSE 'YD'
																				END
												ELSE CASE 
														WHEN @fth > @fta THEN 'NH'
														WHEN @fth < @fta THEN 'NA'
														ELSE 'ND'
													 END
										  END
							WHEN 418 THEN CASE
												WHEN @fth > 0 AND @fta > 0 THEN 'Y'
												ELSE 'N'            
										  END
							WHEN 419 THEN CASE
												WHEN @hth + @hta > 0 THEN '1H'
												WHEN @fth + @fta - (@hth + @hta) > 0 THEN '2H'
												ELSE 'N'
										  END        
							WHEN 420 THEN CASE
												WHEN @hth > 0 THEN '1H'                
												WHEN @fth - @hth > 0 THEN '2H'
												ELSE 'N'
										  END
							WHEN 421 THEN CASE
												WHEN @hta > 0 THEN '1H'                
												WHEN @fta - @hta > 0 THEN '2H'
												ELSE 'N'
										  END
							WHEN 445 THEN CASE
												WHEN @hth > 0 AND @hta > 0 THEN CASE
																						WHEN (@fth - @hth) > 0 AND (@fta - @hta) > 0 THEN 'YY'
																						ELSE 'YN'
																				END
												ELSE CASE 
															WHEN (@fth - @hth) > 0 AND (@fta - @hta) > 0 THEN 'NY'
															ELSE 'NN'
													 END
										  END
							WHEN 446 THEN CASE
												WHEN @hth > 0 THEN CASE 
																		WHEN @fth - @hth > 0 THEN 'YY'
																		ELSE 'YN'
																   END
												ELSE CASE
															WHEN @fth - @hth > 0 THEN 'NY'
															ELSE 'NN'
													 END
										 END
							WHEN 447 THEN CASE
												WHEN @hta > 0 THEN CASE 
																		WHEN @fta - @hta > 0 THEN 'YY'
																		ELSE 'YN'
																   END
												ELSE CASE
															WHEN @fta - @hta > 0 THEN 'NY'
															ELSE 'NN'
													 END
										 END
						END
	            -- process batch by batch
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
						SET    @modds = CASE 
										WHEN bettype IN (417, 419, 420, 421, 445, 446, 447,456) THEN CASE
																									WHEN betteam = @result THEN 1
																									ELSE -1
																								 END
										WHEN bettype = 418 THEN CASE 
																	WHEN betteam = CASE 
																						WHEN @fth + @fta > hdp1 THEN @result + 'O'
																						WHEN @fth + @fta < hdp1 THEN @result + 'U'
																						ELSE NULL 
																						END THEN 1
																	ELSE -1
																END
		                                
										 --457: 1H Both Teams To Score / Total Goals
										WHEN bettype = 457 THEN CASE
																	WHEN betteam = CASE 
																						WHEN @hth + @hta > hdp1 THEN @result + 'O'
																						WHEN @hth + @hta < hdp1 THEN @result + 'U'
																						ELSE NULL 
																					END THEN 1
																	ELSE -1
																END
		                                                        
										--452: Highest Scoring Half (2 Way)
										WHEN bettype = 452 THEN CASE
																	WHEN @totalht = @totalgoal_2H THEN 0
																	WHEN betteam = @result THEN 1
																	ELSE -1
																END	
																                            
										ELSE - 1
									END
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
												WHEN bettype IN (417, 418, 419, 420, 421, 445, 446, 447,456,457,452) THEN odds - 1
												ELSE odds 
												END
										END
									)
								WHEN @modds = 0 THEN actual_stake
								WHEN @modds < 0 THEN 0
								END
							,aWinLost = CASE 
								WHEN @modds > 0 THEN stake * (CASE 
										WHEN odds < 0 THEN 1
										ELSE CASE 
												WHEN bettype IN (417, 418, 419, 420, 421, 445, 446, 447,456,457,452) THEN odds - 1
												ELSE odds
												END
										END
										) * - apositiontaking
								WHEN @modds = 0 THEN 0
								WHEN @modds < 0 THEN actual_stake * apositiontaking
								END
							,mWinLost = CASE 
								WHEN @modds > 0 THEN stake * (CASE 
										WHEN odds < 0 THEN 1
										ELSE CASE 
												WHEN bettype IN (417, 418, 419, 420, 421, 445, 446, 447,456,457,452) THEN odds - 1
												ELSE odds 
												END
										END
										) * - mpositiontaking
								WHEN @modds = 0 THEN 0
								WHEN @modds < 0 THEN actual_stake * mpositiontaking
								END
							,sWinLost = CASE 
								WHEN @modds > 0 THEN stake * (CASE 
										WHEN odds < 0 THEN 1
										ELSE CASE 
												WHEN bettype IN (417, 418, 419, 420, 421, 445, 446, 447,456,457,452) THEN odds - 1
												ELSE odds 
												END
										END
										) * - spositiontaking
								WHEN @modds = 0 THEN 0
								WHEN @modds < 0 THEN actual_stake * spositiontaking
								END
							,PlayerComm = CASE 
								WHEN @modds > 0 THEN @commWinRate * playerdiscount * stake
								WHEN @modds < 0 THEN @commLostRate * playerdiscount * stake
								WHEN @modds = 0 THEN 0
								END
							,Comm = CASE 
								WHEN @modds > 0 THEN @commWinRate * discount * stake * (1 - apositiontaking)
								WHEN @modds < 0 THEN @commLostRate * discount * stake * (1 - apositiontaking)
								WHEN @modds = 0 THEN 0
								END
							,aComm = CASE 
								WHEN @modds > 0 THEN @commWinRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking))
								WHEN @modds < 0 THEN @commLostRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking))
								WHEN @modds = 0 THEN 0
								END
							,sComm = CASE 
								WHEN @modds > 0 THEN @commWinRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
								WHEN @modds < 0 THEN @commLostRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
								WHEN @modds = 0 THEN 0
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
					WHERE    matchid = @matchid            
							AND bettype = @bettype  
							AND i.IsCalculated = 1  
							AND statusID NOT IN (101, 102)
					
					SET @BatchNo = @BatchNo - 1

					WAITFOR DELAY '00:00:00:010'
						
	             END
	                                
			END    
			ELSE
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
				
					UPDATE b
					SET @modds = CASE 
	                                
									--456: 1H Both Teams To Score / Result
									WHEN bettype = 456 THEN CASE
																WHEN LEFT(betteam,1) = 'N' THEN CASE
																									WHEN @hth > 0 AND @hta > 0 THEN -1
																									ELSE NULL
																								END
																ELSE NULL
															END
									--457: 1H Both Teams To Score / Total Goals
									WHEN bettype = 457 THEN CASE
																
																WHEN  LEFT(betteam,1) = 'N' AND @hth > 0 AND @hta > 0 THEN -1
																WHEN  RIGHT(betteam,1) = 'U' AND @hth + @hta > hdp1 THEN -1
																													
																WHEN betteam ='YO' AND @hth > 0 AND @hta > 0 AND @hth + @hta > hdp1 THEN 1
																										
																ELSE NULL
															END
																					
									--452: Highest Scoring Half (2 Way)
									WHEN bettype = 452 THEN CASE
																WHEN @IsHTCal = 1 THEN CASE
																							WHEN betteam = '1H' AND @totalht < @totalgoal_2H THEN -1
																							WHEN betteam = '2H' AND @totalht < @totalgoal_2H THEN 1
																							ELSE NULL
																						END	
																ELSE NULL
															  END  
																					
									WHEN bettype = 417 THEN CASE
																WHEN LEFT(betteam,1) = 'N' THEN CASE
																									WHEN @fth > 0 AND @fta > 0 THEN -1
																									WHEN @fth > @fta AND RIGHT(betteam,1) IN ('A','D') THEN -1
																									WHEN @fth < @fta AND RIGHT(betteam,1) IN ('H','D') THEN -1
																									ELSE NULL
																								END
																ELSE NULL
															END
									WHEN bettype = 418 THEN 
										CASE 
											/*WHEN @fth > 0 AND @fta > 0 THEN CASE
																				WHEN (LEFT(betteam,1) = 'N') THEN -1
																				WHEN (betteam = 'YU' AND (@fth + @fta) > hdp1) THEN -1
																				WHEN (betteam = 'YO' AND (@fth + @fta) > hdp1) THEN 1
																				ELSE NULL
																			END*/
											WHEN (@fth > 0 AND @fta > 0) THEN
												CASE 
													WHEN (@fth + @fta < hdp1) THEN
														CASE
															WHEN LEFT(betteam,1) = 'N' THEN -1
															ELSE NULL
														END
													WHEN (@fth + @fta > hdp1) THEN
														CASE
															WHEN betteam = 'YO' THEN 1
															WHEN betteam = 'YU' THEN -1
															WHEN betteam = 'NO' THEN -1
															WHEN betteam = 'NU' THEN -1
															ELSE NULL
														END
													ELSE NULL
												END
											WHEN (@fth > 0 OR @fta > 0) AND (@fth + @fta > hdp1) THEN 
												CASE
													WHEN RIGHT(betteam,1) = 'U' THEN -1
													ELSE NULL
												END
											ELSE NULL
										END
									WHEN bettype = 419 THEN CASE    
																WHEN @fth + @fta > 0 THEN CASE
																								WHEN betteam = '1H' AND @hth + @hta > 0 THEN 1
																								WHEN betteam = '2H' AND @hth + @hta = 0 THEN 1
																								ELSE -1
																						  END
																WHEN @IsHTCal = 1 AND @fth + @fta = 0 THEN CASE 
																										WHEN betteam = '1H' THEN -1
																										ELSE NULL
																									END                                                                                      
																ELSE NULL
															END
									WHEN bettype = 420 THEN CASE    
																WHEN @fth > 0 THEN CASE
																						WHEN betteam = '1H' AND @hth > 0 THEN 1
																						WHEN betteam = '2H' AND @hth = 0 THEN 1
																						ELSE -1
																					END
																WHEN @IsHTCal = 1 AND @fth = 0 THEN CASE 
																										WHEN betteam = '1H' THEN -1
																										ELSE NULL
																									END
	                                                    
																ELSE NULL
															END
									WHEN bettype = 421 THEN CASE    
																WHEN @fta > 0 THEN CASE
																						WHEN betteam = '1H' AND @hta > 0 THEN 1
																						WHEN betteam = '2H' AND @hta = 0 THEN 1
																						ELSE -1
																					END
																WHEN @IsHTCal = 1 AND @fta = 0 THEN CASE 
																										WHEN betteam = '1H' THEN -1
																										ELSE NULL
																									END
																ELSE NULL
															END
									WHEN bettype = 445 THEN    
										CASE @IsHTCal
										WHEN 0 THEN --abandoned 1H
											CASE 
												WHEN (@hth > 0 AND @hta > 0) THEN --both of teams have scored
													CASE
														WHEN LEFT(betteam,1) = 'N' THEN -1
														ELSE NULL
													END
												ELSE NULL
											END
										WHEN 1 THEN --abandoned 2H
											CASE 
												WHEN (@fth2H + @fta2H = 0 OR ((@fth2H + @fta2H) > 0 and (@fth2H = 0 OR @fta2H = 0) )) THEN  --not both teams haved score
													CASE 
														WHEN (@hth + @hta = 0 OR ((@hth + @hta) > 0 and (@hth = 0 OR @hta = 0) )) THEN
														CASE 
															WHEN betteam = 'YY' THEN -1
															WHEN betteam = 'YN' THEN -1
															ELSE NULL
														END
														WHEN (@hth > 0 AND @hta > 0) THEN
														CASE
															WHEN betteam = 'NY' THEN -1
															WHEN betteam = 'NN' THEN -1
															ELSE NULL
														END
														ELSE NULL
													END
												WHEN (@fth2H > 0 AND @fta2H > 0) THEN --both teams have scored
													CASE
														WHEN (@hth + @hta = 0 OR ((@hth + @hta) > 0 and (@hth = 0 OR @hta = 0) )) THEN
														CASE
															WHEN betteam = 'YY' THEN -1
															WHEN betteam = 'YN' THEN -1
															WHEN betteam = 'NY' THEN 1
															WHEN betteam = 'NN' THEN -1
															ELSE NULL
														END
														WHEN (@hth > 0 AND @hta > 0) THEN 
														CASE
															WHEN betteam = 'YY' THEN 1
															WHEN betteam = 'YN' THEN -1
															WHEN betteam = 'NY' THEN -1
															WHEN betteam = 'NN' THEN -1
															ELSE NULL
														END    
														ELSE NULL 
													END
												ELSE NULL 
	                                            
											END
										END
									WHEN bettype = 446 THEN    CASE 
																WHEN @IsHTCal = 0 AND @hth > 0 THEN CASE
																										WHEN LEFT(betteam,1) = 'N' THEN -1
																										ELSE NULL
																									END
																WHEN @IsHTCal = 1 AND @fth = 0 THEN CASE
																										WHEN LEFT(betteam,1) = 'Y' THEN -1
																										ELSE NULL
																									END
																WHEN @IsHTCal = 1 AND @fth > 0 THEN CASE
																										WHEN @hth = 0 THEN CASE
																																WHEN LEFT(betteam,1) = 'Y' THEN -1
																																WHEN betteam = 'NN' THEN -1
																																WHEN betteam = 'NY' THEN 1
																																ELSE NULL
																															END
																										WHEN @fth = @hth THEN CASE
																																	WHEN LEFT(betteam,1) = 'N' THEN -1
																																	ELSE NULL
																															  END
																										WHEN @hth > 0 AND @fth - @hth > 0 THEN CASE
																																						WHEN betteam = 'YY' THEN 1
																																						ELSE -1
																																				  END
																									END
																ELSE NULL
															END
									WHEN bettype = 447 THEN    CASE 
																WHEN @IsHTCal = 0 AND @hta > 0 THEN CASE
																										WHEN LEFT(betteam,1) = 'N' THEN -1
																										ELSE NULL
																									END
																WHEN @IsHTCal = 1 AND @fta = 0 THEN CASE
																										WHEN LEFT(betteam,1) = 'Y' THEN -1
																										ELSE NULL
																									END
																WHEN @IsHTCal = 1 AND @fta > 0 THEN CASE
																										WHEN @hta = 0 THEN CASE
																																WHEN LEFT(betteam,1) = 'Y' THEN -1
																																WHEN betteam = 'NN' THEN -1
																																WHEN betteam = 'NY' THEN 1
																																ELSE NULL
																															END
																										WHEN @fta = @hta THEN CASE
																																	WHEN LEFT(betteam,1) = 'N' THEN -1
																																	ELSE NULL
																															  END
																										WHEN @hta > 0 AND @fta - @hta > 0 THEN CASE
																																						WHEN betteam = 'YY' THEN 1
																																						ELSE -1
																																				  END
																									END
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
											WHEN bettype IN (417,418,419,420,421,445,446,447,456,452,457) THEN odds - 1
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
											WHEN bettype IN (417,418,419,420,421,445,446,447,456,452,457) THEN odds - 1
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
											WHEN bettype IN (417,418,419,420,421,445,446,447,456,452,457) THEN odds - 1
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
											WHEN bettype IN (417,418,419,420,421,445,446,447,456,452,457) THEN odds - 1
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
								
				WHERE   matchid = @matchid    
						AND bettype = @bettype
						AND statusID NOT IN (101, 102)
						AND i.IsCalculated = 1
						AND 1 = CASE 
									WHEN @IsSettleAbandonedMatch = 1 AND (b.custid IN (50057, 879241, 103873, 78761, 851668, 878902) OR recommend = 1688156) THEN 1
									WHEN @IsSettleAbandonedMatchBetFair = 1 AND b.custid IN (2331, 1077687, 115770, 15523642) THEN 1
									WHEN @IsSettleAbandonedMatchIBC = 1 AND (b.custid NOT IN (50057, 879241, 103873, 78761, 851668, 878902, 2331, 1077687, 115770, 15523642) AND recommend <> 1688156) THEN 1
									ELSE 0
								END
					
					SET @BatchNo = @BatchNo - 1

					WAITFOR DELAY '00:00:00:010'			
				END				
			END
		END
		ELSE
		BEGIN
			SELECT @csHT =  CASE WHEN @hth + @hta >= 4 THEN '4+' 
							 ELSE CAST(@hth AS nvarchar(10)) + ':' + CAST(@hta AS nvarchar(10))
						END
				  ,@csFT =  CASE WHEN @fth + @fta >=4 THEN '4+'
								 ELSE CAST(@fth AS nvarchar(10)) + ':' + CAST(@fta AS nvarchar(10))
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
				
				UPDATE b
					SET @ExcludingHTChoice = CASE WHEN bettype = 416 THEN SUBSTRING(transdesc,0, CHARINDEX('/',transdesc)) ELSE NULL END
					,@ExcludingFTChoice = CASE WHEN bettype = 416 THEN SUBSTRING(transdesc,CHARINDEX('/',transdesc)+1,LEN(transdesc)) ELSE NULL END
					,@htbetteam = CASE WHEN bettype = 416 THEN SUBSTRING(betteam,0,CHARINDEX('/',betteam)) ELSE NULL END
					,@ftbetteam = CASE WHEN bettype = 416 THEN SUBSTRING(betteam,CHARINDEX('/',betteam)+1, LEN(betteam)) ELSE NULL END
		            
					,@modds = CASE WHEN @IsSettleAbandonedMatch = 0 AND @IsSettleAbandonedMatchBetfair = 0 AND @IsSettleAbandonedMatchIBC = 0
											THEN CASE bettype
													WHEN 133 THEN -- Home To Win Both Halves
																 CASE 
																	WHEN betteam = 'y' AND (@hth > @hta) AND ((@fth - @hth) > (@fta - @hta)) THEN 1
																	WHEN betteam = 'n' AND ((@hth <= @hta) OR ((@fth - @hth) <= (@fta - @hta))) THEN 1
																	ELSE -1
																  END
													WHEN 134 THEN -- Away To Win Both Halves
																 CASE 
																	WHEN betteam = 'y' AND (@hta > @hth) AND ((@fta - @hta) > (@fth - @hth)) THEN 1
																	WHEN betteam = 'n' AND ((@hta <=@hth) OR ((@fta - @hta) <= (@fth - @hth))) THEN 1
																	ELSE -1
																  END        
													WHEN 140 THEN -- Highest Scoring Half
																 CASE 
																	WHEN betteam = '1h' AND (@hth + @hta) > (@fth - @hth + @fta - @hta) THEN 1
																	WHEN betteam = 'tie' AND (@hth + @hta) = (@fth - @hth + @fta - @hta) THEN 1
																	WHEN betteam = '2h' AND (@hth + @hta) < (@fth - @hth + @fta - @hta) THEN 1
																	ELSE -1
																 END        
													WHEN 141 THEN -- Highest Scoring Half Home Team
																 CASE 
																	WHEN betteam = '1h' AND @hth > (@fth - @hth) THEN 1
																	WHEN betteam = 'tie' AND @hth = (@fth - @hth) THEN 1
																	WHEN betteam = '2h' AND @hth < (@fth - @hth) THEN 1
																	ELSE -1
																 END            
													WHEN 142 THEN -- Highest Scoring Half Away Team
																 CASE 
																	WHEN betteam = '1h' AND @hta > (@fta - @hta) THEN 1
																	WHEN betteam = 'tie' AND @hta = (@fta - @hta) THEN 1
																	WHEN betteam = '2h' AND @hta < (@fta - @hta) THEN 1
																	ELSE -1
																 END  
													WHEN 145 THEN -- Both Teams To Score
																 CASE 
																	WHEN betteam = 'y' AND (@fth > 0) AND (@fta > 0) THEN 1
																	WHEN betteam = 'n' AND ((@fth = 0) OR (@fta = 0)) THEN 1
																	ELSE -1
																 END 
													WHEN 146 THEN -- 2nd Half Both Teams To Score
																 CASE 
																	WHEN betteam = 'y' AND (@fth - @hth) > 0 AND (@fta - @hta) > 0 THEN 1
																	WHEN betteam = 'n' AND ((@fth - @hth) = 0 OR (@fta - @hta) = 0) THEN 1
																	ELSE -1
																 END
													WHEN 147 THEN -- Home To Score In Both Halves 
																 CASE 
																	WHEN betteam = 'y' AND @hth > 0 AND (@fth - @hth) > 0 THEN 1
																	WHEN betteam = 'n' AND (@hth = 0 OR (@fth - @hth) = 0) THEN 1
																	ELSE -1
																 END
													WHEN 148 THEN -- Away To Score In Both Halves 
																 CASE 
																	WHEN betteam = 'y' AND @hta > 0 AND (@fta - @hta) > 0 THEN 1
																	WHEN betteam = 'n' AND (@hta = 0 OR (@fta - @hta) = 0) THEN 1
																	ELSE -1
																 END
													WHEN 149 THEN -- Home To Win Either Half 
																 CASE 
																	WHEN betteam = 'y' AND ((@hth > @hta) OR (@fth - @hth) > (@fta - @hta)) THEN 1
																	WHEN betteam = 'n' AND (@hth <= @hta) AND (@fth - @hth) <=(@fta - @hta) THEN 1
																	ELSE -1
																 END
													WHEN 150 THEN -- Away To Win Either Half
																 CASE 
																	WHEN betteam = 'y' AND ((@hta > @hth) OR (@fta - @hta) > (@fth - @hth)) THEN 1
																	WHEN betteam = 'n' AND (@hta <= @hth) AND (@fta - @hta) <= (@fth - @hth) THEN 1
																	ELSE -1
																 END 
													WHEN 152 THEN -- Half Time/Full Time Correct Score
																 CASE 
																	WHEN betteam = @csHT + '/' + @csFT THEN 1
																	ELSE -1
																 END     
													WHEN 189 THEN -- Both Halves Over 1.5 Yes/No
																CASE 
																	WHEN betteam ='y' AND (@hth + @hta - 1.5) > 0 AND (@fth + @fta - 1.5)>0 THEN 1  --ftscore save 2nd half score 
																	WHEN betteam ='n' AND ((@hth + @hta - 1.5) <=0 OR (@fth + @fta - 1.5)<=0) THEN 1 
																	ELSE -1 
																END 
													WHEN 190 THEN -- Both Halves Under 1.5 Yes/No  [190]
																CASE 
																	WHEN betteam ='y' AND (@hth + @hta - 1.5) < 0 AND (@fth + @fta - 1.5)<0 THEN 1  --ftscore save 2nd half score 
																	WHEN betteam ='n' AND ((@hth + @hta - 1.5) >=0 OR (@fth + @fta - 1.5)>=0) THEN 1 
																	ELSE -1 
																END        
													WHEN 416 THEN -- Half Time/Full Time Correct Score (own)
																CASE 
																	WHEN CHARINDEX('AOS',betteam) = 0 THEN CASE
																												WHEN betteam = CAST(@hth AS NVARCHAR(10)) + ':' + CAST(@hta AS NVARCHAR(10)) + '/' + CAST(@fth AS NVARCHAR(10)) + ':' + CAST(@fta AS NVARCHAR(10)) THEN 1
																												ELSE -1
																											END
																	WHEN CHARINDEX('AOS/AOS',betteam) > 0 THEN CASE
																													WHEN CHARINDEX(CAST(@hth AS NVARCHAR(10)) + ':' + CAST(@hta AS NVARCHAR(10)),@ExcludingHTChoice) = 0 AND CHARINDEX(CAST(@fth AS NVARCHAR(10)) + ':' + CAST(@fta AS NVARCHAR(10)),@ExcludingFTChoice) = 0 THEN 1
																													ELSE -1
																												END
																	WHEN CHARINDEX('/AOS',betteam) > 0 THEN CASE
																												WHEN betteam = CAST(@hth AS NVARCHAR(10)) + ':' + CAST(@hta AS NVARCHAR(10)) + '/AOS' AND CHARINDEX(CAST(@fth AS NVARCHAR(10)) + ':' + CAST(@fta AS NVARCHAR(10)),@ExcludingFTChoice) = 0 THEN 1
																												ELSE -1
																											END
																	WHEN CHARINDEX('AOS/',betteam) > 0 THEN CASE
																												WHEN betteam = 'AOS/' + CAST(@fth AS NVARCHAR(10)) + ':' + CAST(@fta AS NVARCHAR(10)) AND CHARINDEX(CAST(@hth AS NVARCHAR(10)) + ':' + CAST(@hta AS NVARCHAR(10)),@ExcludingHTChoice) = 0 THEN 1
																												ELSE -1
																											END
																	ELSE -1
																END
													WHEN 433 THEN -- 2H Both Teams To Score (own)
																 CASE 
																	WHEN betteam = 'y' AND (@fth - @hth) > 0 AND (@fta - @hta) > 0 THEN 1
																	WHEN betteam = 'n' AND ((@fth - @hth) = 0 OR (@fta - @hta) = 0) THEN 1
																	ELSE -1
																 END 
													WHEN 434 THEN -- Both Halves Over 1.5 Yes/No (own)
																CASE 
																	WHEN betteam ='y' AND (@hth + @hta - 1.5) > 0 AND (@fth + @fta - 1.5)>0 THEN 1  --ftscore save 2nd half score 
																	WHEN betteam ='n' AND ((@hth + @hta - 1.5) <=0 OR (@fth + @fta - 1.5)<=0) THEN 1 
																	ELSE -1 
																END     
													WHEN 435 THEN -- Both Halves Under 1.5 Yes/No (own)
																CASE 
																	WHEN betteam ='y' AND (@hth + @hta - 1.5) < 0 AND (@fth + @fta - 1.5)<0 THEN 1  --ftscore save 2nd half score 
																	WHEN betteam ='n' AND ((@hth + @hta - 1.5) >=0 OR (@fth + @fta - 1.5)>=0) THEN 1 
																	ELSE -1 
																END            
													WHEN 436 THEN -- Home To Score In Both Halves (own)
																 CASE 
																	WHEN betteam = 'y' AND @hth > 0 AND (@fth - @hth) > 0 THEN 1
																	WHEN betteam = 'n' AND (@hth = 0 OR (@fth - @hth) = 0) THEN 1
																	ELSE -1
																 END    
													WHEN 437 THEN -- Away To Score In Both Halves (own)
																 CASE 
																	WHEN betteam = 'y' AND @hta > 0 AND (@fta - @hta) > 0 THEN 1
																	WHEN betteam = 'n' AND (@hta = 0 OR (@fta - @hta) = 0) THEN 1
																	ELSE -1
																 END
													WHEN 438 THEN -- Home To Win Both Halves (own)
																 CASE 
																	WHEN betteam = 'y' AND (@hth > @hta) AND ((@fth - @hth) > (@fta - @hta)) THEN 1
																	WHEN betteam = 'n' AND ((@hth <= @hta) OR ((@fth - @hth) <= (@fta - @hta))) THEN 1
																	ELSE -1
																  END    
													WHEN 439 THEN -- Away To Win Both Halves (own)
																 CASE 
																	WHEN betteam = 'y' AND (@hta > @hth) AND ((@fta - @hta) > (@fth - @hth)) THEN 1
																	WHEN betteam = 'n' AND ((@hta <=@hth) OR ((@fta - @hta) <= (@fth - @hth))) THEN 1
																	ELSE -1
																  END    
													WHEN 440 THEN -- Home To Win Either Half (own)
																 CASE 
																	WHEN betteam = 'y' AND ((@hth > @hta) OR (@fth - @hth) > (@fta - @hta)) THEN 1
																	WHEN betteam = 'n' AND (@hth <= @hta) AND (@fth - @hth) <=(@fta - @hta) THEN 1
																	ELSE -1
																 END    
													WHEN 441 THEN -- Away To Win Either Half (own)
																 CASE 
																	WHEN betteam = 'y' AND ((@hta > @hth) OR (@fta - @hta) > (@fth - @hth)) THEN 1
																	WHEN betteam = 'n' AND (@hta <= @hth) AND (@fta - @hta) <= (@fth - @hth) THEN 1
																	ELSE -1
																 END         
													WHEN 442 THEN -- Highest Scoring Half (own)
																 CASE 
																	WHEN betteam = '1h' AND (@hth + @hta) > (@fth - @hth + @fta - @hta) THEN 1
																	WHEN betteam = 'tie' AND (@hth + @hta) = (@fth - @hth + @fta - @hta) THEN 1
																	WHEN betteam = '2h' AND (@hth + @hta) < (@fth - @hth + @fta - @hta) THEN 1
																	ELSE -1
																 END    
													WHEN 443 THEN -- Highest Scoring Half Home Team (own)
																 CASE 
																	WHEN betteam = '1h' AND @hth > (@fth - @hth) THEN 1
																	WHEN betteam = 'tie' AND @hth = (@fth - @hth) THEN 1
																	WHEN betteam = '2h' AND @hth < (@fth - @hth) THEN 1
																	ELSE -1
																 END
													WHEN 444 THEN -- Highest Scoring Half Away Team (own)
																 CASE 
																	WHEN betteam = '1h' AND @hta > (@fta - @hta) THEN 1
																	WHEN betteam = 'tie' AND @hta = (@fta - @hta) THEN 1
																	WHEN betteam = '2h' AND @hta < (@fta - @hta) THEN 1
																	ELSE -1
																 END                                                                                                                                                                                       
												 END                                            
										WHEN @IsSettleAbandonedMatch = 1 OR @IsSettleAbandonedMatchBetfair = 1 OR @IsSettleAbandonedMatchIBC = 1 
											THEN CASE bettype
													WHEN 133 THEN
																 CASE 
																	WHEN betteam = 'y' AND @hth <= @hta THEN -1
																	WHEN betteam = 'n' AND @hth <= @hta THEN 1
																 END
													WHEN 134 THEN
																 CASE
																	WHEN betteam = 'y' AND @hta <= @hth THEN -1
																	WHEN betteam = 'n' AND @hta <= @hth THEN 1
																 END
													WHEN 140 THEN 
														CASE @IsHTCal
															WHEN 0 THEN NULL --abandoned 1H
															WHEN 1 THEN --abandoned 2H
															CASE betteam
																WHEN '1h' THEN
																	CASE 
																		WHEN ((@hth + @hta >= 0) AND ((@hth + @hta) < (@fth2H + @fta2H))) THEN -1
																		WHEN ((@hth + @hta >= 0) AND ((@hth + @hta) = (@fth2H + @fta2H))) THEN -1
																		ELSE NULL
																	END
																WHEN '2h' THEN
																	CASE 
																		WHEN ((@hth + @hta >= 0) AND ((@hth + @hta) < (@fth2H + @fta2H))) THEN 1
																		ELSE NULL
																	END
																WHEN 'tie' THEN
																	CASE 
																		WHEN ((@hth + @hta >= 0) AND ((@hth + @hta) < (@fth2H + @fta2H))) THEN -1
																		ELSE NULL
																	END
																ELSE NULL
															END
														END
													WHEN 141 THEN
														CASE @IsHTCal
															WHEN 0 THEN NULL --abandoned 1H
															WHEN 1 THEN --abandoned 2H
															CASE betteam
																WHEN '1h' THEN
																	CASE 
																		WHEN (@hth >= 0 AND @fth2H > @hth) THEN -1
																		WHEN (@hth >= 0 AND @fth2H = @hth) THEN -1
																		ELSE NULL
																	END
																WHEN '2h' THEN
																	CASE 
																		WHEN (@hth >= 0 AND @fth2H > @hth) THEN 1
																		ELSE NULL
																	END
																WHEN 'tie' THEN
																	CASE 
																		WHEN (@hth >= 0 AND @fth2H > @hth) THEN -1
																		ELSE NULL
																	END
																ELSE NULL
															END
														END
													WHEN 142 THEN
														CASE @IsHTCal
															WHEN 0 THEN NULL --abandoned 1H
															WHEN 1 THEN --abandoned 2H
															CASE betteam
																WHEN '1h' THEN
																	CASE 
																		WHEN (@hta >= 0 AND @fta2H > @hta ) THEN -1
																		WHEN (@hta >= 0 AND @fta2H = @hta ) THEN -1
																		ELSE NULL
																	END
																WHEN '2h' THEN
																	CASE 
																		WHEN (@hta >= 0 AND @fta2H > @hta ) THEN 1
																		ELSE NULL
																	END
																WHEN 'tie' THEN
																	CASE 
																		WHEN (@hta >= 0 AND @fta2H > @hta ) THEN -1
																		ELSE NULL
																	END
																ELSE NULL
															END
														END
													WHEN 145 THEN 
																 CASE 
																	WHEN @IsHTCal = 0 THEN -- suspended in 1st half
																							CASE  
																								WHEN betteam = 'y' AND @hth > 0 AND @hta > 0 THEN 1
																								WHEN betteam = 'n' AND @hth > 0 AND @hta > 0 THEN -1
																							END
																	ELSE CASE 
																			WHEN betteam = 'y' AND @fth > 0 AND @fta > 0 THEN 1
																			WHEN betteam = 'n' AND @fth > 0 AND @fta > 0 THEN -1
																		END
																 END 
													WHEN 146 THEN 
																 CASE 
																	WHEN betteam = 'y' AND (@fth - @hth) > 0 AND (@fta - @hta) > 0 THEN 1
																	WHEN betteam = 'n' AND (@fth - @hth) > 0 AND (@fta - @hta) > 0 THEN -1
																 END
													WHEN 147 THEN 
																 CASE 
																	WHEN betteam = 'y' AND @hth = 0 THEN -1
																	WHEN betteam = 'n' AND @hth = 0 THEN 1
																	WHEN betteam = 'y' AND @hth > 0 and (@fth - @hth) > 0 THEN 1
																	WHEN betteam = 'n' AND @hth > 0 and (@fth - @hth) > 0 THEN -1
																 END
													WHEN 148 THEN 
																 CASE
																	WHEN betteam = 'y' AND @hta = 0 THEN -1
																	WHEN betteam = 'n' AND @hta = 0 THEN 1
																	WHEN betteam = 'y' AND @hta > 0 AND (@fta - @hta) > 0 THEN 1
																	WHEN betteam = 'n' AND @hta > 0 AND (@fta - @hta) > 0 THEN -1 
																 END
													WHEN 149 THEN 
																 CASE 
																	WHEN betteam = 'y' AND @hth > @hta THEN 1
																	WHEN betteam = 'n' AND @hth > @hta THEN -1
																 END
													WHEN 150 THEN 
																 CASE 
																	WHEN betteam = 'y' AND @hta > @hth THEN 1
																	WHEN betteam = 'n' AND @hta > @hth THEN -1
																 END
													WHEN 152 THEN
																 CASE 
																	WHEN @IsHTCal = 0 THEN CASE
																								WHEN LEFT(betteam,2) = '4+' AND (@hth + @hta) >= 4 THEN 1
																								WHEN LEFT(betteam,2) <> '4+' AND (LEFT(LEFT(betteam,3),1) < @hth OR RIGHT(LEFT(betteam,3),1) < @hta) THEN -1
																							END
																	ELSE CASE 
																			WHEN betteam = '4+/4+' AND (@hth + @hta) >= 4 AND (@fth + @fta) >= 4 THEN 1
																			WHEN LEFT(betteam,3) <> @csHT  THEN -1        
																			WHEN RIGHT(betteam,2) = '4+' AND (@fth + @fta) >= 4 THEN 1
																			WHEN RIGHT(betteam,2) <>'4+' AND (LEFT(RIGHT(betteam,3),1) < @fth OR RIGHT(RIGHT(betteam,3),1) < @fta) THEN -1                                                                                                                                                                                                
																		 END
																END
													WHEN 416 THEN
																CASE
																	WHEN @IsHTCal = 0 THEN CASE 
																								WHEN @htbetteam <> 'AOS' THEN CASE
																																WHEN CAST(LEFT(@htbetteam,1) AS INT) < @hth OR CAST(RIGHT(@htbetteam,1) AS INT) < @hta THEN -1																							
																															  END
																								ELSE  CASE
																											WHEN @ftbetteam = 'AOS' THEN CASE WHEN @hth > 4 OR @hta > 4 THEN 1 END
																											WHEN LEFT(@ftbetteam,1) < @hth OR RIGHT(@ftbetteam,1) < @hta THEN -1
																									  END
																							END
																	ELSE CASE 
																			WHEN @htbetteam <> 'AOS' THEN CASE
																												WHEN CAST(LEFT(@htbetteam,1) AS INT) <> @hth OR CAST(RIGHT(@htbetteam,1) AS INT) <> @hta THEN -1
																												WHEN @ftbetteam <> 'AOS' THEN CASE WHEN LEFT(@ftbetteam,1) < @fth OR RIGHT(@ftbetteam,1) < @fta THEN -1 END
																												WHEN CAST(LEFT(@htbetteam,1) AS INT) = @hth AND CAST(RIGHT(@htbetteam,1) AS INT) = @hta AND CHARINDEX(CAST(@fth AS NVARCHAR(10)) + ':' + CAST(@fta AS NVARCHAR(10)),@ExcludingFTChoice) = 0 THEN 1
																										  END
																			ELSE CASE 
																						WHEN CHARINDEX(CAST(@hth AS NVARCHAR(10)) + ':' + CAST(@hta AS NVARCHAR(10)),@ExcludingHTChoice) > 0 THEN -1
																						WHEN @ftbetteam <> 'AOS' THEN CASE WHEN LEFT(@ftbetteam,1) < @fth OR RIGHT(@ftbetteam,1) < @fta THEN -1 END
																						WHEN CHARINDEX(CAST(@fth AS NVARCHAR(10)) + ':' + CAST(@fta AS NVARCHAR(10)),@ExcludingFTChoice) = 0 THEN 1
																				  END
																		END	
																END
													WHEN 433 THEN 
																 CASE 
																	WHEN betteam = 'y' AND (@fth - @hth) > 0 AND (@fta - @hta) > 0 THEN 1
																	WHEN betteam = 'n' AND (@fth - @hth) > 0 AND (@fta - @hta) > 0 THEN -1
																 END
													WHEN 436 THEN 
																 CASE 
																	WHEN betteam = 'y' AND @hth = 0 THEN -1
																	WHEN betteam = 'n' AND @hth = 0 THEN 1
																	WHEN betteam = 'y' AND @hth > 0 and (@fth - @hth) > 0 THEN 1
																	WHEN betteam = 'n' AND @hth > 0 and (@fth - @hth) > 0 THEN -1
																 END
													WHEN 437 THEN 
																 CASE
																	WHEN betteam = 'y' AND @hta = 0 THEN -1
																	WHEN betteam = 'n' AND @hta = 0 THEN 1
																	WHEN betteam = 'y' AND @hta > 0 AND (@fta - @hta) > 0 THEN 1
																	WHEN betteam = 'n' AND @hta > 0 AND (@fta - @hta) > 0 THEN -1 
																 END    
													WHEN 438 THEN
																 CASE 
																	WHEN betteam = 'y' AND @hth <= @hta THEN -1
																	WHEN betteam = 'n' AND @hth <= @hta THEN 1
																 END    
													WHEN 439 THEN
																 CASE
																	WHEN betteam = 'y' AND @hta <= @hth THEN -1
																	WHEN betteam = 'n' AND @hta <= @hth THEN 1
																 END
													WHEN 440 THEN 
																 CASE 
																	WHEN betteam = 'y' AND @hth > @hta THEN 1
																	WHEN betteam = 'n' AND @hth > @hta THEN -1
																 END
													WHEN 441 THEN 
																 CASE 
																	WHEN betteam = 'y' AND @hta > @hth THEN 1
																	WHEN betteam = 'n' AND @hta > @hth THEN -1
																 END
													WHEN 442 THEN 
														CASE @IsHTCal
															WHEN 0 THEN NULL --abandoned 1H
															WHEN 1 THEN --abandoned 2H
															CASE betteam
																WHEN '1h' THEN
																	CASE 
																		WHEN ((@hth + @hta >= 0) AND ((@hth + @hta) < (@fth2H + @fta2H))) THEN -1
																		WHEN ((@hth + @hta >= 0) AND ((@hth + @hta) = (@fth2H + @fta2H))) THEN -1
																		ELSE NULL
																	END
																WHEN '2h' THEN
																	CASE 
																		WHEN ((@hth + @hta >= 0) AND ((@hth + @hta) < (@fth2H + @fta2H))) THEN 1
																		ELSE NULL
																	END
																WHEN 'tie' THEN
																	CASE 
																		WHEN ((@hth + @hta >= 0) AND ((@hth + @hta) < (@fth2H + @fta2H))) THEN -1
																		ELSE NULL
																	END
																ELSE NULL
															END
														END
													WHEN 443 THEN
														CASE @IsHTCal
															WHEN 0 THEN NULL --abandoned 1H
															WHEN 1 THEN --abandoned 2H
															CASE betteam
																WHEN '1h' THEN
																	CASE 
																		WHEN (@hth >= 0 AND @fth2H > @hth) THEN -1
																		WHEN (@hth >= 0 AND @fth2H = @hth) THEN -1
																		ELSE NULL
																	END
																WHEN '2h' THEN
																	CASE 
																		WHEN (@hth >= 0 AND @fth2H > @hth) THEN 1
																		ELSE NULL
																	END
																WHEN 'tie' THEN
																	CASE 
																		WHEN (@hth >= 0 AND @fth2H > @hth) THEN -1
																		ELSE NULL
																	END
																ELSE NULL
															END
														END
													WHEN 444 THEN 
														CASE @IsHTCal
															WHEN 0 THEN NULL --abandoned 1H
															WHEN 1 THEN --abandoned 2H
															CASE betteam
																WHEN '1h' THEN
																	CASE 
																		WHEN (@hta >= 0 AND @fta2H > @hta ) THEN -1
																		WHEN (@hta >= 0 AND @fta2H = @hta ) THEN -1
																		ELSE NULL
																	END
																WHEN '2h' THEN
																	CASE 
																		WHEN (@hta >= 0 AND @fta2H > @hta ) THEN 1
																		ELSE NULL
																	END
																WHEN 'tie' THEN
																	CASE 
																		WHEN (@hta >= 0 AND @fta2H > @hta ) THEN -1
																		ELSE NULL
																	END
																ELSE NULL
															END
														END
													--#67462-Implement SDT for over/under full WL
													WHEN 189 THEN 
														CASE 
															WHEN betteam = 'y' AND @hta + @hth < 1.5 THEN -1
															WHEN betteam = 'n' AND @hta + @hth < 1.5 THEN 1
															------
															WHEN betteam = 'y' AND @hta + @hth > 1.5 AND (@fth2H + @fta2H > 1.5) THEN 1
															WHEN betteam = 'n' AND @hta + @hth > 1.5 AND (@fth2H + @fta2H > 1.5) THEN -1
														END
													WHEN 190 THEN 
														CASE 
															WHEN betteam = 'y' AND @hta + @hth > 1.5 THEN -1
															WHEN betteam = 'n' AND @hta + @hth > 1.5 THEN 1
															------
															WHEN betteam = 'y' AND @hta + @hth < 1.5 AND (@fth2H + @fta2H > 1.5) THEN -1
															WHEN betteam = 'n' AND @hta + @hth < 1.5 AND (@fth2H + @fta2H > 1.5) THEN 1
														END
													WHEN 434 THEN 
														CASE 
															WHEN betteam = 'y' AND @hta + @hth < 1.5 THEN -1
															WHEN betteam = 'n' AND @hta + @hth < 1.5 THEN 1
															------
															WHEN betteam = 'y' AND @hta + @hth > 1.5 AND (@fth2H + @fta2H > 1.5) THEN 1
															WHEN betteam = 'n' AND @hta + @hth > 1.5 AND (@fth2H + @fta2H > 1.5) THEN -1
														END
													WHEN 435 THEN 
														CASE 
															WHEN betteam = 'y' AND @hta + @hth > 1.5 THEN -1
															WHEN betteam = 'n' AND @hta + @hth > 1.5 THEN 1
															------
															WHEN betteam = 'y' AND @hta + @hth < 1.5 AND (@fth2H + @fta2H > 1.5) THEN -1
															WHEN betteam = 'n' AND @hta + @hth < 1.5 AND (@fth2H + @fta2H > 1.5) THEN 1
														END
													--#67462
												 END 

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
										WHEN bettype IN (133, 134, 140, 141, 142, 145, 146, 147, 148, 149, 150, 152,189,190,416,433,434,435,436,437,438,439,440,441,442,443,444) THEN odds - 1
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
										WHEN bettype IN (133, 134, 140, 141, 142, 145, 146, 147, 148, 149, 150, 152,189,190,416,433,434,435,436,437,438,439,440,441,442,443,444) THEN odds - 1
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
										WHEN bettype IN (133, 134, 140, 141, 142, 145, 146, 147, 148, 149, 150, 152,189,190,416,433,434,435,436,437,438,439,440,441,442,443,444) THEN odds - 1
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
										WHEN bettype IN (133, 134, 140, 141, 142, 145, 146, 147, 148, 149, 150, 152,189,190,416,433,434,435,436,437,438,439,440,441,442,443,444) THEN odds - 1
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
					,ruben = CASE WHEN @modds IS NOT NULL THEN 1 ELSE ruben END
			
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
								
				WHERE matchid = @matchid 
					AND bettype = @bettype 
					AND statusID NOT IN (101, 102) -- reject, void
					AND i.IsCalculated = 1
					AND 1 = CASE WHEN @IsSettleAbandonedMatch = 0 AND @IsSettleAbandonedMatchBetFair = 0 AND @IsSettleAbandonedMatchIBC = 0 THEN 1
								 WHEN (
										(@IsSettleAbandonedMatch = 1 AND (b.custid IN (50057, 879241, 103873, 78761, 851668, 878902) OR recommend = 1688156))
										OR (@IsSettleAbandonedMatchBetFair = 1 AND b.custid IN (2331, 1077687, 115770, 15523642))
										OR (@IsSettleAbandonedMatchIBC = 1 AND (b.custid NOT IN (50057, 879241, 103873, 78761, 851668, 878902, 2331, 1077687, 115770, 15523642) AND recommend <> 1688156))
									) THEN 1                       
								 ELSE 0
							END 
				
				SET @BatchNo = @BatchNo - 1

				WAITFOR DELAY '00:00:00:010'
						
			END		
		END
		
	END	
END
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Admin_Calculate_9999] TO [vnteam] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[NAP_Admin_Calculate_9999] TO [bodbAdminNet]
GO