/*<info serverAlias="DBTNX-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20230830@louisa
	Task: Get Max TransID bettrans G[Redmine: #179580]
	DB:DBTXN/bodb02
	
*/

use bodb02

---STEP 1. get max TransID on DBTRANS and SiteDB before deployment
SELECT MAX(TransId) FROM bettransG WITH(NOLOCK)

-----------------------------------------------------------------------------

---STEP 2. Capture datetime after deployment is successfull


---STEP 3. Get list cust has new TransId after deployment

DECLARE @MaxTransID BIGINT  ---input @MaxTransID

SELECT DISTINCT custid FROM bettransG  WITH(NOLOCK)
WHERE TransId > @MaxTransID  ---input @MaxTransID from STEP 1
	AND transdate <= @CheckTime  ---Input @CheckTime from STEP 2





