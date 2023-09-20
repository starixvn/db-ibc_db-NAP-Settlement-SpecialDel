/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20230711@Aries
	Task: Apply Settle Determined for Basketball [Redmine: #184124]
	DB: DBPRO/bodb02
*/
 
USE bodb02
GO
/************************Add setting Cal SDT**************************/
IF NOT EXISTS (SELECT * FROM   sys.columns  WHERE  object_id = OBJECT_ID(N'[dbo].[AutoPayoutResultOS]') AND name = 'SourceID')
BEGIN
	ALTER TABLE AutoPayoutResultOS ADD SourceID TINYINT;
END


