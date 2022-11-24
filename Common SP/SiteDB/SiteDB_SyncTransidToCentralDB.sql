/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[SiteDB_SyncTransidToCentralDB]
(
	@transid VARCHAR(MAX)
	,@TableName VARCHAR(200) 
	,@ErrCode			INT				= 0	 OUTPUT
	,@ErrMsg			VARCHAR(300)	= '' OUTPUT

)
AS
/*
	Created by: 20221124@Helen
	Task: Settlement  

	Revisions:
		- 20221124@Helen: Support to sync tickets from sitedb to central DB
	
	Notes: sample execution
		-- UPDATE bettrans
		DECLARE @ErrCode INT = 0
				, @ErrMsg VARCHAR(300)	= ''
		EXEC SiteDB_SyncTransidToCentralDB @transid = '', @TableName = 'bettrans', @ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT
		SELECT @ErrCode, @ErrMsg

		-- UPDATE bettransm
		DECLARE @ErrCode INT = 0
				, @ErrMsg VARCHAR(300)	= ''
		EXEC SiteDB_SyncTransidToCentralDB @transid = '', @TableName = 'bettransm', @ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT
		SELECT @ErrCode, @ErrMsg


*/
BEGIN
	
	IF ISNULL(@transid,'') =  '' OR @TableName NOT IN ('bettrans', 'bettransm')
	BEGIN
		SET @ErrCode = 100
		SET @ErrMsg = 'Wrong input param'

		RETURN
	END
	
	--should define primary key for the temporary tables
	CREATE TABLE #Result(
		id [INT] IDENTITY (1,1) PRIMARY KEY,
		Transid BIGINT
	)

	INSERT INTO #Result (Transid)
	SELECT f.[value] AS transid
	FROM STRING_SPLIT(@transid, ',') f 

	IF @@ROWCOUNT = 0 
	BEGIN
		SET @ErrMsg = 'NO DATA'

		RETURN
	END

	------ info for deployer
	DECLARE @StartRow INT 
			, @StopRow INT 
			, @MaxRow INT  -- Keep the total row of your data
			, @Threshold INT  -- the number of each batch
		
	DECLARE @debug_message VARCHAR(500)
	SET @MaxRow = (SELECT MAX(ID) FROM #Result)
	SET @Threshold = 1000

	IF @Threshold >= @MaxRow
		SET @Threshold = @MaxRow

	-- SET for first batch
	SELECT @StartRow = 1, @StopRow = @Threshold

	WHILE (@MaxRow IS NOT NULL)
	BEGIN
			PRINT @StartRow
			PRINT @StopRow
	
			-- YOUR CODE PROCESS FOR DATA FROM @StartRow & @StopRow
			IF @TableName = 'bettrans'
			BEGIN
				UPDATE b
					SET RepUpdateTime = SYSDATETIME()
				FROM bettrans b WITH (ROWLOCK,UPDLOCK)
					INNER JOIN #Result r ON r.Transid = b.TransId
				WHERE r.id BETWEEN @StartRow AND @StopRow
			END
		
			ELSE IF @TableName = 'bettransm'
			BEGIN
				UPDATE b
					SET RepUpdateTime = SYSDATETIME()
				FROM bettransm b WITH (ROWLOCK,UPDLOCK)
					INNER JOIN #Result r ON r.Transid = b.TransId
				WHERE r.id BETWEEN @StartRow AND @StopRow
			END
			ELSE
				BREAK

			SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
			RAISERROR (@debug_message, 0, 1) WITH NOWAIT
		
			IF @StopRow = @MaxRow BREAK

			WAITFOR DELAY '00:00:00.020' --optional

			SET @StartRow = @StopRow + 1
			SET @StopRow = @StopRow + @Threshold

			IF @StopRow >= @MaxRow
				SET @StopRow = @MaxRow

	END

	DROP TABLE #Result
END