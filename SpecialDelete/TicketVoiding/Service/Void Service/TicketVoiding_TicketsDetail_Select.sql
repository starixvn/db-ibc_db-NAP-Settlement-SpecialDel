/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_TicketsDetail_Select]
(
	@TransIds		VARCHAR(MAX) = NULL
   ,@TicketType		TINYINT
   ,@MatchId		INT = NULL
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
	
	DECLARE @SiteDBGroupID SMALLINT = 0
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	DECLARE @tmp_TransIds AS TABLE (TransId BIGINT)
	DECLARE @tmp_Results TABLE (
			MainTransId BIGINT,
			CustId INT,
			SubTransId BIGINT,
			SubMatchId INT,
			SubBettypeId SMALLINT,
			SubHdp1 SMALLMONEY,
			SubHdp2 SMALLMONEY,
			Subbetcheck NVARCHAR(100),
			SubBetteam NVARCHAR(100),
			Transdesc NVARCHAR(1000),
			Refno BIGINT,
			SelectionCount INT
		)

	INSERT INTO @tmp_TransIds (TransId)
	SELECT value
	FROM STRING_SPLIT(@TransIds, ',')

	IF @TicketType = 0
	BEGIN
		INSERT INTO @tmp_Results (MainTransId, CustId, SubTransId, SubMatchId, SubBettypeId, SubHdp1, SubHdp2, Subbetcheck, SubBetteam, Transdesc)
		SELECT b.TransId AS MainTransId, b.custid, NULL AS SubTransId, NULL AS SubMatchId, NULL AS SubBettypeId, NULL AS SubHdp1, NULL AS SubHdp2, NULL AS Subbetcheck, NULL AS SubBetteam, b.transdesc
		FROM @tmp_TransIds t
			INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransID = t.TransId AND b.matchid = 29 AND b.bettype = 29 AND b.oddsspread = 3
		WHERE b.SiteDBGroupID = @SiteDBGroupID
	END

	ELSE IF @TicketType = 1
	BEGIN
		INSERT INTO @tmp_Results (MainTransId, CustId, SubTransId, SubMatchId, SubBettypeId, SubHdp1, SubHdp2, Subbetcheck, SubBetteam, transdesc, Refno)
		SELECT b.TransId AS MainTransId, b.CustId, t.TransId AS SubTransId, bm.matchid AS SubMatchId, bm.bettype AS SubBettypeId, bm.hdp1 AS SubHdp1, bm.hdp2 AS SubHdp2, bm.betcheck AS Subbetcheck, bm.betteam AS SubBetteam, b.transdesc, bm.refno
		FROM @tmp_TransIds t
			INNER JOIN dbo.bettransm bm WITH (NOLOCK) ON bm.TransId = t.TransId
			INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.refno = bm.refno AND b.matchid = 29 AND b.bettype = 29
		WHERE b.SiteDBGroupID = @SiteDBGroupID AND bm.MatchId = @MatchId

		UPDATE r
		SET r.SelectionCount = sc.SelectionCount
		FROM @tmp_Results r
			CROSS APPLY 
				( 
					SELECT bm.refno, bm.matchid, COUNT(1) AS SelectionCount
					FROM dbo.bettransm bm WITH (NOLOCK)
					WHERE r.Refno = bm.refno AND r.SubMatchId = bm.matchid
					GROUP BY bm.refno, bm.matchid
				) sc
	END
	SELECT MainTransId, CustId, SubTransId, SubMatchId, SubBettypeId, SubHdp1, SubHdp2, Subbetcheck, SubBetteam, transdesc, SelectionCount
	FROM @tmp_Results
	
END
GO

