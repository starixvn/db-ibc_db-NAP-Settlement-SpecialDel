/*<info serverAlias="DBARC-bodb_archive" executers="" isFunction="0"></info>*/
/*
    Created: 20200211@Helen
	Task: TVS - Fix Data for TVS Archive - [Redmine: #150199]
	DB: DBARC-bodb_archive 
*/
USE bodb_archive
GO

CREATE TABLE #TicketVoiding_VoidedTransaction_bk(
	[TransId] [bigint] NOT NULL,
	[MessageId] [int] NOT NULL,
	[ReasonId] [int] NOT NULL,
	[MatchId] [int] NULL,
	[CreatedDate] [datetime] NULL ,
	[Id] [int] NOT NULL,
	[IssueTypeID] [tinyint] NULL,
	[SubIssueTypeID] [tinyint] NULL,
	[CustID] [int] NULL,
)

CREATE TABLE #zzzbettrans_bk(
	[transid] [bigint] NOT NULL,
	[custid] [int] NOT NULL,
	[transdate] [datetime] NOT NULL,
	[oddsid] [int] NOT NULL,
	[hdp1] [smallmoney] NULL,
	[hdp2] [smallmoney] NULL,
	[odds] [smallmoney] NULL,
	[stake] [money] NOT NULL,
	[status] [nvarchar](10) NULL,
	[winlost] [money] NULL,
	[livehomescore] [smallint] NULL,
	[liveawayscore] [smallint] NULL,
	[liveindicator] [bit] NULL,
	[betteam] [nvarchar](10) NULL,
	[creator] [int] NOT NULL,
	[refno] [bigint] NULL,
	[comstatus] [nvarchar](20) NULL,
	[winlostdate] [smalldatetime] NULL,
	[betfrom] [nvarchar](1) NULL,
	[betcheck] [nvarchar](50) NULL,
	[checktime] [datetime] NULL,
	[matchid] [int] NULL,
	[bettype] [smallint] NULL,
	[keyid] [int] NOT NULL,
	[VoidingHistoryId] [int] NULL,
 )

CREATE TABLE #zzzbettransm_bk(
	[transid] [bigint] NOT NULL,
	[custid] [int] NOT NULL,
	[transdate] [datetime] NOT NULL,
	[oddsid] [int] NOT NULL,
	[hdp1] [smallmoney] NULL,
	[hdp2] [smallmoney] NULL,
	[odds] [smallmoney] NULL,
	[stake] [money] NOT NULL,
	[status] [nvarchar](10) NULL,
	[winlost] [money] NULL,
	[livehomescore] [smallint] NULL,
	[liveawayscore] [smallint] NULL,
	[liveindicator] [bit] NULL,
	[betteam] [nvarchar](10) NULL,
	[creator] [int] NOT NULL,
	[refno] [bigint] NULL,
	[comstatus] [nvarchar](20) NULL,
	[winlostdate] [smalldatetime] NULL,
	[betfrom] [nvarchar](1) NULL,
	[betcheck] [nvarchar](50) NULL,
	[checktime] [datetime] NULL,
	[matchid] [int] NULL,
	[bettype] [smallint] NULL,
	[keyid] [int] NOT NULL,
	[VoidingHistoryId] [int] NULL
)

CREATE TABLE #ArchiveDate (
			id			INT		IDENTITY(1,1)
		,	winlostdate	SMALLDATETIME
		);
INSERT INTO #ArchiveDate (winlostdate)
VALUES ('2021-01-29 00:00:00.000'),
('2021-01-30 00:00:00.000'),
('2021-01-31 00:00:00.000'),
('2021-02-01 00:00:00.000'),
('2021-02-02 00:00:00.000'),
('2021-02-03 00:00:00.000'),
('2021-02-04 00:00:00.000')

DECLARE @start INT = 1
	,@stop INT
	,@winlostdate SMALLDATETIME

DECLARE	@Query	NVARCHAR(MAX)

SET @stop = (SELECT COUNT(1) FROM #ArchiveDate)

DECLARE @debug_message VARCHAR(500)
SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)


