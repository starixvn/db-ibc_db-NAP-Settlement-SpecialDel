/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_HybridParlay_ScheduleSel] 
       @MatchId	INT = 0
AS
/*
    Created by: Max
	Date 20251027
	Task: [Settlement] - Integration - Jacktime - Basketball Main Bettype Hybrid Parlay [Redmine: #241652]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20251027@Max: Init new SP [Redmine: #241652]

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON;

	IF EXISTS (SELECT TOP 1 1 FROM dbo.Parlay_Calculate_Queue p WITH (NOLOCK) WHERE p.matchid = @MatchId AND p.IsCalculating IN (0,1))
	BEGIN
		SELECT NULL AS MatchId
		RETURN
	END
	ELSE 
	BEGIN
		SELECT @MatchId AS MatchId
		WHERE EXISTS (SELECT TOP 1 1 FROM bettransm bm WITH (NOLOCK)
							WHERE bm.matchid = @MatchId
								AND bm.statuswinlost IS NOT NULL
								AND bm.statusID IN (0,1)
					)
	END
END