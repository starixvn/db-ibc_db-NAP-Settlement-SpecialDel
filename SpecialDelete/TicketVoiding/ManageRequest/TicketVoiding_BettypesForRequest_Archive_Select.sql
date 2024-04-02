/*<info serverAlias="DBARC-bodb_Archive" executers="wsv_nap" isFunction="0"></info>*/
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
		- 20211118@Kathy: Tuning performance [Redmine:#164819]
		- 20220808@July: Change function to STRING_SPLIT [Redmine: #175412]

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
		TransId			BIGINT,
		Bettype			SMALLINT,
		BetId			BIGINT
	)

	-- Parse xml @RequestInfo
	INSERT INTO #tblRequestInfo(RequestId, TransIds)
	SELECT	t.c.value('@RequestId','INT') AS RequestId
			,t.c.value('@TransIds','VARCHAR(MAX)') AS TransIds
	FROM	@RequestInfo.nodes('Requests/Request') t(c)
	OPTION (OPTIMIZE FOR (@RequestInfo = NULL))

	INSERT INTO #tblRequestInfo_Detail(RequestId, TransId)
	SELECT	req.RequestId, CAST(tr.value AS BIGINT)
	FROM	#tblRequestInfo req
		CROSS APPLY STRING_SPLIT(req.TransIds, ',') tr
	
	UPDATE t
		SET Bettype = s.Bettype
			,BetId = CASE WHEN f.IsNameXBettype = 1 THEN s.BetId ELSE NULL END
	FROM	#tblRequestInfo_Detail t
		CROSS APPLY (
			SELECT	TOP 1 s.Bettype, s.BetId
			FROM	dbo.TicketVoiding_RequestDetailTicket_Single_bk s WITH(NOLOCK)
			WHERE	s.RequestId = t.RequestId
					AND s.TransId = t.TransId
		)s
		OUTER APPLY (
			SELECT	TOP 1 f.IsNameXBettype
			FROM	dbo.f_SD_GetGroupBettypes () f
			WHERE	f.bettype = s.Bettype
		)f
	
	-- Return data
	SELECT	RequestId, Bettype, BetId
	FROM	#tblRequestInfo_Detail
	GROUP BY RequestId, Bettype, BetId
	ORDER BY Bettype DESC

	DROP TABLE #tblRequestInfo
	DROP TABLE #tblRequestInfo_Detail
END
GO
