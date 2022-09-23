/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/
/*
	Created: July
	Date: 20211011
	Task : Add new logaction
	DB: DBLOG/bodb_CustomerLog
*/
USE bodb_CustomerLog
GO
INSERT INTO dbo.LogAction (ActionID, SPName, ActionNameEN, ActionNameCH, ActionNameCS, ActionNameJP, ActionNameTH, ActionNameKO, ActionNameVI,IsInternal) 
VALUES (90511, 
		'Nap_SpecialDelete_MarkedTickets_Update', 
		'TVS - UnMark Ticket When Edit Request',
		'TVS - UnMark Ticket When Edit Request',
		'TVS - UnMark Ticket When Edit Request',
		'TVS - UnMark Ticket When Edit Request',
		'TVS - UnMark Ticket When Edit Request',
		'TVS - UnMark Ticket When Edit Request',
		'TVS - UnMark Ticket When Edit Request',
		0
		)
GO

UPDATE dbo.LogAction
SET ActionNameEN = 'TVS - Mark Ticket When Add/Edit Request'
  , ActionNameCH = 'TVS - Mark Ticket When Add/Edit Request'
  , ActionNameCS = 'TVS - Mark Ticket When Add/Edit Request'
  , ActionNameJP = 'TVS - Mark Ticket When Add/Edit Request'
  , ActionNameTH = 'TVS - Mark Ticket When Add/Edit Request'
  , ActionNameKO = 'TVS - Mark Ticket When Add/Edit Request'
  , ActionNameVI = 'TVS - Mark Ticket When Add/Edit Request'
WHERE ActionID = 90508
GO
