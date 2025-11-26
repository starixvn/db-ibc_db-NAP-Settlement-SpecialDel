/*<info serverAlias="DBCTG-bodb02" executers="" isFunction="0"></info>*/
/*
	Created: 20251117@Lani
	Task: [TVS] Manage Remark - New function to remark issue of matches - Add new column IsRemark [Redmine: #234937]
	DB: DBCTG/bodb02

	Parameter explanations: 
		RemarkId: NOT NULL -> Remark func
		RequestId: NOT NULL -> Void func
*/
USE bodb02
GO

ALTER TABLE TicketVoiding_OperatorInfo ADD RemarkId INT;
GO

ALTER TABLE TicketVoiding_OperatorInfo ALTER COLUMN RequestId INT NULL;
GO