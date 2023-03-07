/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
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
	SELECT t.transid
		FROM #tblTransIds t
			LEFT JOIN dbo.bettrans b WITH(NOLOCK) ON t.transid = b.transid
			WHERE b.bettype <> 29

	-- Return parlay transid
	SELECT t.transid
		FROM #tblTransIds t
			LEFT JOIN dbo.bettrans b WITH(NOLOCK) ON t.transid = b.transid
			WHERE b.bettype = 29

	DROP TABLE #tblTransIds
END