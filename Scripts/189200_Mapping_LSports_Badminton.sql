/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created	: 20230605@Louisa
	Task	: Mapping Lsports Provider to Badminton [Redmine:#189200]
	DB		: DBPRO/bodb02

	Revisions:
		20210305@Louisa: Mapping Lsports Provider to Badminton [Redmine:#189200]
*/

USE bodb02
GO

BEGIN
	
	UPDATE ProviderGameTypeMapping WITH(ROWLOCK,UPDLOCK)
	SET OrderNo = 3 
	WHERE sporttype = 9
		AND SourceId = 29


	IF NOT EXISTS ( SELECT TOP 1 1 
					FROM dbo.ProviderGameTypeMapping pgm WITH(NOLOCK)
					WHERE pgm.sporttype = 9 AND SourceId = 25
					)
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
		SELECT 25, 0, '', 2, 1, 9
	END

END