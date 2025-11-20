/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_HybridParlayLog_Sel] 
	@MatchId	INT
	,@TransIds	VARCHAR(MAX) = ''
	,@Logdate	DATETIMEOFFSET
AS
/*
    Created by: Max
	Date 20251027
	Task: [Settlement] - Integration - Jacktime - Basketball Main Bettype Hybrid Parlay [Redmine: #241652]
	DB: DBCTG-bodb02
	
	Revisions: 
		- 20251027@Max: Init new SP [Redmine: #241652]

	Param's explanation:
		@TransIds: Comma separated main parlay TransId list
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @lDate DATETIME
	SET @lDate = CAST(@Logdate AS DATETIME)	

	DECLARE @tmpTransId AS TABLE (TransId BIGINT)

	IF @TransIds <> ''
	BEGIN
		INSERT INTO @tmpTransId (TransId)
		SELECT DISTINCT value
		FROM string_split(@TransIds, ',')

		SELECT @MatchId AS MatchId, t.TransId, l.Odds
		FROM @tmpTransId t
		CROSS APPLY (
				SELECT TOP 1 Odds
				FROM dbo.BetBuilderHybridParlayLog l WITH (NOLOCK)
				WHERE l.MatchId = @MatchId
					AND l.TransId = t.TransId
					AND l.Logdate >= @lDate
				ORDER BY LogDate DESC
		)l

	END
	ELSE
	BEGIN
		;WITH cte AS (
			SELECT l.MatchId, l.TransId, MAX(Logdate) AS maxLogDate
			FROM dbo.BetBuilderHybridParlayLog l WITH (NOLOCK)
			WHERE l.MatchId = @MatchId
				AND l.LogDate >= @lDate
			GROUP BY l.MatchID, l.TransId
		)
		SELECT t.MatchID, t.TransId, l.Odds
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