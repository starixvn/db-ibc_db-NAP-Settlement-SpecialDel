/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created: 20230307@Louisa
	Task: Update ResultDetailES14  [Redmine:184747]
	DB: DBPRO/bodb02

*/
USE bodb02
GO

BEGIN

	UPDATE r
	SET r.HomeValue = '2'
		,r.AwayValue = '0'
	FROM dbo.ResultDetailES14 r WITH(ROWLOCK, UPDLOCK)
	WHERE r.matchid = 64495555
		AND r.ResourceID = '904001'

END
GO
 