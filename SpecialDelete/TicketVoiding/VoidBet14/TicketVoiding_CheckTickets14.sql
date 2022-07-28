/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_CheckTickets14]
(
	 @TransIds			VARCHAR(MAX) = NULL
	,@TransInfo		VARCHAR(MAX)  = NULL
)
AS
/*  
	Created by: July
	Date: 20211123
	Task: TVS - Void Archived Tickets
	DB: DBTXN/bodb02   

	Revisions:  
		- 20211123@July: Create new SP [Redmine: #140180]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220727@July: Change of TVS regarding to Scale out DBTrans [Redmine: #173229]

	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @InvalidTransIds				VARCHAR(MAX) = ''
		   ,@UnsupportedDateRangeTransIds	VARCHAR(MAX) = ''
		   ,@before_movebetday				DATETIME
	       ,@MovebetDate					DATETIME
		   ,@TransInfoXML					XML = NULL

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
		,betfrom		NVARCHAR(1)
		,refno			BIGINT
		,winlostdate	DATETIME
		,betdaqid		BIGINT
	)

	CREATE TABLE #tmpTransInfo(
	   matchid INT
	  ,transid BIGINT PRIMARY KEY
      ,refno BIGINT
      ,bettype SMALLINT
      ,betid BIGINT
	  ,betdaqid BIGINT
      ,statusID TINYINT
      ,betfrom NVARCHAR(1)
	  ,statuswinlost TINYINT
	  ,winlostdate SMALLDATETIME
	  ,SiteDBGroupID SMALLINT
	)
	SET @TransInfoXML = CONVERT(XML, @TransInfo)
	INSERT INTO #tmpTransInfo( 
		   matchid
		  ,transid 
		  ,refno
		  ,bettype
		  ,betid
		  ,betdaqid 
		  ,betfrom
		  ,statusID
		  ,statuswinlost
		  ,winlostdate
		  ,SiteDBGroupID
		)
	SELECT t.c.value('@matchid','INT') AS matchid
			,t.c.value('@transid','BIGINT') AS transid
			,t.c.value('@refno','BIGINT') AS refno
			,t.c.value('@bettype','SMALLINT') AS bettype
			,t.c.value('@betid','BIGINT') AS betid
			,t.c.value('@betdaqid','BIGINT') AS betdaqid
			,t.c.value('@betfrom','NVARCHAR(1)') AS betfrom
			,t.c.value('@statusID','TINYINT') AS statusID
			,t.c.value('@statuswinlost','TINYINT') AS statuswinlost
			,t.c.value('@winlostdate','SMALLDATETIME') AS winlostdate
			,t.c.value('@SiteDBGroupID','SMALLINT') AS SiteDBGroupID
	FROM @TransInfoXML.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@TransInfoXML = NULL))

	IF (@TransIds IS NULL OR LEN(@TransIds) = 0) RETURN;

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

	-- return table result
	SELECT @InvalidTransIds AS InvalidTransIds
		  ,@UnsupportedDateRangeTransIds AS UnsupportedDateRangeTransIds

	SET @TransInfoXML = (
	SELECT DISTINCT 
			t.matchid AS "@matchid"
		    ,t.transid AS "@transid"
			,t.refno AS "@refno"
			,b.winlostdate AS "@winlostdate"
			,b.statuswinlost AS "@statuswinlost"
			,b.betid AS "@betid"
			,t.statusID AS "@statusID"
			,b.betfrom AS "@betfrom"
			,b.betdaqid AS "@betdaqid"
			,b.bettype AS "@bettype"
			,b.SiteDBGroupID AS "@SiteDBGroupID"
	FROM #validTransId t
		INNER JOIN #tmpTransInfo b ON t.matchid = b.matchid AND t.transid = b.transid
	FOR XML PATH('r'), ROOT('root')
	)

	SELECT @TransInfoXML AS TransInfo

	DROP TABLE #transIdTemp
	DROP TABLE #validTransId
	DROP TABLE #tmpTransInfo
END