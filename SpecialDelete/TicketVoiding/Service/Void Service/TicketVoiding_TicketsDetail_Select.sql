/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_TicketsDetail_Select]
(
	@TransIds		VARCHAR(MAX) = NULL
	,@TicketType	TINYINT
)
AS
/*	
	Created by: Max
	Date 20251027
	Task: [TVS] Integrate Hybrid Parlay from Jacktime for Basketball sport [Redmine: #241502]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
	
	Revisions: 
		- 20251027@Max: Init new SP [Redmine: #241502]

	Param's explanation:
		@TicketType: 
			0 - MainHybrid Parlay
			1 - SubHybrid Parlay	
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @tmp_TransIds AS TABLE (TransId BIGINT)

	INSERT INTO @tmp_TransIds (TransId)
	SELECT value
	FROM STRING_SPLIT(@TransIds, ',')

	IF @TicketType = 0
	BEGIN
		SELECT b.TransId AS MainTransId, b.custid, NULL AS SubTransId, NULL AS SubMatchId, NULL AS SubBettype, NULL AS SubHdp1, NULL AS SubBetteam, b.transdesc 
		FROM @tmp_TransIds t
			INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransID = t.TransId AND b.matchid = 29 AND b.bettype = 29 AND b.oddsspread = 3
	END
	IF @TicketType = 1
	BEGIN
		SELECT b.TransId AS MainTransId, b.custid, t.TransId AS SubTransId, bm.matchid AS SubMatchId, bm.bettype AS SubBettype, bm.hdp1 AS SubHdp1, bm.betteam AS SubBetteam, b.transdesc 
		FROM @tmp_TransIds t
			INNER JOIN dbo.bettransm bm WITH (NOLOCK) ON bm.TransId = t.TransId
			INNER HASH JOIN dbo.bettrans b WITH (NOLOCK) ON b.refno = bm.refno AND b.matchid = 29 AND b.bettype = 29
	END
END
GO

