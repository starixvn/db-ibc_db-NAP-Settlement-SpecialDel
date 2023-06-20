/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created	: 20230620@Louisa
	Task	: Mapping BetConstruct Provider to Tennis [Redmine:#190038]
	DB		: DBPRO/bodb02

	Revisions:
		20230620@Louisa: Mapping BetConstruct Provider to Tennis [Redmine:#190038]
*/

USE bodb02
GO

BEGIN
	

	IF NOT EXISTS ( SELECT TOP 1 1 
					FROM dbo.ProviderGameTypeMapping pgm WITH(NOLOCK)
					WHERE pgm.sporttype = 5 AND SourceId = 29
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
		SELECT 29, 0, '', 29, 1, 5
	END

END