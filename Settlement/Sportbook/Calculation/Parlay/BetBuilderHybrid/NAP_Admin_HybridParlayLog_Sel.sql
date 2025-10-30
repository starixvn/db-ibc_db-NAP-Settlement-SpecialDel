/*<info serverAlias="DBLOG-bodb_Customerlog" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_HybridParlayLog_Sel] 
	@MatchId	INT
	,@TransIds	VARCHAR(MAX) = ''
	,@Logdate	DATETIME
AS
/*
    Created by: Max
	Date 20251027
	Task: [Settlement] - Integration - Jacktime - Basketball Main Bettype Hybrid Parlay [Redmine: #241652]
	DB: DBLOG-bodb_Customerlog
	
	Revisions: 
		- 20251027@Max: Init new SP [Redmine: #241652]

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @tmpTransId AS TABLE (TransId BIGINT)

	IF @TransIds <> ''
	BEGIN
		INSERT INTO @tmpTransId (TransId)
		SELECT DISTINCT value
		FROM string_split(@TransIds, ',')

		SELECT @MatchId AS MatchId, t.TransId AS Betid, l.Odds
		FROM @tmpTransId t
		CROSS APPLY (
				SELECT TOP 1 Odds
				FROM dbo.BetBuilderHybridParlayLog l WITH (NOLOCK)
				WHERE l.MatchId = @MatchId
					AND l.TransId = t.TransId
					AND l.Logdate >= @Logdate
				ORDER BY LogDate DESC
		)l
	END
	ELSE
	BEGIN
		;WITH cte AS (
			SELECT l.MatchId, l.TransId, MAX(Logdate) AS maxLogDate
			FROM dbo.BetBuilderHybridParlayLog l WITH (NOLOCK)
			WHERE l.MatchId = @MatchId
				AND l.LogDate >= @Logdate
			GROUP BY l.MatchID, l.TransId
		)
		SELECT t.MatchID, t.TransId AS Betid, l.Odds
		FROM cte t
		CROSS APPLY (
				SELECT TOP 1 Odds
				FROM dbo.BetBuilderHybridParlayLog l WITH (NOLOCK)
				WHERE l.MatchId = t.MatchId
					AND l.TransId = t.TransId
					AND l.Logdate = t.maxLogDate
				ORDER BY LogDate DESC
		)l
	END

	
END