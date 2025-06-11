/*<info serverAlias="DBCTG-bodb02" executers="" isFunction="0"></info>*/

/*
    Created: 20250611@Louisa
	Task: script move ticket to 14 [Redmine: #230022]
	DB:DBCTG/bodb02

	Revision:
		- 20250611@Louisa: script move ticket to 14 [Redmine: #230022]

*/

USE bodb02
GO

DELETE b
FROM bettrans b
WHERE	transid IN (139965201695899699,139965218875768834)