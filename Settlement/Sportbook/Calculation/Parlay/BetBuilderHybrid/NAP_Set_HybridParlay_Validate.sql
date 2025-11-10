/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_HybridParlay_Validate] 
	@MatchId	INT
	,@ErrCode		INT = 0 OUTPUT
	,@ErrMsg		NVARCHAR(200) = NULL OUTPUT
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

	IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.Parlay_Calculate_Queue p WITH (NOLOCK) WHERE p.matchid = @MatchId AND p.IsCalculating IN (0,1))
	BEGIN	
		SELECT DISTINCT TransId
		FROM dbo.bettrans b WITH (NOLOCK)
		CROSS APPLY (
			SELECT TOP 1 1 AS valid
			FROM bettransm bm WITH (NOLOCK)
			WHERE bm.refno = b.refno
				AND bm.matchid = @MatchId
				AND bm.statuswinlost IS NOT NULL
				AND bm.statusID IN (0,1)	
		)bm
		WHERE b.oddsspread = 3
			AND b.matchid = 29
			AND b.bettype = 29

		IF @@ROWCOUNT = 0
		BEGIN
			SELECT @ErrCode = 101
				, @ErrMsg = 'No valid ticket found.'
		END
	END
	ELSE
	BEGIN
		SELECT @ErrCode = 100
			, @ErrMsg = 'The parlay queue has not been completed yet.'
		
	END
END