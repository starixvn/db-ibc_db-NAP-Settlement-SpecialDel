/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created: Kathy
    Date: 20200720
    Task : Extend data type of table Settled_Message [Redmine:#135846]
    DB: DBTXN-bodb02
*/

USE bodb02
GO

ALTER TABLE dbo.Settled_Message ALTER COLUMN Action VARCHAR(20)
GO