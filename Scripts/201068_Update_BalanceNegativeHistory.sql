/*<info serverAlias="DBSID-bodb02" executers="" viewers="" isFunction="0" isNested="1"></info>*/

/*
    Created by: 20240221@Louisa
    Task: Update BalanceNegativeHistory.StatusID from 0 to 1 [Redmine:#201068]
    DB: DBSID/bodb02

*/

--run on SiteDB1, SiteDB2
USE bodb02
GO

BEGIN
	
	UPDATE BalanceNegativeHistory WITH(ROWlOCK, UPDLOCK)
	SET StatusID = 1
	WHERE StatusID = 0
	AND LogDate <= '2024-02-19 04:28:00'

END
GO