/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_DuplicateTickets_TransIds_Select]
(
	@RequestId INT = 0
	,@VoidingHistoryId INT = NULL
)
AS
/*	
	Created by:20230717@Max
	Task: [TVS] Duplicate Ticket - New Issue Type [Redmine: #187835]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20230717@Max: Create new SP [Redmine:#187835]

	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @IsITSupport		BIT = 0
		,@IsITSupportCreatedRequest BIT = 0

	CREATE TABLE #tmp_TransIdsXML (GroupId INT IDENTITY(1,1), OrgTransIds VARCHAR(MAX), VoidedTransIds VARCHAR(MAX))

	--Check IT User
	SELECT @IsITSupport = ISNULL((SELECT IsValid FROM dbo.f_NAP_UserControl_UserSelect (vh.UserId,2)),0)
		, @IsITSupportCreatedRequest = ISNULL((SELECT IsValid FROM dbo.f_NAP_UserControl_UserSelect (r.UserId,2)),0) 
	FROM dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK)
		INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK)
			ON r.RequestId =  vh.RequestId
	WHERE	vh.VoidingHistoryId = @VoidingHistoryId

	--Get data XML from request
	INSERT INTO #tmp_TransIdsXML (OrgTransIds, VoidedTransIds)
	SELECT xTrans.OrgTransIds, xTrans.VoidedTransIds
	FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
	CROSS APPLY (
			SELECT CONVERT(XML, rd.TransIds)
		)AS t(xDATA)
	CROSS APPLY (
			SELECT t.c.value('@OrgTransIds','VARCHAR(MAX)') AS OrgTransIds
				,t.c.value('@VoidedTransIds','VARCHAR(MAX)') AS VoidedTransIds
			FROM t.xDATA.nodes('root/r') t(c)
		)xTrans
	WHERE rd.RequestId = @RequestId

	;WITH cte_Voided AS
	(
		SELECT f.TransId
			,t.GroupId
		FROM #tmp_TransIdsXML t
			CROSS APPLY (
				SELECT value AS TransId
				FROM string_split(VoidedTransIds, ',')
				WHERE value <> ''
			)f
	)
	,cte_TransInfo AS
	(
		SELECT f.GroupId
			,c.username
			,c.site
			,CASE 
				WHEN c.recommend IN (1077687,2331,115770,15523642,15042477,16041068,16041058) THEN 'BetFair'
				ELSE c.site
			END AS EmailGroup
			,b.currency
		FROM cte_Voided f
			INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = f.TransId
			INNER JOIN CustDB.dbo.customer c WITH (NOLOCK) ON c.custid = b.custid
	)
	,cte_IsHasUUSTickets AS
	(
		SELECT t.GroupId
			,COUNT(CASE WHEN t.currency = 20 THEN 1 ELSE NULL END) AS cnt_trans
		FROM cte_TransInfo t
		GROUP BY t.GroupId
	)
	,cte_StuffInfo AS
	(
		SELECT GroupId
			,STUFF((
				SELECT DISTINCT ',' + CAST(username AS VARCHAR(MAX)) 
				FROM cte_TransInfo
				WHERE (GroupId = r.GroupId)
				FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
				,1,1,''
			) AS usernames
			,STUFF((
				SELECT DISTINCT ',' + CAST(EmailGroup AS VARCHAR(MAX)) 
				FROM cte_TransInfo
				WHERE (GroupId = r.GroupId)
				FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
				,1,1,''
			) AS EmailGroup
			,STUFF((
				SELECT DISTINCT ',' + CAST(site AS VARCHAR(MAX)) 
				FROM cte_TransInfo
				WHERE (GroupId = r.GroupId)
				FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
				,1,1,''
			) AS site
		FROM cte_TransInfo r
		GROUP BY r.GroupId		
	)
	SELECT t.GroupId AS Id
		,REPLACE(t.OrgTransIds, ',', ', ') AS OrgTransIds
		,t.VoidedTransIds
		,t1.usernames
		,t1.EmailGroup
		,t1.site
		,@IsITSupport AS IsITSupport
		,@IsITSupportCreatedRequest AS IsITSupportCreatedRequest
		,CASE WHEN t2.cnt_trans > 0 THEN 1 ELSE 0 END AS IsHasUUSTickets
	FROM #tmp_TransIdsXML t
		INNER JOIN cte_StuffInfo t1 ON t1.GroupId = t.GroupId
		INNER JOIN cte_IsHasUUSTickets t2 ON t2.GroupId = t.GroupId
	ORDER BY t.GroupId

	DROP TABLE #tmp_TransIdsXML
END		
GO


