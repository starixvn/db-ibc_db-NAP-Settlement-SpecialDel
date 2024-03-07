/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20240307@Aries
	Task: Enhance the Provider Result Logs Phase 2 [Redmine: #201480]
	DB: DBPRO/bodb02
*/
USE bodb02
GO
IF NOT EXISTS (SELECT * FROM sys.columns  WHERE  object_id = OBJECT_ID(N'[dbo].[AutoPayoutResultOS]') AND name = 'Remark')
BEGIN
	ALTER TABLE AutoPayoutResultOS ADD Remark VARCHAR(1000);
END


IF NOT EXISTS (SELECT * FROM sys.columns  WHERE  object_id = OBJECT_ID(N'[dbo].[AutoPayoutResult]') AND name = 'Remark')
BEGIN
	ALTER TABLE AutoPayoutResult ADD Remark VARCHAR(1000);
END
