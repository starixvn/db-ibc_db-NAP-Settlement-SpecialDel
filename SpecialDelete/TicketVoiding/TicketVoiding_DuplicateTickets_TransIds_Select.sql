/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_DuplicateTickets_TransIds_Select]
(
	@RequestId INT = 0
)
AS
/*	
	Created by:20230717@Max
	Task: [TVS] Duplicate Ticket - New Issue Type [Redmine: #187835]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20230717@Max: Create new SP [Redmine:#187835]

	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	SELECT ROW_NUMBER() OVER (ORDER BY xTrans.OrgTransIds) AS Id
		,xTrans.OrgTransIds, xTrans.VoidedTransIds, c.Usernames
	FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
	CROSS APPLY (
			SELECT CONVERT(XML, rd.TransIds)
		)AS t(xDATA)
	CROSS APPLY (
			SELECT t.c.value('@OrgTransIds','VARCHAR(MAX)') AS OrgTransIds
				,t.c.value('@VoidedTransIds','VARCHAR(MAX)') AS VoidedTransIds
			FROM t.xDATA.nodes('root/r') t(c)
		)xTrans
	CROSS APPLY (
			SELECT STUFF((SELECT DISTINCT ',' + c.username
					FROM string_split(xTrans.VoidedTransIds, ',') f
						INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = f.value
						INNER JOIN CustDB.dbo.custInfo c WITH (NOLOCK) ON c.custid = b.custid
					WHERE value <> ''
			FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)') ,1,2,'')
		)c(Usernames)
	WHERE rd.RequestId = @RequestId
END		
GO


