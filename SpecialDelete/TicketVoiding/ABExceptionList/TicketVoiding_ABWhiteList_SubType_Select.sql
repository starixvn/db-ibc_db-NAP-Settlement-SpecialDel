/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_ABWhiteList_SubType_Select]
AS
/*	Created by: July
	Task: Support AB Exclusion by sub issue type 
	DB: DBCTG/bodb02
	
	Revisions:
		20220414@July: Get subtype load combobox [Redmine:#170771]
		
*/
BEGIN
	SET NOCOUNT ON

	SELECT	CONVERT(VARCHAR(20), '27,41') AS SubIssueTypeIds
		   ,CONVERT(VARCHAR(100), 'Abnormal') AS SubIssueTypeName   
	UNION ALL SELECT '28,42','Group Betting'
	UNION ALL SELECT '29,43','Hedging'
	UNION ALL SELECT '30,44','Arbitrage'
	UNION ALL SELECT '31,45','Fixed Game'
	UNION ALL SELECT '32,46','AB Bet'
	UNION ALL SELECT '36,47','Robot Betting'
	UNION ALL SELECT '37,48','Irrigation Bet'
	UNION ALL SELECT '38,49','System Formula Bet'

	SET NOCOUNT OFF
END
GO
