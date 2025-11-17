/*<info serverAlias="DBCTG-bodb02" executers="" isFunction="0"></info>*/
/*
	Created: 20251117@Lani
	Task: [TVS] Manage Remark - New function to remark issue of matches - Add new column IsRemark [Redmine: #234937]
	DB: DBCTG/bodb02

	Parameter explanations: 
		RequestType: 1 - Void func
					   2 - Remark func
*/
USE bodb02
GO

ALTER TABLE TicketVoiding_OperatorInfo ADD RequestType TINYINT;
