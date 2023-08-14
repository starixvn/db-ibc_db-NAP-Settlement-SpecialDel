/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Admin_SendNotify_s178
	@MatchID INT
AS
/*	
	Creator: 20230704@Louisa 
	Task: Virtual Leap Gaming - VS3
	DB: DBTXN/bodb02 
	
	Revisions:
		- 20230704@Louisa:  Virtual Leap Gaming - VS3 [Redmine:#189854]
 
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
	)

	
				
	INSERT INTO @betTicket ( 
		transid
		, CustID
		, srecommend
		, Username
		, TransDate
	)
	SELECT b.transid
		, b.custid
		, b.srecommend
		, c.Username
		, b.TransDate
	FROM dbo.bettrans b WITH(NOLOCK)
		INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK)
		ON b.custid		= c.custid
	WHERE matchid		= @matchid
		AND b.statusId	NOT IN (101, 102)
		
	SET @totalTicket = @@ROWCOUNT

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
		, 'Single Ticket' AS TicketType
		, CustID
		, Username
		, TransDate
	FROM @betTicket
	WHERE IsDeposit = 0

	--deposite tickets
	SELECT TransID
		, 'Single Ticket' AS TicketType
		, CustID
		, Username
		, TransDate
		, SiteName
	FROM @betTicket
	WHERE IsDeposit = 1


END
GO