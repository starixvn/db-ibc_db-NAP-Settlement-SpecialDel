/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created by: 20250218@Louisa
	Task: Correct statusid from NULL to 0 [Redmine:#218005] 
		
*/
	
---RUN ON DBTRANS AND SITEDB3	

BEGIN
	UPDATE Bettrans14 WITH(ROWLOCK,UPDLOCK)
	SET statusid = 0
	WHERE STATUS = 355632504826232844
END
GO