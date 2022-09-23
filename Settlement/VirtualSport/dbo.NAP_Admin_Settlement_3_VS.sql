/*<info serverAlias="DBTXN-bodb02" executers="Dot_Member,bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [NAP_Admin_Settlement_3_VS]
	@creator int,
	@matchid int,
	@mode varchar(6) = 'CAL',
	@IsCentral	BIT = 0
AS
/*
	Created: Kathy
	Date: 20140213
	Task : Covered SP for settlement
	DB: DBTXN/BODB02
	Original: Admin_Settlement_3_VS
	Revisions:
		- 20151210@Patrick: Database - Change datatype [Redmine: #48660]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]

	Param's Explanation:
	• @Mode:
		CAL : All BetTypes
		CAL-HT : HT Only
		CAL-FT : FT Only (All Except HT)
*/
SET NOCOUNT ON 

	Declare @fth int, @fta int, @hth int, @hta int, @sporttype smallint,
		@betstatus nvarchar(50), @GoalRecord varchar(50), @matchCode nvarchar(50)

	SELECT  @fth = FinalHomeScore, @fta = FinalAwayScore,
			@hth = HTHomeScore, @HTA = HTAwayScore,
			@sporttype = SportType,
			@betstatus = betstatus,
			@GoalRecord = IsNull(GoalRecord, ''),
			@matchCode = IsNull(matchCode, '')
	FROM DBPRO.BODB02.dbo.Match with (nolock) WHERE matchid = @matchid
	
	IF @sporttype NOT IN (180,181,182,183,184,185,186) RETURN
	
	Declare @totalgoal smallmoney, @scorediff smallmoney, @correctscore nvarchar(10)

	SELECT @totalgoal = (@fth + @fta), @scorediff = (@fth - @fta),
		@correctscore = CAST(@fth as nvarchar(3)) + ':' + CAST(@fta as nvarchar(3))
		
	IF @Mode IN ('CAL-FT', 'CAL')
	BEGIN	    
	-- bettype 1201 : Virtual Handicap
		EXEC dbo.NAP_Admin_PreCalculate_1 @matchid, 1201, @fth, @fta, @IsCentral
	-- bettype 1203 : Virtual Over/Under
		EXEC dbo.NAP_Admin_PreCalculate_3 @matchid, 1203, @totalgoal, @IsCentral
	-- bettype 1204 : Virtual Correct Score
		EXEC dbo.NAP_Admin_PreCalculate_4 @matchid, 1204, @correctscore, @scorediff, @IsCentral
	-- bettype 1205 : Virtual 1x2
		EXEC dbo.NAP_Admin_PreCalculate_5 @matchid, 1205, @scorediff, @IsCentral
	---- bettype 1206 : Virtual Total Goal
		EXEC dbo.NAP_Admin_PreCalculate_6 @matchid, 1206, @totalgoal, @IsCentral					
	---- bettype 1224 : Virtual Double Chance 
		EXEC dbo.NAP_Admin_PreCalculate_24 @matchid, 1224, @scorediff, @IsCentral
	-- bettype 1220 : Money Line	
		EXEC dbo.NAP_Admin_PreCalculate_1 @matchid, 1220, @fth, @fta, @IsCentral			
	-- bettype 1235 : Virtual Score Bet	
		EXEC dbo.NAP_Admin_PreCalculate_4 @matchid, 1235, @betstatus, @scorediff
	-- bettype 1236 : Virtual Total Points	
		EXEC dbo.NAP_Admin_PreCalculate_6 @matchid, 1236, @totalgoal, @IsCentral	
		
	END


GO

