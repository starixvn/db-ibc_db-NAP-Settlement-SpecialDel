/*<info serverAlias="DBTXN-bodb02,SBSETTLE-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/



	DELETE 
	FROM	dbo.SiteDB_SettlementLock WITH(ROWLOCK, UPDLOCK)
	WHERE	sessionId = @SessionId
		AND SiteDBGroupId = @SiteDBGroupId