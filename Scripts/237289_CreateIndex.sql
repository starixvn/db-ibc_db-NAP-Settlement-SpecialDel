/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
/* 
	Created by: 20250904@Louisa
    Task: Create index to enhance performance SP Auto Settle [Redmine:#237289]
    DB: DBPRO/bodb02
	
	Revisions:
		 - 20250904@Louisa: Create [Redmine:#237289]
*/

USE bodb02
GO

	CREATE NONCLUSTERED INDEX IX_ProviderExternalResultDetail_CreateDate 
	ON ProviderExternalResultDetail(CreateDate)
	INCLUDE (MatchId)
	WITH ( ONLINE = ON )
	GO
	----------------------------------------
	CREATE NONCLUSTERED INDEX IX_ProviderExternalResultDetailOS_CreateDate 
	ON ProviderExternalResultDetailOS(CreateDate)
	INCLUDE (matchid)
	WITH ( ONLINE = ON )
	GO
	-----------------------------------------
	CREATE NONCLUSTERED INDEX IX_ProviderExternalResultDetailES_CreateDate 
	ON ProviderExternalResultDetailES(CreateDate)
	INCLUDE (matchid)
	WITH ( ONLINE = ON )
	GO
	-----------------------------------------
	CREATE NONCLUSTERED INDEX IX_ResultDetail_LastModifyDate 
	ON ResultDetail	(LastModifyDate)
	INCLUDE (MatchId, ResultStatusId)
	WITH ( ONLINE = ON )
	GO
	-----------------------------------------
	CREATE NONCLUSTERED INDEX IX_ResultDetailOS_LastModifyDate 
	ON ResultDetailOS(LastModifyDate)
	INCLUDE (MatchId, ResultStatusId)
	WITH ( ONLINE = ON )
	GO
	-----------------------------------------
	CREATE NONCLUSTERED INDEX IX_ResultDetailES_LastModifyDate 
	ON ResultDetailES(LastModifyDate)
	INCLUDE (MatchId, ResultStatusId)
	WITH ( ONLINE = ON )
	GO
