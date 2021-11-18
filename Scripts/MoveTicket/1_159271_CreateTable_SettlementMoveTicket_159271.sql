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


	CREATE CLUSTERED INDEX CIX_SettlementMoveTicketHistoryTemp ON dbo.SettlementMoveTicketHistoryTemp
	(
		CreatedDate ASC,
		matchid ASC		
	) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)

GO
