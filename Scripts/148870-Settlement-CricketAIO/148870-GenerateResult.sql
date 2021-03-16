/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by: 20210312@Louisa
    Task: 20210312@Louisa: Cricket AIO [Redmine:#148870]
    DB: DBPRO/bodb02
	
	Revisions:
		- 20210312@Louisa: Generate ResultDetailOS for Cricket [Redmine:#148870]
*/


BEGIN
	SET NOCOUNT ON


	-------Step 1: Generate Resource '00' for Cricket MatchId not exists in ResultDetailOS
	CREATE TABLE #tmpResultDetailOS (
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

	INSERT INTO #tmpResultDetailOS (
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
	SELECT m.matchid
			,'00'		
			,m.finalhomescore			
			,m.finalawayscore			
			,CASE WHEN m.eventstatus = 'completed' THEN 5 --manually settled
					ELSE 0 -- inittial
				END AS ResultStatusID
				
			,CASE WHEN m.eventstatus = 'completed' THEN 
													CASE WHEN ISNULL(m.betstatus,'') LIKE '%Refund%' THEN 1 --Refund All
														ELSE 4 -- Completed -Cal FT
													END
					ELSE 0 
				END AS SettlementStatusID	
			,8			
			,GETDATE()			
			,8	
			,GETDATE()			
	FROM dbo.match m WITH(NOLOCK)
		LEFT JOIN dbo.ResultDetailOS r WITH(NOLOCK)
			ON  r.MatchID = m.matchid
	WHERE m.sporttype = 50
		AND r.MatchID IS NULL
	

	------- Step 2: Insert data into ResultDetailOS by batch
	DECLARE @batch SMALLINT = 1000

	WHILE (@batch > 0)
	BEGIN
		DELETE TOP(@batch) #tmpResultDetailOS
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
		 INTO  dbo.ResultDetailOS (
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