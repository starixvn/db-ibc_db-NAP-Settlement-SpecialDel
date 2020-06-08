/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_5] 
	 @MatchID			INT 
	,@Action			VARCHAR(10)	= 'CAL-SET'
	,@Mode				VARCHAR(6)	= 'CAL'
	,@SelectedSet		VARCHAR(50)	= ''	
	
AS
/*
	Created by: Jamie
	Date: 20141015
	Task: Settlement for Tennis ( including Sporting Solution) 
	DB: DBTXN/bodb02

	Revisions:
		- 20141204@Jamie: Sportting Solution settlement - Change rule Set x Correct Score [Redmine:#23034]

	Param's Explanation: 

*/
BEGIN
	SET NOCOUNT ON 

	DECLARE	 @fth					INT
			,@fta					INT
			,@HomeValueMatch		INT = 0 
			,@AwayValueMatch		INT = 0 
			,@TotalGameHomeMatch	INT = 0
			,@TotalGameAwayMatch	INT = 0 

			,@TotalGameHomeSet1		INT	= 0 
			,@TotalGameHomeSet2		INT = 0 
			,@TotalGameHomeSet3		INT = 0 
			,@TotalGameHomeSet4		INT = 0 
			,@TotalGameHomeSet5		INT = 0 
			,@TotalGameAwaySet1		INT = 0 
			,@TotalGameAwaySet2		INT = 0 
			,@TotalGameAwaySet3		INT = 0 
			,@TotalGameAwaySet4		INT = 0 
			,@TotalGameAwaySet5		INT = 0 
			,@SetxGameyHomeWON		VARCHAR(MAX) = '' 
			,@SetxGameyAwayWON		VARCHAR(MAX) = ''
			,@SetxGameyDRAW			VARCHAR(MAX) = ''
			,@SetxGameyREFUND		VARCHAR(MAX) = ''

			,@TotalSetMatch			INT = 0 
			,@TotalGameMatch		INT = 0 
			,@TotalGameSet1			INT = 0 
			,@TotalGameSet2			INT = 0 
			,@TotalGameSet3			INT = 0 
			,@TotalGameSet4			INT = 0 
			,@TotalGameSet5			INT = 0 
			,@GameDiffMatch			SMALLMONEY 
			,@GameDiffSet1			SMALLMONEY 
			,@GameDiffSet2			SMALLMONEY 
			,@GameDiffSet3			SMALLMONEY 
			,@GameDiffSet4			SMALLMONEY 
			,@GameDiffSet5			SMALLMONEY 

			,@CorrectScoreMatch		NVARCHAR(10) 
			,@CorrectScoreSet1		NVARCHAR(10)
			,@CorrectScoreSet2		NVARCHAR(10)
			,@CorrectScoreSet3		NVARCHAR(10)
			,@CorrectScoreSet4		NVARCHAR(10)
			,@CorrectScoreSet5		NVARCHAR(10)
			,@OddEvenGameMatch		SMALLMONEY
			,@OddEvenSetMatch		SMALLMONEY 
			,@OddEvenGameSet1		SMALLMONEY
			,@OddEvenGameSet2		SMALLMONEY
			,@OddEvenGameSet3		SMALLMONEY
			,@OddEvenGameSet4		SMALLMONEY
			,@OddEvenGameSet5		SMALLMONEY

			,@betCount_1			INT	= 0 
			,@betCount_2			INT = 0 
			,@betCount_3			INT = 0 
			,@betCount_20			INT = 0 
			,@betCount_153			INT = 0 
			,@betCount_154			INT = 0 
			,@betCount_155			INT = 0 
			,@betCount_156			INT = 0 
			,@betCount_1301			INT = 0 
			,@betCount_1302			INT = 0 
			,@betCount_1303			INT = 0 
			,@betCount_1305			INT = 0 
			,@betCount_1306			INT = 0 
			,@betCount_1308			INT = 0 
			,@betCount_1311			INT = 0 
			,@betCount_1312			INT = 0 
			,@betCount_1316			INT = 0 
			,@betCount_1317			INT = 0 
			,@betCount_1318			INT = 0 
			,@betCount_1324			INT = 0 

	DECLARE	@tmpResultDetail TABLE(
		 ResourceID			VARCHAR(20)
		,HomeValue			VARCHAR(20)
		,AwayValue			VARCHAR(20)
		,SettlementStatusID	TINYINT 
	)

	INSERT INTO @tmpResultDetail(
		 ResourceID
		,HomeValue
		,AwayValue
		,SettlementStatusID
	)
	SELECT	 ResourceID
			,HomeValue
			,AwayValue
			,SettlementStatusID
	FROM	DBPRO.bodb02.dbo.ResultDetail WITH (NOLOCK)
	WHERE	MatchID = @MatchID
			AND SettlementStatusID > 0 
			AND ResultStatusID = 5 -- Score from Settlement Site 

	/*START: Ticket Count*/
	IF @Action='CAL' AND @SelectedSet LIKE '%6%'  -- Match Scope 
	BEGIN
		SELECT	 @betCount_1		= ISNULL(SUM(CASE WHEN bettype = 1 THEN 1 ELSE 0 END),0)
				,@betCount_2		= ISNULL(SUM(CASE WHEN bettype = 2 THEN 1 ELSE 0 END),0)
				,@betCount_3		= ISNULL(SUM(CASE WHEN bettype = 3 THEN 1 ELSE 0 END),0)
				,@betCount_20		= ISNULL(SUM(CASE WHEN bettype = 20 THEN 1 ELSE 0 END),0)
				,@betCount_153		= ISNULL(SUM(CASE WHEN bettype = 153 THEN 1 ELSE 0 END),0)
				,@betCount_1301		= ISNULL(SUM(CASE WHEN bettype = 1301 THEN 1 ELSE 0 END),0)
				,@betCount_1302		= ISNULL(SUM(CASE WHEN bettype = 1302 THEN 1 ELSE 0 END),0)
				,@betCount_1303		= ISNULL(SUM(CASE WHEN bettype = 1303 THEN 1 ELSE 0 END),0)
				,@betCount_1305		= ISNULL(SUM(CASE WHEN bettype = 1305 THEN 1 ELSE 0 END),0)
				,@betCount_1306		= ISNULL(SUM(CASE WHEN bettype = 1306 THEN 1 ELSE 0 END),0)
				,@betCount_1308		= ISNULL(SUM(CASE WHEN bettype = 1308 THEN 1 ELSE 0 END),0)

		FROM	Bettrans WITH (NOLOCK)
		WHERE	MatchID = @MatchID		
				AND bettype IN (1,2,3,20,153,1301,1302,1303,1305,1306,1308)
	END 
	IF @Action='CAL' AND @SelectedSet LIKE '%[1-5]%'	-- Set scope 
	BEGIN
		SELECT	 @betCount_154		= ISNULL(SUM(CASE WHEN bettype = 154 THEN 1 ELSE 0 END),0)
				,@betCount_155		= ISNULL(SUM(CASE WHEN bettype = 155 THEN 1 ELSE 0 END),0)
				,@betCount_156		= ISNULL(SUM(CASE WHEN bettype = 156 THEN 1 ELSE 0 END),0)
				,@betCount_1311		= ISNULL(SUM(CASE WHEN bettype = 1311 THEN 1 ELSE 0 END),0)
				,@betCount_1312		= ISNULL(SUM(CASE WHEN bettype = 1312 THEN 1 ELSE 0 END),0)
				,@betCount_1316		= ISNULL(SUM(CASE WHEN bettype = 1316 THEN 1 ELSE 0 END),0)
				,@betCount_1317		= ISNULL(SUM(CASE WHEN bettype = 1317 THEN 1 ELSE 0 END),0)
				,@betCount_1318		= ISNULL(SUM(CASE WHEN bettype = 1318 THEN 1 ELSE 0 END),0)
				,@betCount_1324		= ISNULL(SUM(CASE WHEN bettype = 1324 THEN 1 ELSE 0 END),0)

		FROM	Bettrans WITH (NOLOCK)
		WHERE	MatchID = @MatchID		
				AND bettype IN (154,155,156,1311,1312,1316,1317,1318,1324)
	END 	
	/*END: Ticket Count*/

	
	SELECT	 @HomeValueMatch		= ISNULL(SUM(CASE WHEN ResourceID='00' THEN HomeValue ELSE 0 END),0)
			,@AwayValueMatch		= ISNULL(SUM(CASE WHEN ResourceID='00' THEN AwayValue ELSE 0 END),0) 
			,@TotalGameHomeMatch	= ISNULL(SUM(CASE WHEN ResourceID LIKE '0[1-5]' THEN HomeValue ELSE 0 END),0)
			,@TotalGameAwayMatch	= ISNULL(SUM(CASE WHEN ResourceID LIKE '0[1-5]' THEN AwayValue ELSE 0 END),0)
			,@TotalGameHomeSet1		= ISNULL(SUM(CASE WHEN ResourceID ='01' THEN HomeValue ELSE 0 END),0)
			,@TotalGameHomeSet2		= ISNULL(SUM(CASE WHEN ResourceID ='02' THEN HomeValue ELSE 0 END),0)
			,@TotalGameHomeSet3		= ISNULL(SUM(CASE WHEN ResourceID ='03' THEN HomeValue ELSE 0 END),0)
			,@TotalGameHomeSet4		= ISNULL(SUM(CASE WHEN ResourceID ='04' THEN HomeValue ELSE 0 END),0)
			,@TotalGameHomeSet5		= ISNULL(SUM(CASE WHEN ResourceID ='05' THEN HomeValue ELSE 0 END),0)
			,@TotalGameAwaySet1		= ISNULL(SUM(CASE WHEN ResourceID ='01' THEN AwayValue ELSE 0 END),0)
			,@TotalGameAwaySet2		= ISNULL(SUM(CASE WHEN ResourceID ='02' THEN AwayValue ELSE 0 END),0)
			,@TotalGameAwaySet3		= ISNULL(SUM(CASE WHEN ResourceID ='03' THEN AwayValue ELSE 0 END),0)
			,@TotalGameAwaySet4		= ISNULL(SUM(CASE WHEN ResourceID ='04' THEN AwayValue ELSE 0 END),0)
			,@TotalGameAwaySet5		= ISNULL(SUM(CASE WHEN ResourceID ='05' THEN AwayValue ELSE 0 END),0)
	FROM	@tmpResultDetail
	WHERE	SettlementStatusID = 4 --Completed 
			AND ResourceID LIKE '0[0-5]'

	SELECT   @SetxGameyHomeWON		= @SetxGameyHomeWON + CASE WHEN CAST((CASE WHEN HomeValue='A' THEN '65' ELSE HomeValue END) AS INT) - CAST((CASE WHEN AwayValue ='A' THEN '65' ELSE AwayValue END) AS INT) > 0 
																		AND SettlementStatusID = 4 THEN ResourceID +',' ELSE '' END
			,@SetxGameyAwayWON		= @SetxGameyAwayWON + CASE WHEN CAST((CASE WHEN HomeValue='A' THEN '65' ELSE HomeValue END) AS INT) - CAST((CASE WHEN AwayValue ='A' THEN '65' ELSE AwayValue END) AS INT) < 0 
																		AND SettlementStatusID = 4 THEN ResourceID +',' ELSE '' END
			,@SetxGameyDRAW			= @SetxGameyDRAW + CASE WHEN CAST((CASE WHEN HomeValue='A' THEN '65' ELSE HomeValue END) AS INT) - CAST((CASE WHEN AwayValue ='A' THEN '65' ELSE AwayValue END) AS INT) = 0 
																		AND SettlementStatusID = 4 THEN ResourceID +',' ELSE '' END
			,@SetxGameyREFUND		= @SetxGameyREFUND + CASE WHEN SettlementStatusID = 1 THEN ResourceID +',' ELSE '' END 
	FROM	@tmpResultDetail 
	WHERE	SettlementStatusID > 0 
			AND ResourceID LIKE '0[1-5][0-9][0-9]'

	SELECT	 @CorrectScoreMatch		= CAST(@HomeValueMatch AS NVARCHAR(5)) + CAST(@AwayValueMatch AS NVARCHAR(5)) 
			,@CorrectScoreSet1		= CASE	WHEN @TotalGameHomeSet1 > 7 AND (@TotalGameHomeSet1 - @TotalGameAwaySet1)>=2 THEN 'haos'
											WHEN @TotalGameAwaySet1 > 7 AND (@TotalGameAwaySet1 - @TotalGameHomeSet1)>=2 THEN 'aaos'  
											ELSE CAST(@TotalGameHomeSet1 AS NVARCHAR(5)) + CAST(@TotalGameAwaySet1 AS NVARCHAR(5)) 
											END 
			,@CorrectScoreSet2		= CASE	WHEN @TotalGameHomeSet2 > 7 AND (@TotalGameHomeSet2 - @TotalGameAwaySet2)>=2 THEN 'haos'
											WHEN @TotalGameAwaySet2 > 7 AND (@TotalGameAwaySet2 - @TotalGameHomeSet2)>=2 THEN 'aaos'  
											ELSE CAST(@TotalGameHomeSet2 AS NVARCHAR(5)) + CAST(@TotalGameAwaySet2 AS NVARCHAR(5)) 
											END
			,@CorrectScoreSet3		= CASE	WHEN @TotalGameHomeSet3 > 7 AND (@TotalGameHomeSet3 - @TotalGameAwaySet3)>=2 THEN 'haos'
											WHEN @TotalGameAwaySet3 > 7 AND (@TotalGameAwaySet3 - @TotalGameHomeSet3)>=2 THEN 'aaos'  
											ELSE CAST(@TotalGameHomeSet3 AS NVARCHAR(5)) + CAST(@TotalGameAwaySet3 AS NVARCHAR(5)) 
											END
			,@CorrectScoreSet4		= CASE	WHEN @TotalGameHomeSet4 > 7 AND (@TotalGameHomeSet4 - @TotalGameAwaySet4)>=2 THEN 'haos'
											WHEN @TotalGameAwaySet4 > 7 AND (@TotalGameAwaySet4 - @TotalGameHomeSet4)>=2 THEN 'aaos'  
											ELSE CAST(@TotalGameHomeSet4 AS NVARCHAR(5)) + CAST(@TotalGameAwaySet4 AS NVARCHAR(5)) 
											END
			,@CorrectScoreSet5		= CASE	WHEN @TotalGameHomeSet5 > 7 AND (@TotalGameHomeSet5 - @TotalGameAwaySet5)>=2 THEN 'haos'
											WHEN @TotalGameAwaySet5 > 7 AND (@TotalGameAwaySet5 - @TotalGameHomeSet5)>=2 THEN 'aaos'  
											ELSE CAST(@TotalGameHomeSet5 AS NVARCHAR(5)) + CAST(@TotalGameAwaySet5 AS NVARCHAR(5))
											END
			,@OddEvenGameMatch		= (@TotalGameHomeMatch + @TotalGameAwayMatch) % 2
			,@OddEvenSetMatch		= (@HomeValueMatch + @AwayValueMatch)%2 
			,@OddEvenGameSet1		= (@TotalGameHomeSet1 + @TotalGameAwaySet1) % 2 
			,@OddEvenGameSet2		= (@TotalGameHomeSet2 + @TotalGameAwaySet2) % 2 
			,@OddEvenGameSet3		= (@TotalGameHomeSet3 + @TotalGameAwaySet3) % 2 
			,@OddEvenGameSet4		= (@TotalGameHomeSet4 + @TotalGameAwaySet4) % 2 
			,@OddEvenGameSet5		= (@TotalGameHomeSet5 + @TotalGameAwaySet5) % 2 

			,@TotalSetMatch			= @HomeValueMatch + @AwayValueMatch
			,@TotalGameMatch		= @TotalGameHomeMatch + @TotalGameAwayMatch
			,@TotalGameSet1			= @TotalGameHomeSet1 + @TotalGameAwaySet1
			,@TotalGameSet2			= @TotalGameHomeSet2 + @TotalGameAwaySet2
			,@TotalGameSet3			= @TotalGameHomeSet3 + @TotalGameAwaySet3
			,@TotalGameSet4			= @TotalGameHomeSet4 + @TotalGameAwaySet4
			,@TotalGameSet5			= @TotalGameHomeSet5 + @TotalGameAwaySet5
			,@GameDiffMatch			= @TotalGameHomeMatch - @TotalGameAwayMatch


	IF @Action = 'CAL'
	BEGIN
		EXEC dbo.NAP_Admin_Calculate_Main
					 @matchid			= @matchid
					,@action			= 'CAL-SET'
					,@mode				= 'CAL'
					,@SelectedSet		= @SelectedSet
					,@fth				= @HomeValueMatch
					,@fta				= @AwayValueMatch
					,@correctscore		= @CorrectScoreMatch
					,@OddEven			= @OddEvenGameMatch
					,@totalgoal			= @TotalGameMatch
					,@scorediff			= @GameDiffMatch
					,@OddEvenSetMatch	= @OddEvenSetMatch
					,@OddEvenGameSet1	= @OddEvenGameSet1	
					,@OddEvenGameSet2	= @OddEvenGameSet2	
					,@OddEvenGameSet3	= @OddEvenGameSet3	
					,@OddEvenGameSet4	= @OddEvenGameSet4	
					,@OddEvenGameSet5	= @OddEvenGameSet5	
					,@CorrectScoreSet1	= @CorrectScoreSet1
					,@CorrectScoreSet2	= @CorrectScoreSet2
					,@CorrectScoreSet3	= @CorrectScoreSet3	
					,@CorrectScoreSet4	= @CorrectScoreSet4	
					,@CorrectScoreSet5	= @CorrectScoreSet5	
					,@TotalGameHomeMatch= @TotalGameHomeMatch
					,@TotalGameAwayMatch= @TotalGameAwayMatch
					,@TotalGameHomeSet1 = @TotalGameHomeSet1
					,@TotalGameHomeSet2 = @TotalGameHomeSet2
					,@TotalGameHomeSet3 = @TotalGameHomeSet3
					,@TotalGameHomeSet4 = @TotalGameHomeSet4
					,@TotalGameHomeSet5 = @TotalGameHomeSet5
					,@TotalGameAwaySet1	= @TotalGameAwaySet1
					,@TotalGameAwaySet2	= @TotalGameAwaySet2
					,@TotalGameAwaySet3	= @TotalGameAwaySet3
					,@TotalGameAwaySet4	= @TotalGameAwaySet4
					,@TotalGameAwaySet5	= @TotalGameAwaySet5
					,@TotalSetMatch		= @TotalSetMatch
					,@TotalGameSet1		= @TotalGameSet1
					,@TotalGameSet2		= @TotalGameSet2
					,@TotalGameSet3		= @TotalGameSet3
					,@TotalGameSet4		= @TotalGameSet4
					,@TotalGameSet5		= @TotalGameSet5
					,@GameDiffSet1		= @GameDiffSet1	
					,@GameDiffSet2		= @GameDiffSet2
					,@GameDiffSet3		= @GameDiffSet3	 
					,@GameDiffSet4		= @GameDiffSet4	 
					,@GameDiffSet5		= @GameDiffSet5	 
					,@SetxGameyHomeWON	= @SetxGameyHomeWON
					,@SetxGameyAwayWON  = @SetxGameyAwayWON
					,@SetxGameyDRAW		= @SetxGameyDRAW
					,@SetxGameyREFUND	= @SetxGameyREFUND
					,@betCount_1		= @betCount_1
					,@betCount_2		= @betCount_2
					,@betCount_3		= @betCount_3
					,@betCount_20		= @betCount_20
					,@betCount_153		= @betCount_153
					,@betCount_154		= @betCount_154
					,@betCount_155		= @betCount_155
					,@betCount_156		= @betCount_156
					,@betcount_1301		= @betCount_1301
					,@betcount_1302		= @betCount_1302
					,@betcount_1303		= @betCount_1303
					,@betcount_1305		= @betCount_1305
					,@betcount_1306		= @betCount_1306
					,@betcount_1308		= @betCount_1308
					,@betcount_1311		= @betCount_1311
					,@betcount_1312		= @betCount_1312
					,@betcount_1316		= @betCount_1316
					,@betcount_1317		= @betCount_1317
					,@betcount_1318		= @betCount_1318
					,@betcount_1324		= @betCount_1324
					,@CalledByBrokerService = 0
	END
END
GO