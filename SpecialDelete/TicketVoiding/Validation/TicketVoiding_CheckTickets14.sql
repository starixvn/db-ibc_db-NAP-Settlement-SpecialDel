/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_CheckTickets14]
(
	 @TransIds			VARCHAR(MAX) = NULL
	,@IsVoidAllArchivedTickets	BIT = 0
)
AS
/*  
	Created by: 20211123@July
	Task: TVS - Void Archived Tickets
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02

	Revisions:  
		- 20211123@July: Create new SP [Redmine: #140180]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220808@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20221124@Max: [TVS] Increase data size when sending data between web and DB [Redmine:	#180863]
		- 20230103@Max: Change JSON input [Redmine: #180625]
		- 20230201@Max: [TVS] Separate Sync Log table for SB and Non-Sports [Redmine: #179183]
		- 20230420@July: [TVS] Update the data length of 'betfrom' column [Redmine: #187035]
		- 20240102@July: [TVS] Recover Ticket - Combine table result return [Redmine: #196020]
		- 20240304@Max: [TVS] Archived Ticket - Void full range of archived tickets [Redmine: #201448]
		- 20250828@July: ScaleOut DBTrans [Phase 6] - Archived Ticket [Redmine: #236118]
		
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @InvalidTransIds				VARCHAR(MAX) = ''
		   ,@UnsupportedDateRangeTransIds	VARCHAR(MAX) = ''
		   ,@before_movebetday				DATETIME
	       ,@MovebetDate					DATETIME
		   ,@TransInfoJson					VARBINARY(MAX) = NULL
		   ,@SiteDBGroupID					SMALLINT

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

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
		,betfrom		NVARCHAR(4)
		,winlostdate	DATETIME
		,betdaqid		BIGINT
		,custid			INT	
		,betid			BIGINT
		,SiteDBGroupID  SMALLINT
		,IsMixParlay	BIT
	)

	CREATE TABLE #tmpTransInfo(
	   matchid INT
	  ,transid BIGINT PRIMARY KEY
      ,custid	INT	
	  ,bettype SMALLINT
      ,betid BIGINT
	  ,betdaqid BIGINT
      ,statusID TINYINT
      ,betfrom NVARCHAR(4)
	  ,winlostdate SMALLDATETIME
	  ,IsMixParlay BIT
	  ,SiteDBGroupID SMALLINT
	)

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
		,winlostdate
		,betdaqid
		,custid
		,SiteDBGroupID
		,betid
		,IsMixParlay
		)
	SELECT b.transid
		,statusID
		,bettype
		,matchid
		,betfrom
		,winlostdate
		,betdaqid
		,custid
		,SiteDBGroupID
		,betid
		,0 AS IsMixParlay
	FROM #transIdTemp t
		INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON b.TransId = t.transid
	WHERE b.statusID NOT IN (101, 102, 103)
		AND b.betfrom <> 'P'
		AND b.SiteDBGroupID = @SiteDBGroupID
	
	--final valid transid
	DELETE t
	FROM #validTransId t
		OUTER APPLY (SELECT bettype FROM @bettype_tmp WHERE bettype = t.bettype) bt
	WHERE bt.bettype IS NULL
		OR t.betdaqid = 0 --old main cashout
		
	-- invalid transId
	SELECT @InvalidTransIds = ISNULL(STUFF((SELECT ',' + CAST(t.transid AS VARCHAR(50))
										FROM #transIdTemp t
										WHERE NOT EXISTS (SELECT TOP 1 1 FROM #validTransId WHERE transid = t.transid)
										FOR XML PATH('')), 1, 1, ''), '')

	IF @IsVoidAllArchivedTickets = 0 AND EXISTS (SELECT TOP 1 1 FROM #validTransId WHERE winlostdate <= @before_movebetday)
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

	/*****************Return table **************************/
	-- 1. Return validation/Transinfo table
	SET @TransInfoJson = COMPRESS((SELECT t.matchid AS 'mid'
		,t.transid AS 't'
		,t.custid AS  'c' 
		,t.bettype AS 'btype'
		,t.betid AS 'bid'
		,t.IsMixParlay AS 'isP'
		,t.SiteDBGroupID AS 'sitedb'
	FROM #validTransId t
	FOR JSON PATH))
	
	SELECT @InvalidTransIds AS InvalidTransIds
		 , @UnsupportedDateRangeTransIds AS UnsupportedDateRangeTransIds
		 , CONVERT(VARCHAR(MAX), @TransInfoJson, 1) AS TransInfoJson

	DROP TABLE #transIdTemp
	DROP TABLE #validTransId
END