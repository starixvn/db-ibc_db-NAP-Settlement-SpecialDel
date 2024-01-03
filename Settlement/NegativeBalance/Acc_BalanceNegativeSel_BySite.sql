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
		- 20231108@Louisa: HF-missing info when send mail for child match Cricket [Redmine:#196508]
		- 20231229@Louisa: Fix issue missing data outright [Redmine: #199060]

	Param's Explanation: 
		@isTest: 0: Real Currency; 1: UUS Currency 
	
*/
BEGIN 
	SET NOCOUNT ON 

	DECLARE @BalanceNegative TABLE (LogID bigint, LogDate datetime, MatchID int, GroupID tinyint, CustID int, Username varchar(30), TotalBalance money, CurrencyName nvarchar(50), [site] varchar(50), CustomInfo1 nvarchar(200), Username2 varchar(50) )
	DECLARE @RowCnt int
	
	/*CHIT CODE ON SIT FOR Haifa Site 
	IF @Site='Haifa'
	RETURN
	*/
	INSERT INTO @BalanceNegative (LogID, LogDate, MatchID, GroupID, CustID, Username, TotalBalance, CurrencyName, [site], Username2 )
	SELECT LogID
			, CASE WHEN ParentID IS NOT NULL THEN MAX(LogDate)  OVER(PARTITION BY MatchID, GroupID, CustID ORDER BY LogDate DESC)
					ELSE LogDate
				END AS LogDate
			, MatchID
			, GroupID
			, CustID
			, Username
			, CASE WHEN ParentID IS NOT NULL THEN MAX(TotalBalance) OVER(PARTITION BY MatchID, GroupID, CustID ORDER BY LogDate DESC) 
					ELSE TotalBalance
			 END AS TotalBalance
			, CurrencyName
			, [site]
			, Username2
	FROM ( SELECT h.LogID
				, h.LogDate
				, CASE WHEN ISNULL(m.sporttype,0) = 50 AND ISNULL(m.childmatchType,0) = 200 THEN m.ParentID 
					   ELSE h.MatchID
				  END AS MatchID
				, h.GroupID
				, h.CustID
				, c.Username
				, h.TotalBalance
				, CurrencyName = e.currency 
				, h.Site
				, c.username2
				,ParentID
		FROM	BalanceNegativeHistory h WITH (NOLOCK)
				LEFT JOIN match m WITH(NOLOCK) ON h.MatchID = m.matchid
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
	)b
	
	SET @RowCnt=@@ROWCOUNT
	
	IF @RowCnt>0 and @Site='Haifa'
	BEGIN
		SELECT DISTINCT
			  h.LogDate
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
	END
	ELSE
	BEGIN
		SELECT	DISTINCT LogDate, MatchID, GroupID, CustID, Username, TotalBalance, CurrencyName, Site, username2 AS CustomInfo1
		FROM @BalanceNegative
	END

	SELECT LogID FROM @BalanceNegative

END
GO