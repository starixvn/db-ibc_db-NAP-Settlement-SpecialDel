/*<info serverAlias="DBCTG-SiteDBtmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230602@Louisa
    Task: Migrate 12Bet from DBTrans to SiteDB2 [Redmineid:#188707] 
    DB: DBCTG-SiteDBtmp

	Revisions:
		- 20230602@Louisa: Prepare data - custid [Redmineid:#188707] 

*/

USE SiteDBtmp
GO

IF NOT EXISTS (SELECT TOP 1 1 FROM sys.objects where name = 'Cust12B_20230602')
BEGIN
	CREATE TABLE Cust12B_20230602
	(
		custid INT PRIMARY KEY
	)
END
GO

TRUNCATE TABLE Cust12B_20230602
GO

INSERT INTO Cust12B_20230602 (custid)
SELECT DISTINCT custid
FROM CustDB.dbo.Customer c WITH (NOLOCK)
WHERE c.site = '12Bet'
GO

SELECT COUNT(1) as cnt_CustID FROM Cust12B_20230602
