
/*
	Creator:	20210920@Louisa
	Task:		Cleanup data in dbo.ResultDetail, dbo.ProviderExternalResultDetailES - [Redmine:#161455]
	Database:	DBPRO.bodb02
	
	Revisions:
		Cleanup data in dbo.ResultDetail, dbo.ProviderExternalResultDetailES - [Redmine:#161455]
		
*/

USE bodb02

SET NOCOUNT ON

BEGIN 
	--ProviderExternalResultDetailES
	CREATE TABLE #__resultESData(rowId INT IDENTITY(1,1) PRIMARY KEY, providerExternalId INT)

	--collect redundant data
	INSERT INTO #__resultESData(providerExternalId)
	SELECT p.ProviderExternalId
	FROM dbo.Louisa_ProviderExternalResultDetailES p WITH(NOLOCK) ----- *******************
		LEFT JOIN dbo.match m WITH(NOLOCK) ON p.MatchId = m.matchid
	WHERE m.matchid IS NULL

	--backup data if can
	IF OBJECT_ID('MonDB.dbo.__ProviderExternalResultDetailES_161455') IS NOT NULL
	DROP TABLE MonDB.dbo.__ProviderExternalResultDetailES_161455

	SELECT p.* INTO MonDB.dbo.__ProviderExternalResultDetailES_161455
	FROM dbo.Louisa_ProviderExternalResultDetailES p WITH(NOLOCK)				 ----- *******************
	WHERE EXISTS (
		SELECT TOP 1 1 FROM #__resultESData t WHERE t.providerExternalId = p.ProviderExternalId
	)


	DECLARE  @__rowId INT			= 1
			,@__batch INT			= 2000
			,@__message VARCHAR(200)
			,@__tempData VARCHAR(MAX)= NULL
 

	WHILE 1 = 1
	BEGIN
		SET @__tempData = (
			SELECT providerExternalId AS id
			FROM #__resultESData 
			WHERE rowId >= @__rowId 
				AND rowId < @__rowId + @__batch
			FOR XML RAW ('r'), root ('root')
		)

		IF @__tempData IS NULL
			BREAK

		--call SP excep rep
		EXEC dbo.QC_Local_ExecRep10 @TableName = 'Louisa_ProviderExternalResultDetailES' --ExecRep_APL_00  ----- *******************
			, @data = @__tempData

		SELECT @__rowId = @__rowId + @__batch
			, @__message = '@__rowId: ' + CAST(@__rowId AS VARCHAR(20)) + '- dt: '+ CONVERT(VARCHAR(50), GETDATE(), 121)
		
		WAITFOR DELAY '00:00:00:010' --waifor replication release
		RAISERROR(@__message, 0, 1) WITH NOWAIT
	END
END
GO

BEGIN --ResultDetail
 
	CREATE TABLE #__resultData(rowId INT IDENTITY(1,1) PRIMARY KEY, matchId INT, resourceId VARCHAR(20))

	--collect redundant data
	INSERT INTO #__resultData(matchId, resourceId)
	SELECT r.MatchId, r.ResourceId
	FROM dbo.Louisa_ResultDetail r WITH(NOLOCK)		 ----- *******************
		LEFT JOIN dbo.match m WITH(NOLOCK) ON r.MatchId = m.matchid
	WHERE m.matchid IS NULL

	--backup data if can
	IF OBJECT_ID('MonDB.dbo.__ResultDetail_161455') IS NOT NULL
	DROP TABLE MonDB.dbo.__ResultDetail_161455

	SELECT r.* INTO MonDB.dbo.__ResultDetail_161455
	FROM dbo.Louisa_ResultDetail r WITH(NOLOCK)	 ----- *******************
	WHERE EXISTS (
		SELECT TOP 1 1 FROM #__resultData t WHERE t.matchId = r.MatchId AND t.resourceId = r.ResourceId
	)

	DECLARE  @__rowId INT			= 1
			,@__batch INT			= 2000
			,@__message VARCHAR(200)
			,@__tempData VARCHAR(MAX) = NULL
	
	WHILE 1 = 1
	BEGIN
		SET @__tempData = (
			SELECT matchId AS m, resourceId AS r
			FROM #__resultData 
			WHERE rowId >= @__rowId and rowId < @__rowId + @__batch
			FOR XML RAW ('r'), root ('root')
		)
		
		IF @__tempData IS NULL
			BREAK

		--call SP excep rep
		EXEC dbo.QC_Local_ExecRep10 @TableName = 'Louisa_ResultDetail'	 --ExecRep_APL_00  ----- *******************
			, @data = @__tempData

		SELECT @__rowId = @__rowId + @__batch
			, @__message = '@__rowId: ' + CAST(@__rowId AS VARCHAR(20)) + '- dt: '+ CONVERT(VARCHAR(50), GETDATE(), 121)
		
		WAITFOR DELAY '00:00:00:010' --waifor replication release
		RAISERROR(@__message, 0, 1) WITH NOWAIT
	END
END
GO

