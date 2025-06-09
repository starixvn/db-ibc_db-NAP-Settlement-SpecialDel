/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Set_Service_ArchiveData_Sel  
	@Date DATE
	,@BatchNo INT = 2000
	,@TableName VARCHAR(100)
	,@LastValue	VARCHAR(100) = ''
	,@JsonInfo VARBINARY(MAX) OUTPUT

AS  
/* 
	 Creator: 20250606@Louisa 
	 Task: archive data to DB061 [Redmine:#229613] 
	     
	 Revisions:  
		- 20250606@Louisa: archive data to DB061 [Redmine:#229613]
*/  
BEGIN  
	SET NOCOUNT ON  

	IF NOT EXISTS (SELECT TOP 1 1 FROM sys.objects WHERE name = @TableName )
	RETURN

	IF @TableName = 'ProviderExternalResultDetail'
	BEGIN
		;WITH cte_AllData AS
		(	SELECT TOP(@BatchNo) 
				r.ProviderExternalId		
				,r.MatchId		
				,r.SourceId
				,r.ResourceId	
				,r.HomeValue
				,r.AwayValue	
				,r.CreateDate
				,r.IsLive
			FROM ProviderExternalResultDetail r WITH(NOLOCK)
			WHERE r.ProviderExternalId > CAST(@LastValue AS INT)
				AND r.CreateDate < @Date
				AND r.SourceId < 1001 AND SourceID NOT IN (98, 99) ---exclude INST score, confirm refund SDT
			ORDER BY cte.ProviderExternalId
		)
		SELECT @JsonInfo = COMPRESS(( SELECT 
										cte.ProviderExternalId AS 'id'				
										,cte.MatchId AS 'm'		
										,cte.SourceId AS 's'
										,cte.ResourceId AS 'rs'	
										,cte.HomeValue AS 'h'		
										,cte.AwayValue AS 'a'
										,cte.CreateDate AS 'cd'
										,cte.IsLive AS 'il'
									FROM cte_AllData cte
									FOR JSON PATH
								))
	END

	ELSE IF @TableName = 'ProviderExternalResultDetailES'
	BEGIN
		;WITH cte_AllData AS
		(	SELECT TOP(@BatchNo) 
				r.ProviderExternalId			
				,r.MatchId		
				,r.SourceId
				,r.ResourceId	
				,r.HomeValue
				,r.AwayValue
				,r.CreateDate
				,r.IsLive
			FROM ProviderExternalResultDetailES r WITH(NOLOCK)
			WHERE r.ProviderExternalId > CAST(@LastValue AS INT)
				AND r.CreateDate < @Date
				AND r.SourceId < 1001 AND SourceID NOT IN (98, 99)
			ORDER BY ProviderExternalId
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
									FOR JSON PATH
								))
	END

	ELSE IF @TableName = 'ProviderExternalResultDetailOS'
	BEGIN
		;WITH cte_AllData AS
		(	SELECT  TOP(@BatchNo) 
				r.ProviderExternalId			
				,r.MatchId		
				,r.SourceId
				,r.ResourceId	
				,r.HomeValue	
				,r.AwayValue	
				,r.CreateDate
				,r.IsLive
			FROM ProviderExternalResultDetailOS r WITH(NOLOCK)
			WHERE r.ProviderExternalId > CAST(@LastValue AS INT)
				AND r.CreateDate < @Date
				AND r.SourceId < 1001 AND SourceID NOT IN (98, 99)
			ORDER BY ProviderExternalId
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
									FOR JSON PATH
								))
	END

END  
GO