/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER TABLE dbo.TempVariableNumber DROP CONSTRAINT PK_TempVariableNumber
GO
ALTER TABLE dbo.TempVariableNumber ALTER COLUMN KeyValue INT NOT NULL
GO
ALTER TABLE dbo.TempVariableNumber ADD CONSTRAINT PK_TempVariableNumber PRIMARY KEY (KeyValue, KeyValue2, KeyId)