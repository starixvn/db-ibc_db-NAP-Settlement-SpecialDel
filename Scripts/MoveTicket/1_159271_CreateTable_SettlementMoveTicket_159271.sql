/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*	
	Creator: Louisa
	Date: 20210930
	Task: Move ticket
	DB: DBTXN/bodb02

	Revisions:
		- 20210930@Louisa: Create table to backup data before move ticket  [Redmine:#159271]

*/
USE bodb02
GO

	SET NOCOUNT ON
	
	IF EXISTS ( SELECT TOP 1 1 FROM sys.objects o WHERE o.name = 'SettlementMoveTicketHistoryTemp' )
	RETURN


	CREATE TABLE SettlementMoveTicketHistoryTemp 
	(
		matchid		INT
		, transid	BIGINT
		, oddsid	INT
		, CreatedBy	INT
		, CreatedDate	DATETIME
	)
GO

