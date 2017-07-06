/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Admin_Match_Update_s160
	@Action			VARCHAR(10) = NULL
	,@IsAuto		BIT 
	,@strMatchInfo	VARCHAR(MAX)	
AS
/*
	Created by: Kathy
	Date: 20170426
	Task: Lucky 3 - Settlement 
	DB: DBPRO/BODB02
	
	Revisions:
		- 20170426@Kathy: Lucky 3 - Settlement  [Redmine:#77170]
		
	Param's Explanation:	
		* @strMatchInfo: <root>
							<r m="22579125" fn="1" sn="20" tn="23" fb="1" sb="7" tb="43"/>
							<r m="22579135" fn="2" sn="40" tn="63" fb="1" sb="12" tb="36"/>
						</root>
		* @Action: CAL/REFUND/UNDO: for settlement
				 NULL: called by VoidByBetId function
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @tmpMatchInfo TABLE (
		Matchid					INT
		,FirstBall				TINYINT
		,SecondBall				TINYINT
		,ThirdBall				TINYINT
		,NumberOfFirstPrize		INT
		,NumberOfSecondPrize	INT
		,NumberOfThirdPrize		INT
	)
	
	DECLARE @xml XML
	SET @xml = CAST(@strMatchInfo AS XML)
	
	INSERT INTO @tmpMatchInfo(Matchid, FirstBall, SecondBall, ThirdBall, NumberOfFirstPrize, NumberOfSecondPrize, NumberOfThirdPrize)
	SELECT  T.c.value('./@m','INT')
			,T.c.value('./@fb','TINYINT')
			,T.c.value('./@sb','TINYINT')
			,T.c.value('./@tb','TINYINT')
			,T.c.value('./@fn','INT')
			,T.c.value('./@sn','INT')
			,T.c.value('./@tn','INT')
	FROM    @xml.nodes('/root/r') AS T(c)
	OPTION ( OPTIMIZE FOR ( @xml = NULL ) )

	
	IF @Action IN ('CAL', 'UNDO', 'REFUND')
	BEGIN			
		MERGE dbo.bingoBall TARGET
		USING (
			SELECT	Matchid
					,1 AS seq
					,FirstBall AS Number
			FROM @tmpMatchInfo
			UNION ALL
			SELECT	Matchid
					,2 AS seq
					,SecondBall AS Number
			FROM @tmpMatchInfo
			UNION ALL
			SELECT	Matchid
					,3 AS seq
					,ThirdBall AS Number
			FROM @tmpMatchInfo
		)SOURCE
			ON TARGET.Matchid = SOURCE.matchid
				AND TARGET.Seq = SOURCE.seq
		WHEN MATCHED THEN UPDATE SET Number = CASE 
							WHEN @Action = 'CAL' 
								THEN CASE
										WHEN @IsAuto = 0 THEN SOURCE.Number								
										ELSE TARGET.Number
									END
							ELSE NULL
						END
		WHEN NOT MATCHED THEN INSERT (MatchId, Seq, Number, sporttype, UpdateTime) VALUES (SOURCE.matchid, SOURCE.seq, SOURCE.Number, 160, GETDATE());
				
	END
	
	UPDATE m
		SET	eventstatus = CASE 
							WHEN @Action IN ('CAL', 'REFUND') THEN 'Completed'
							WHEN @Action = 'UNDO' THEN 'running'
							ELSE m.eventstatus
						END
			,betstatus = CASE 
							WHEN @Action = 'REFUND' THEN 'Refund;'
							WHEN @Action IN ('CAL', 'UNDO') THEN ''
							ELSE m.betstatus
						END
			,livehomescore = t.NumberOfFirstPrize
			,liveawayscore = t.NumberOfSecondPrize
			,finalhomescore = t.NumberOfThirdPrize
			,settletime = CASE 
							WHEN @Action IN ('CAL', 'REFUND', 'UNDO') THEN GETDATE() 
							ELSE m.settletime 
						END
			,changetime = GETDATE()
	FROM	dbo.match m WITH(ROWLOCK, UPDLOCK)
		INNER JOIN @tmpMatchInfo t
			ON m.matchid = t.Matchid
	
END
GO