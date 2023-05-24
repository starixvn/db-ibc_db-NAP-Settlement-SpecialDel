/*<info serverAlias="DBCTG-bodb02, DBSID-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.Acc_BalanceNegativeSel_BySite
  @Site		VARCHAR(50) = 'Haifa'
 ,@isTest	BIT			= 0

AS
/*
	Created by: Jamie
	Date: 2013-06-26
	Task: Retrieve Negative Balance by Site 
	DB: DBTXN/bodb02 
	
	Revision: 
		- 20131108@Elodie: Splitting bodb02 into CustDB (call custInfo, exchange by link database)
		- 20150120@Jamie: Edit the definition of @isTest 
		- 20150316@Elodie: Support Negative Balance function for all licensee [Red:#30840]
		- 20160118@Vivi: only site='Haifa' join to bbin db
		- 20180103@Helen: Change Action List on Negative Balance email & Get Mailing List from OIC [Redmine:82430]
		- 20230523@Kathy: change metadata [Redmine:#188452]

	Param's Explanation: 
		@isTest: 0: Real Currency; 1: UUS Currency 
	
*/
BEGIN 
	SET NOCOUNT ON 

	DECLARE @BalanceNegative TABLE (LogID bigint, LogDate datetime, MatchID int, GroupID tinyint, CustID int, Username varchar(30), TotalBalance money, CurrencyName nvarchar(50), [site] varchar(50), CustomInfo1 nvarchar(200), Username2 varchar(50))
	DECLARE @RowCnt int
	
	/*CHIT CODE ON SIT FOR Haifa Site 
	IF @Site='Haifa'
	RETURN
	*/
	INSERT INTO @BalanceNegative (LogID, LogDate, MatchID, GroupID, CustID, Username, TotalBalance, CurrencyName, [site], Username2)
	SELECT	  h.LogID
			, h.LogDate
			, h.MatchID
			, h.GroupID
			, h.CustID
			, c.Username
			, h.TotalBalance
			, CurrencyName = e.currency 
			, h.Site
			, c.username2
	FROM	BalanceNegativeHistory h WITH (NOLOCK)
			INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON h.CustID = c.custid
			INNER JOIN CustDB.dbo.exchange e WITH (NOLOCK) ON c.currency = e.exchangeid
	WHERE	h.StatusID = 0 
			AND h.Site = @Site
			AND 1 = CASE WHEN @isTest = 0 AND e.exchangeID <> 20 THEN 1 
						 WHEN @isTest = 1 AND e.exchangeID = 20 THEN 1 
						 ELSE 0 
						 END
			AND 1= CASE WHEN h.GroupID IN (1,2)	AND h.ActionID IN (SELECT actionid FROM dbo.f_Set_NegativeBalance_ActionGroup()) THEN 1
						WHEN h.GroupID NOT IN (1,2) THEN 1
						ELSE 0 END

									   
	ORDER BY	  h.LogID ASC
				, h.MatchID ASC
				, c.Username ASC
	
	SET @RowCnt=@@ROWCOUNT
	
	IF @RowCnt>0 and @Site='Haifa'
	BEGIN
		SELECT  h.LogID	
			, h.LogDate
			, h.MatchID
			, h.GroupID
			, h.CustID
			, h.Username
			, h.TotalBalance
			, h.CurrencyName
			, h.Site
			, CASE WHEN bin.CustomInfo1 IS NULL THEN h.username2 ELSE bin.CustomInfo1 END AS CustomInfo1
		FROM @BalanceNegative h
			LEFT JOIN DBDEPBBIN.bbin.dbo.Customer bin WITH (NOLOCK) ON h.CustID = bin.IBCCustID
		ORDER BY h.LogID ASC
				, h.MatchID ASC
				, h.Username ASC
	END
	ELSE
	BEGIN
		SELECT	LogID, LogDate, MatchID, GroupID, CustID, Username, TotalBalance, CurrencyName, Site, username2 AS CustomInfo1
		FROM @BalanceNegative
		ORDER BY LogID ASC
				, MatchID ASC
				, Username ASC
	END
END
GO
GRANT EXECUTE ON [dbo].[Acc_BalanceNegativeSel_BySite] TO [bodbAdminNet] AS [dbo]
GO