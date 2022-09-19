/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20220808@Max
	Task: Initial data TicketVoiding_RequestDetail_MixParlay - [Redmine:#175412]  
	DB: DBCTG-bodb02
*/

USE bodb02
GO

DECLARE @tmp_Transids AS TABLE (RequestId INT, MainTransId BIGINT)
INSERT INTO @tmp_Transids(RequestId, MainTransId)
SELECT s.RequestId, s.TransId
FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
	INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = s.RequestId AND r.IssueTypeId = 11 AND r.ActionId = 1
WHERE s.MatchId = 29

IF @@ROWCOUNT > 0
BEGIN
	INSERT INTO dbo.TicketVoiding_RequestDetail_MixParlay(RequestId, MatchId, MainTransId)
	SELECT t.RequestId, bm.matchid, t.MainTransId
	FROM @tmp_Transids t
		INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = t.MainTransId
		INNER HASH JOIN dbo.bettransm bm WITH (NOLOCK) ON bm.refno = b.refno
END





