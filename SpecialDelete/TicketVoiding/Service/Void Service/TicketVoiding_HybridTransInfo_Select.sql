/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_HybridTransInfo_Select]
(
	@TransId	VARCHAR(MAX) = NULL
)
AS
/*	
	Created by: Max
	Date 20251027
	Task: [TVS] Integrate Hybrid Parlay from Jacktime for Basketball sport [Redmine: #241502]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20251027@Max: Init new SP [Redmine: #241502]

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @tmp_TransIds AS TABLE (TransId BIGINT)

	INSERT INTO @tmp_TransIds (TransId)
	SELECT value
	FROM string_split(@TransId, ',')

	SELECT t.TransId, bm.matchid, bm.bettype, bm.hdp1, bm.betteam
	FROM @tmp_TransIds t
		INNER JOIN dbo.bettransm bm WITH (NOLOCK) ON bm.TransId = t.TransId
END
GO

