/*<info serverAlias="DB052-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20210119@July
	Task: [TVS SP] Clear data of Dot_Admin_AcceptTicketActionLog Support Subject - [Redmine: #149004]
	DB: DB052-bodb02
*/

USE bodb02
GO

TRUNCATE TABLE Dot_Admin_AcceptTicketActionLog

GO

