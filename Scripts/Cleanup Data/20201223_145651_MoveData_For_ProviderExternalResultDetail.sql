/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/*
	Created by: 20201223@Louisa
	Task: Move data from ProviderExternalResultDetail to ProviderExternalResultDetail14 and ProviderExternalResultDetail_bk [Redmine:#145651]
	DB: DBPRO/bodb02

*/

USE bodb02
GO

BEGIN

DECLARE  @TotalRow	INT  = 0 , @Count14 INT  = 0 ,  @Count_bk INT  = 0
		,@ErrCode 	INT	 = 0
		,@ErrMsg	NVARCHAR(500) =	''

		--DROP TABLE #output
		--DROP TABLE #ProviderExternalIdList

	BEGIN TRY
		
	----STEP 1: Get data not in Active
		CREATE TABLE #output (
			ProviderExternalId  INT  
			,MatchId3rd			INT 
			,MatchId			INT 
			,SourceId			SMALLINT  
			,ResourceId			VARCHAR (20) 
			,HomeValue			VARCHAR (50) 
			,AwayValue			VARCHAR (50) 
			,OtherInfo			VARCHAR (50) 
			,CreateDate			DATETIME 
			,LastModifyDate		DATETIME 
			,CreateBy			INT  
			,LastModifyBy		INT
		)
		INSERT INTO #output (ProviderExternalId, MatchId3rd, MatchId, SourceId, ResourceId, HomeValue, AwayValue, OtherInfo, CreateDate, LastModifyDate, CreateBy, LastModifyBy)
		SELECT 				 ProviderExternalId, MatchId3rd, MatchId, SourceId, ResourceId, HomeValue, AwayValue, OtherInfo, CreateDate, LastModifyDate, CreateBy, LastModifyBy
		FROM 		dbo.ProviderExternalResultDetail ex  WITH (NOLOCK)
		WHERE NOT EXISTS ( SELECT 1 FROM dbo.match AS m WITH (NOLOCK) WHERE ex.matchid = m.matchid)

		SELECT ProviderExternalId INTO #ProviderExternalIdList FROM #output	
		
		SELECT @TotalRow = @@ROWCOUNT		
		--- select * from #ProviderExternalIdList

	----STEP 2: INSERT data into ProviderExternalResultDetail14
		DELETE o
		OUTPUT DELETED.ProviderExternalId
			 , DELETED.MatchId3rd
			 , DELETED.MatchId
			 , DELETED.SourceId
			 , DELETED.ResourceId
			 , DELETED.HomeValue
			 , DELETED.AwayValue
			 , DELETED.OtherInfo
			 , DELETED.CreateDate
			 , DELETED.LastModifyDate
			 , DELETED.CreateBy
			 , DELETED.LastModifyBy
		INTO dbo.ProviderExternalResultDetail14 
		FROM #output o
		WHERE	EXISTS (SELECT 1 FROM dbo.match14 AS m WITH (NOLOCK) WHERE o.matchid = m.matchid)

		SELECT @Count14 = @@ROWCOUNT
		PRINT 'INSERT INTO ProviderExternalResultDetail14  ' + CAST ( @Count14 AS VARCHAR(7)) + ' row(s)'


	----STEP 3: insert data into ProviderExternalResultDetail_bk
		INSERT INTO DBACC.bodb_Archive.dbo.ProviderExternalResultDetail_bk 
			  (ProviderExternalId, MatchId3rd, MatchId, SourceId, ResourceId, HomeValue, AwayValue, OtherInfo, CreateDate, CreateBy, LastModifyDate, LastModifyBy	)
		SELECT ProviderExternalId, MatchId3rd, MatchId, SourceId, ResourceId, HomeValue, AwayValue, OtherInfo, CreateDate, CreateBy, LastModifyDate, LastModifyBy 
		FROM #output

		SELECT @Count_bk = @@ROWCOUNT
		PRINT 'INSERT INTO ProviderExternalResultDetail_bk  ' + CAST ( @Count_bk AS VARCHAR(7)) + ' row(s)'


	----STEP 4: delete data in ProviderExternalResultDetail
		IF ( @Count14 + @Count_bk = @TotalRow)
		BEGIN
			DELETE FROM ProviderExternalResultDetail
				WHERE ProviderExternalId IN ( SELECT ProviderExternalId FROM #ProviderExternalIdList )

				PRINT 'DELETE in ProviderExternalResultDetail ' + CAST ( @@RowCOunt AS VARCHAR(7)) + ' row(s)'
		END

	END TRY

	BEGIN CATCH

		SET @ErrCode =  @@ERROR
		SET @ErrMsg  =  ERROR_MESSAGE()

	END CATCH

	SELECT @ErrCode, @ErrMsg

END


