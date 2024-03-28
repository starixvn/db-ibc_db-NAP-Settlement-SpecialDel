/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_GetBetIDForVoiding_Select]
(	
	@MemberUsername		VARCHAR(50) = ''
	,@TicketStatus		TINYINT
)
AS
/*	Created by: Raymond
	Date 20200309
	Task:  Get list betId for voiding [Redmine:#129973]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20200309@Raymond: Create new SP [Redmine:#129973]
		- 20240221@Max: [TVS] Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]
		
	Param's explanation:	
	
*/      
BEGIN
	SET NOCOUNT ON

	DECLARE @MemberId INT = NULL;

	SELECT @MemberId = ci.custid
	FROM CustDB.dbo.custInfo AS ci WITH (NOLOCK)
	WHERE ci.username = @MemberUsername
		AND ci.roleid = 1

	IF @MemberId IS NULL
	BEGIN
		RETURN;
	END

	-- single tickets
	SELECT b.transid AS transid
	FROM dbo.bettrans AS b WITH (NOLOCK)
	WHERE b.statusID = @TicketStatus
		AND b.bettype NOT IN (9, 29, 2799, 10449) -- main parlay
		AND b.bettype NOT IN (911, 912, 913, 914) -- cash out sub ticket
		AND b.bettype NOT BETWEEN 801 AND 899  -- metric gaming
		AND b.custid = @MemberId
	UNION 

	SELECT tl.translogid AS transid
	FROM dbo.translog AS tl WITH (NOLOCK)
	WHERE tl.statusID = @TicketStatus
		AND tl.custid = @MemberId

	-- parlay tickets
	SELECT bm.transid
	FROM dbo.bettransm AS bm WITH (NOLOCK)
	WHERE bm.statusID = @TicketStatus
	AND bm.custid = @MemberId
END
GO