/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_WaitingOtherSportSel_MatchInfo] 
	@MatchIds	VARCHAR(MAX)
AS
/*
	Created: 20230920@Aries
	Task: Remove remote query [Redmine:#194117] 
	DB: DBTXN/BODB02
	
	Revision:
		- 20230920@Aries: Remove remote query [Redmine:#194117]

	Param's explanation:  
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @tmpMatch TABLE (MatchId INT, Sporttype SMALLINT)
	DECLARE @tmpMatchAutoStatus TABLE ( Matchid INT, StatusId TINYINT )
	DECLARE @tmpMatchOddsES TABLE (MatchId INT)

	INSERT INTO @tmpMatch (MatchId, Sporttype)
	SELECT f.[value]
		  ,m.Sporttype
	FROM STRING_SPLIT(@MatchIds, ',') AS f
		INNER JOIN dbo.match AS m WITH (NOLOCK) ON f.[value] = m.MatchId
	
	INSERT INTO @tmpMatchAutoStatus (MatchId, StatusId)
	SELECT  m.matchid,MAX(r.StatusId) AS StatusId
	FROM @tmpMatch AS m 
		INNER JOIN dbo.AutoPayoutResultOS AS r WITH (NOLOCK) ON r.MatchId = m.MatchId AND ISNULL(r.SourceID,0) = 0 
	GROUP BY m.MatchId

	IF EXISTS (SELECT TOP 1 1 FROM @tmpMatchIds WHERE sporttype = 43)
	BEGIN
		INSERT INTO @tmpMatchOddsES (MatchId)
		SELECT	DISTINCT o.matchid 
		FROM	DBPRO.bodb02.dbo.oddsES AS o WITH(NOLOCK)
			INNER JOIN @tmpMatchIds AS m ON o.matchid = m.matchid
		WHERE o.bettype IN (SELECT bt.bettype FROM dbo.f_Set_GetEarlyBettypes() AS bt)
				AND m.sporttype = 43
	END

	SELECT m.MatchId
		  ,ma.StatusId
		  ,IIF(mo.MatchId IS NOT NULL,0,1) AS IsOpenOdds
	FROM @tmpMatch AS m
		LEFT JOIN @tmpMatchAutoStatus AS ma ON ma.MatchId = m.MatchId
		LEFT JOIN @tmpMatchOddsES AS mo ON mo.MatchId = m.MatchId
	WHERE ma.MatchId IS NOT NULL
		OR mo.MatchId IS NOT NULL
END
GO