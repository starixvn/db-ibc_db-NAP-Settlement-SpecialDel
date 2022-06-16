/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
	Created: 20220609@July 
	Task: TVS - Remove SP [Redmine: #173389]
	DB: DBTXN/bodb02
*/
USE bodb02
GO

DROP PROCEDURE dbo.NAP_SpecialDelete_CheckNegativeBalanceCashOutTransaction

GO