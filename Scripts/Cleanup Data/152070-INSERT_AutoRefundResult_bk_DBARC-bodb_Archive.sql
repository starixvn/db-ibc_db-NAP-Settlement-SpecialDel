/*<info serverAlias="DBARC-bodb_archive" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created:20210322@Louisa
    Task: Move data from AutoRefundResult to AutoRefundResult_bk [Redmine:#152070]
    DB: DBPRO/bodb02
	
	Revisions:
		- 20210322@Louisa: Step1: Move data from AutoRefundResult to AutoRefundResult_bk [Redmine:#152070]
	
	Param's Explanation: 
		
*/

USE bodb_archive
GO

BEGIN

SET NOCOUNT ON
			
	CREATE TABLE #temp_Table (
		AutoRefundResultId	INT
		,MatchId			INT
		,SourceId			TINYINT
		,TypeId				TINYINT
		,StatusId			TINYINT
		,TryCount			TINYINT
		,CreateDate			DATETIME
		,ModifiedDate		DATETIME
		)

	INSERT INTO #temp_Table
			( AutoRefundResultId	,MatchId ,SourceId	,TypeId		,StatusId	,TryCount	,CreateDate	 ,ModifiedDate )
	SELECT	 r.AutoRefundResultId ,r.MatchId ,r.SourceId ,r.TypeId ,r.StatusId ,r.TryCount ,r.CreateDate ,r.ModifiedDate		
	FROM DBPRO.bodb02.dbo.AutoRefundResult r WITH(NOLOCK)
		INNER JOIN dbo.match_bk m WITH(NOLOCK) 
				ON r.MatchId = m.matchid
	WHERE m.eventdate <= '2021-03-11 00:00:00.000'

	---INSERT data into ProviderExternalResultDetail_bk
	INSERT INTO dbo.AutoRefundResult_bk
			(AutoRefundResultId		,MatchId ,SourceId	,TypeId		,StatusId  ,TryCount	,CreateDate	 ,ModifiedDate	)
	SELECT	 r.AutoRefundResultId ,r.MatchId ,r.SourceId ,r.TypeId ,r.StatusId ,r.TryCount ,r.CreateDate ,r.ModifiedDate		
	FROM #temp_Table r

END
	
GO
    
