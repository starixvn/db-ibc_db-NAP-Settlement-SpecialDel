/*<info serverAlias="DBCUST-CustDB" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_DecidedBy_Select]
AS
/*	Created by: July@20240810
	Task: Get username special list 
	DB: DBCUST-CustDB
	
	Revisions: 
		- 20240810@July: Create new SP [Redmine: #208659]
	
	Param's explanation:	
		Affected issue type: Danger Accepted, Red Card, Wrong Score
		
*/
BEGIN
	SET NOCOUNT ON

	SELECT 'Void by SOP' AS username
	UNION ALL
	SELECT username
	FROM dbo.Customer WITH (NOLOCK) 
	WHERE (
			username LIKE 'SSNV%' 
		 OR username LIKE 'CSNV%'
		 OR username IN ('Yong','Pau')
		) 
		AND username NOT LIKE '%[0-9]%'
		AND roleid >= 5
	ORDER BY username ASC

END
GO
