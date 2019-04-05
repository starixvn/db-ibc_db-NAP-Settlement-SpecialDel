/*<info serverAlias="DBTXN-custdb" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Nap_Settlement_InsertCustSuper_Job]
AS
/*
	Created by:Sol
    Date: 20190307
    Task: Settlement 
    DB: DBTXN/custdb

    Revisions:
		- 20190225@Sol: Job to get CN88's super [Redmine:#109007]
        - 20190328@Kathy: Correct the condition to get maxCustId [Redmine:#109007]
*/
BEGIN

	SET NOCOUNT ON;

	DECLARE @lastCustId INT
			,@maxCustId INT = NULL;

	-- get last inserted cust id from system setting 
	SELECT	@lastCustId = CAST(vvalue AS INT)
	FROM	bodb02.dbo.systemsettings WITH(NOLOCK)
	WHERE	vname = 'CN88MaxCustID'; 

	-- get max custid from customer 
	SELECT	@maxCustId = MAX(custid)
	FROM	dbo.customer WITH(ROWLOCK)
	WHERE	custid > @lastcustid
	
	-- insert customer with role = super (id = 4) and site = cn88
	INSERT INTO bodb02.dbo.cs_custsuper (custid)
	SELECT	custid
	FROM	dbo.customer WITH(ROWLOCK)
	WHERE	roleid = 4 AND 
			[site] = 'CN88' AND 
			custid > @lastcustid AND 
			custid <= @maxCustId;

	-- update max custid to system setting table
	UPDATE	bodb02.dbo.systemsettings WITH(ROWLOCK, UPDLOCK)
		SET vvalue = ISNULL(@maxCustId,vvalue)
	WHERE	vname = 'CN88MaxCustID';
	
	SET NOCOUNT OFF;	
END;
GO