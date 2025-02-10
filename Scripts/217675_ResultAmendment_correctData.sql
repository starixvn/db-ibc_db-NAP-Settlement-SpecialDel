﻿/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20250210@Louisa
	Task:  Result Amendment [Redmine:#217675]
	DB: DBPRO-bodb02

*/

USE bodb02
GO

BEGIN
	SET NOCOUNT ON;

	UPDATE dbo.RefResource	WITH(ROWLOCK, UPDLOCK)
	SET ResourceId = UPPER(ResourceId) 
	WHERE RefId = 'ResultSettlement' 
		AND ResourceId IN( 'Bottom','None' )

	/*
		SELECT * 
		FROM dbo.RefResource	WITH(ROWLOCK, UPDLOCK)
		WHERE RefId = 'ResultSettlement' 
			AND ResourceId IN( 'Bottom','None' )
	*/
END
GO

