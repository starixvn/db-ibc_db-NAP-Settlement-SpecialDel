/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/
USE bodb02
GO

DECLARE @currentmatchid int = 77763827
	,@newmatchid int = 77841195

UPDATE dbo.bettrans WITH(ROWLOCK, UPDLOCK)
	SET matchid = @newmatchid 
		,RepUpdateTime = SYSDATETIME()
WHERE	matchid = @currentmatchid
		AND hdp1 = 18