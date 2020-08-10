/*<info serverAlias="DBARC-bodb_Archive" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_BettypesForRequest_Archive_Select]
(
	@RequestInfo	XML	= NULL
)
AS
/*	Created by: Zane
	Date 20200811
	Task: Edit SP for new change of Archive process [Redmine:#139208]
	DB: DBARC/bodb_Archive
	
	Revisions: 
		- 20200811@Zane: Archive process for Ticket Voiding tables [Redmine:#111093]

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
		INNER JOIN dbo.bettrans_bk bt WITH(NOLOCK) on req.TransId = bt.transid
		INNER JOIN dbo.f_SD_GetGroupBettypes() f ON f.BetType = bt.bettype
	
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
