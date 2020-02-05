/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_Set_Parlay_SDT_CalModds] (
	@bettype 			SMALLINT
	, @betteam 			VARCHAR(50)
	, @hdp1 			SMALLMONEY
	, @hdp2 			SMALLMONEY
	, @hScore1H			TINYINT
	, @aScore1H			TINYINT
	, @hScore2H			TINYINT
	, @aScore2H			TINYINT
	, @transdesc		NVARCHAR(1000)
	, @isHT				BIT
)
RETURNS TABLE
WITH SCHEMABINDING
AS
/*
    Created:20161129@Bobby
    Task: Implement SDT Parlay bettypes - Modds Calculation
    DB: DBTXN/bodb02
    Revisions:
		- 20170227@Bobby: #72205 - Implement SDT half WON-LOSE for bettype Over/Under
		- 20170919@Kathy: Offer new 4 bettypes (461, 462, 463, 464) [Redmine:#83261]
		- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
		- 20190603@Sol: Incorporate PHAIO 4 [Redmine:#112885]
		- 20190626@Sol: Incorporate PHAIO 4b - 27 Corners Bet Types [Redmine:#115232]
		- 20191112@Sol: Incorporate PHAIO 5 [Redmine:#121681]
		
    Parameters Explanation:    
		- @hScore1H: Home score in 1H
		- @aScore1H: Away score in 1H
		- @hScore2H: Home score in 2H
		- @aScore2H: Away score in 2H
	
*/

