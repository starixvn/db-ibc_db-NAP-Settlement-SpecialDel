/*<info serverAlias="DBSID-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20231106@Louisa
	Task: HF-Child match Cricket-send mail under main matchid [Redmine:#196508]
	DB: DBSID-bodb02

*/

USE bodb02
GO

---RUN ON SITEDB1 ONLY

UPDATE BalanceNegativeHistory WITH(ROWLOCK, UPDLOCK)
SET StatusId = 0
	,matchid = 75715975 
WHERE logid = 150725
GO

