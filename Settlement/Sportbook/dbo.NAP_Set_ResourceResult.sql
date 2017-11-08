/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_ResourceResult
	@MatchId			INT
	,@Action			VARCHAR(20)
	,@Mode				VARCHAR(20)		= NULL
	,@goalrecord		VARCHAR(50)		= NULL
	,@ResourceResult	VARCHAR(MAX)	= NULL OUTPUT	
AS
/*
	Created by: Kathy
	Date: 20170815
	Task: 
	DB: DBTXN/bodb02 

	Revision
		- 20170815@Kathy: Using table ResultDetail to store FGLG result instead of betstatus [Redmine:#81308]
		
	Param's Explanation: 
		+ @Results: 'H,1,X,NL,...'  NL: Blank result of Bettype 216 
		+ @ResourceResult
					<Results>
						<Resource Id="" HomeValue=""/>
					</Results>
*/
BEGIN
	DECLARE @tmpBettrans TABLE(bettype SMALLINT, betteam VARCHAR(10), statusId TINYINT)
	DECLARE @tmpResourceResult TABLE (Id VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50))
	DECLARE @tmpBettype TABLE (bettype SMALLINT)
	
	DECLARE @FirstGoalTeam VARCHAR(1)
	
	SELECT @FirstGoalTeam = CASE
								WHEN i.home_index > 0
									THEN CASE
											WHEN i.away_index = 0 THEN 'H'
											WHEN i.home_index < i.away_index THEN 'H'
											ELSE 'A'
											END
								WHEN i.away_index > 0
									THEN CASE
											WHEN i.home_index = 0 THEN 'A'
											WHEN i.away_index < i.home_index THEN 'A'
											ELSE 'H'
											END
								ELSE 'N'
								END
	FROM (
		SELECT	CHARINDEX('H',@goalrecord) AS home_index
				,CHARINDEX('A',@goalrecord) AS away_index
	)i	
	
	IF @Action IN ('CAL-INST', 'UNDO-INST')
	BEGIN
		INSERT INTO @tmpBettrans (bettype)
		SELECT	b.bettype
		FROM	dbo.bettrans b WITH (NOLOCK)
		WHERE	b.matchid = @MatchId 
				AND b.bettype IN (14, 127)
				AND statusId BETWEEN 111 AND 113					
				AND RIGHT(betteam, 1) IN ('0', '1' )
		GROUP BY b.bettype
		
		IF @Mode = 'INST-HT' AND EXISTS (SELECT TOP 1 1 FROM @tmpBettrans WHERE bettype = 127) 
			INSERT INTO @tmpResourceResult(Id, HomeValue) VALUES ('127F', @FirstGoalTeam)
			
		IF EXISTS (SELECT TOP 1 1 FROM @tmpBettrans WHERE bettype = 14)
			INSERT INTO @tmpResourceResult(Id, HomeValue) VALUES ('14F', @FirstGoalTeam)			
	END
	
	IF @Action IN ('CAL', 'CAL-HT', 'CAL-FT', 'REFUND', 'REFUND-HT', 'REFUND-FT')
	BEGIN
		INSERT INTO @tmpBettype (bettype)
		SELECT	BetType
		FROM	dbo.f_Set_GetGroupBettypes()
		WHERE	IsUsedGoalRecordValue = 1
				AND 1 = CASE
							WHEN @Action IN ('CAL-HT','REFUND-HT') AND BetType = 127 THEN 1
							WHEN @Action IN ('CAL-FT','REFUND-FT') AND BetType <> 127 THEN 1
							ELSE 1
						END
				
		INSERT INTO @tmpBettrans (bettype)
		SELECT	b.bettype
		FROM	dbo.bettrans b WITH(NOLOCK)
		WHERE	b.matchid = @MatchId
				AND b.bettype IN (SELECT bettype FROM @tmpBettype)
				AND b.statusID NOT BETWEEN 101 AND 102
		UNION ALL
		SELECT	bm.bettype
		FROM	dbo.bettransm bm WITH(NOLOCK)
		WHERE	bm.matchid = @MatchId
				AND bm.bettype IN (SELECT bettype FROM @tmpBettype)
				AND bm.statusID NOT BETWEEN 101 AND 102
				
		IF EXISTS (SELECT TOP 1 1 FROM @tmpBettrans WHERE bettype = 127)
			INSERT INTO @tmpResourceResult(Id, HomeValue) VALUES ('127F',@FirstGoalTeam), ('127L', @FirstGoalTeam)
			
		IF EXISTS (SELECT TOP 1 1 FROM @tmpBettrans WHERE bettype = 14)
			INSERT INTO @tmpResourceResult(Id, HomeValue) VALUES ('14F',@FirstGoalTeam), ('14L', @FirstGoalTeam)
				
		IF EXISTS (SELECT TOP 1 1 FROM @tmpBettrans)
			INSERT INTO @tmpResourceResult(Id, HomeValue)
			VALUES('08', @GoalRecord)			
	END
	
	SET @ResourceResult = CAST (
			(SELECT	Id AS '@Id'
					,HomeValue AS '@HomeValue'
			FROM	@tmpResourceResult
			FOR XML PATH ('Resource'), ROOT ('Results'), TYPE
			) AS VARCHAR(MAX)
		)	
END
GO
