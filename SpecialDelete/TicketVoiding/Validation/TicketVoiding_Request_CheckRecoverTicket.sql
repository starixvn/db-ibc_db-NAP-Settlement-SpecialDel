/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Request_CheckRecoverTicket]
(
	@RequestId					INT = 0
	,@IsVoidAllArchivedTickets	BIT = 0
	,@RecoverTicketInfo			VARCHAR(MAX) = NULL
)
AS
/*	
	Created by: 20240102@July
	Task: [TVS] Recover Ticket issue type [Redmine: #196020]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20240102@July: Create new SP [Redmine:#196020]
		- 20240416@Max: [TVS] Recover Ticket - Recover full range of archived tickets [Redmine: #203754]
		- 20250602@Lani: [TVS] Recover Ticket - Support Recover More Products - Sub Parlay [Redmine: #227829]
		
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @InvalidTransIds				VARCHAR(MAX) = ''
		   ,@UnsupportedDateRangeTransIds	VARCHAR(MAX) = ''
		   ,@ExistingReqTransIds			VARCHAR(MAX) = ''
		   ,@TransInfoJson_Output			VARBINARY(MAX) = NULL
		   ,@UnmarkTransIds					VARCHAR(MAX) =''
		   ,@GetDateRange					DATETIME
		   ,@SiteDBGroupId					SMALLINT
		   ,@RecoverTicketInfoXML			XML			 = NULL
		   ,@TransIds						VARCHAR(MAX) = NULL
		   ,@ProductIds						VARCHAR(50)	 = NULL
		   ,@FilterBy						TINYINT		 = NULL --(NULL: single & main parlay, 1: subparlay)
		   ,@MatchId						INT			 = NULL --(NULL: single & main parlay)

	SET @GetDateRange = DATEADD(DAY, -7, CAST(GETDATE() AS DATE))
	SELECT @SiteDBGroupId = dbo.f_Get_SiteDBGroupID()
	
	DECLARE @UnsupportedTransids AS TABLE (transid BIGINT)	
	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)
	DECLARE @ProductId_tmp AS TABLE (ProductId TINYINT)
	DECLARE @TmpMatchId AS TABLE (MatchId INT)

	CREATE TABLE #transIdTemp (transid BIGINT PRIMARY KEY)
	CREATE TABLE #TransidInRequest (TransId BIGINT PRIMARY KEY)
	
	--Get user input info
	SET @RecoverTicketInfoXML = CONVERT(XML, @RecoverTicketInfo)
	SELECT @TransIds = t.c.value('@TransIds','NVARCHAR(MAX)')
		  ,@ProductIds = t.c.value('@ProductIds','VARCHAR(50)')
		  ,@FilterBy = CASE WHEN t.c.value('@FilterBy','TINYINT') = 0 THEN NULL ELSE t.c.value('@FilterBy','TINYINT') END
		  ,@MatchId = CASE WHEN t.c.value('@MatchId','INT') = 0 THEN NULL ELSE t.c.value('@MatchId','INT') END
	FROM @RecoverTicketInfoXML.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@RecoverTicketInfoXML = NULL))

	--Insert ProductId list into tmp table
	INSERT INTO @ProductId_tmp (ProductId)
	SELECT DISTINCT value
	FROM STRING_SPLIT(@ProductIds, ',')
	WHERE value <> ''

	--Insert transid list into tmp table
	INSERT INTO #transIdTemp (transid)
	SELECT DISTINCT value
	FROM STRING_SPLIT(@TransIds,',')
	WHERE value <> ''			

	INSERT INTO @bettype_tmp (bettype)
	SELECT DISTINCT pt.bettype
	FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
	WHERE pt.ProductID IN (SELECT ProductId FROM @ProductId_tmp)
		AND pt.SubProduct NOT IN ('MG-SuperLive', 'BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') --, Metric Gaming, Bet trade (BT-)
		AND pt.bettype NOT IN (31,32,33,71,72,73)	-- NOT IN [Racing, Casino]
		AND pt.bettype NOT BETWEEN 1501 AND 1599 -- NOT IN Keno
		AND pt.BetType NOT IN  (10) --Outright
	
	CREATE TABLE #validTransId (
		transid			BIGINT PRIMARY KEY
		,StatusId		INT
		,bettype		SMALLINT
		,matchid		INT
		,betteam		NVARCHAR(10)
		,betfrom		NVARCHAR(4)
		,winlostdate	DATETIME
		,betdaqid		BIGINT
		,Subtransid		BIGINT
		,IsMove14		BIT
		,IsMixParlay    BIT DEFAULT(0)
		,custid			INT
		,refno			BIGINT
		,SiteDBGroupId	SMALLINT
		,betid			BIGINT
	)

	IF @FilterBy IS NULL
	BEGIN
		INSERT INTO #validTransId( 
			   matchid
			  ,transid 
			  ,custid
			  ,bettype
			  ,betid
			  ,betdaqid 
			  ,betfrom
			  ,betteam
			  ,statusID
			  ,winlostdate
			  ,SiteDBGroupID
			  ,IsMove14
			  ,refno
			  ,Subtransid
			)
		SELECT z.matchid
			  ,z.transid
			  ,z.custid
			  ,b.bettype
			  ,b.betid
			  ,b.betdaqid
			  ,b.betfrom
			  ,b.betteam
			  ,b.statusID
			  ,b.winlostdate
			  ,b.SiteDBGroupID
			  ,0 AS IsMove14
			  ,z.refno
			  ,z.transid AS SubTransId
		FROM dbo.zzzbettrans AS z WITH (NOLOCK)
		INNER JOIN #transIdTemp AS t ON z.transid = t.transid
		INNER JOIN dbo.bettrans AS b WITH (NOLOCK)
			ON b.TransId = z.transid
			AND b.custid = z.custid
			AND b.matchid = z.matchid
			AND b.bettype = z.bettype
		WHERE b.betfrom <> 'p'
			AND z.SiteDBGroupID = @SiteDBGroupId 
			AND b.SiteDBGroupID = z.SiteDBGroupID
			AND ISNULL(z.comstatus,'') <> 'CO'

		--Update Main MatchId for child match cricket/baseball (Sporttype In (50,8))
		UPDATE d
		SET d.matchid = m.ParentID
		FROM #validTransId AS d
		INNER JOIN dbo.match AS m WITH (NOLOCK) 
			ON d.matchid = m.matchid 
			AND m.sporttype IN (50,8)
			AND m.ChildMatchType = 200
		WHERE d.bettype NOT IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))
	END
	ELSE
	BEGIN
		--Get child match of cricket/baseball
		INSERT INTO @TmpMatchId (MatchId)
		SELECT matchid
		FROM dbo.match WITH (NOLOCK)
		WHERE  1 = CASE WHEN sporttype NOT IN (50,8) AND matchid = @MatchId THEN 1
						WHEN sporttype IN (50,8) AND (matchid = @MatchId OR ParentID = @MatchId) THEN 1
						ELSE 0 END

		INSERT INTO #validTransId( 
				   matchid
				  ,transid 
				  ,custid
				  ,bettype
				  ,betid
				  ,betdaqid 
				  ,betfrom
				  ,betteam
				  ,statusID
				  ,winlostdate
				  ,SiteDBGroupID
				  ,IsMixParlay
				  ,IsMove14
				  ,refno
				  ,Subtransid
				)
		SELECT	bm.matchid
				,b.transid
				,b.custid
				,bm.bettype
				,b.betid
				,b.betdaqid
				,b.betfrom
				,b.betteam
				,bm.statusID
				,bm.winlostdate AS SubWinlostdate
				,bm.SiteDBGroupID
				,1 AS IsMixParlay
				,0 AS IsMove14
				,bm.refno
				,bm.transid AS SubTransId
		FROM #transIdTemp AS t 
		INNER JOIN dbo.bettrans AS b WITH (NOLOCK) 
				ON b.TransId = t.TransId AND b.SiteDBGroupID = @SiteDBGroupId
		INNER JOIN dbo.bettransm AS bm WITH (NOLOCK) 
				ON b.refno = bm.refno AND b.SiteDBGroupID = bm.SiteDBGroupID
		INNER JOIN @TmpMatchId AS tm 
				ON bm.matchid = tm.MatchId
		WHERE b.bettype = 29
			AND bm.statusID = 102
			AND b.betfrom <> 'p'
	END
	
	--get ticket in bettrans14
	IF EXISTS (SELECT TOP (1) 1 FROM #transIdTemp AS t 
								INNER JOIN dbo.bettrans14 AS b14 WITH (NOLOCK) ON b14.transid = t.transid
								WHERE b14.SiteDBGroupID = @SiteDBGroupId AND @FilterBy IS NULL)
	BEGIN 
		INSERT INTO #validTransId( 
		   matchid
		  ,transid 
		  ,custid
		  ,bettype
		  ,betid
		  ,betdaqid 
		  ,betfrom
		  ,betteam
		  ,statusID
		  ,winlostdate
		  ,SiteDBGroupID
		  ,IsMove14
		  ,refno
		  ,Subtransid
		)
		SELECT 
			z.matchid
			,z.transid
			,z.custid
			,b14.bettype
			,b14.betid
			,b14.betdaqid
			,b14.betfrom
			,b14.betteam
			,b14.statusID
			,b14.winlostdate
			,b14.SiteDBGroupID
			,1 AS IsMove14
			,z.refno
			,z.transid AS SubTransId
		FROM dbo.zzzbettrans AS z WITH (NOLOCK) 
			INNER JOIN #transIdTemp AS t ON z.transid = t.transid
			INNER JOIN dbo.bettrans14 AS b14 WITH (NOLOCK)
				ON b14.transid = z.transid
				AND b14.custid = z.custid
				AND b14.matchid = z.matchid
				AND b14.bettype = z.bettype
		WHERE b14.betfrom <> 'p'
			AND z.SiteDBGroupID = @SiteDBGroupId
			AND b14.SiteDBGroupID = z.SiteDBGroupID
			AND ISNULL(z.comstatus,'') <> 'CO'
			AND 1 = CASE WHEN b14.bettype NOT IN (SELECT b14.bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1)) AND b14.statuswinlost IS NULL THEN 0 ELSE 1 END -- not support recover single tickets that don't have statuswinlost in range 14

		--exclude main parlay with refno not exist in BetParlayResults and all combine not completed
		DELETE t
		FROM #validTransId AS t
		OUTER APPLY (
			SELECT TOP 1 1 refno
			FROM dbo.BetParlayResult AS b WITH (NOLOCK)
			WHERE b.RefNo = t.refno ) AS rs
		WHERE rs.refno IS NULL
			AND t.IsMove14 = 1
			AND t.matchid IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))

		DELETE t
		FROM #validTransId AS t
		CROSS APPLY (
			SELECT TOP 1 1 refno
			FROM dbo.BetParlayResult AS b WITH (NOLOCK)
			WHERE b.refno = t.refno AND b.statusid = 0 ) AS rs
		WHERE t.IsMove14 = 1 
			AND t.matchid IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))
	
		--Update main matchid for child match cricket/baseball
		UPDATE d
		SET d.matchid = m.ParentID
		FROM #validTransId AS d
		INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON d.matchid = m.matchid AND m.sporttype IN (50,8) AND m.ChildMatchType = 200
		WHERE d.bettype NOT IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))
	END
	
	IF NOT EXISTS (SELECT TOP 1 1 FROM #validTransId)
	BEGIN
		-- Return validation/Transinfo table
		SET @InvalidTransIds = @TransIds
		SELECT @InvalidTransIds AS InvalidTransIds
			  ,@UnmarkTransIds AS UnmarkTransIds
			  ,@TransInfoJson_Output AS TransInfoJson
		
		RETURN;
	END

	--final valid transid
	DELETE t
	FROM #validTransId t
		OUTER APPLY (SELECT bettype FROM @bettype_tmp WHERE bettype = t.bettype) bt
	WHERE StatusId NOT IN (102) --VOID
		OR bt.bettype IS NULL
		OR t.betfrom = 'p'
		
	-- invalid transId
	SELECT @InvalidTransIds = ISNULL(STUFF((SELECT ',' + CAST(t.transid AS VARCHAR(50))
										FROM #transIdTemp t
										WHERE NOT EXISTS (SELECT TOP 1 1 FROM #validTransId WHERE transid = t.transid)
										FOR XML PATH('')), 1, 1, ''), '')
	
	INSERT INTO #TransidInRequest (TransId)
	SELECT DISTINCT rs.TransId
	FROM  DBCTG.bodb02.dbo.TicketVoiding_Request r WITH (NOLOCK) 
		INNER JOIN DBCTG.bodb02.dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK) ON rs.RequestId = r.RequestId
		CROSS APPLY (
					SELECT TOP 1 t.transid
					FROM #transIdTemp t
					WHERE rs.TransId = t.transid
			)t
	WHERE r.RequestId <> @RequestId AND r.IssueTypeId IN (22) -- Recover Ticket
	UNION 
	SELECT DISTINCT rsp.MainTransId
	FROM DBCTG.bodb02.dbo.TicketVoiding_Request AS r WITH (NOLOCK)
		INNER JOIN DBCTG.bodb02.dbo.TicketVoiding_RequestDetailTicket_SubParlay AS rsp WITH (NOLOCK) ON r.RequestId = rsp.RequestId
		CROSS APPLY (
			SELECT TOP 1 t.transid
			FROM #transIdTemp AS t
			WHERE t.transid = rsp.MainTransId
		) AS t
	WHERE r.RequestId <> @RequestId AND r.IssueTypeId IN (22) AND rsp.MatchId = @MatchId AND @FilterBy IS NOT NULL 
	

	SELECT @ExistingReqTransIds = ISNULL(STUFF((SELECT ',' + CAST(t.transid AS VARCHAR(50))
										FROM #transIdTemp t 
											INNER JOIN #TransidInRequest tr ON t.transid = tr.TransId
										FOR XML PATH('')), 1, 1, ''), '')


	IF @IsVoidAllArchivedTickets = 0 AND EXISTS (SELECT TOP 1 1 FROM #validTransId WHERE winlostdate < @GetDateRange)
	BEGIN
		DELETE 
		FROM #validTransId
			OUTPUT	DELETED.TransId
			INTO @UnsupportedTransids (TransId)
		WHERE winlostdate < @GetDateRange

		SELECT @UnsupportedDateRangeTransIds = ISNULL(STUFF((SELECT ',' + CAST(t.transid AS VARCHAR(50))
														FROM @UnsupportedTransids t
														FOR XML PATH('')
													), 1, 1, ''), '')
	END	

	SELECT @UnmarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(v.SubTransid AS VARCHAR(50)) 
											FROM #validTransId v
											WHERE v.IsMove14 = 0
											FOR XML PATH('')), 1,1,''),'')

	/*****************Return table **************************/
	-- 1. Return validation/Transinfo table
	SET @TransInfoJson_Output = COMPRESS((SELECT t.matchid AS 'mid'
		,t.transid AS 't'
		,t.Subtransid  AS 's_t'
		,t.custid AS  'c' 
		,t.bettype AS 'btype'
		,t.betid AS 'bid'
		,t.IsMixParlay AS 'isP'
		,t.IsMove14 AS 'isM'
		,t.SiteDBGroupID AS 'sitedb'
	FROM #validTransId t
	FOR JSON PATH))
	
	SELECT @InvalidTransIds AS InvalidTransIds
		 , @UnsupportedDateRangeTransIds AS UnsupportedDateRangeTransIds
		 , @ExistingReqTransIds AS ExistingReqTransIds
		 , @UnmarkTransIds AS UnmarkTransIds
		 , CONVERT(VARCHAR(MAX), @TransInfoJson_Output, 1) AS TransInfoJson

	DROP TABLE #transIdTemp
	DROP TABLE #validTransId
	DROP TABLE #TransidInRequest
END