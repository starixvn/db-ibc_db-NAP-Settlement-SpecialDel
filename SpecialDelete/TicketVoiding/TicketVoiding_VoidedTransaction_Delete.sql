/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_VoidedTransaction_Delete]
	@TicketsXML			XML			
AS
/*	Created by: 20181212@Kathy
	Task: remove voided transaction after recovering [Redmine:#106655]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20181221@Kathy: Create new SP [Redmine:#106655]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20230328@July: [TVS] Send problem customer in Abnormal Account request to CTS [Redmine: #185238]

	Param's explanation:	
		 @TicketsXML : <root><r TransId="1"  MatchId="1" /></root>
		
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tblTicketInfo (
		TransId BIGINT
		,MatchId INT
		)

	INSERT INTO #tblTicketInfo (
		TransId
		,MatchId
		)
	SELECT t.c.value('@TransId', 'BIGINT')
		  ,t.c.value('@MatchId', 'INT')
	FROM @TicketsXml.nodes('root/r') t(c)

	WHILE (1=1)
	BEGIN
		DELETE TOP (1000) vt
		FROM	#tblTicketInfo t
			INNER JOIN dbo.TicketVoiding_VoidedTransaction vt WITH(ROWLOCK, UPDLOCK)
				ON vt.TransId = t.TransId
				AND	vt.MatchId = t.MatchId

		IF @@ROWCOUNT < 1000
			BREAK
	END	
	
	DROP TABLE #tblTicketInfo
END
GO
