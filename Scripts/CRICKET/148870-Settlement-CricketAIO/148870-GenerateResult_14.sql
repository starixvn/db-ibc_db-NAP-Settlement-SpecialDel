/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by: 20210409@Louisa
    Task: 20210409@Louisa: Cricket AIO [Redmine:#148870]
    DB: DBPRO/bodb02
	
	Revisions:
		- 20210409@Louisa: Generate ResultDetailOS14 for Cricket [Redmine:#148870]
*/

BEGIN
	SET NOCOUNT ON

	-------Step 1: Generate Resource '00' for Cricket MatchId not exists in ResultDetailOS14
	CREATE TABLE #tmpResultDetailOS14 (
			MatchID				INT 
			,ResourceID			VARCHAR(20)
			,HomeValue			VARCHAR(50)
			,AwayValue			VARCHAR(50)
			,ResultStatusID		TINYINT 
			,SettlementStatusID	TINYINT 
			,CreateBy			INT 
			,CreateDate			SMALLDATETIME 
			,LastModifyBy		INT 
			,LastModifyDate		SMALLDATETIME
			)

	INSERT INTO #tmpResultDetailOS14 (
			MatchID 
			,ResourceID	 
			,HomeValue	 
			,AwayValue	 
			,ResultStatusID 
			,SettlementStatusID 
			,CreateBy 
			,CreateDate 
			,LastModifyBy 
			,LastModifyDate
			)
	SELECT m14.matchid
			,'00'		
			,m14.finalhomescore			
			,m14.finalawayscore			
			, 5  AS ResultStatusID --manually settled				
			,CASE WHEN ISNULL(m14.betstatus,'') LIKE '%Refund%' THEN 1 --Refund All
					ELSE 4 -- Completed -Cal FT
				END AS SettlementStatusID	
			,8			
			,GETDATE()			
			,8	
			,GETDATE()			
	FROM dbo.match14 m14 WITH(NOLOCK)
		LEFT JOIN dbo.ResultDetailOS14 r WITH(NOLOCK)
			ON  r.MatchID = m14.matchid
		LEFT JOIN dbo.Match m WITH(NOLOCK) 
			ON m.matchid = m14.MatchID
	WHERE m14.sporttype = 50
		AND ISNULL(m14.ChildMatchType,0) <> 200
		AND r.MatchID IS NULL
		AND m14.eventstatus = 'completed'
		AND m.matchid IS NULL --- Check if data in Copy process

	------- Step 2: Insert data into ResultDetailOS by batch
	DECLARE @batch SMALLINT = 1000

	WHILE (@batch > 0)
	BEGIN
		DELETE TOP(@batch) #tmpResultDetailOS14
		OUTPUT
				 DELETED.MatchID				
				,DELETED.ResourceID			
				,DELETED.HomeValue			
				,DELETED.AwayValue			
				,DELETED.ResultStatusID		
				,DELETED.SettlementStatusID	
				,DELETED.CreateBy			
				,DELETED.CreateDate			
				,DELETED.LastModifyBy		
				,DELETED.LastModifyDate	
		 INTO  dbo.ResultDetailOS14 (
				MatchID				
				,ResourceID			
				,HomeValue			
				,AwayValue			
				,ResultStatusID		
				,SettlementStatusID	
				,CreateBy			
				,CreateDate			
				,LastModifyBy		
				,LastModifyDate	
				)
		
		SET @batch = @@ROWCOUNT

		WAITFOR DELAY '00:00:00:280'
	END

END