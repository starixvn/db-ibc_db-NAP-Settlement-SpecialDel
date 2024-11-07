/*<info serverAlias="DBCUST-CustDB" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_Currency_Select]
AS
/*	Created by: 20240925@July
	Task: [TVS] New Issue Type "Wrong Offered Name" [Redmine: #187408]
	DB: DBCUST-CustDB
	
	Revisions: 
		- 20240925@July: Create new SP [Redmine: #187408]
	
	Param's explanation:	
*/
BEGIN
	SET NOCOUNT ON
	
	SELECT exchangeid AS Id, currency AS CurrencyCode
	FROM dbo.exchange WITH(NOLOCK)
	WHERE [Description] IS NULL OR [Description] <> 'Unused'
	ORDER BY CASE WHEN Code = 'CNY' THEN 0 ELSE 1 END, Code
	
	SET NOCOUNT OFF
END
GO
