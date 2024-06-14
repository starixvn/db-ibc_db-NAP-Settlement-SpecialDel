/*<info serverAlias="DBSID-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_BalanceNegativeSel] (
	@isTest	BIT		= 0
	, @IsExistNegativeBalance BIT OUTPUT
)
AS
/*
	Created: 20240614@Helen
	Task : Enhance  for the service Negative Balance
	DB: DBSID/bodb02
	
	Revisions:  
		- 20240614@Helen: Create SP [Redmine: #206523]

*/
BEGIN
	SET @IsExistNegativeBalance = ISNULL((
	SELECT TOP (1) 1
	FROM	BalanceNegativeHistory h WITH (NOLOCK)
			INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON h.CustID = c.custid
			INNER JOIN CustDB.dbo.exchange e WITH (NOLOCK) ON c.currency = e.exchangeid
	WHERE	h.StatusID = 0 
		AND 1 = CASE WHEN @isTest = 0 AND e.exchangeID <> 20 THEN 1 
					 WHEN @isTest = 1 AND e.exchangeID = 20 THEN 1 
					 ELSE 0 
					 END
		AND 1= CASE WHEN h.GroupID IN (1,2)	AND h.ActionID IN (SELECT actionid FROM dbo.f_Set_NegativeBalance_ActionGroup()) THEN 1
					WHEN h.GroupID NOT IN (1,2) THEN 1
					ELSE 0 END 
	),0)
END

