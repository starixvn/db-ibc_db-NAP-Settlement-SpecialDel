/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0" isNested="0"></info>*/
/*
	Created: 20250718@Max
	Task: Support Daily Settlement Report for Vega project - [Redmine: #233410]
	DB: DBTXN-bodb02

	Note:
*/

USE bodb02
GO

DECLARE @MinSingleKeyId BIGINT
	,@MinParlayKeyId BIGINT

SELECT @MinSingleKeyId = MIN(KeyId) - 1 FROM dbo.Single_Calculate_Queue WITH (NOLOCK)
SELECT @MinParlayKeyId = MIN(KeyId) - 1 FROM dbo.Parlay_Calculate_Queue WITH (NOLOCK)

INSERT INTO dbo.Systemsettings (VName, VValue) VALUES ('Single_Calculate_Queue', @MinSingleKeyId)
															   
INSERT INTO dbo.Systemsettings (VName, VValue) VALUES ('Parlay_Calculate_Queue ',@MinParlayKeyId)


															   
