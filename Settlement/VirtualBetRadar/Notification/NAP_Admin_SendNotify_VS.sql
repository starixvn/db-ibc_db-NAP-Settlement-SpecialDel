/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Admin_SendNotify_VS
	@MatchId			INT 
AS
/*	Creator: 20231215@Louisa
	Task: Moving function send email to web [Redmine:#194949]
	DB: DBTXN/BODB02
	
	Revisions:
		- 20231215@Louisa: Initialize
 
*/
BEGIN
	
	DECLARE  @totalTicket		INT
 
	
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
	WHERE matchid		= @matchid
		AND b.statusId	NOT IN (101, 102)
	
	--main parlay
	;WITH cte_refno AS (
		SELECT bm.custid, bm.refno
		FROM dbo.bettransm bm WITH(NOLOCK)
		WHERE bm.matchid = @matchid
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
	WHERE matchid		= 2799
		AND b.statusId	NOT IN (101, 102)
		AND b.custid  = r.custid
		AND b.bettype = 2799
		
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