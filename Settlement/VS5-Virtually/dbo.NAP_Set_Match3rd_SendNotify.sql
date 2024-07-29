/*<info serverAlias="DBCTG-bodb02,DBSID-bodb02,DBSIC-bodb02" executers="wsv_nap" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE  NAP_Set_Match3rd_SendNotify
	 @MatchId				INT 
	,@SportType				TINYINT
	,@SelectedResources		VARCHAR(MAX)
AS
/*
    Creator: 20240704@Aries 
	Task: VS5 - Virtually Sports
	DB: DBPRO-bodb02
	
	Revision:
		- 20240704@Aries: Initial [Redmine:#207309]

    Parameters Explanation:

*/
BEGIN
	
	DECLARE  @totalTicket			INT
			,@MatchIdMainParlay		INT = 0
			,@BettypeMainParlay		SMALLINT = 0
			,@handle				INT

	DECLARE @tmpSelectedResources TABLE (ResourceID VARCHAR(20), BetType SMALLINT, BetID BIGINT,PRIMARY KEY (BetType,BetID))

	IF  @SportType IN (147)
	BEGIN
		SET @MatchIdMainParlay = 11099
		SET @BettypeMainParlay = @MatchIdMainParlay
	END

	EXEC sp_xml_preparedocument @handle OUTPUT, @SelectedResources 

	INSERT INTO @tmpSelectedResources(ResourceID, BetType, BetID)  
	SELECT Id, sp.BetType, sp.BetID
	FROM OPENXML(@handle,'Resources/Resource',1) WITH(Id VARCHAR(20)) AS tbl
		INNER JOIN dbo.SettlementSpecialBettypeProfile sp WITH (NOLOCK) ON	sp.ResourceID = tbl.Id
	WHERE sp.SportType = @SportType
	
	EXEC sp_xml_removedocument @handle

	DECLARE @betTicket	TABLE
	(
		TransID 		BIGINT
		, CustID 		INT
		, srecommend	INT
		, Username 		VARCHAR(30)
		, TransDate		DATETIME
		, IsDeposit		BIT DEFAULT(0)
		, SiteName		VARCHAR(30) DEFAULT('MBC')
		, TicketType	VARCHAR(1) 
	)
			
	INSERT INTO @betTicket ( 
		transid
		, CustID
		, srecommend
		, Username
		, TransDate
		, TicketType
	)
	SELECT b.transid
		, b.custid
		, b.srecommend
		, c.Username
		, b.TransDate
		, 's'
	FROM dbo.bettrans b WITH(NOLOCK)
		INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK)
		ON b.custid		= c.custid
	WHERE matchid		= @MatchId
		AND b.statusId	NOT IN (101, 102)
		AND EXISTS (
			SELECT TOP 1 1
			FROM @tmpSelectedResources t 
			WHERE b.BetType = t.BetType AND (t.BetID = 0 OR b.BetID = t.BetID) 
		)

	
	--main parlay
	;WITH cte_refno AS (
		SELECT bm.custid, bm.refno
		FROM dbo.bettransm bm WITH(NOLOCK)
		WHERE bm.matchid = @MatchId
			AND EXISTS (
				SELECT TOP 1 1
				FROM @tmpSelectedResources t 
				WHERE bm.BetType = t.BetType AND (t.BetID = 0 OR t.BetID = bm.betcheck)
			)
	)
	INSERT INTO @betTicket ( 
		transid
		, CustID
		, srecommend
		, Username
		, TransDate
		, TicketType
	)
	SELECT b.transid
		, b.custid
		, b.srecommend
		, c.Username
		, b.TransDate
		, 'p'
	FROM dbo.bettrans b WITH(NOLOCK)
		INNER JOIN cte_refno r 
			ON b.refno = r.refno
		INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK)
			ON b.custid		= c.custid
	WHERE matchid		= @MatchIdMainParlay
		AND b.statusId	NOT IN (101, 102)
		AND b.custid  = r.custid
		AND b.bettype = @BettypeMainParlay
		
	SET @totalTicket = (SELECT COUNT(1) FROM @betTicket)

	IF @totalTicket > 0
	BEGIN
		UPDATE b 
		SET IsDeposit = CASE WHEN cs.custid > 0 THEN 1 ELSE 0 END
			,SiteName = CASE WHEN cs.custid > 0 THEN cs.[Site] ELSE 'MBC' END
		FROM @betTicket b
			LEFT JOIN CustDB.dbo.Dep_CustSuper cs WITH(NOLOCK)
				ON b.srecommend = cs.custid
	END

----------return data

	--credit tickets
	SELECT TransID
		, CASE TicketType WHEN 's' THEN 'Single Ticket' 
						  WHEN 'p' THEN 'Selection of Mix Parlay'
						  ELSE ''
		  END AS TicketType
		, CustID
		, Username
		, TransDate
	FROM @betTicket
	WHERE IsDeposit = 0

	--deposite tickets
	SELECT TransID
		, CASE TicketType WHEN 's' THEN 'Single Ticket' 
						  WHEN 'p' THEN 'Selection of Mix Parlay'
						  ELSE ''
		  END AS TicketType
		, CustID
		, Username
		, TransDate
		, SiteName
	FROM @betTicket
	WHERE IsDeposit = 1


END
GO