RETURN (
	SELECT ods.modds
		, CASE 
			WHEN ods.modds > 0 THEN 112 --WON
			WHEN ods.modds < 0 THEN 113 --LOSE
			ELSE 0
		END AS StatusId
	FROM (
		SELECT t1.modds
		FROM ( 
			-- Input parrams definition
			SELECT 
				@hScore1H			AS HomeScore1H
				, @aScore1H			AS AwayScore1H
				, @hScore2H			AS HomeScore2H
				, @aScore2H			AS AwayScore2H
				, CASE WHEN @isHT = 1 THEN @hScore1H + @aScore1H ELSE @hScore1H + @aScore1H + @hScore2H + @aScore2H END AS TotalGoal
				, (@hScore1H + @aScore1H) AS TotalGoal1H
				, CASE WHEN @isHT = 0 THEN @hScore2H + @aScore2H ELSE NULL END AS TotalGoal2H
				, CASE WHEN @isHT = 1 THEN @hScore1H ELSE @hScore1H + @hScore2H END AS HomeScoreFT
				, CASE WHEN @isHT = 1 THEN @aScore1H ELSE @aScore1H + @aScore2H END AS AwayScoreFT
				--CASE WHEN @hScore1H + @aScore1H >= 4 THEN '4+' ELSE CAST(@hScore1H AS NVARCHAR(10)) + ':' + CAST(@hta AS NVARCHAR(10)) END
				, CASE 
					WHEN @hScore1H + @aScore1H >= 4
						THEN '4+'
					ELSE CAST(@hScore1H AS NVARCHAR(10)) + ':' + CAST(@aScore1H AS NVARCHAR(10))
				END AS CS1H -- Correct Score HT
				, CASE WHEN @isHT = 0 THEN CAST(((@hScore1H + @aScore1H) % 2) AS SMALLMONEY) ELSE NULL END AS OddEven1H 
				, CASE 
					WHEN @bettype IN(3) THEN (@hScore1H + @aScore1H) + (@hScore2H + @aScore2H)
					WHEN @bettype IN(8) THEN (@hScore1H + @aScore1H)
					WHEN @bettype IN (18, 178) THEN  (@hScore2H + @aScore2H)
					WHEN @bettype IN (401, 461, 482, 389) THEN (@hScore1H + @hScore2H)
					WHEN @bettype IN (402, 462, 483, 388) THEN (@aScore1H + @aScore2H)
					WHEN @bettype IN (403, 463, 484) THEN @hScore1H
					WHEN @bettype IN (404, 464, 485) THEN @aScore1H
					ELSE 0
				END AS TotalGoalOU
				,CASE WHEN @bettype = 416 THEN SUBSTRING(@betteam,0,CHARINDEX('/',@betteam)) ELSE NULL END AS betteam1H
				,CASE WHEN @bettype = 416 THEN SUBSTRING(@betteam,CHARINDEX('/',@betteam)+1, LEN(@betteam)) ELSE NULL END AS betteamFT
				,CASE WHEN @bettype = 416 THEN SUBSTRING(@transdesc,0, CHARINDEX('/',@transdesc)) ELSE NULL END AS ExcludingHTChoice
				,CASE WHEN @bettype = 416 THEN SUBSTRING(@transdesc,CHARINDEX('/',@transdesc)+1,LEN(@transdesc)) ELSE NULL END AS ExcludingFTChoice
		) AS ip
		CROSS APPLY (
			-- Modds calculation
			SELECT 
				CASE
				--#3-8-18-178-401-402-403-404
				WHEN @bettype IN (3,8,18,178,401,402,403,404,461,462,463,464,482,483,484,485,389,388) THEN -- apply half WON|LOSE
					CASE 
						WHEN @betteam IN ('h', 'o') AND @hdp1 <= ip.TotalGoalOU - 0.25 THEN ip.TotalGoalOU - @hdp1 
						WHEN @betteam IN ('a', 'u') AND @hdp1 <= ip.TotalGoalOU - 0.25 THEN @hdp1 - ip.TotalGoalOU
						ELSE NULL
					END			
				WHEN @bettype IN (4) THEN --Correct Score
					CASE 
						WHEN @betteam NOT IN ('0:5', '5:0') AND (ip.HomeScoreFT > LEFT(@betteam,1) OR ip.AwayScoreFT > RIGHT(@betteam,1)) THEN -1 
						ELSE NULL 
					END
				WHEN @bettype IN (6) THEN--Total Goal
					CASE 
						WHEN @betteam IN ('7-over', '7&over') THEN CASE WHEN ip.TotalGoal >=7 THEN 1 ELSE NULL END
						WHEN ip.TotalGoal > RIGHT(@betteam,1) THEN -1
						ELSE NULL 
					END
				WHEN @bettype IN (13) THEN -- Clean Sheet
					CASE
						WHEN @betteam = 'ay' AND ip.HomeScoreFT > 0  THEN -1
						WHEN @betteam = 'an' AND ip.HomeScoreFT > 0  THEN 1
						WHEN @betteam = 'hy' AND ip.AwayScoreFT > 0  THEN -1
						WHEN @betteam = 'hn' AND ip.AwayScoreFT > 0  THEN 1
						ELSE NULL
					END
				WHEN @bettype IN (16) AND @isHT	= 0 THEN --HT/FT refund FT with SDT
					CASE 
						WHEN ip.HomeScore1H > ip.AwayScore1H AND LEFT(@betteam,1) IN ('0','2') THEN -1
						WHEN ip.HomeScore1H = ip.AwayScore1H AND LEFT(@betteam,1) IN ('1','2') THEN -1
						WHEN ip.HomeScore1H < ip.AwayScore1H AND LEFT(@betteam,1) IN ('0','1') THEN -1
						ELSE NULL
					END
				WHEN @bettype IN (26) THEN --Both/One/Neither Team To Score
					CASE
						WHEN @betteam = 'b' AND ip.HomeScoreFT > 0 AND ip.AwayScoreFT > 0 THEN 1
						WHEN @betteam = 'o' AND ip.HomeScoreFT > 0 AND ip.AwayScoreFT > 0 THEN - 1
						WHEN @betteam = 'n' AND (ip.HomeScoreFT > 0 OR ip.AwayScoreFT > 0) THEN - 1
						ELSE NULL
					END
				WHEN @bettype IN (27) THEN --To Win To Nil
					CASE 
						WHEN @betteam = 'a' AND ip.HomeScoreFT > 0 THEN - 1
						WHEN @betteam = 'h' AND ip.AwayScoreFT > 0 THEN - 1
						WHEN ip.HomeScoreFT > 0 AND ip.AwayScoreFT > 0 THEN - 1
						ELSE NULL
					END
				WHEN @bettype IN (30) AND @isHT = 1 THEN --1H Correct Score
					CASE 
						WHEN @betteam NOT IN ('0:4', '4:0') AND ((ip.HomeScore1H > LEFT(@betteam,1) OR ip.AwayScore1H > RIGHT(@betteam,1))) THEN -1
						ELSE NULL
					END
				WHEN @bettype IN (126) AND @isHT = 1 THEN--1H Total Goal
					CASE 
						WHEN @betteam IN ('4-over', '4&over') THEN CASE WHEN ip.TotalGoal >=4 THEN 1 ELSE NULL END
						WHEN ip.TotalGoal > RIGHT(@betteam,1) THEN -1
						ELSE NULL 
					END
				WHEN @bettype IN (128) AND @isHT = 0 THEN --HT/FT Odd/Even
					CASE 
						WHEN @betteam IN ('oo', 'oe') AND ip.OddEven1H = 0 THEN - 1
						WHEN @betteam IN ('eo', 'ee') AND ip.OddEven1H = 1 THEN - 1
						ELSE NULL
					END
				WHEN @bettype IN (129) AND @isHT = 1 THEN--Exact 1H Goal
					CASE 
						WHEN @betteam IN ('5-over', '5&over') THEN CASE WHEN ip.TotalGoal >= 5 THEN 1 ELSE NULL END
						WHEN ip.TotalGoal > RIGHT(@betteam,1) THEN -1
						ELSE NULL 
					END
				WHEN @bettype IN (130) THEN--Exact Goal
					CASE 
						WHEN @betteam IN ('7-over', '7&over') THEN CASE WHEN ip.TotalGoal >= 7 THEN 1 ELSE NULL END
						WHEN ip.TotalGoal > CAST(@betteam AS INT) THEN -1
						ELSE NULL
					END
				WHEN @bettype IN (131) THEN--Home Team Total Goal
					CASE 
						WHEN @betteam IN ('4-over', '4&over') THEN CASE WHEN ip.HomeScoreFT >= 4 THEN 1 ELSE NULL END
						WHEN ip.HomeScoreFT > RIGHT(@betteam,1) THEN -1
						ELSE NULL 
					END
				WHEN @bettype IN (132) THEN--Away Team Total Goal
					CASE 
						WHEN @betteam IN ('4-over', '4&over') THEN CASE WHEN ip.AwayScoreFT >= 4 THEN 1 ELSE NULL END
						WHEN ip.AwayScoreFT > RIGHT(@betteam,1) THEN -1
						ELSE NULL 
					END
				WHEN @bettype IN (133) AND @isHT = 0 THEN--Home To Win Both Halves
					CASE 
						WHEN @betteam = 'y' AND ip.HomeScore1H <= ip.AwayScore1H THEN -1
						WHEN @betteam = 'n' AND ip.HomeScore1H <= ip.AwayScore1H THEN 1
						ELSE NULL 
					END
				WHEN @bettype IN (134) AND @isHT = 0 THEN--Away To Win Both Halves
					CASE
						WHEN @betteam = 'y' AND ip.AwayScore1H <= ip.HomeScore1H THEN -1
						WHEN @betteam = 'n' AND ip.AwayScore1H <= ip.HomeScore1H THEN 1
						ELSE NULL 
					END
				WHEN @bettype IN (140) AND @isHT = 0 THEN --Highest Scoring Half
					CASE @betteam
						WHEN '1h' THEN
							CASE 
								WHEN ((ip.HomeScore1H + ip.AwayScore1H >= 0) AND ((ip.HomeScore1H + ip.AwayScore1H) < ((ip.HomeScoreFT - ip.HomeScore1H + (ip.AwayScoreFT - ip.AwayScore1H))))) THEN -1
								WHEN ((ip.HomeScore1H + ip.AwayScore1H >= 0) AND ((ip.HomeScore1H + ip.AwayScore1H) = ((ip.HomeScoreFT - ip.HomeScore1H + (ip.AwayScoreFT - ip.AwayScore1H))))) THEN -1
								ELSE NULL
							END
						WHEN '2h' THEN
							CASE 
								WHEN ((ip.HomeScore1H + ip.AwayScore1H >= 0) AND ((ip.HomeScore1H + ip.AwayScore1H) < ((ip.HomeScoreFT - ip.HomeScore1H + (ip.AwayScoreFT - ip.AwayScore1H))))) THEN 1
								ELSE NULL
							END
						WHEN 'tie' THEN
							CASE 
								WHEN ((ip.HomeScore1H + ip.AwayScore1H >= 0) AND ((ip.HomeScore1H + ip.AwayScore1H) < ((ip.HomeScoreFT - ip.HomeScore1H + (ip.AwayScoreFT - ip.AwayScore1H))))) THEN -1
								ELSE NULL
							END
						ELSE NULL
					END
				WHEN @bettype IN (141) AND @isHT = 0 THEN --Highest Scoring Half Home Team
					CASE @betteam
						WHEN '1h' THEN
							CASE 
								WHEN (ip.HomeScore1H >= 0 AND (ip.HomeScoreFT - ip.HomeScore1H) > ip.HomeScore1H) THEN -1
								WHEN (ip.HomeScore1H >= 0 AND (ip.HomeScoreFT - ip.HomeScore1H) = ip.HomeScore1H) THEN -1
								ELSE NULL
							END
						WHEN '2h' THEN
							CASE 
								WHEN (ip.HomeScore1H >= 0 AND (ip.HomeScoreFT - ip.HomeScore1H) > ip.HomeScore1H) THEN 1
								ELSE NULL
							END
						WHEN 'tie' THEN
							CASE 
								WHEN (ip.HomeScore1H >= 0 AND (ip.HomeScoreFT - ip.HomeScore1H) > ip.HomeScore1H) THEN -1
								ELSE NULL
							END
						ELSE NULL
					END
				WHEN @bettype IN (142) AND @isHT = 0 THEN --Highest Scoring Half Away Team
					CASE @betteam
						WHEN '1h' THEN
							CASE 
								WHEN (ip.AwayScore1H >= 0 AND (ip.AwayScoreFT - ip.AwayScore1H) > ip.AwayScore1H ) THEN -1
								WHEN (ip.AwayScore1H >= 0 AND (ip.AwayScoreFT - ip.AwayScore1H) = ip.AwayScore1H ) THEN -1
								ELSE NULL
							END
						WHEN '2h' THEN
							CASE 
								WHEN (ip.AwayScore1H >= 0 AND (ip.AwayScoreFT - ip.AwayScore1H) > ip.AwayScore1H ) THEN 1
								ELSE NULL
							END
						WHEN 'tie' THEN
							CASE 
								WHEN (ip.AwayScore1H >= 0 AND (ip.AwayScoreFT - ip.AwayScore1H) > ip.AwayScore1H ) THEN -1
								ELSE NULL
							END
						ELSE NULL
					END
				WHEN @bettype IN (143) AND @isHT = 1 THEN	-- 1H Result/Total Goals
					CASE 
						WHEN RIGHT(@betteam,1) ='u' AND @hdp1 <= (ip.HomeScore1H + ip.AwayScore1H) - 0.5 THEN @hdp1 - (ip.HomeScore1H + ip.AwayScore1H)
						ELSE NULL
					END
				WHEN @bettype IN (144, 163) THEN	-- Result/Total Goals & (3rd)
					CASE 
						WHEN RIGHT(@betteam,1) = 'u' AND @hdp1 <= (ip.HomeScoreFT + ip.AwayScoreFT) - 0.5 THEN @hdp1 - (ip.HomeScoreFT + ip.AwayScoreFT)
						ELSE NULL
					END
				WHEN @bettype IN (145) THEN	-- Both Teams To Score
					CASE 
						WHEN @IsHT = 1 AND @betteam = 'y' AND ip.HomeScore1H > 0 AND ip.AwayScore1H > 0 THEN 1
						WHEN @IsHT = 1 AND @betteam = 'n' AND ip.HomeScore1H > 0 AND ip.AwayScore1H > 0 THEN -1
						WHEN @IsHT = 0 AND @betteam = 'y' AND ip.HomeScoreFT > 0 AND ip.AwayScoreFT > 0 THEN 1
						WHEN @IsHT = 0 AND @betteam = 'n' AND ip.HomeScoreFT > 0 AND ip.AwayScoreFT > 0 THEN -1
						ELSE NULL
					END 
				WHEN @bettype IN (146) AND @isHT = 0 THEN	-- 2H Both Teams To Score
					CASE 
						WHEN @IsHT = 0 AND @betteam = 'y' AND ip.HomeScore2H > 0 AND ip.AwayScore2H > 0 THEN 1
						WHEN @IsHT = 0 AND @betteam = 'n' AND ip.HomeScore2H > 0 AND ip.AwayScore2H > 0 THEN -1
						ELSE NULL
					END 
				WHEN @bettype IN (147) AND @IsHT = 0 THEN	-- Home To Score In Both Halves
					CASE 
						WHEN @betteam = 'y' AND ip.HomeScore1H = 0 THEN -1
						WHEN @betteam = 'n' AND ip.HomeScore1H = 0 THEN 1
						WHEN @betteam = 'y' AND ip.HomeScore1H > 0 AND ip.HomeScore2H > 0 THEN 1
						WHEN @betteam = 'n' AND ip.HomeScore1H > 0 AND ip.HomeScore2H > 0 THEN -1
						ELSE NULL
					END
				WHEN @bettype IN (148) AND @IsHT = 0 THEN	-- Away To Score In Both Halves
					CASE
						WHEN @betteam = 'y' AND ip.AwayScore1H = 0 THEN -1
						WHEN @betteam = 'n' AND ip.AwayScore1H = 0 THEN 1
						WHEN @betteam = 'y' AND ip.AwayScore1H > 0 AND (ip.AwayScoreFT - ip.AwayScore1H) > 0 THEN 1
						WHEN @betteam = 'n' AND ip.AwayScore1H > 0 AND (ip.AwayScoreFT - ip.AwayScore1H) > 0 THEN -1 
						ELSE NULL
					END
				WHEN @bettype IN (149) AND @IsHT = 0 THEN	-- Home To Win Either Half
					CASE 
						WHEN @betteam = 'y' AND ip.HomeScore1H > ip.AwayScore1H THEN 1
						WHEN @betteam = 'n' AND ip.HomeScore1H > ip.AwayScore1H THEN -1
						ELSE NULL
					END
				WHEN @bettype IN (150) AND @IsHT = 0 THEN	-- Away To Win Either Half
					CASE 
						WHEN @betteam = 'y' AND ip.AwayScore1H > ip.HomeScore1H THEN 1
						WHEN @betteam = 'n' AND ip.AwayScore1H > ip.HomeScore1H THEN -1
						ELSE NULL
					END
				WHEN @bettype IN (152) THEN	-- Half Time/Full Time Correct Score
					CASE 
						WHEN @IsHT = 1 AND LEFT(@betteam,2) = '4+' AND (ip.HomeScore1H + ip.AwayScore1H) >= 4 THEN 1
						WHEN @IsHT = 1 AND LEFT(@betteam,2) <> '4+' AND (LEFT(LEFT(@betteam,3),1) < ip.HomeScore1H OR RIGHT(LEFT(@betteam,3),1) < ip.AwayScore1H) THEN -1					
						WHEN @IsHT = 0 AND @betteam = '4+/4+' AND (ip.HomeScore1H + ip.AwayScore1H) >= 4 AND (ip.HomeScoreFT + ip.AwayScoreFT) >= 4 THEN 1
						WHEN @IsHT = 0 AND LEFT(@betteam,3) <> ip.CS1H THEN -1        
						WHEN @IsHT = 0 AND RIGHT(@betteam,2) = '4+' AND (ip.HomeScoreFT + ip.AwayScoreFT) >= 4 THEN 1
						WHEN @IsHT = 0 AND RIGHT(@betteam,2) <>'4+' AND (LEFT(RIGHT(@betteam,3),1) < ip.HomeScoreFT OR RIGHT(RIGHT(@betteam,3),1) < ip.AwayScoreFT) THEN -1
						ELSE NULL
					END
				WHEN @bettype IN (159,406) THEN	-- Exact Total Goals (3rd)
					CASE
						WHEN @betteam LIKE 'G[0-5]' THEN CASE WHEN ip.TotalGoal > CAST(RIGHT(@betteam,1) AS TINYINT) THEN -1 ELSE NULL END
						WHEN @betteam = 'G6' AND ip.TotalGoal >= 6 THEN 1 
						ELSE NULL
					END
				WHEN @bettype IN (161,407) THEN	-- Exact Home Team Goals
					CASE
						WHEN @betteam LIKE 'G[0-2]' THEN CASE WHEN ip.HomeScoreFT > RIGHT(@betteam,1) THEN -1 ELSE NULL END
						WHEN @betteam ='G3' AND ip.HomeScoreFT >= 3 THEN 1 
						ELSE NULL
					END
				WHEN @bettype IN (162,409) THEN	-- Exact Away Team Goals
					CASE
						WHEN @betteam LIKE 'G[0-2]' THEN CASE WHEN ip.AwayScoreFT > RIGHT(@betteam,1) THEN -1 ELSE NULL END
						WHEN @betteam ='G3' AND ip.AwayScoreFT >= 3 THEN 1 
						ELSE NULL
					END
				
				--#170
				WHEN @bettype IN (170) THEN	-- Teams To Score
					CASE
						WHEN @betteam = 'b' AND ip.HomeScoreFT > 0 AND ip.AwayScoreFT > 0 THEN 1
						WHEN @betteam = 'n' AND (ip.HomeScoreFT > 0 OR ip.AwayScoreFT > 0) THEN -1
						WHEN @betteam = 'h' AND ip.AwayScoreFT > 0 THEN -1
						WHEN @betteam = 'a' AND ip.HomeScoreFT > 0 THEN -1
						ELSE NULL
					END
				
				--#179
				WHEN @bettype IN (179) AND @isHT = 1 THEN	-- Exact 1H Goals
					CASE
						WHEN @betteam LIKE 'G[0-3]' THEN CASE WHEN ip.TotalGoal1H > RIGHT(@betteam,1) THEN -1 ELSE NULL END
						WHEN @betteam ='G4' AND ip.TotalGoal1H >= 4 THEN 1 			
						ELSE NULL
					END
				WHEN @bettype IN (181) AND @isHT = 1 THEN	-- 1H Home Team Goals
					CASE
						WHEN @betteam LIKE 'G[0-2]' THEN CASE WHEN ip.HomeScore1H > RIGHT(@betteam,1) THEN -1 ELSE NULL END
						WHEN @betteam ='G3' AND ip.HomeScore1H >= 3 THEN 1 
						ELSE NULL
					END
				WHEN @bettype IN (182) AND @isHT = 1 THEN	-- 1H Away Team Goals
					CASE
						WHEN @betteam LIKE 'G[0-2]' THEN CASE WHEN ip.AwayScore1H > RIGHT(@betteam,1) THEN -1 ELSE NULL END
						WHEN @betteam ='G3' AND ip.AwayScore1H >= 3 THEN 1 
						ELSE NULL
					END
				
				--#187
				WHEN @bettype IN (187) AND @isHT = 0 THEN	-- Exact 2H Goals
					CASE
						WHEN @betteam LIKE 'G[0-1]' THEN CASE WHEN ip.TotalGoal2H > RIGHT(@betteam,1) THEN -1 ELSE NULL END
						WHEN @betteam ='G2' AND ip.TotalGoal2H >= 2 THEN 1 
						ELSE NULL
					END
				--#188,427
				WHEN @bettype IN (188, 427) AND @isHT = 1 THEN	-- 1H Both Teams To Score
					CASE 
						WHEN @betteam = 'n' AND (ip.HomeScore1H > 0 AND ip.AwayScore1H > 0) THEN -1
						WHEN @betteam = 'y' AND (ip.HomeScore1H > 0 AND ip.AwayScore1H > 0) THEN 1					
						ELSE NULL
					END
				--#189-434
				WHEN @bettype IN (189,434) AND @IsHT = 0 THEN --refund FT with SDT
					CASE
						WHEN @betteam = 'y' AND ip.TotalGoal1H < 1.5 THEN -1
						WHEN @betteam = 'n' AND ip.TotalGoal1H < 1.5 THEN 1
						WHEN @betteam = 'y' AND ip.TotalGoal1H > 1.5 AND ip.TotalGoal2H > 1.5 THEN 1
						WHEN @betteam = 'n' AND ip.TotalGoal1H > 1.5 AND ip.TotalGoal2H > 1.5 THEN -1
						ELSE NULL 
					END
				--#190-435
				WHEN @bettype IN (190,435) THEN 
					CASE 
						WHEN @isHT = 1 THEN --1H
							CASE
								WHEN @betteam = 'y' AND ip.TotalGoal1H > 1.5 THEN -1
								WHEN @betteam = 'n' AND ip.TotalGoal1H > 1.5 THEN 1
								ELSE NULL
							END
						WHEN @isHT = 0 THEN --2H
							CASE
								WHEN @betteam = 'y' AND ip.TotalGoal1H > 1.5 THEN -1
								WHEN @betteam = 'n' AND ip.TotalGoal1H > 1.5 THEN 1
								WHEN @betteam = 'y' AND ip.TotalGoal1H < 1.5 AND ip.TotalGoal2H > 1.5 THEN -1
								WHEN @betteam = 'n' AND ip.TotalGoal1H < 1.5 AND ip.TotalGoal2H > 1.5 THEN 1
								ELSE NULL
							END
						ELSE NULL
					END		
				--#405
				WHEN @bettype IN (405) AND @isHT = 0 THEN --2H Correct Score
					CASE 
						WHEN @betteam NOT IN ('AOS') THEN CASE WHEN (ip.HomeScore2H > LEFT(@betteam,1) OR ip.AwayScore2H > RIGHT(@betteam,1)) THEN -1 ELSE NULL END
						WHEN @betteam IN ('AOS') AND CHARINDEX(CAST((ip.HomeScore2H) AS VARCHAR) + ':' + CAST((ip.AwayScore2H) AS VARCHAR), @transdesc) = 0 THEN 1
						ELSE NULL
					END	
					
				WHEN @bettype IN ( 408 ) THEN
					CASE 
						WHEN @betteam = 'NG' AND ip.TotalGoal > 0 THEN -1
						ELSE NULL
					END
				--#412
				WHEN @bettype IN (412) AND @isHT = 1 THEN --Exact 1st Half Goal
					CASE
						WHEN @betteam IN ('3-over') THEN CASE WHEN ip.TotalGoal1H >= 3 THEN 1 ELSE NULL END
						WHEN ip.TotalGoal1H > CAST(@betteam AS INT) THEN -1 
						ELSE NULL
					END
				--#413
				WHEN @bettype IN (413) THEN --Correct Score (AOS)
					CASE
						WHEN @betteam = 'AOS' THEN CASE WHEN CHARINDEX(CAST(ip.HomeScoreFT AS VARCHAR) + ':' + CAST(ip.AwayScoreFT AS VARCHAR), @transdesc) = 0 THEN 1 ELSE NULL END
						WHEN (ip.HomeScoreFT > LEFT(@betteam,1) OR ip.AwayScoreFT > RIGHT(@betteam,1)) THEN -1
						ELSE NULL
					END
				--#414
				WHEN @bettype IN (414) AND @isHT = 1 THEN --1H Correct Score (AOS)
					CASE
						WHEN @betteam = 'AOS' THEN CASE WHEN CHARINDEX(CAST(ip.HomeScore1H AS VARCHAR) + ':' + CAST(ip.AwayScore1H AS VARCHAR), @transdesc) = 0 THEN 1 ELSE NULL END
						WHEN @betteam NOT IN ('AOS') AND (ip.HomeScore1H > LEFT(@betteam,1) OR ip.AwayScore1H > RIGHT(@betteam,1)) THEN -1
						ELSE NULL
					END
				--#416
				WHEN @bettype IN (416) THEN --Half Time/Full Time Correct Score (AOS)
					CASE
						WHEN @IsHT = 1 THEN --abandoned 1H
							CASE 
								WHEN ip.betteam1H <> 'AOS' THEN 
									CASE
										WHEN CAST(LEFT(ip.betteam1H,1) AS INT) < ip.HomeScore1H OR CAST(RIGHT(ip.betteam1H,1) AS INT) < ip.AwayScore1H THEN -1
										ELSE NULL
									END
								ELSE
									CASE
										WHEN ip.betteamFT = 'AOS' THEN CASE WHEN ip.HomeScore1H > 4 OR ip.AwayScore1H > 4 THEN 1 ELSE NULL END
										WHEN LEFT(ip.betteamFT,1) < ip.HomeScore1H OR RIGHT(ip.betteamFT,1) < ip.AwayScore1H THEN -1
										ELSE NULL
									END
							END
						ELSE CASE --abandoned 2H
								WHEN ip.betteam1H <> 'AOS' THEN 
									CASE
										WHEN CAST(LEFT(ip.betteam1H,1) AS INT) <> ip.HomeScore1H OR CAST(RIGHT(ip.betteam1H,1) AS INT) <> ip.AwayScore1H THEN -1
										WHEN ip.betteamFT <> 'AOS' THEN CASE WHEN LEFT(ip.betteamFT,1) < ip.HomeScoreFT OR RIGHT(ip.betteamFT,1) < ip.AwayScoreFT THEN -1 END
										WHEN CAST(LEFT(ip.betteam1H,1) AS INT) = ip.HomeScore1H AND CAST(RIGHT(ip.betteam1H,1) AS INT) = ip.AwayScore1H AND CHARINDEX(CAST(ip.HomeScoreFT AS NVARCHAR(10)) + ':' + CAST(ip.AwayScoreFT AS NVARCHAR(10)),ip.ExcludingFTChoice) = 0 THEN 1
										ELSE NULL
									END
								ELSE 
									CASE 
										WHEN CHARINDEX(CAST(ip.HomeScore1H AS NVARCHAR(10)) + ':' + CAST(ip.AwayScore1H AS NVARCHAR(10)),ip.ExcludingHTChoice) > 0 THEN -1
										WHEN ip.betteamFT <> 'AOS' THEN CASE WHEN LEFT(ip.betteamFT,1) < ip.HomeScoreFT OR RIGHT(ip.betteamFT,1) < ip.AwayScoreFT THEN -1 END
										WHEN CHARINDEX(CAST(ip.HomeScoreFT AS NVARCHAR(10)) + ':' + CAST(ip.AwayScoreFT AS NVARCHAR(10)),ip.ExcludingFTChoice) = 0 THEN 1
										ELSE NULL
									END
							END	
					END
				WHEN @bettype IN (417) THEN --Both Team Score / Result
					CASE
						WHEN LEFT(@betteam,1) = 'N' THEN 
							CASE
								WHEN ip.HomeScoreFT > 0 AND ip.AwayScoreFT > 0 THEN -1
								WHEN ip.HomeScoreFT > ip.AwayScoreFT AND RIGHT(@betteam,1) IN ('A','D') THEN -1
								WHEN ip.HomeScoreFT < ip.AwayScoreFT AND RIGHT(@betteam,1) IN ('H','D') THEN -1
								ELSE NULL
							END
						ELSE NULL
					END
				WHEN @bettype IN (418) THEN --Both Teams to Score/ Total Goal
					CASE 
						WHEN (ip.HomeScoreFT > 0 AND ip.AwayScoreFT > 0) THEN
							CASE 
								WHEN (ip.HomeScoreFT + ip.AwayScoreFT < @hdp1) THEN
									CASE
										WHEN LEFT(@betteam,1) = 'N' THEN -1
										ELSE NULL
									END
								WHEN (ip.HomeScoreFT + ip.AwayScoreFT > @hdp1) THEN
									CASE
										WHEN @betteam = 'YO' THEN 1
										WHEN @betteam = 'YU' THEN -1
										WHEN @betteam = 'NO' THEN -1
										WHEN @betteam = 'NU' THEN -1
										ELSE NULL
									END
								ELSE NULL
							END
						WHEN (ip.HomeScoreFT > 0 OR ip.AwayScoreFT > 0) AND (ip.HomeScoreFT + ip.AwayScoreFT > @hdp1) THEN 
							CASE
								WHEN RIGHT(@betteam,1) = 'U' THEN -1
								ELSE NULL
							END
						ELSE NULL
					END
				WHEN @bettype IN (419) THEN --Which Half First Goal
					CASE    
						WHEN ip.HomeScoreFT + ip.AwayScoreFT > 0 THEN 
							CASE
								WHEN @betteam = '1H' AND ip.HomeScore1H + ip.AwayScore1H > 0 THEN 1
								WHEN @betteam = '2H' AND ip.HomeScore1H + ip.AwayScore1H = 0 THEN 1
								ELSE -1
							END
						WHEN @IsHT = 0 AND ip.HomeScoreFT + ip.AwayScoreFT = 0 THEN 
							CASE 
								WHEN @betteam = '1H' THEN -1
								ELSE NULL
							END                                                                                      
						ELSE NULL
					END
				WHEN @bettype IN (420) THEN --Home Team Which Half First Goal
					CASE    
						WHEN ip.HomeScoreFT > 0 THEN 
							CASE
								WHEN @betteam = '1H' AND ip.HomeScore1H > 0 THEN 1
								WHEN @betteam = '2H' AND ip.HomeScore1H = 0 THEN 1
								ELSE -1
							END
						WHEN @IsHT = 0 AND ip.HomeScoreFT = 0 THEN 
							CASE 
								WHEN @betteam = '1H' THEN -1
								ELSE NULL
							END				
						ELSE NULL
					END
				WHEN @bettype IN (421) THEN --Away Team Which Half First Goal
					CASE    
						WHEN ip.AwayScoreFT > 0 THEN 
							CASE
								WHEN @betteam = '1H' AND ip.AwayScore1H > 0 THEN 1
								WHEN @betteam = '2H' AND ip.AwayScore1H = 0 THEN 1
								ELSE -1
							END
						WHEN @IsHT = 0 AND ip.AwayScoreFT = 0 THEN 
							CASE 
								WHEN @betteam = '1H' THEN -1
								ELSE NULL
							END
						ELSE NULL
					END
				WHEN @bettype IN (426) AND @isHT = 1 THEN --1H Winning Margin
					CASE
						WHEN @betteam = 'NG' AND ip.TotalGoal1H > 0 THEN -1
						ELSE NULL
					END
				WHEN @bettype IN (429) AND @IsHT = 0 AND ip.TotalGoal2H > 0 THEN --Exact 2nd Half Goal
					CASE
						WHEN @betteam IN ('3-over','3&over') THEN 
							CASE 
								WHEN ip.TotalGoal2H >= 3 THEN 1 
								ELSE NULL 
							END
						ELSE 
							CASE
								WHEN ip.TotalGoal2H > CAST(@betteam AS INT) THEN -1
								ELSE NULL
							END
					END
						
				WHEN @bettype IN (433) AND @isHT = 0 THEN --2H Both Teams To Score (own)
					CASE 
						WHEN @betteam = 'y' AND ip.HomeScore2H > 0 AND ip.AwayScore2H > 0 THEN 1
						WHEN @betteam = 'n' AND ip.HomeScore2H > 0 AND ip.AwayScore2H > 0 THEN -1
						ELSE NULL
					END
				WHEN @bettype IN (436) AND @isHT = 0 THEN --Home To Score In Both Halves (own)
					CASE 
						WHEN @betteam = 'y' AND ip.HomeScore1H = 0 THEN -1
						WHEN @betteam = 'n' AND ip.HomeScore1H = 0 THEN 1
						WHEN @betteam = 'y' AND ip.HomeScore1H > 0 AND ip.HomeScore2H > 0 THEN 1
						WHEN @betteam = 'n' AND ip.HomeScore1H > 0 AND ip.HomeScore2H > 0 THEN -1
						ELSE NULL
					END
				WHEN @bettype IN (437) AND @isHT = 0 THEN --Away To Score In Both Halves (own)
					CASE
						WHEN @betteam = 'y' AND ip.AwayScore1H = 0 THEN -1
						WHEN @betteam = 'n' AND ip.AwayScore1H = 0 THEN 1
						WHEN @betteam = 'y' AND ip.AwayScore1H > 0 AND ip.AwayScore2H > 0 THEN 1
						WHEN @betteam = 'n' AND ip.AwayScore1H > 0 AND ip.AwayScore2H > 0 THEN -1 
						ELSE NULL
					END   
				WHEN @bettype IN (438) AND @isHT = 0 THEN --Home To Win Both Halves (own)
					CASE 
						WHEN @betteam = 'y' AND ip.HomeScore1H <= ip.AwayScore1H THEN -1
						WHEN @betteam = 'n' AND ip.HomeScore1H <= ip.AwayScore1H THEN 1
						ELSE NULL
					END  
				WHEN @bettype IN (439) AND @isHT = 0 THEN --Away To Win Both Halves (own)
					CASE 
						WHEN @betteam = 'y' AND ip.AwayScore1H <= ip.HomeScore1H THEN -1
						WHEN @betteam = 'n' AND ip.AwayScore1H <= ip.HomeScore1H THEN 1
						ELSE NULL
					END  
				WHEN @bettype IN (440) AND @isHT = 0 THEN --Home To Win Either Half (own)
					CASE 
						WHEN @betteam = 'y' AND ip.HomeScore1H > ip.AwayScore1H THEN 1
						WHEN @betteam = 'n' AND ip.HomeScore1H > ip.AwayScore1H THEN -1
						ELSE NULL
					 END
				WHEN @bettype IN (441) AND @isHT = 0 THEN --Away To Win Either Half (own)
					CASE 
						WHEN @betteam = 'y' AND ip.AwayScore1H > ip.HomeScore1H THEN 1
						WHEN @betteam = 'n' AND ip.AwayScore1H > ip.HomeScore1H THEN -1
						ELSE NULL
					 END
				WHEN @bettype IN (442) AND @IsHT = 0 THEN --Highest Scoring Half (own)
					CASE @betteam
						WHEN '1h' THEN
							CASE 
								WHEN ((ip.TotalGoal1H >= 0) AND (ip.TotalGoal1H < ip.TotalGoal2H)) THEN -1
								WHEN ((ip.TotalGoal1H >= 0) AND (ip.TotalGoal1H = ip.TotalGoal2H)) THEN -1
								ELSE NULL
							END
						WHEN '2h' THEN
							CASE 
								WHEN ((ip.TotalGoal1H >= 0) AND (ip.TotalGoal1H < ip.TotalGoal2H)) THEN 1
								ELSE NULL
							END
						WHEN 'tie' THEN
							CASE 
								WHEN ((ip.TotalGoal1H >= 0) AND (ip.TotalGoal1H < ip.TotalGoal2H)) THEN -1
								ELSE NULL
							END
						ELSE NULL
					END
				WHEN @bettype IN (443) AND @IsHT = 0 THEN --Highest Scoring Half Home Team (own)
					CASE @betteam
						WHEN '1h' THEN
							CASE 
								WHEN (ip.HomeScore1H >= 0 AND ip.HomeScore2H > ip.HomeScore1H) THEN -1
								WHEN (ip.HomeScore1H >= 0 AND ip.HomeScore2H = ip.HomeScore1H) THEN -1
								ELSE NULL
							END
						WHEN '2h' THEN
							CASE 
								WHEN (ip.HomeScore1H >= 0 AND ip.HomeScore2H > ip.HomeScore1H) THEN 1
								ELSE NULL
							END
						WHEN 'tie' THEN
							CASE 
								WHEN (ip.HomeScore1H >= 0 AND ip.HomeScore2H > ip.HomeScore1H) THEN -1
								ELSE NULL
							END
						ELSE NULL
					END
				WHEN @bettype IN (444) AND @IsHT = 0 THEN --Highest Scoring Half Away Team (own)
					CASE @betteam
						WHEN '1h' THEN
							CASE 
								WHEN (ip.AwayScore1H >= 0 AND ip.AwayScore2H > ip.AwayScore1H ) THEN -1
								WHEN (ip.AwayScore1H >= 0 AND ip.AwayScore2H = ip.AwayScore1H ) THEN -1
								ELSE NULL
							END
						WHEN '2h' THEN
							CASE 
								WHEN (ip.AwayScore1H >= 0 AND ip.AwayScore2H > ip.AwayScore1H ) THEN 1
								ELSE NULL
							END
						WHEN 'tie' THEN
							CASE 
								WHEN (ip.AwayScore1H >= 0 AND ip.AwayScore2H > ip.AwayScore1H ) THEN -1
								ELSE NULL
							END
						ELSE NULL
					END
				WHEN @bettype IN (445) THEN --Both Team To Score in 1H / 2H
					CASE 
						WHEN @IsHT = 1 THEN --abandoned 1H
							CASE 
								WHEN (ip.HomeScore1H > 0 AND ip.AwayScore1H > 0 AND LEFT(@betteam,1) = 'N') THEN -1 --both of teams have scored
								ELSE NULL
							END
						WHEN @IsHT = 0 THEN --abandoned 2H
							CASE 
								WHEN (ip.TotalGoal2H = 0 OR (ip.TotalGoal2H > 0 AND (ip.HomeScore2H = 0 OR ip.AwayScore2H = 0))) THEN  --not both teams haved score
									CASE 
										WHEN (ip.TotalGoal1H = 0 OR (ip.TotalGoal1H > 0 AND (ip.HomeScore1H = 0 OR ip.AwayScore1H = 0) )) THEN
											CASE 
												WHEN @betteam = 'YY' THEN -1
												WHEN @betteam = 'YN' THEN -1
												ELSE NULL
											END
										WHEN (ip.HomeScore1H > 0 AND ip.AwayScore1H > 0) THEN
											CASE
												WHEN @betteam = 'NY' THEN -1
												WHEN @betteam = 'NN' THEN -1
												ELSE NULL
											END
										ELSE NULL
									END
								WHEN (ip.HomeScore2H > 0 AND ip.AwayScore2H > 0) THEN --both teams have scored
									CASE
										WHEN (ip.TotalGoal1H = 0 OR (ip.TotalGoal1H) > 0 and (ip.HomeScore1H = 0 OR ip.AwayScore1H = 0)) THEN
											CASE
												WHEN @betteam = 'YY' THEN -1
												WHEN @betteam = 'YN' THEN -1
												WHEN @betteam = 'NY' THEN 1
												WHEN @betteam = 'NN' THEN -1
												ELSE NULL
											END
										WHEN (ip.HomeScore1H > 0 AND ip.AwayScore1H > 0) THEN 
											CASE
												WHEN @betteam = 'YY' THEN 1
												WHEN @betteam = 'YN' THEN -1
												WHEN @betteam = 'NY' THEN -1
												WHEN @betteam = 'NN' THEN -1
												ELSE NULL
											END    
										ELSE NULL 
									END
								ELSE NULL 
							END
						END
				WHEN @bettype IN (446) THEN --Home 1H to Score/ 2H To Score
					CASE 
						WHEN @IsHT = 1 THEN --1H
							CASE
								WHEN ip.HomeScore1H > 0 AND LEFT(@betteam,1) = 'N' THEN -1
								ELSE NULL
							END
						WHEN @IsHT = 0 THEN --2H
							CASE
								WHEN ip.HomeScoreFT = 0 AND LEFT(@betteam,1) = 'Y' THEN -1
								WHEN ip.HomeScoreFT > 0 THEN
									CASE
										WHEN ip.HomeScore1H = 0 AND LEFT(@betteam,1) = 'Y' THEN -1
										WHEN ip.HomeScore1H = 0 AND @betteam = 'NN' THEN -1
										WHEN ip.HomeScore1H = 0 AND @betteam = 'NY' THEN 1
										WHEN ip.HomeScoreFT = ip.HomeScore1H AND LEFT(@betteam,1) = 'N' THEN -1
										WHEN ip.HomeScore1H > 0 AND ip.HomeScore2H > 0 THEN 
											CASE
												WHEN @betteam = 'YY' THEN 1
												ELSE -1
											END
										ELSE NULL
									END
								ELSE NULL
							END
						ELSE NULL
					END
				WHEN @bettype IN (447) THEN --Away 1H to Score/ 2H To Score
					CASE 
						WHEN @IsHT = 1 THEN --1H
							CASE
								WHEN LEFT(@betteam,1) = 'N' AND ip.AwayScore1H > 0 THEN -1
								ELSE NULL
							END
						WHEN @IsHT = 0 THEN --2H
							CASE
								WHEN ip.AwayScoreFT = 0 THEN
									CASE
										WHEN LEFT(@betteam,1) = 'Y' THEN -1
										ELSE NULL
									END
								WHEN ip.AwayScoreFT > 0 THEN
									CASE
										WHEN ip.AwayScore1H = 0 AND LEFT(@betteam,1) = 'Y' THEN -1
										WHEN ip.AwayScore1H = 0 AND @betteam = 'NN' THEN -1
										WHEN ip.AwayScore1H = 0 AND @betteam = 'NY' THEN 1
										WHEN ip.AwayScoreFT = ip.AwayScore1H AND LEFT(@betteam,1) = 'N' THEN -1
										WHEN ip.AwayScore1H > 0 AND ip.AwayScore2H > 0 THEN 
											CASE
												WHEN @betteam = 'YY' THEN 1
												ELSE -1
											END
										ELSE NULL
									END
								ELSE NULL
							END
						ELSE NULL
					END
				  --456: 1H Both Teams To Score / Result
				  WHEN @bettype = 456 THEN CASE
											WHEN LEFT(@betteam,1) = 'N' THEN CASE
																				WHEN ip.HomeScore1H > 0 AND ip.AwayScore1H > 0 THEN -1
																				ELSE NULL
																			END
											ELSE NULL
										END
				--457: 1H Both Teams To Score / Total Goals				
				WHEN  @bettype = 457 THEN CASE
											WHEN  LEFT(@betteam,1) = 'N' AND ip.HomeScore1H > 0 AND ip.AwayScore1H > 0 THEN -1
											WHEN  RIGHT(@betteam,1) = 'U' AND ip.TotalGoal1H > @hdp1 THEN -1
											WHEN @betteam ='YO' AND ip.HomeScore1H > 0 AND ip.AwayScore1H > 0 AND ip.TotalGoal1H > @hdp1 THEN 1
											ELSE NULL
										END
				
				--449: Double Chance & Total Goals
				WHEN @bettype = 449 THEN CASE 
											WHEN RIGHT(@betteam,1) = 'U' AND ip.TotalGoal > @hdp1 THEN -1
											ELSE NULL
										END	
				
				--450: Odd/Even & Total Goals
				WHEN @bettype = 450 THEN CASE 
											WHEN RIGHT(@betteam,1) = 'U' AND ip.TotalGoal > @hdp1 THEN -1
											ELSE NULL
										END
				--451: Both Teams To Score / Double Chance
				WHEN @bettype = 451 THEN CASE
											WHEN LEFT(@betteam,1) = 'N' AND ip.HomeScoreFT > 0 AND ip.AwayScoreFT > 0 THEN -1
											ELSE NULL
										  END
				--452: Highest Scoring Half (2 Way)
				                                                            
				WHEN @bettype = 452 THEN CASE
											 WHEN @isHT = 0 THEN CASE
																		WHEN @betteam = '1H' AND ip.HomeScore1H	+  ip.AwayScore1H < ip.HomeScore2H	+  ip.AwayScore2H THEN -1
																		WHEN @betteam = '2H' AND ip.HomeScore1H	+  ip.AwayScore1H < ip.HomeScore2H	+  ip.AwayScore2H THEN 1
																		ELSE NULL
																	END	
                                             ELSE NULL	
                                          END   
				
				-- #112885 - PH4
				WHEN @bettype = 467 THEN -- HT/FT Exact Total Goal
					CASE WHEN @isHT = 1 THEN -- suspended in HT 
							CASE 
								WHEN ip.TotalGoal1H >= 7 AND @betteam = 'G7+/G7+' THEN 1
								WHEN (SUBSTRING(@betteam, 2,1) < ip.TotalGoal1H AND SUBSTRING(@betteam, 2,1) < 7) THEN -1
								ELSE NULL
							END
						ELSE -- suspended in FT
							CASE 
								WHEN ip.TotalGoal1H >= 7 AND @betteam = 'G7+/G7+' THEN 1
								WHEN ip.TotalGoal1H = 0 AND ip.TotalGoal >= 7 AND @betteam = 'G0/G7+' THEN 1
								WHEN ip.TotalGoal1H = 1 AND ip.TotalGoal >= 7 AND @betteam = 'G1/G7+' THEN 1
								WHEN ip.TotalGoal1H = 2 AND ip.TotalGoal >= 7 AND @betteam = 'G2/G7+' THEN 1
								WHEN ip.TotalGoal1H = 3 AND ip.TotalGoal >= 7 AND @betteam = 'G3/G7+' THEN 1
								WHEN ip.TotalGoal1H = 4 AND ip.TotalGoal >= 8 AND @betteam = 'G4/G8+' THEN 1
								WHEN ip.TotalGoal1H = 5 AND ip.TotalGoal >= 9 AND @betteam = 'G5/G9+' THEN 1
								WHEN ip.TotalGoal1H = 6 AND ip.TotalGoal >= 10 AND @betteam = 'G6/G10+' THEN 1
								WHEN SUBSTRING(@betteam, 2,1) <> ip.TotalGoal1H THEN -1
								WHEN SUBSTRING(@betteam, 2,1) = ip.TotalGoal1H AND REPLACE(SUBSTRING(@betteam, CHARINDEX('/G',@betteam) + 2, LEN(@betteam)),'+','') < ip.TotalGoal THEN -1
								WHEN SUBSTRING(@betteam, 2,1) = ip.TotalGoal1H AND REPLACE(SUBSTRING(@betteam, CHARINDEX('/G',@betteam) + 2, LEN(@betteam)),'+','') >= ip.TotalGoal THEN NULL
								ELSE NULL
							END
					END               			  							 					
				-- Total Corners
				WHEN @bettype IN (473) THEN--Total Goal
											CASE 
												 WHEN @betteam = '0-5' and IP.TotalGoal > 5 THEN -1
												WHEN @betteam = '6-8' and IP.TotalGoal > 8 THEN -1
												WHEN @betteam = '9-11' and IP.TotalGoal > 11 THEN -1
												WHEN @betteam = '12-14' and IP.TotalGoal > 14 THEN -1
												WHEN @betteam = '15+' and IP.TotalGoal >= 15 THEN 1
												ELSE NULL
											END		  		
						
				-- 1H Total Corners			
				WHEN @bettype IN (474) THEN--Total Goal
											CASE WHEN @betteam = '0-2' and IP.TotalGoal1H > 2 THEN -1
												WHEN @betteam = '3-4' and IP.TotalGoal1H > 4 THEN -1
												WHEN @betteam = '5-6' and IP.TotalGoal1H > 6 THEN -1
												WHEN @betteam = '7+' and IP.TotalGoal1H >= 7 THEN 1
												ELSE NULL 
											END		 			
					
				-- Alternative Corners
				WHEN @bettype IN (475) THEN 
											CASE WHEN @betteam = 'o' AND IP.TotalGoal > @hdp1 THEN 1
												WHEN @betteam = 'u' AND IP.TotalGoal >= @hdp1 THEN -1
												WHEN @betteam = 'e' AND IP.TotalGoal > @hdp1 THEN -1
												ELSE NULL
											END		
				-- 1H Alternative Corners
				WHEN @bettype IN (476) THEN CASE WHEN @betteam = 'o' AND IP.TotalGoal1H > @hdp1 THEN 1
														WHEN @betteam = 'u' AND IP.TotalGoal1H >= @hdp1 THEN -1
														WHEN @betteam = 'e' AND IP.TotalGoal1H > @hdp1 THEN -1
														ELSE NULL
													END
				-- HT/FT Total Corners
				WHEN @bettype IN (493) THEN 
					CASE WHEN @IsHT = 1 THEN -- suspended in HT 
							CASE 
								WHEN @betteam = 'AOS' THEN CASE WHEN CHARINDEX(
																				CASE WHEN IP.TotalGoal1H = 0 AND IP.TotalGoal >= 8 THEN '0/8+'
																					WHEN IP.TotalGoal1H = 1 AND IP.TotalGoal >= 9 THEN '1/9+'  
																					WHEN IP.TotalGoal1H = 2 AND IP.TotalGoal >= 10 THEN '2/10+'
																					WHEN IP.TotalGoal1H = 3 AND IP.TotalGoal >= 11 THEN '3/11+'
																					WHEN IP.TotalGoal1H = 4 AND IP.TotalGoal >= 12 THEN '4/12+'
																					WHEN IP.TotalGoal1H = 5 AND IP.TotalGoal >= 13 THEN '5/13+'
																					WHEN IP.TotalGoal1H = 6 AND IP.TotalGoal >= 14 THEN '6/14+'
																					WHEN IP.TotalGoal1H IN (7,8,9) AND IP.TotalGoal >= 15 THEN CAST(IP.TotalGoal1H AS VARCHAR(5)) + '/15+'
																				ELSE CAST(IP.TotalGoal1H AS VARCHAR(5)) + '/' + CAST(IP.TotalGoal AS VARCHAR(5))
																				END, @transdesc
																			) = 0 THEN 1
																ELSE NULL END
								WHEN @betteam <> 'AOS' AND LEFT(@betteam, 1) < IP.TotalGoal1H THEN -1
								ELSE NULL
							END
						WHEN @IsHT = 0 THEN -- suspended in FT
							CASE 
								WHEN @betteam = 'AOS' THEN CASE WHEN CHARINDEX(
																				CASE WHEN IP.TotalGoal1H = 0 AND IP.TotalGoal >= 8 THEN '0/8+'
																					WHEN IP.TotalGoal1H = 1 AND IP.TotalGoal >= 9 THEN '1/9+'  
																					WHEN IP.TotalGoal1H = 2 AND IP.TotalGoal >= 10 THEN '2/10+'
																					WHEN IP.TotalGoal1H = 3 AND IP.TotalGoal >= 11 THEN '3/11+'
																					WHEN IP.TotalGoal1H = 4 AND IP.TotalGoal >= 12 THEN '4/12+'
																					WHEN IP.TotalGoal1H = 5 AND IP.TotalGoal >= 13 THEN '5/13+'
																					WHEN IP.TotalGoal1H = 6 AND IP.TotalGoal >= 14 THEN '6/14+'
																					WHEN IP.TotalGoal1H IN (7,8,9) AND IP.TotalGoal >= 15 THEN CAST(IP.TotalGoal1H AS VARCHAR(5)) + '/15+'
																				ELSE CAST(IP.TotalGoal1H AS VARCHAR(5)) + '/' + CAST(IP.TotalGoal AS VARCHAR(5))
																				END, @transdesc
																			) = 0 THEN 1
																WHEN CHARINDEX(
																				CASE WHEN IP.TotalGoal1H = 0 AND IP.TotalGoal >= 8 THEN '0/8+'
																					WHEN IP.TotalGoal1H = 1 AND IP.TotalGoal >= 9 THEN '1/9+'  
																					WHEN IP.TotalGoal1H = 2 AND IP.TotalGoal >= 10 THEN '2/10+'
																					WHEN IP.TotalGoal1H = 3 AND IP.TotalGoal >= 11 THEN '3/11+'
																					WHEN IP.TotalGoal1H = 4 AND IP.TotalGoal >= 12 THEN '4/12+'
																					WHEN IP.TotalGoal1H = 5 AND IP.TotalGoal >= 13 THEN '5/13+'
																					WHEN IP.TotalGoal1H = 6 AND IP.TotalGoal >= 14 THEN '6/14+'
																					WHEN IP.TotalGoal1H IN (7,8,9) AND IP.TotalGoal >= 15 THEN CAST(IP.TotalGoal1H AS VARCHAR(5)) + '/15+'
																				ELSE CAST(IP.TotalGoal1H AS VARCHAR(5)) + '/' + CAST(IP.TotalGoal AS VARCHAR(5))
																				END, @transdesc
																			) > 0
																			AND 
																			CHARINDEX(
																				CASE WHEN IP.TotalGoal1H = 0 THEN '0/8+'
																					WHEN IP.TotalGoal1H = 1 THEN '1/9+'  
																					WHEN IP.TotalGoal1H = 2 THEN '2/10+'
																					WHEN IP.TotalGoal1H = 3 THEN '3/11+'
																					WHEN IP.TotalGoal1H = 4 THEN '4/12+'
																					WHEN IP.TotalGoal1H = 5 THEN '5/13+'
																					WHEN IP.TotalGoal1H = 6 THEN '6/14+'
																					WHEN IP.TotalGoal1H IN (7,8,9) THEN CAST(IP.TotalGoal1H AS VARCHAR(5)) + '/15+'
																				END, @transdesc
																			) > 0 THEN -1
																ELSE NULL END
								ELSE CASE WHEN IP.TotalGoal1H = 0 AND IP.TotalGoal >= 8 AND @betteam = '0/8+' THEN 1
											WHEN IP.TotalGoal1H = 1 AND IP.TotalGoal >= 9 AND @betteam = '1/9+' THEN 1
											WHEN IP.TotalGoal1H = 2 AND IP.TotalGoal >= 10 AND @betteam = '2/10+' THEN 1
											WHEN IP.TotalGoal1H = 3 AND IP.TotalGoal >= 11 AND @betteam = '3/11+' THEN 1
											WHEN IP.TotalGoal1H = 4 AND IP.TotalGoal >= 12 AND @betteam = '4/12+' THEN 1
											WHEN IP.TotalGoal1H = 5 AND IP.TotalGoal >= 13 AND @betteam = '5/13+' THEN 1
											WHEN IP.TotalGoal1H = 6 AND IP.TotalGoal >= 14 AND @betteam = '6/14+' THEN 1
											WHEN IP.TotalGoal1H = 7 AND IP.TotalGoal >= 15 AND @betteam = '7/15+' THEN 1
											WHEN IP.TotalGoal1H = 8 AND IP.TotalGoal >= 15 AND @betteam = '8/15+' THEN 1
											WHEN IP.TotalGoal1H = 9 AND IP.TotalGoal >= 15 AND @betteam = '9/15+' THEN 1
											WHEN LEFT(@betteam, 1) <> IP.TotalGoal1H THEN -1
											WHEN LEFT(@betteam, 1) = IP.TotalGoal1H AND REPLACE(SUBSTRING(@betteam, CHARINDEX('/',@betteam) + 1, LEN(@betteam)),'+','') < IP.TotalGoal THEN -1
											WHEN LEFT(@betteam, 1) = IP.TotalGoal1H AND REPLACE(SUBSTRING(@betteam, CHARINDEX('/',@betteam) + 1, LEN(@betteam)),'+','') >= IP.TotalGoal THEN NULL
											ELSE NULL
										END
							END
						END
				-- 1H Correct Corners
				WHEN @bettype IN (494) THEN 
					CASE WHEN @IsHT = 1 THEN
							CASE 
								WHEN @betteam = 'AOS' THEN CASE WHEN CHARINDEX(CAST(IP.HomeScore1H AS VARCHAR(5)) + '-' + CAST(IP.AwayScore1H AS VARCHAR(5)), @transdesc) = 0 THEN 1 ELSE NULL END
								WHEN @betteam <> 'AOS' AND LEFT(@betteam, 1) >= IP.HomeScore1H AND RIGHT(@betteam, 1) >= IP.AwayScore1H THEN NULL
								ELSE -1
							END
					END
				-- 2H Correct Corners
				WHEN @bettype IN (495) THEN 
					CASE WHEN @IsHT = 0 THEN
							CASE 
								WHEN @betteam = 'AOS' THEN CASE WHEN CHARINDEX(CAST(IP.HomeScore2H AS VARCHAR(5)) + '-' + CAST(IP.AwayScore2H AS VARCHAR(5)), @transdesc) = 0 THEN 1 ELSE NULL END
								WHEN @betteam <> 'AOS' AND LEFT(@betteam, 1) >= IP.HomeScore2H AND RIGHT(@betteam, 1) >= IP.AwayScore2H THEN NULL
								ELSE -1
							END
					END
				-- Corner Highest Scoring Half
				WHEN @bettype IN (496) AND @IsHT = 0 THEN 
						CASE @betteam
							WHEN '1h' THEN
								CASE 
									WHEN ip.TotalGoal1H <= ip.TotalGoal2H THEN -1
									ELSE NULL
								END
							WHEN '2h' THEN
								CASE 
									WHEN ip.TotalGoal1H < ip.TotalGoal2H THEN 1
									ELSE NULL
								END
							WHEN 'tie' THEN
								CASE 
									WHEN ip.TotalGoal1H < ip.TotalGoal2H THEN -1
									ELSE NULL
								END
							ELSE NULL
						END
				-- Corner Highest Scoring Half (2-Way)
				WHEN @bettype IN (497) AND @IsHT = 0 THEN 
						CASE @betteam
							WHEN '1h' THEN
								CASE 
									WHEN ip.TotalGoal1H < ip.TotalGoal2H THEN -1
									ELSE NULL
								END
							WHEN '2h' THEN
								CASE 
									WHEN ip.TotalGoal1H < ip.TotalGoal2H THEN 1
									ELSE NULL
								END
							ELSE NULL
						END

				-- ##Start - Incorporate PHAIO 5 [Redmine:#121681]

				WHEN @bettype IN (399) THEN -- Extra Time Correct Score
					CASE
						WHEN @betteam = 'AOS' THEN CASE WHEN CHARINDEX(CAST(ip.HomeScoreFT AS VARCHAR(6)) + '-' + CAST(ip.AwayScoreFT AS VARCHAR(6)), @transdesc) = 0 THEN 1 ELSE NULL END
						WHEN @betteam <> 'AOS' AND (ip.HomeScoreFT > LEFT(@betteam,1) OR ip.AwayScoreFT > RIGHT(@betteam,1)) THEN -1
						ELSE NULL
					END

				WHEN @bettype IN ( 397 ) THEN
					CASE 
						WHEN @betteam = 'NG' AND ip.TotalGoal > 0 THEN -1
						ELSE NULL
					END

				WHEN @bettype IN (392) THEN -- Penalty Shootout Correct Score
					CASE
						WHEN @betteam NOT IN ('HAOS', 'AAOS') AND (ip.HomeScoreFT > LEFT(@betteam,1) OR ip.AwayScoreFT > RIGHT(@betteam,1)) THEN -1
						ELSE NULL
					END

				-- ##End - Incorporate PHAIO 5 [Redmine:#121681]
				---------------------------------------
				ELSE NULL -- else non-supported bettype
			END AS modds
		) AS t1
	) AS ods
)
GO