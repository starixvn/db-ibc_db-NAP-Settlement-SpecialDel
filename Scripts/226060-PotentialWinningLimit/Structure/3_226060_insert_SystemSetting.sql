/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*	
	Created: 20250416@Louisa
	Task:  Potential Winning Limit/Threshold [Redmine:#226060]
	DB: DBSIC/bodb02
	
	Revisions:
		- 20250416@Louisa:  init new setting on SystemSetting [Redmine:#226060]

*/

---run on SiteDB03 Only

USE bodb02
GO

DECLARE @MaxValue VARCHAR(20)
SELECT @MaxValue = (SELECT  CAST(MAX(rowid) AS VARCHAR(20))  from balancetrigger WITH(NOLOCK) )

INSERT INTO dbo.SystemSettings ( VName, VValue )
VALUES ('CustWinLimitBet', @MaxValue )

