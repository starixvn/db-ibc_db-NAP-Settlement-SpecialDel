/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/*
	Creator:	20210920@Louisa
	Task:		Cleanup data - [Redmine:#161455]
	Database:	DBPRO/bodb02
	
	Revisions:
		Cleanup data in dbo.ResultDetail, dbo.ProviderExternalResultDetailES - [Redmine:#161455]
	
	Param's Explanation: 
		- SP test execrep local DB206, 215, DB234, db233\sqlserver2008R2 : QC_Local_ExecRep10	
*/

USE bodb02
GO

SET NOCOUNT ON

BEGIN 
	DECLARE @DayBefore VARCHAR(10)
	SET @DayBefore =  CONVERT(VARCHAR(10),DATEADD (DAY, -7, GETDATE()), 120)

	--ProviderExternalResultDetailES
	CREATE TABLE #__resultESData(rowId INT IDENTITY(1,1) PRIMARY KEY, providerExternalId INT)

	--collect redundant data
	INSERT INTO #__resultESData(providerExternalId)
	SELECT p.ProviderExternalId
	FROM dbo.ProviderExternalResultDetailES p WITH(NOLOCK) ----- table local test: Louisa_ProviderExternalResultDetailES
		LEFT JOIN dbo.match m WITH(NOLOCK) ON p.MatchId = m.matchid
	WHERE m.matchid IS NULL
		AND p.CreateDate <= @DayBefore

	--backup data if can
	IF OBJECT_ID('MonDB.dbo.__ProviderExternalResultDetailES_161455') IS NOT NULL
	DROP TABLE MonDB.dbo.__ProviderExternalResultDetailES_161455

	SELECT p.* INTO MonDB.dbo.__ProviderExternalResultDetailES_161455
	FROM dbo.ProviderExternalResultDetailES p WITH(NOLOCK)	----- table local test: Louisa_ProviderExternalResultDetailES
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
		--local test: EXEC dbo.QC_Local_ExecRep10 @TableName = 'Louisa_ProviderExternalResultDetailES'

		EXEC dbo.ExecRep_APL_00 @TableName = 'ProviderExternalResultDetailES' 
			, @data = @__tempData

		SELECT @__rowId = @__rowId + @__batch
			, @__message = '@__rowId: ' + CAST(@__rowId AS VARCHAR(20)) + '- dt: '+ CONVERT(VARCHAR(50), GETDATE(), 121)
		
		WAITFOR DELAY '00:00:00:500' --waifor replication release
		RAISERROR(@__message, 0, 1) WITH NOWAIT
	END
END
GO

BEGIN --ResultDetail
	
	DECLARE @DayBefore VARCHAR(10)
	SET @DayBefore =  CONVERT(VARCHAR(10),DATEADD (DAY, -7, GETDATE()), 120)

	CREATE TABLE #__resultData(rowId INT IDENTITY(1,1) PRIMARY KEY, matchId INT, resourceId VARCHAR(20))

	--collect redundant data
	INSERT INTO #__resultData(matchId, resourceId)
	SELECT r.MatchId, r.ResourceId
	FROM dbo.ResultDetail r WITH(NOLOCK) ----- table local test: Louisa_ResultDetail
		LEFT JOIN dbo.match m WITH(NOLOCK) ON r.MatchId = m.matchid
	WHERE m.matchid IS NULL
		AND r.CreateDate <= @DayBefore

	--backup data if can
	IF OBJECT_ID('MonDB.dbo.__ResultDetail_161455') IS NOT NULL
	DROP TABLE MonDB.dbo.__ResultDetail_161455

	SELECT r.* INTO MonDB.dbo.__ResultDetail_161455
	FROM dbo.ResultDetail r WITH(NOLOCK)	  ----- table local test: Louisa_ResultDetail
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
		--local test: EXEC dbo.QC_Local_ExecRep10 @TableName = 'Louisa_ResultDetail'

		EXEC dbo.ExecRep_APL_00 @TableName = 'ResultDetail'
			, @data = @__tempData

		SELECT @__rowId = @__rowId + @__batch
			, @__message = '@__rowId: ' + CAST(@__rowId AS VARCHAR(20)) + '- dt: '+ CONVERT(VARCHAR(50), GETDATE(), 121)
		
		WAITFOR DELAY '00:00:00:500' --waifor replication release
		RAISERROR(@__message, 0, 1) WITH NOWAIT
	END
END
GO

