/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE ArchiveService_Sel  
	@Date DATE
	,@BatchNo INT = 2000
	,@TableName VARCHAR(100)
	,@LastValue	VARCHAR(100) = ''
	,@JsonInfo VARBINARY(MAX) OUTPUT

AS  
/* 
	 Creator:20240222@Louisa  
	 Task: Archive data for ProviderExternalResultDetailXX [Redmine:#201196] 
	     
	 Revisions:  
		- 20240222@Louisa:  Initial [Redmine:#201196]
		- 20241114@Aries: Support to add a new Live columns for Provider Tables [Redmine:#213217]
    
*/  
BEGIN  
	SET NOCOUNT ON  

	IF NOT EXISTS (SELECT TOP 1 1 FROM sys.objects WHERE name = @TableName )
	RETURN

	IF @TableName = 'ProviderExternalResultDetail'
	BEGIN
		;WITH cte_AllData AS
		(	SELECT r.ProviderExternalId		
				,r.MatchId		
				,r.SourceId
				,r.ResourceId	
				,r.HomeValue
				,r.AwayValue	
				,r.CreateDate
				,ROW_NUMBER() OVER (PARTITION BY r.matchId, r.SourceId, r.ResourceId ORDER BY r.CreateDate DESC) AS rn
				,r.IsLive
			FROM ProviderExternalResultDetail r WITH(NOLOCK)
			WHERE r.ProviderExternalId > CAST(@LastValue AS INT)
				AND r.CreateDate < @Date
				AND r.SourceId < 1001 AND SourceID NOT IN (98, 99) ---exclude INST score, confirm refund SDT
		)
		SELECT @JsonInfo = COMPRESS(( SELECT TOP(@BatchNo)
										cte.ProviderExternalId AS 'id'				
										,cte.MatchId AS 'm'		
										,cte.SourceId AS 's'
										,cte.ResourceId AS 'rs'	
										,cte.HomeValue AS 'h'		
										,cte.AwayValue AS 'a'
										,cte.CreateDate AS 'cd'
										,cte.IsLive AS 'il'
									FROM cte_AllData cte
									WHERE cte.rn = 1
									ORDER BY cte.ProviderExternalId
									FOR JSON PATH
								))
	END

	ELSE IF @TableName = 'ProviderExternalResultDetailES'
	BEGIN
		;WITH cte_AllData AS
		(	SELECT r.ProviderExternalId			
				,r.MatchId		
				,r.SourceId
				,r.ResourceId	
				,r.HomeValue
				,r.AwayValue
				,r.CreateDate
				,ROW_NUMBER() OVER (PARTITION BY r.matchId, r.SourceId, r.ResourceId ORDER BY r.CreateDate DESC) AS rn
				,r.IsLive
			FROM ProviderExternalResultDetailES r WITH(NOLOCK)
			WHERE r.ProviderExternalId > CAST(@LastValue AS INT)
				AND r.CreateDate < @Date
				AND r.SourceId < 1001 AND SourceID NOT IN (98, 99)
		)
		SELECT @JsonInfo = COMPRESS(( SELECT TOP(@BatchNo)
										cte.ProviderExternalId AS 'id'				
										,cte.MatchId AS 'm'		
										,cte.SourceId AS 's'
										,cte.ResourceId AS 'rs'	
										,cte.HomeValue AS 'h'		
										,cte.AwayValue AS 'a'
										,cte.CreateDate AS 'cd'
										,cte.IsLive AS 'il'
									FROM cte_AllData cte
									WHERE cte.rn = 1
									ORDER BY ProviderExternalId
									FOR JSON PATH
								))
	END

	ELSE IF @TableName = 'ProviderExternalResultDetailOS'
	BEGIN
		;WITH cte_AllData AS
		(	SELECT r.ProviderExternalId			
				,r.MatchId		
				,r.SourceId
				,r.ResourceId	
				,r.HomeValue	
				,r.AwayValue	
				,r.CreateDate
				,ROW_NUMBER() OVER (PARTITION BY r.matchId, r.SourceId, r.ResourceId ORDER BY r.CreateDate DESC) AS rn
				,r.IsLive
			FROM ProviderExternalResultDetailOS r WITH(NOLOCK)
			WHERE r.ProviderExternalId > CAST(@LastValue AS INT)
				AND r.CreateDate < @Date
				AND r.SourceId < 1001 AND SourceID NOT IN (98, 99)
		)
		SELECT @JsonInfo = COMPRESS(( SELECT TOP(@BatchNo)
										cte.ProviderExternalId AS 'id'				
										,cte.MatchId AS 'm'		
										,cte.SourceId AS 's'
										,cte.ResourceId AS 'rs'	
										,cte.HomeValue AS 'h'		
										,cte.AwayValue AS 'a'
										,cte.CreateDate AS 'cd'
										,cte.IsLive AS 'il'
									FROM cte_AllData cte
									WHERE cte.rn = 1
									ORDER BY ProviderExternalId
									FOR JSON PATH
								))
	END

END  
GO