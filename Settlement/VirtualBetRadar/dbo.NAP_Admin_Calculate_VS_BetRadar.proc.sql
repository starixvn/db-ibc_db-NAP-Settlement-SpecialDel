/*<info serverAlias="DBTXN-bodb02" executers="Dot_Member" viewers="vnteam" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Admin_Calculate_VS_BetRadar]
	@creator 		INT
	,@matchid 		INT
	,@mode 			VARCHAR(6) = 'CAL'
	,@CALBettypes 	VARCHAR(MAX)
AS
/*
	Created: 20160606@Bobby
	Task :  77720 - Implement BetRadar VS League & Nation
	DB: DBTXN/BODB02
	Revisions:
		- 20160606@Bobby: Initialize
		

	Param's Explanation:
	• @Mode:
		CAL : All single BetTypes (HT-FT)
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @fth INT
		, @fta INT
		, @hth INT
		, @hta INT
		, @sporttype SMALLINT
		, @betstatus NVARCHAR(50)
		, @GoalRecord VARCHAR(50)
		, @matchCode NVARCHAR(50)
		, @FTtotalgoal 	SMALLMONEY
		, @HTtotalgoal 		SMALLMONEY
		, @FTscorediff 		SMALLMONEY
		, @HTscorediff 		SMALLMONEY
		, @correctscore 	NVARCHAR(10)
		, @xmlBettype	 	XML
	
	DECLARE @tempBettype TABLE (bettype SMALLINT)
	
	SELECT TOP(1)
		@fth 	= FinalHomeScore
		, @fta 	= FinalAwayScore
		, @hth 	= HTHomeScore
		, @HTA 	= HTAwayScore
		, @sporttype = SportType
		, @betstatus = betstatus
		, @GoalRecord = ISNULL(GoalRecord, '')
		, @matchCode = ISNULL(matchCode, '')
	FROM DBPRO.BODB02.dbo.Match WITH (NOLOCK)
	WHERE matchid = @matchid

	IF (@sporttype NOT BETWEEN 190 AND 199 ) RETURN

	SELECT @FTtotalgoal 	= (@fth + @fta)
		, @HTtotalgoal 		= (@hth + @hta)
		, @FTscorediff 		= (@fth - @fta)
		, @HTscorediff 		= (@hth - @hta)
		, @correctscore 	= CAST(@fth AS NVARCHAR(3)) + ':' + CAST(@fta AS NVARCHAR(3))
	
	--CONVERT bettype
	SET @xmlBettype = CONVERT(XML, @CALBettypes)
	
	INSERT INTO @tempBettype (bettype)
	SELECT T.C.value('./@t', 'SMALLINT') AS bettype
	FROM @xmlBettype.nodes('/r') AS T(C)
	OPTION (OPTIMIZE FOR (@xmlBettype = NULL ))
	
	IF (@@ROWCOUNT = 0) RETURN
	
	-- bettype 2701-2702 : FT 1X2
	IF(EXISTS(SELECT 1 FROM @tempBettype WHERE bettype = 2701))
	BEGIN
		EXEC dbo.NAP_Admin_Calculate_VS_BetRadar_5 @matchid = @matchid
			, @bettype = 2701
			, @scorediff = @FTscorediff
	END
	
	-- bettype 2702 : HT 1X2
	IF(EXISTS(SELECT 1 FROM @tempBettype WHERE bettype = 2702))
	BEGIN
	EXEC dbo.NAP_Admin_Calculate_VS_BetRadar_5 @matchid = @matchid
		, @bettype = 2702
		, @scorediff = @HTscorediff
	END
	
	-- bettype 2703: FT O/U
	IF(EXISTS(SELECT 1 FROM @tempBettype WHERE bettype = 2703))
	BEGIN
		EXEC dbo.NAP_Admin_Calculate_VS_BetRadar_3 @matchid = @matchid
			, @bettype = 2703
			, @totalgoal = @FTtotalgoal
	END
	
	-- bettype 2704 : HT O/U
	IF(EXISTS(SELECT 1 FROM @tempBettype WHERE bettype = 2704))
	BEGIN
		EXEC dbo.NAP_Admin_Calculate_VS_BetRadar_3 @matchid = @matchid
			, @bettype = 2704
			, @totalgoal = @HTtotalgoal
	END
	
	-- bettype 2705: FT HDP
	IF(EXISTS(SELECT 1 FROM @tempBettype WHERE bettype = 2705))
	BEGIN
		EXEC dbo.NAP_Admin_Calculate_VS_BetRadar_1 @matchid = @matchid
			, @bettype = 2705
			, @homescore = @fth
			, @awayscore = @fta
	END
	
	-- bettype 2706 : HT HDP
	IF(EXISTS(SELECT 1 FROM @tempBettype WHERE bettype = 2706))
	BEGIN
		EXEC dbo.NAP_Admin_Calculate_VS_BetRadar_1 @matchid = @matchid
			, @bettype = 2706
			, @homescore = @hth
			, @awayscore = @hta
	END
	
	-- bettype 2707  : Correct Score
	IF(EXISTS(SELECT 1 FROM @tempBettype WHERE bettype = 2707))
	BEGIN
		EXEC dbo.NAP_Admin_Calculate_VS_BetRadar_4 @matchid = @matchid
			, @bettype 		= 2707
			, @correctscore = @correctscore
			, @scorediff 	= @FTscorediff
	END
	
	RETURN
END
GO



