/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230727@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBSIC-bodb02

	Revisions:
		- 20230727@Louisa: Update RepUpdteTime on SITEDB3 to sync ticket to DBTRANS[Redmineid:#181595] 

*/

---Run on SITEDB3

USE bodb02
GO

---Required input @tableName
DECLARE @TableName	VARCHAR(200)  ----bettrans , bettransRnG , bettransLC , bettransG , translog, bettransm , transfer 


-------------------------------------------------------
DECLARE @StartRow		INT = 1
		, @StopRow		INT 
		, @MaxRow		INT 
		, @Threshold	INT = 500
		, @debug_message VARCHAR(500)

SET @MaxRow = (SELECT MAX(ID) FROM dbo.CheckSum_MigrateSiteDB3_Temp WITH(NOLOCK) WHERE TableName = @TableName )
IF @Threshold >= @MaxRow
		SET @Threshold = @MaxRow

SET @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
	BEGIN
		IF @TableName = 'bettrans'
		BEGIN
			UPDATE b
				SET RepUpdateTime = SYSDATETIME()
			FROM bettrans b WITH (ROWLOCK,UPDLOCK)
				INNER JOIN dbo.CheckSum_MigrateSiteDB3_Temp t WITH(NOLOCK) ON t.Transid = b.TransId
			WHERE t.ID BETWEEN @StartRow AND @StopRow
				AND t.TableName = @TableName 
		END

		ELSE IF @TableName = 'bettransRnG'
		BEGIN
			UPDATE b
				SET RepUpdateTime = SYSDATETIME()
			FROM bettransRnG b WITH (ROWLOCK,UPDLOCK)
				INNER JOIN dbo.CheckSum_MigrateSiteDB3_Temp t WITH(NOLOCK) ON t.Transid = b.TransId
			WHERE t.ID BETWEEN @StartRow AND @StopRow
				AND t.TableName = @TableName 
		END

		ELSE IF @TableName = 'bettransLC'
		BEGIN
			UPDATE b
				SET RepUpdateTime = SYSDATETIME()
			FROM bettransLC b WITH (ROWLOCK,UPDLOCK)
				INNER JOIN dbo.CheckSum_MigrateSiteDB3_Temp t WITH(NOLOCK) ON t.Transid = b.TransId
			WHERE t.ID BETWEEN @StartRow AND @StopRow
				AND t.TableName = @TableName 
		END

		ELSE IF @TableName = 'bettransG'
		BEGIN
			UPDATE b
				SET RepUpdateTime = SYSDATETIME()
			FROM bettransG b WITH (ROWLOCK,UPDLOCK)
				INNER JOIN dbo.CheckSum_MigrateSiteDB3_Temp t WITH(NOLOCK) ON t.Transid = b.TransId
			WHERE t.ID BETWEEN @StartRow AND @StopRow
				AND t.TableName = @TableName 
		END

		ELSE IF @TableName = 'translog'
		BEGIN
			UPDATE b
				SET RepUpdateTime = SYSDATETIME()
			FROM translog b WITH (ROWLOCK,UPDLOCK)
				INNER JOIN dbo.CheckSum_MigrateSiteDB3_Temp t WITH(NOLOCK) ON t.Transid = b.translogid
			WHERE t.ID BETWEEN @StartRow AND @StopRow
				AND t.TableName = @TableName 
		END
		
		ELSE IF @TableName = 'bettransm'
		BEGIN
			UPDATE b
				SET RepUpdateTime = SYSDATETIME()
			FROM bettransm b WITH (ROWLOCK,UPDLOCK)
				INNER JOIN dbo.CheckSum_MigrateSiteDB3_Temp t WITH(NOLOCK) ON t.Transid = b.Transid
			WHERE t.ID BETWEEN @StartRow AND @StopRow
				AND t.TableName = @TableName 
		END

		ELSE IF @TableName = 'transfer'
		BEGIN
			UPDATE b
				SET RepUpdateTime = SYSDATETIME()
			FROM transfer b WITH (ROWLOCK,UPDLOCK)
				INNER JOIN dbo.CheckSum_MigrateSiteDB3_Temp t WITH(NOLOCK) ON t.Transid = b.Transid
			WHERE t.ID BETWEEN @StartRow AND @StopRow
				AND t.TableName = @TableName 
		END

		ELSE
			BREAK

		SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT
		
		IF @StopRow = @MaxRow BREAK

		WAITFOR DELAY '00:00:00.180'

		SET @StartRow = @StopRow + 1
		SET @StopRow = @StopRow + @Threshold

		IF @StopRow >= @MaxRow
			SET @StopRow = @MaxRow

	END