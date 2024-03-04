/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_Request_CheckRecoverTicket]
(
	 @TransIds					VARCHAR(MAX) = NULL
	,@RequestId					INT = 0
	,@FilterBy					TINYINT	= NULL -- (NULL: sing & mix parlay, 3: subparlay)
	,@ProductIds				VARCHAR(50)  = NULL
	,@TransInfoJson				VARCHAR(MAX) = NULL
)
AS
/*	
	Created by: 20240102@July
	Task: [TVS] Recover Ticket issue type [Redmine: #196020]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20240102@July: Create new SP [Redmine:#196020]
		
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

	SET @GetDateRange = DATEADD(DAY, -7, CAST(GETDATE() AS DATE))
	
	DECLARE @UnsupportedTransids AS TABLE (transid BIGINT)	
	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)
	DECLARE @ProductId_tmp AS TABLE (ProductId TINYINT)
	
	INSERT INTO @ProductId_tmp (ProductId)
	SELECT DISTINCT value
	FROM STRING_SPLIT(@ProductIds, ',')
	WHERE value <> ''

	INSERT INTO @bettype_tmp (bettype)
	SELECT DISTINCT pt.bettype
	FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
	WHERE pt.ProductID IN (SELECT ProductId FROM @ProductId_tmp)
		AND pt.SubProduct NOT IN ('MG-SuperLive', 'BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') --, Metric Gaming, Bet trade (BT-)
		AND pt.bettype NOT IN (31,32,33,71,72,73)	-- NOT IN [Racing, Casino]
		AND pt.bettype NOT BETWEEN 1501 AND 1599 -- NOT IN Keno
		AND pt.BetType NOT IN  (10) --Outright

	CREATE TABLE #transIdTemp (transid BIGINT PRIMARY KEY)
	CREATE TABLE #TransidInRequest (TransId BIGINT PRIMARY KEY)
	
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
	)

	CREATE TABLE #tmpTransInfo(
	   matchid INT
	  ,transid BIGINT
      ,custid	INT	
	  ,bettype SMALLINT
      ,betid BIGINT
	  ,betdaqid BIGINT
      ,betteam	NVARCHAR(10)
	  ,statusID TINYINT
      ,betfrom NVARCHAR(4)
	  ,winlostdate SMALLDATETIME
	  ,IsMixParlay BIT
	  ,SiteDBGroupID SMALLINT
	  ,IsMove14 BIT

	)

	INSERT INTO #tmpTransInfo( 
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
		  ,IsMixParlay
		  ,SiteDBGroupID
		  ,IsMove14
		)
	SELECT mid, t, c, btype, bid, bdaq, bfr, bteam, sid, wld, isP, sitedb, isM
	FROM STRING_SPLIT(@TransInfoJson, ',') f
		CROSS APPLY (SELECT CAST(DECOMPRESS(CONVERT(VARBINARY(MAX), f.value, 1)) AS NVARCHAR(MAX)) AS Decompress_TransInfoJson) t
		CROSS APPLY (
				SELECT mid, t, c, btype, bid, bdaq, bfr, bteam, sid, wld, isP, sitedb, isM
				FROM OPENJSON(t.Decompress_TransInfoJson) 
					WITH( mid INT, t BIGINT, c INT, btype SMALLINT, bid BIGINT, bdaq BIGINT, bfr NVARCHAR(4), bteam NVARCHAR(10)
						, sid TINYINT, wld SMALLDATETIME, isP BIT, sitedb SMALLINT, isM BIT)
		) tbl
	WHERE f.value <> ''

	IF NOT EXISTS (SELECT TOP 1 1 FROM #tmpTransInfo)
	BEGIN
		-- Return validation/Transinfo table
		SET @InvalidTransIds = @TransIds
		SELECT @InvalidTransIds AS InvalidTransIds
			  ,@UnmarkTransIds AS UnmarkTransIds
			  ,@TransInfoJson_Output AS TransInfoJson
		
		RETURN;
	END

	INSERT INTO #transIdTemp (transid)
	SELECT DISTINCT value
	FROM STRING_SPLIT(@TransIds, ',')
	WHERE value <> ''

	INSERT INTO #validTransId (
		transid
		,StatusId
		,bettype
		,matchid
		,betfrom
		,betteam
		,winlostdate
		,betdaqid
		,IsMove14
		,Subtransid
		,IsMixParlay
		)
	SELECT b.transid
		,statusID
		,bettype
		,matchid
		,betfrom
		,betteam
		,winlostdate
		,betdaqid
		,IsMove14
		,b.transid AS Subtransid
		,b.IsMixParlay
	FROM #tmpTransInfo b
		INNER JOIN #transIdTemp tmp ON b.transid = tmp.transid
	
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
	FROM  dbo.TicketVoiding_Request r WITH (NOLOCK) 
		INNER JOIN dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK) ON rs.RequestId = r.RequestId
		CROSS APPLY (
					SELECT TOP 1 t.transid
					FROM #transIdTemp t
					WHERE rs.TransId = t.transid
			)t
	WHERE r.RequestId <> @RequestId AND r.IssueTypeId IN (22) -- Recover Ticket

	SELECT @ExistingReqTransIds = ISNULL(STUFF((SELECT ',' + CAST(t.transid AS VARCHAR(50))
										FROM #transIdTemp t 
											INNER JOIN #TransidInRequest tr ON t.transid = tr.TransId
										FOR XML PATH('')), 1, 1, ''), '')


	IF EXISTS (SELECT TOP 1 1 FROM #validTransId WHERE winlostdate < @GetDateRange)
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
		,b.custid AS  'c' 
		,b.bettype AS 'btype'
		,b.betid AS 'bid'
		,b.IsMixParlay AS 'isP'
		,b.IsMove14 AS 'isM'
		,b.SiteDBGroupID AS 'sitedb'
	FROM #validTransId t
		INNER JOIN #tmpTransInfo b ON t.matchid = b.matchid AND t.transid = b.transid
	FOR JSON PATH))
	
	SELECT @InvalidTransIds AS InvalidTransIds
		 , @UnsupportedDateRangeTransIds AS UnsupportedDateRangeTransIds
		 , @ExistingReqTransIds AS ExistingReqTransIds
		 , @UnmarkTransIds AS UnmarkTransIds
		 , CONVERT(VARCHAR(MAX), @TransInfoJson_Output, 1) AS TransInfoJson

	DROP TABLE #transIdTemp
	DROP TABLE #validTransId
	DROP TABLE #tmpTransInfo
END