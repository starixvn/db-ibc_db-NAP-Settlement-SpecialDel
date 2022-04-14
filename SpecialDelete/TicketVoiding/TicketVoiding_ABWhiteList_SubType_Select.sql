/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_ABWhiteList_SubType_Select]
AS
/*	Created by: July
	Task: Support AB Exclusion by sub issue type 
	DB: DBTXN/bodb02
	
	Revisions:
		20220414@July: Get subtype load combobox [Redmine:#170771]
		
*/
BEGIN
	SET NOCOUNT ON

	SELECT	CONVERT(TINYINT, 1) AS SubIssueTypeId
		   ,CONVERT(VARCHAR(100), 'Abnormal') AS SubIssueTypeName   
	UNION ALL SELECT 2,'Group Betting'
	UNION ALL SELECT 3,'Hedging'
	UNION ALL SELECT 4,'Arbitrage'
	UNION ALL SELECT 5,'Arbitrage'
	UNION ALL SELECT 6,'AB Bet'
	UNION ALL SELECT 7,'Robot Betting'
	UNION ALL SELECT 8,'Irrigation Bet'
	UNION ALL SELECT 9,'System Formula Bet'

	SET NOCOUNT OFF
END
GO
