/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_CheckTickets14]
(
	 @TransIds			VARCHAR(MAX) = NULL
	,@TransInfo		    XML  = NULL
)
AS
/*  
	Created by: July
	Date: 20211123
	Task: TVS - Void Archived Tickets
	DB: DBCTG/bodb02   

	Revisions:  
		- 20211123@July: Create new SP [Redmine: #140180]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220808@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]

	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @InvalidTransIds				VARCHAR(MAX) = ''
		   ,@UnsupportedDateRangeTransIds	VARCHAR(MAX) = ''
		   ,@before_movebetday				DATETIME
	       ,@MovebetDate					DATETIME

	EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @MovebetDate OUTPUT

	SELECT @before_movebetday = DATEADD(DAY, -3, @Movebetdate)
	
	DECLARE @UnsupportedTransids AS TABLE (transid BIGINT)	
	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)
		
	INSERT INTO @bettype_tmp (bettype)
	SELECT DISTINCT pt.bettype
	FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
	WHERE pt.ProductID = 1 -- Sportsbook
		AND pt.SubProduct NOT IN ('Bet Builder', 'MG-SuperLive', 'BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet Builder, Metric Gaming, Bet trade (BT-)

	CREATE TABLE #transIdTemp (transid BIGINT PRIMARY KEY)
	CREATE TABLE #validTransId (
		transid			BIGINT PRIMARY KEY
		,StatusId		INT
		,bettype		SMALLINT
		,matchid		INT
		,betfrom		NVARCHAR(3)
		,refno			BIGINT
		,winlostdate	DATETIME
		,betdaqid		BIGINT
	)

	CREATE TABLE #tmpTransInfo(
	   matchid INT
	  ,transid BIGINT PRIMARY KEY
      ,refno BIGINT
      ,custid	INT	
	  ,bettype SMALLINT
      ,betid BIGINT
	  ,betdaqid BIGINT
      ,statusID TINYINT
      ,betfrom NVARCHAR(3)
	  ,winlostdate SMALLDATETIME
	  ,IsMixParlay BIT
	  ,SiteDBGroupID SMALLINT
	)
	INSERT INTO #tmpTransInfo( 
		   matchid
		  ,transid 
		  ,refno
		  ,custid
		  ,bettype
		  ,betid
		  ,betdaqid 
		  ,betfrom
		  ,statusID
		  ,winlostdate
		  ,IsMixParlay
		  ,SiteDBGroupID
		)
	SELECT t.c.value('@mid','INT') AS matchid
			,t.c.value('@t','BIGINT') AS transid
			,t.c.value('@ref','BIGINT') AS refno
			,t.c.value('@c','INT') AS custid
			,t.c.value('@btype','SMALLINT') AS bettype
			,t.c.value('@bid','BIGINT') AS betid
			,t.c.value('@bdaq','BIGINT') AS betdaqid
			,t.c.value('@bfr','NVARCHAR(3)') AS betfrom
			,t.c.value('@sid','TINYINT') AS statusID
			,CASE WHEN t.c.value('@wld','SMALLDATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@wld','SMALLDATETIME') END AS winlostdate
			,t.c.value('@isP','BIT') AS IsMixParlay
			,t.c.value('@sitedb','SMALLINT') AS SiteDBGroupID
	FROM @TransInfo.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@TransInfo = NULL))

	IF (@TransIds IS NULL OR LEN(@TransIds) = 0) RETURN;

	IF NOT EXISTS (SELECT TOP 1 1 FROM #tmpTransInfo)
	BEGIN

		SET @InvalidTransIds = @TransIds
		SELECT  @InvalidTransIds AS InvalidTransIds

		RETURN;
	END

	INSERT INTO #transIdTemp (transid)
	SELECT DISTINCT value
	FROM STRING_SPLIT(@TransIds, ',')
	WHERE value <> ''

	-- select valid TransId of Abnormal bet
	INSERT INTO #validTransId (
		transid
		,StatusId
		,bettype
		,matchid
		,betfrom
		,refno
		,winlostdate
		,betdaqid
		)
	SELECT b14.transid
		,statusID
		,bettype
		,matchid
		,betfrom
		,refno
		,winlostdate
		,betdaqid
	FROM #tmpTransInfo b14
		INNER JOIN #transIdTemp tmp ON b14.transid = tmp.transid
	
	--final valid transid
	DELETE t
	FROM #validTransId t
		OUTER APPLY (SELECT bettype FROM @bettype_tmp WHERE bettype = t.bettype) bt
	WHERE StatusId IN (101, 102, 103)
		OR bt.bettype IS NULL
		OR t.betfrom ='p'
		OR t.betdaqid = 0 --old main cashout
		
	-- invalid transId
	SELECT @InvalidTransIds = ISNULL(STUFF((SELECT ',' + CAST(t.transid AS VARCHAR(50))
										FROM #transIdTemp t
										WHERE NOT EXISTS (SELECT TOP 1 1 FROM #validTransId WHERE transid = t.transid)
										FOR XML PATH('')), 1, 1, ''), '')

	IF EXISTS (SELECT TOP 1 1 FROM #validTransId WHERE winlostdate <= @before_movebetday)
	BEGIN
		DELETE 
		FROM #validTransId
			OUTPUT	DELETED.TransId
			INTO @UnsupportedTransids (TransId)
		WHERE winlostdate <= @before_movebetday

		SELECT @UnsupportedDateRangeTransIds = ISNULL(STUFF((SELECT ',' + CAST(t.transid AS VARCHAR(50))
														FROM @UnsupportedTransids t
														FOR XML PATH('')
													), 1, 1, ''), '')
	END	

	-- 1. return table result
	SELECT @InvalidTransIds AS InvalidTransIds
		  ,@UnsupportedDateRangeTransIds AS UnsupportedDateRangeTransIds

	-- 2. Transinfo table
	SELECT DISTINCT 
			t.matchid
		    ,t.transid 
			,b.refno
			,b.custid 
			,t.statusID
			,b.bettype
			,b.betid
			,b.IsMixParlay 
			,b.SiteDBGroupID 
	FROM #validTransId t
		INNER JOIN #tmpTransInfo b ON t.matchid = b.matchid AND t.transid = b.transid

	DROP TABLE #transIdTemp
	DROP TABLE #validTransId
	DROP TABLE #tmpTransInfo
END