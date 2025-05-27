/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20250527@Aries
	Task	  : SOP- Soccer- Phase 3.2- Outside Score for Calculate Popup [Redmine:#226229]
	DB		  : DBPRO/bodb02
	Revisions:
		20250527@Aries: Mapping Provider [Redmine:#226229]
*/
USE bodb02
GO
BEGIN
	IF NOT EXISTS ( SELECT TOP 1 1 FROM dbo.ProviderGameTypeMapping pgm WITH(ROWLOCK)
					WHERE pgm.sporttype = 1 AND SourceId = 1	)
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
		SELECT 1, 0, '', 1, 1, 1
	END
END
GO