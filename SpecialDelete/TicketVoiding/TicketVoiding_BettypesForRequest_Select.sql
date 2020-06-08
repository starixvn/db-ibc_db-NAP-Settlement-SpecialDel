/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_BettypesForRequest_Select]
(
	@RequestInfo	XML	= NULL
)
AS
/*	Created by: Charles
	Date 20200602
	Task: Get bettypes for request [Redmine:#135041]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20200602@Charles: Create new SP [Redmine:#135041]
		
	Param's explanation:
	- @RequestInfo : 
		'<Requests>
			<Request 
				RequestId="52174"						-- RequestId
				TransIds="109029184195,109029184196"	-- TransIds
			/>
		<Requests/>'	
*/
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #tblRequestInfo
	(
		RequestId		INT PRIMARY KEY,
		TransIds		VARCHAR(MAX)
	)

	CREATE TABLE #tblRequestInfo_Detail
	(
		RequestId		INT,
		TransId			BIGINT
	)

	CREATE TABLE #tblResult
	(
		RequestId		INT,
		Bettype			SMALLINT,
		BetId			BIGINT
	)

	-- Parse xml @RequestInfo
	INSERT INTO #tblRequestInfo(RequestId, TransIds)
	SELECT t.c.value('@RequestId','INT') AS RequestId
			, t.c.value('@TransIds','VARCHAR(MAX)') AS TransIds
	FROM @RequestInfo.nodes('Requests/Request') t(c)
	OPTION (OPTIMIZE FOR (@RequestInfo = NULL))

	INSERT INTO #tblRequestInfo_Detail(RequestId, TransId)
	SELECT req.RequestId, CAST(tr.val AS BIGINT)
	FROM #tblRequestInfo req
		CROSS APPLY dbo.strSplit(req.TransIds, ',') tr
	OPTION (MAXRECURSION 0)
	
	INSERT INTO #tblResult(RequestId, Bettype, BetId)
	SELECT req.RequestId
			,bt.bettype AS Bettype
			,CASE WHEN f.IsNameXBettype = 1 THEN bt.betid ELSE NULL END AS BetId
	FROM #tblRequestInfo_Detail req
		INNER JOIN dbo.bettrans bt WITH(NOLOCK) on req.TransId = bt.transid
		INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = bt.bettype
	
	-- Return data
	SELECT RequestId, Bettype, BetId
	FROM #tblResult
	GROUP BY RequestId, Bettype, BetId
	ORDER BY Bettype DESC


	DROP TABLE #tblRequestInfo
	DROP TABLE #tblRequestInfo_Detail
	DROP TABLE #tblResult
END
GO