WHILE (@start <= @stop)
BEGIN
	SET  @winlostdate = (SELECT winlostdate FROM #ArchiveDate WHERE id = @start )
	
	RAISERROR (@debug_message, 0, 1) WITH NOWAIT
	
	-----------------------TicketVoiding_VoidedTransaction_bk-------------
	--process for ticket sub parlay (sportbook and virtual sport)
	SELECT	@Query = N'';
	SELECT	@Query = @Query + N'\
	INSERT INTO	#TicketVoiding_VoidedTransaction_bk
	(	TransId, MessageId, ReasonId, MatchId, CreatedDate, Id, IssueTypeID, SubIssueTypeID, CustID)
	SELECT	TransId, MessageId, ReasonId, MatchId, CreatedDate, Id, IssueTypeID, SubIssueTypeID, CustID
	FROM	OPENQUERY(DBTXN, ''\
	DECLARE	@StartDate	SMALLDATETIME = ''''' + CONVERT(NVARCHAR(50), @winlostdate, 121) + ''''';

	SELECT	TransId, MessageId, ReasonId, MatchId, CreatedDate, Id, IssueTypeID, SubIssueTypeID, CustID
	FROM	bodb02.dbo.TicketVoiding_VoidedTransaction AS t1 WITH (NOLOCK)
	WHERE	EXISTS (SELECT 1 FROM bodb02.dbo.bettrans14 AS t2 WITH (NOLOCK) join bodb02.dbo.bettransm14 t4 WITH (NOLOCK) on t2.refno=t4.refno
					WHERE t1.transid = t2.transid AND t2.bettype in (29,2799) AND t1.MatchId!=0 AND t1.MatchId=t4.MatchId AND t4.statusID=102 AND t2.winlostdate = @StartDate)
	;'');';
					
	EXECUTE	sys.sp_executesql @Query;
	WAITFOR DELAY '00:00:00.280'	
	-------------------- zzzbettrans_bk ------------
	SELECT	@Query = N'';
	SELECT	@Query = @Query + N'\
	INSERT INTO	#zzzbettrans_bk
	(	transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, STATUS, winlost, livehomescore, liveawayscore, liveindicator, betteam, creator, refno, comstatus, winlostdate, betfrom, betcheck, checktime, matchid, bettype, keyid, VoidingHistoryId)
	SELECT	transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, STATUS, winlost, livehomescore, liveawayscore, liveindicator, betteam, creator, refno, comstatus, winlostdate, betfrom, betcheck, checktime, matchid, bettype, keyid, VoidingHistoryId
	FROM	OPENQUERY(DBTXN, ''\
	DECLARE	@StartDate	SMALLDATETIME = ''''' + CONVERT(NVARCHAR(50), @winlostdate, 121) + ''''';

	SELECT	transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, STATUS, winlost, livehomescore, liveawayscore, liveindicator, betteam, creator, refno, comstatus, winlostdate, betfrom, betcheck, checktime, matchid, bettype, keyid, VoidingHistoryId
	FROM	bodb02.dbo.zzzbettrans AS t1 WITH (NOLOCK)
	WHERE	t1.VoidingHistoryId IS NULL	
	AND (EXISTS (SELECT 1 FROM bodb02.dbo.bettrans14 AS t2 WITH (NOLOCK) join bodb02.dbo.SportBettypeMatrix t3 WITH (NOLOCK) ON t2.bettype=t3.BetType
					WHERE t1.transid = t2.transid AND t3.ProductID IN (1,3,5,25,27,37) AND t2.statusID=102 AND t2.winlostdate = @StartDate)
		OR EXISTS (SELECT 1 FROM bodb02.dbo.bettransm14 AS t2 WITH (NOLOCK) WHERE t1.transid = t2.transid AND t2.statusID=102 and t1.matchid=t2.matchid AND t2.winlostdate = @StartDate))
	;'');';

	EXECUTE	sys.sp_executesql @Query;
	WAITFOR DELAY '00:00:00.280'	
	-------------------zzzbettransM_bk-------------
	SELECT	@Query = '';
	SELECT	@Query = @Query + N'\
	INSERT INTO	#zzzbettransM_bk
	(transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, STATUS, winlost, livehomescore, liveawayscore, liveindicator, betteam, creator, refno, comstatus, winlostdate, betfrom, betcheck, checktime, matchid, bettype, keyid, VoidingHistoryId)
	SELECT transid, custid, transdate, 
	oddsid, hdp1, hdp2, odds, stake, STATUS, winlost, livehomescore, liveawayscore, liveindicator, betteam, creator, refno, comstatus, winlostdate, betfrom, betcheck, checktime, matchid, bettype, keyid, VoidingHistoryId
	FROM	OPENQUERY(DBTXN, ''\
	DECLARE	@StartDate	SMALLDATETIME = ''''' + CONVERT(NVARCHAR(50), @winlostdate, 121) + ''''';

	SELECT	transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, STATUS, winlost, livehomescore, liveawayscore, liveindicator, betteam, creator, refno, comstatus, winlostdate, betfrom, betcheck, checktime, matchid, bettype, keyid, VoidingHistoryId
	FROM	bodb02.dbo.zzzbettransM AS t1 WITH (NOLOCK)
	WHERE	EXISTS (SELECT 1 FROM bodb02.dbo.bettransm14 AS t2 WITH (NOLOCK) WHERE t1.transid = t2.transid AND t2.statusID=102 and t1.matchid=t2.matchid AND t2.winlostdate = @StartDate)
	AND t1.VoidingHistoryId IS NULL;'');';

	EXECUTE	sys.sp_executesql @Query;
	WAITFOR DELAY '00:00:00.280'
			
	SET @start = @start + 1
		
END
/*
---------------- insert final result ---------------
INSERT INTO	TicketVoiding_VoidedTransaction_bk(	TransId, MessageId, ReasonId, MatchId, CreatedDate, Id, IssueTypeID, SubIssueTypeID, CustID)
SELECT	TransId, MessageId, ReasonId, MatchId, CreatedDate, Id, IssueTypeID, SubIssueTypeID, CustID
FROM #TicketVoiding_VoidedTransaction_bk

INSERT INTO	zzzbettrans_bk(	transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, STATUS, winlost, livehomescore, liveawayscore, liveindicator, betteam, creator, refno, comstatus, winlostdate, betfrom, betcheck, checktime, matchid, bettype, keyid, VoidingHistoryId)
SELECT	transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, STATUS, winlost, livehomescore, liveawayscore, liveindicator, betteam, creator, refno, comstatus, winlostdate, betfrom, betcheck, checktime, matchid, bettype, keyid, VoidingHistoryId
FROM #zzzbettrans_bk

INSERT INTO	zzzbettransM_bk	(transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, STATUS, winlost, livehomescore, liveawayscore, liveindicator, betteam, creator, refno, comstatus, winlostdate, betfrom, betcheck, checktime, matchid, bettype, keyid, VoidingHistoryId)
SELECT transid, custid, transdate,oddsid, hdp1, hdp2, odds, stake, STATUS, winlost, livehomescore, liveawayscore, liveindicator, betteam, creator, refno, comstatus, winlostdate, betfrom, betcheck, checktime, matchid, bettype, keyid, VoidingHistoryId
FROM #zzzbettransM_bk

------------------------------------------------------
*/