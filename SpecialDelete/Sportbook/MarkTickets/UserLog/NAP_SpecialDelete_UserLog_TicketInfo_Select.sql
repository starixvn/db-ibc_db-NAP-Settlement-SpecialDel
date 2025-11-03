/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_SpecialDelete_UserLog_TicketInfo_Select 
    @TransIdsXml XML
AS
/*
	Create By: Zane
	Created Date: 20200911
	Task: Edit SP support Move server DB logs - [Redmine: #141235]
	DB: DBACC/BODB02
	
	Revisions: 
		- 20200911@Zane: Create new SP [Redmine: #141235]
		- 20251028@July: [TVS] Integration - Jacktime - Basketball Main Bettype Hybrid Parlay [Redmine: #241652]

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tblTransIds (transid BIGINT);
	
	INSERT INTO #tblTransIds (transid)
	SELECT T.C.value('@Id', 'BIGINT') AS transid
	FROM @TransIdsXml.nodes('/Tickets/Ticket') AS T(C)
	OPTION ( OPTIMIZE FOR ( @TransIdsXml = NULL ) )

	-- Return single transid	
	SELECT t.transid, b.TransId AS MainTransId
	FROM #tblTransIds t
		INNER JOIN dbo.bettrans b WITH(NOLOCK) ON t.transid = b.transid
	WHERE b.bettype <> 29

	-- Return parlay transid
	SELECT t.transid, b.TransId AS MainTransId
	FROM #tblTransIds t
		INNER JOIN dbo.bettrans b WITH(NOLOCK) ON t.transid = b.transid
	WHERE b.bettype = 29 AND ISNULL(b.oddsspread,0) <> 3
	
	-- Return Hybrid parlay transid
	SELECT t.transid, b.TransId AS MainTransId
	FROM #tblTransIds t
		INNER JOIN dbo.bettransm bm WITH(NOLOCK) ON t.transid = bm.transid
		INNER HASH JOIN dbo.bettrans b WITH(NOLOCK) ON b.refno = bm.refno
	WHERE b.bettype = 29 AND b.oddsspread = 3

	DROP TABLE #tblTransIds
END