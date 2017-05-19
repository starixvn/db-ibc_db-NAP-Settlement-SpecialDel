USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[NAP_Admin_Calculate_6]    Script Date: 03/22/2016 11:08:39 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.Admin_Calculate_6    Script Date: 2/26/2014 6:01:44 PM ******/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_6] @matchid INT
	,@bettype SMALLINT
	,@totalgoal INT
	,@betcount INT = 0
	,@IsHTCal	 BIT = 0
	,@IsSettleAbandonedMatch BIT = 0
	,@IsSettleAbandonedMatchIBC BIT = 0
	,@IsSettleAbandonedMatchBetFair BIT = 0
	,@isExcludeCorner				BIT = 0 
AS
/*
	Created by: Kathy
	Date: 20140211
	Task: Settlement 
	DB: DBO2.BODB02
	
	Revisions:
		- 20140426@Kathy: Add 1H Total Goal (126) [Redmine:#14449]
		- 20140728@Kathy: Settle determined tickets for Total Goal (6, 126)[Redmine:#19310]
		- 20140807@Kathy: Support new 11 bettypes: 129, 130, 131, 132 [Redmine:#19667]
		- 20150413@Jamie: Settlement Betradar phase 2 [Redmine: #27212]
		- 20150618@Jamie: Offer the option Exclude Corner tickets [Feature #38099]
		- 20151125@Patrick: Apply 28 Live Bettypes for Settlement [Redmine:#47843]
		- 20151210@Patrick: Database - Change datatype [Redmine: #48660]
		- 20160322@Kathy: Change betteam of bettype 412 (3&over --> 3-over) [Redmine:#54596]
		- 20160705@Kathy: PH-AIO phase 2 (67 bettypes ) [Redmine:#53154]
		
*/
BEGIN
	SET NOCOUNT ON

	IF @betcount = 0 AND @@SERVERNAME NOT LIKE N'DBIOM%' RETURN

	IF @@SERVERNAME IN ('DB04', 'DB042', 'DB043', 'DB044') RETURN	

	DECLARE @modds MONEY
		,@commWinRate SMALLMONEY
		,@commLostRate SMALLMONEY
		,@result NVARCHAR(10)
	
	IF @IsSettleAbandonedMatchIBC = 1 OR @IsSettleAbandonedMatch = 1 OR @IsSettleAbandonedMatchBetFair = 1
	BEGIN
		UPDATE bettrans WITH (ROWLOCK, UPDLOCK)
		SET @modds = CASE 
								WHEN betteam = '0-1' and @totalgoal >= 2 then -1 --6,200,201 
								WHEN betteam = '2-3' and @totalgoal >= 4 then -1
								WHEN betteam = '4-6' and @totalgoal >=7  and @bettype = 6 then -1
								WHEN betteam in ('4-over', '4&over') and @totalgoal >=4 then 1 -- 126, 131, 132,200,201
								WHEN betteam = '5&over' AND @totalgoal >= 5 THEN 1 -- 129
								WHEN betteam in ('7-over', '7&over') and @totalgoal >=7 then 1		-- 6, 130, 195,196,202 
								WHEN bettype IN(195,196) AND betteam='0-2' AND @totalgoal > 2 THEN -1 
								WHEN bettype IN(195,196) AND betteam='3-4' AND @totalgoal > 4 THEN -1 
								WHEN bettype IN(195,196,202) AND betteam='5-6' AND @totalgoal > 6 THEN -1 
								WHEN bettype = 199 AND betteam ='0-8' AND @totalgoal > 8 THEN -1
								WHEN bettype = 199 AND betteam ='9-11' AND @totalgoal >11 THEN -1
								WHEN bettype = 199 AND betteam ='12-over' AND @totalgoal>=12 THEN 1 
								WHEN bettype IN (200,201) AND betteam ='2' AND @totalgoal > 2 THEN -1 
								WHEN bettype IN (200,201) AND betteam ='3' AND @totalgoal > 3 THEN -1 
								WHEN bettype = 202 AND betteam ='0-4' AND @totalgoal > 4 THEN -1 
								WHEN betteam not in ('5&over') and @bettype = 129 and @totalgoal > cast(betteam as INT)  THEN -1 -- 129
								WHEN betteam not in ('7&over') and @bettype = 130 and @totalgoal > cast(betteam as INT)  THEN -1 -- 130							
								WHEN betteam NOT IN ('3-over') AND @bettype = 412 AND @totalgoal > CAST(betteam AS INT) THEN -1 --412
								WHEN betteam IN ('3-over') AND @bettype = 412 AND @totalgoal >= 3 THEN 1 --412
								WHEN bettype IN (159,406) AND betteam LIKE 'G[0-5]' AND @totalgoal > CAST(RIGHT(betteam,1) AS TINYINT) THEN -1 
								WHEN bettype IN (159,406) AND betteam ='G6' AND @totalgoal >= CAST(RIGHT(betteam,1) AS TINYINT) THEN 1 
								WHEN bettype = 179 AND betteam LIKE 'G[0-3]' AND @totalgoal > CAST(RIGHT(betteam,1) AS TINYINT) THEN -1 
								WHEN bettype = 179 AND betteam ='G4' AND @totalgoal >= CAST(RIGHT(betteam,1) AS TINYINT) THEN 1 
								WHEN bettype IN (161,162,181,182,407,409) AND betteam LIKE 'G[0-2]' AND @totalgoal > CAST(RIGHT(betteam,1) AS TINYINT) THEN -1 
								WHEN bettype IN (161,162,181,182,407,409) AND betteam ='G3' AND @totalgoal >= CAST(RIGHT(betteam,1) AS TINYINT) THEN 1 
								WHEN bettype = 187 AND betteam LIKE 'G[0-1]' AND @totalgoal > CAST(RIGHT(betteam,1) AS TINYINT) THEN -1 
								WHEN bettype = 187 AND betteam ='G2' AND @totalgoal >= CAST(RIGHT(betteam,1) AS TINYINT) THEN 1 
								WHEN bettype = 429 THEN CASE
															WHEN @IsHTCal = 1 AND @totalgoal > 0 THEN CASE
																										WHEN @totalgoal >= 3 AND betteam = '3-over' THEN 1
																										WHEN betteam <> '3-over' THEN CASE
																																		WHEN @totalgoal > CAST(betteam AS INT) THEN -1
																																		ELSE NULL
																																	  END
																										ELSE NULL
																									END
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
								WHEN bettype IN (6, 126, 129, 130, 131, 132, 159,161,162,179,181,182,187,195,196,199,200,201,202,406,407,409,412,429) THEN odds - 1
								ELSE odds END
								) END
						)
				WHEN @modds = 0.25 THEN actual_stake + stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (6, 126, 129, 130, 131, 132, 159,161,162,179,181,182,187,195,196,199,200,201,202,406,407,409,412,429) THEN odds - 1
								ELSE odds END
								) END
						) * 0.5
				WHEN @modds = 0 THEN actual_stake
				WHEN @modds = - 0.25 THEN actual_stake * 0.5
				WHEN @modds < - 0.25 THEN 0
				WHEN @modds IS NULL then winlost
				END
			,aWinLost = CASE 
				WHEN @modds > 0.25 THEN stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (6, 126, 129, 130, 131, 132, 159,161,162,179,181,182,187,195,196,199,200,201,202,406,407,409,412,429) THEN odds - 1
								ELSE odds END
								) END
						) * - apositiontaking
				WHEN @modds = 0.25 THEN stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (6, 126, 129, 130, 131, 132, 159,161,162,179,181,182,187,195,196,199,200,201,202,406,407,409,412,429) THEN odds - 1
								ELSE odds END
								) END
						) * - apositiontaking * 0.5
				WHEN @modds = 0 THEN 0
				WHEN @modds = - 0.25 THEN actual_stake * apositiontaking * 0.5
				WHEN @modds < - 0.25 THEN actual_stake * apositiontaking
				WHEN @modds IS NULL then awinlost
				END
			,mWinLost = CASE 
				WHEN @modds > 0.25 THEN stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (6, 126, 129, 130, 131, 132, 159,161,162,179,181,182,187,195,196,199,200,201,202,406,407,409,412,429) THEN odds - 1
								ELSE odds END
								) END
						) * - mpositiontaking
				WHEN @modds = 0.25 THEN stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (6, 126, 129, 130, 131, 132, 159,161,162,179,181,182,187,195,196,199,200,201,202,406,407,409,412,429) THEN odds - 1
								ELSE odds END
								) END
						) * - mpositiontaking * 0.5
				WHEN @modds = 0 THEN 0
				WHEN @modds = - 0.25 THEN actual_stake * mpositiontaking * 0.5
				WHEN @modds < - 0.25 THEN actual_stake * mpositiontaking
				WHEn @modds IS NULL then mwinlost
				END
			,sWinLost = CASE 
				WHEN @modds > 0.25 THEN stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (6, 126, 129, 130, 131, 132, 159,161,162,179,181,182,187,195,196,199,200,201,202,406,407,409,412,429) THEN odds - 1
								ELSE odds END
								) END
						) * - spositiontaking
				WHEN @modds = 0.25 THEN stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (6, 126, 129, 130, 131, 132, 159,161,162,179,181,182,187,195,196,199,200,201,202,406,407,409,412,429) THEN odds - 1
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
				--WHEN @modds = 0 THEN 'DRAW'
				WHEN @modds < 0 THEN 'LOSE'
				WHEn @modds IS NULL THEN status
				END
			,StatusID = CASE 
				WHEN @modds > 0 THEN 112 --WON
				--WHEN @modds = 0 THEN 111 --DRAW
				WHEN @modds < 0 THEN 113 --LOSE
				WHEN @modds IS NULL THEN statusID
				END
			,ruben = CASE when @modds IS NULL THEN ruben
							ELSE 1
					 END
		WHERE matchid = @matchid AND bettype = @bettype 
			AND statusID NOT IN (101, 102)
			AND 1 = CASE WHEN @isExcludeCorner = 1 AND @bettype IN (195,196,199,200,201,202) THEN 0 ELSE 1 END 
			AND 1 = CASE WHEN @bettype <> 187 THEN 1 
						 WHEN @bettype = 187 AND @IsHTCal = 1 THEN 1 
						 ELSE 0 END 
			AND 1 = CASE 
						WHEN @IsSettleAbandonedMatch = 1 AND (custid IN (50057, 879241, 103873, 78761, 851668, 878902) OR recommend = 1688156) THEN 1
						WHEN @IsSettleAbandonedMatchBetFair = 1 AND custid IN (2331, 1077687, 115770, 15523642) THEN 1
						WHEN @IsSettleAbandonedMatchIBC = 1 AND (custid NOT IN (50057, 879241, 103873, 78761, 851668, 878902, 2331, 1077687, 115770, 15523642) AND recommend <> 1688156) THEN 1
						ELSE 0
					END
	END
	ELSE
	BEGIN
		SET @result = CASE @bettype
							WHEN 429 THEN CASE 
										WHEN @totalgoal >=3 THEN '3-Over'
										ELSE CAST(@totalgoal AS NVARCHAR(10)) 
									  END
					  END		
					  
		UPDATE bettrans WITH (ROWLOCK, UPDLOCK)
		SET @modds = CASE 
				WHEN bettype = 1206 AND betteam = cast(cast(@totalgoal AS TINYINT) AS VARCHAR(5)) THEN 1
				WHEN betteam = '0-1' AND @totalgoal <= 1 THEN 1		-- + 200,201
				WHEN betteam = '2-3' AND @totalgoal IN (2, 3) THEN 1
				WHEN betteam = '4-6' AND @totalgoal IN (4, 5, 6) THEN 1
				WHEN bettype IN (195,196) AND betteam = '0-2' AND @totalgoal <=2 THEN 1			
				WHEN bettype IN (195,196) AND betteam = '3-4' AND @totalgoal IN (3, 4) THEN 1	
				WHEN bettype IN (195,196,202) AND betteam = '5-6' AND @totalgoal IN(5, 6) THEN 1	
				WHEN bettype = 199 AND betteam ='0-8' AND @totalgoal<=8 THEN 1 
				WHEN bettype = 199 AND betteam ='9-11' AND @totalgoal IN(9,10,11) THEN 1 	
				WHEN bettype = 199 AND betteam ='12-over' AND @totalgoal>=12 THEN 1 
				WHEN bettype IN (200,201) AND (betteam ='2' OR betteam='3') AND betteam = cast(cast(@totalgoal AS TINYINT) AS VARCHAR(5)) THEN 1
				WHEN bettype = 202 AND betteam ='0-4' AND  @totalgoal<=4 THEN 1 
				WHEN betteam IN ('4-over', '4&over') AND @totalgoal >= 4 THEN 1		--+ 200,201 
				WHEN betteam IN ('7-over', '7&over') AND @totalgoal >= 7 THEN 1		-- 7-over(195, 196,202)			
				WHEN betteam = '5&over' and bettype = 129  AND @totalgoal >= 5 THEN 1
				WHEN betteam = '3-over' and bettype = 412  AND @totalgoal >= 3 THEN 1 --412
				WHEN ((betteam <> '5&over' and bettype = 129) 
						or (betteam <> '7&over' and bettype = 130) 
						or (betteam <> '3-over' and bettype = 412)) 
					AND @totalgoal = cast(betteam AS INT) THEN 1 --412
				WHEN bettype IN (159,406) AND betteam LIKE 'G[0-5]' AND @totalgoal = CAST(RIGHT(betteam,1)AS TINYINT) THEN 1 
				WHEN bettype IN (159,406) AND betteam ='G6' AND @totalgoal >=CAST(RIGHT(betteam,1)AS TINYINT) THEN 1 
				WHEN bettype = 179 AND betteam LIKE 'G[0-3]' AND @totalgoal = CAST(RIGHT(betteam,1)AS TINYINT) THEN 1 
				WHEN bettype = 179 AND betteam ='G4' AND @totalgoal >=CAST(RIGHT(betteam,1)AS TINYINT) THEN 1 
				WHEN bettype IN (161,162,181,182,407,409) AND betteam LIKE 'G[0-2]' AND @totalgoal = CAST(RIGHT(betteam,1)AS TINYINT) THEN 1
				WHEN bettype IN (161,162,181,182,407,409) AND betteam ='G3' AND @totalgoal >=CAST(RIGHT(betteam,1)AS TINYINT) THEN 1
				WHEN bettype = 187 AND betteam LIKE 'G[0-1]' AND @totalgoal = CAST(RIGHT(betteam,1)AS TINYINT) THEN 1
				WHEN bettype = 187 AND betteam ='G2' AND @totalgoal >=CAST(RIGHT(betteam,1)AS TINYINT) THEN 1
				WHEN bettype = 429 THEN CASE
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
				WHEN @modds > 0.25 THEN actual_stake + stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (4, 5, 6, 126, 129, 130, 131, 132, 159,161,162,179,181,182,187,195,196,199,200,201,202,1206,406,407,409,412,429) THEN odds - 1
								ELSE odds END
								) END
						)
				WHEN @modds = 0.25 THEN actual_stake + stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (4, 5, 6, 126, 129, 130, 131, 132,159,161,162,179,181,182,187,195,196,199,200,201,202, 1206,406,407,409,412,429) THEN odds - 1
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
								WHEN bettype IN (4, 5, 6, 126, 129, 130, 131, 132,159,161,162,179,181,182,187,195,196,199,200,201,202, 1206,406,407,409,412,429) THEN odds - 1
								ELSE odds END
								) END
						) * - apositiontaking
				WHEN @modds = 0.25 THEN stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (4, 5, 6, 126, 129, 130, 131, 132,159,161,162,179,181,182,187,195,196,199,200,201,202, 1206,406,407,409,412,429) THEN odds - 1
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
								WHEN bettype IN (4, 5, 6, 126, 129, 130, 131, 132,159,161,162,179,181,182,187,195,196,199,200,201,202, 1206,406,407,409,412,429) THEN odds - 1
								ELSE odds END
								) END
						) * - mpositiontaking
				WHEN @modds = 0.25 THEN stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (4, 5, 6, 126, 129, 130, 131, 132,159,161,162,179,181,182,187,195,196,199,200,201,202, 1206,406,407,409,412,429) THEN odds - 1
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
								WHEN bettype IN (4, 5, 6, 126, 129, 130, 131, 132,159,161,162,179,181,182,187,195,196,199,200,201,202, 1206,406,407,409,412,429) THEN odds - 1
								ELSE odds END
								) END
						) * - spositiontaking
				WHEN @modds = 0.25 THEN stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (4, 5, 6, 126, 129, 130, 131, 132,159,161,162,179,181,182,187,195,196,199,200,201,202, 1206,406,407,409,412,429) THEN odds - 1
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
			statusID NOT IN (101, 102)
			AND 1 = CASE WHEN @isExcludeCorner = 1 AND @bettype IN (195,196,199,200,201,202) THEN 0 ELSE 1 END 
	END
END

GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Admin_Calculate_6] TO [vnteam] AS [dbo]