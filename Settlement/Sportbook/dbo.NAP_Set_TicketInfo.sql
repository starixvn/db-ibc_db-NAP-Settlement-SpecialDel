/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_TicketInfo
	@strMatchIds	VARCHAR(8000)
	,@strBettypes	VARCHAR(8000) = NULL
	
	,@strResults	VARCHAR(8000) = '' OUTPUT
AS
/*  
	Created: 20170920@Kathy  
	Task: get ticket information of list matches
	DB: DBTXN/BODB02  

	Revisions:  
		
	Param explanation:  
		@strMatchIds: 	<root>
							<match m="" im="" />
						</root>
						(m: matchid, im: indicate this match is move to match14 or not)
						
						
		@strBettypes:	<root>
							<bettype b="" />
						</root>
		
		@strResults:	<root>
							<result m="" b="" e="" />
						</root>
						(m: matchid, b: bettype, e: indicate bettype is exist or not)
  
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @xmlMatch		XML
			,@xmlBettype	XML
	
	DECLARE @tmpMatch TABLE (MatchId INT)
	DECLARE @tmpMatch14 TABLE (MatchId INT)
	DECLARE @tmpBettype TABLE (Bettype SMALLINT)
	
	SET @xmlMatch = CAST(@strMatchIds AS XML)
	SET @xmlBettype = CAST(@strBettypes AS XML)
	
	INSERT INTO @tmpMatch (MatchId)
	SELECT	T.C.value('@m', 'INT') AS MatchId
	FROM	@xmlMatch.nodes('/root/match') AS T(C)
	WHERE	T.C.value('@im', 'BIT') = 0
	OPTION ( OPTIMIZE FOR ( @xmlMatch = NULL ) )
	
	INSERT INTO @tmpMatch14 (MatchId)
	SELECT	T.C.value('@m', 'INT') AS MatchId
	FROM	@xmlMatch.nodes('/root/match') AS T(C)
	WHERE	T.C.value('@im', 'BIT') = 1
	OPTION ( OPTIMIZE FOR ( @xmlMatch = NULL ) )
	
	INSERT INTO @tmpBettype (Bettype)
	SELECT	T.C.value('@b', 'SMALLINT') AS MatchId
	FROM	@xmlBettype.nodes('/root/bettype') AS T(C)
	OPTION ( OPTIMIZE FOR ( @xmlBettype = NULL ) )
	
	SET  @strResults = CAST((
					SELECT	t.matchid	AS '@m'
							,t.bettype	AS '@b'
							,CASE WHEN t.cnt > 0 THEN 1 ELSE 0 END AS '@e'
					FROM(
						SELECT	b.matchid 
								,b.bettype
								,COUNT(1) AS cnt
						FROM	dbo.bettrans b WITH(NOLOCK)
							INNER JOIN @tmpMatch m
								ON	b.matchid = m.MatchId
							INNER JOIN @tmpBettype t
								ON	b.bettype = t.Bettype
						GROUP BY b.matchid, b.bettype
						UNION ALL
						SELECT	b.matchid
								,b.bettype
								,COUNT(1) AS cnt
						FROM	dbo.bettrans14 b WITH(NOLOCK)
							INNER JOIN @tmpMatch14 m
								ON	b.matchid = m.MatchId
							INNER JOIN @tmpBettype t
								ON	b.bettype = t.Bettype
						GROUP BY b.matchid, b.bettype
					) t
						FOR XML PATH ('result'), ROOT ('root'), TYPE
					) AS VARCHAR(MAX))
	
END
GO