/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*	
	Created: 20250416@Louisa
	Task:  Potential Winning Limit/Threshold [Redmine:#226060]
	DB: DBSIC/bodb02
	
	Revisions:
		- 20250416@Louisa:  Potential Winning Limit/Threshold [Redmine:#226060]

*/
 
USE bodb02
GO

drop table if exists CustWinLimitBet_Errors
CREATE TABLE CustWinLimitBet_Errors 
(
	ID BIGINT IDENTITY(1,1)
	,ErrName VARCHAR(100)
	, ExtraInfo VARCHAR(MAX) --format JS
	, CreatedDate DATETIME
	, IsNotify BIT
)

ALTER TABLE CustWinLimitBet_Errors
ADD CONSTRAINT PK_CustWinLimitBet_Errors
PRIMARY KEY CLUSTERED (	ID ) 

GO
CREATE NONCLUSTERED INDEX IDX_CustWinLimitBet_Errors_CreatedDate
ON CustWinLimitBet_Errors (CreatedDate);
GO
