/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_CheckTickets14]
(
	 @TransIds	VARCHAR(MAX) = NULL
)
AS
/*  
	Created by: July
	Date: 20211123
	Task: TVS - Void Archived Tickets
	DB: DBTXN/bodb02   

	Revisions:  
		- 20211123@July: Create new SP [Redmine: #140180]

	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @InvalidTransIds				VARCHAR(MAX) = ''
		   ,@UnsupportedDateRangeTransIds	VARCHAR(MAX) = ''
		   ,@before_movebetday				DATETIME
	       ,@MovebetDate					DATETIME

	EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @MovebetDate OUTPUT

	SELECT @before_movebetday = CONVERT(varchar(10), DATEADD(DAY, -3, @Movebetdate), 120)	
	
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
		)

	IF (@TransIds IS NULL
		OR LEN(@TransIds) = 0
			) RETURN;

	INSERT INTO #transIdTemp (transid)
	SELECT DISTINCT val
	FROM dbo.f_SplitString(@TransIds, ',')
	WHERE val <> ''
	OPTION (MAXRECURSION 0)

	-- select valid TransId of Abnormal bet
	INSERT INTO #validTransId (
		transid
		,StatusId
		,bettype
		,matchid
		,betfrom
		,refno
		,winlostdate
		)
	SELECT b14.transid
		,statusID
		,bettype
		,matchid
		,betfrom
		,refno
		,winlostdate
	FROM dbo.bettrans14 AS b14 WITH (NOLOCK)
		INNER JOIN #transIdTemp tmp ON b14.transid = tmp.transid
	
	--final valid transid
	DELETE t
	FROM #validTransId t
		OUTER APPLY (SELECT bettype FROM @bettype_tmp WHERE bettype = t.bettype) bt
	WHERE StatusId IN (101, 102, 103)
		OR bt.bettype IS NULL
		OR t.betfrom ='p'
		
	-- invalid transId
	SELECT @InvalidTransIds = ISNULL(STUFF((SELECT ',' + CAST(t.transid AS VARCHAR(50))
										FROM #transIdTemp t
										WHERE NOT EXISTS (SELECT TOP 1 1 FROM #validTransId WHERE transid = t.transid)
										FOR XML PATH('')), 1, 1, ''), '')

	IF EXISTS (SELECT TOP 1 1 FROM #validTransId WHERE winlostdate < @before_movebetday)
	BEGIN
		DELETE 
		FROM #validTransId
			OUTPUT	DELETED.TransId
			INTO @UnsupportedTransids (TransId)
		WHERE winlostdate < @before_movebetday

		SELECT @UnsupportedDateRangeTransIds = ISNULL(STUFF((SELECT ',' + CAST(t.transid AS VARCHAR(50))
														FROM @UnsupportedTransids t
														FOR XML PATH('')
													), 1, 1, ''), '')
	END	

	-- return table result
	SELECT @InvalidTransIds AS InvalidTransIds
		  ,@UnsupportedDateRangeTransIds AS UnsupportedDateRangeTransIds

	DROP TABLE #transIdTemp
	DROP TABLE #validTransId
END