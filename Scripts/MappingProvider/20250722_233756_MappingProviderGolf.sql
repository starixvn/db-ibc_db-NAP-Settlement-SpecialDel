/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20250722@Max
	Task	  : Support feeding data from SBO providers for Golfl to enable AutoPayout setting. [Redmine:#233756]
	DB		  : DBPRO/bodb02
	Revisions:
		- 20250722@Max: Mapping Provider [Redmine:#233756]
*/
USE bodb02
GO
BEGIN
	IF NOT EXISTS ( SELECT TOP 1 1 FROM dbo.ProviderGameTypeMapping pgm WITH(ROWLOCK)
					WHERE pgm.sporttype = 10 AND SourceId = 1	)
	BEGIN
		INSERT INTO dbo.ProviderGameTypeMapping
					(
					SourceId
					,GameType
					,Remark
					,OrderNo
					,isActive
					,sporttype
					)
		SELECT 1, 0, '', 1, 1, 10
	END
END
GO