/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_TechnicalError_CheckProviderMistakeTickets]
(
	 @TransIds					VARCHAR(MAX) = NULL
)
AS
/*  
	Created by: 20250520@hyman.wu  
	Task: Validate tickets for Provider Mistake issue type
	DB: DBCTG/bodb02   
	Original: [Redmine: #227379]     

	Revisions:  
		- 20250520@hyman.wu: Create new SP [Redmine: #227379]
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @InvalidTransIds			VARCHAR(MAX) = ''
			,@ExistingReqTransIds	VARCHAR(MAX) = ''
			,@UnsupportedTransids	VARCHAR(MAX) = ''
			,@TransInfoJson_Output	VARBINARY(MAX) = NULL
            ,@SiteDBGroupID         SMALLINT


             SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()
			 
	CREATE TABLE #tmpInputTransid_RemarkId (
		 Transid		BIGINT
		,RemarkId		INT	  /*  1: Invalid
								, 5: Unsupported
								, 6: ExistingReq
							  */
	)
	CREATE TABLE #inputTransid (transid BIGINT PRIMARY KEY)
	CREATE TABLE #validTransId (
		transid			BIGINT PRIMARY KEY
		,StatusId		INT
		,bettype		SMALLINT
		,custId			INT
		,matchid		INT
		,sporttype		SMALLINT
		,betfrom		NVARCHAR(4)
		,betteam		NVARCHAR(10)
		,CurrencyName	NVARCHAR(50)
		)
	CREATE TABLE #TransidInRequest (TransId BIGINT PRIMARY KEY)
	CREATE TABLE #UnsupportedTransids(transid BIGINT PRIMARY KEY)
	CREATE TABLE #tmpTransInfo(
	   matchid			INT
	  ,transid			BIGINT
      ,refno			BIGINT
	  ,custid			INT	
      ,hdp1				SMALLMONEY
	  ,hdp2				SMALLMONEY
      ,odds				SMALLMONEY
	  ,oddsspread		MONEY
	  ,betfrom			NVARCHAR(4)
      ,bettype			SMALLINT
	  ,betteam			NVARCHAR(10)
      ,betcheck			NVARCHAR(50)
	  ,Status			NVARCHAR(10)
	  ,transdate		DATETIME
	  ,betid			BIGINT
	  ,Transdesc		NVARCHAR(1000)
	  ,statusID			TINYINT
	  ,creator			INT
	  ,WalletType		TINYINT
	  ,RefCode			BIGINT
	  ,stake			MONEY
	  ,oddstype			TINYINT
	  ,CurrencyName		NVARCHAR(50)
	  ,betdaqid			BIGINT
	  ,ExtraInfo		VARCHAR(1000)
	  ,statuswinlost	TINYINT
	  ,IsMoved14		BIT
	  ,winlost			MONEY
	  ,actual_stake		MONEY
	  ,winlostdate		SMALLDATETIME
	  ,modds			SMALLMONEY
	  ,IsMixParlay		BIT
	  ,SiteDBGroupID	SMALLINT
	  ,username         NVARCHAR(50)
	  ,homeid           INT
      ,awayid           INT
	  ,leagueid         INT
	  ,isNeutral        BIT
	  ,matchcode        NVARCHAR(50)
	  ,showtime         NVARCHAR(50)
      ,sporttype        SMALLINT
	  ,eventstatus		NVARCHAR(50)
	)

	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)
	-- Populate allowed bettypes (copy from CheckAbnormalBet)
	INSERT INTO @bettype_tmp (bettype)
	SELECT DISTINCT pt.bettype
	FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
	WHERE pt.ProductID = 1 -- Sportsbook
			AND pt.bettype NOT IN (10, 9, 29) -- outright, parlay
			AND pt.bettype NOT BETWEEN 221 AND 227 -- Fast Market
			AND pt.SubProduct NOT IN ('Bet Builder', 'MG-SuperLive', 'BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet Builder, Metric Gaming, Bet trade (BT-)

	-- Parse input transaction IDs
	INSERT INTO #tmpInputTransid_RemarkId (transid)
	SELECT value
	FROM STRING_SPLIT(@TransIds, ',')
	WHERE value <> ''

	INSERT INTO #inputTransid (transid)
	SELECT DISTINCT transid
	FROM #tmpInputTransid_RemarkId
	
    -- AB Mode: Query bettrans and bettrans14, insert into #tmpTransInfo
    INSERT INTO #tmpTransInfo (
        matchid, transid, refno, custid, hdp1, hdp2, odds, oddsspread,
        betfrom, bettype, betteam, betcheck, Status, transdate, betid, Transdesc, statusID,
        creator, WalletType, RefCode, stake, oddstype, winlost,
        CurrencyName, betdaqid, ExtraInfo, actual_stake, winlostdate, modds, statuswinlost, IsMoved14, IsMixParlay, SiteDBGroupID,
        username
    )
    SELECT
        b.matchid, b.TransId, b.refno, b.custid, b.hdp1, b.hdp2, b.odds, b.oddsspread,
        b.betfrom, b.bettype, b.betteam, b.betcheck, b.Status, b.transdate, b.betid, b.Transdesc, b.statusID,
        b.creator, b.WalletType, b.RefCode, b.stake, b.oddstype, b.winlost,
        b.CurrencyName, b.betdaqid, b.ExtraInfo, b.actual_stake, b.winlostdate, b.modds, b.statuswinlost, 0, 0, b.SiteDBGroupID,
        b.username
    FROM #inputTransid t
    INNER JOIN dbo.bettrans b ON b.TransId = t.transid
    WHERE b.statusID NOT IN (101, 102, 103)
      AND b.bettype NOT IN (805, 806)
      AND b.bettype NOT BETWEEN 901 AND 920
      AND b.betfrom <> 'P'
      AND b.SiteDBGroupID = @SiteDBGroupID;

	IF NOT EXISTS (SELECT TOP 1 1 FROM #tmpTransInfo)
	BEGIN
		-- Return empty result sets if no valid transactions
		SET @InvalidTransIds = @TransIds
		SELECT @InvalidTransIds AS InvalidTransIds
		SELECT @TransInfoJson_Output AS TransInfoJson
		RETURN;
	END

	-- Update match information
	UPDATE d
	SET matchcode 	= m.matchcode
		,homeid 	= m.homeid
		,awayid 	= m.awayid
		,leagueid 	= m.leagueid
		,sporttype 	= m.sporttype
		,IsNeutral 	= ISNULL(m.IsNeutral, CONVERT(BIT, 0))
		,showtime	= ISNULL(CONVERT(NVARCHAR(20), m.kickofftime, 113), '')
		,eventstatus = ISNULL(m.eventstatus,'')
	FROM #tmpTransInfo d
		INNER JOIN dbo.match m WITH (NOLOCK) 
		ON	d.matchid = m.matchid
	WHERE d.bettype NOT IN (9, 29)

	-- Get valid transactions
	INSERT INTO #validTransId (
		transid
		,StatusId
		,bettype
		,custId
		,matchid
		,sporttype
		,betfrom
		,betteam
		,CurrencyName
		)
	SELECT b.transid
		,b.statusID
		,b.bettype
		,b.custid
		,b.matchid
		,b.sporttype
		,b.betfrom
		,b.betteam
		,b.CurrencyName
	FROM #tmpTransInfo b
		INNER JOIN #inputTransid tmp ON b.transid = tmp.transid

	-- Get unsupported transactions (use OUTER APPLY with @bettype_tmp)
	INSERT #UnsupportedTransids (transid)
	SELECT t.transid
	FROM #validTransId t
		OUTER APPLY (SELECT bettype FROM @bettype_tmp WHERE bettype = t.bettype) bt
	WHERE bt.bettype IS NULL

	SELECT @UnsupportedTransids = ISNULL(STUFF((SELECT ',' + CAST(t.transid AS VARCHAR(50))
									FROM #UnsupportedTransids t
									FOR XML PATH('')), 1, 1, ''), '')
	
	UPDATE t
	SET t.RemarkId = 5
	FROM #tmpInputTransid_RemarkId t
		INNER JOIN #UnsupportedTransids u ON t.Transid = u.transid

	-- Get existing request transactions (remove join to TicketVoiding_Request, select all TransIds from TicketVoiding_RequestDetailTicket_Single)
	SELECT @ExistingReqTransIds = ISNULL(STUFF((
		SELECT ',' + CAST(t.transid AS VARCHAR(50))
		FROM #inputTransid t
		INNER JOIN DBCTG.bodb02.dbo.TicketVoiding_RequestDetailTicket_Single rds WITH (NOLOCK)
			ON t.transid = rds.TransId
		FOR XML PATH('')), 1, 1, ''), '')

	UPDATE t
	SET t.RemarkId = 6
	FROM #tmpInputTransid_RemarkId t
		INNER JOIN #TransidInRequest v ON t.Transid = v.transid

	-- Get invalid transactions
	SELECT @InvalidTransIds = ISNULL(STUFF((SELECT ',' + CAST(t.transid AS VARCHAR(50))
        FROM #tmpInputTransid_RemarkId t
        WHERE t.RemarkId NOT IN (6,5)
            AND NOT EXISTS (SELECT 1 FROM #validTransId v WHERE v.transid = t.transid)
        FOR XML PATH('')), 1, 1, ''), '')

	-- Prepare output
	SET @TransInfoJson_Output = COMPRESS((SELECT t.matchid AS 'mid'
		,t.transid AS 't'
		,b.custid AS  'c'           
		,b.bettype AS 'btype'
		,b.betid AS 'bid'
		,b.IsMixParlay AS 'isP'
		,b.SiteDBGroupID AS 'sitedb'
	FROM #validTransId t
		INNER JOIN #tmpTransInfo b ON t.matchid = b.matchid AND t.transid = b.transid
	FOR JSON PATH))

	-- Return results
	SELECT @InvalidTransIds AS InvalidTransIds
		  ,@ExistingReqTransIds AS ExistingReqTransIds
		  ,@UnsupportedTransids AS UnsupportedTransids

	SELECT CONVERT(VARCHAR(MAX), @TransInfoJson_Output, 1) AS TransInfoJson

	-- Clean up
	DROP TABLE #inputTransid
	DROP TABLE #validTransId
	DROP TABLE #TransidInRequest
	DROP TABLE #UnsupportedTransids
	DROP TABLE #tmpTransInfo
	DROP TABLE #tmpInputTransid_RemarkId
    DROP TABLE #transIdTemp

END 