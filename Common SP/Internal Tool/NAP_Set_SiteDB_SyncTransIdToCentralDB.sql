/*<info serverAlias="DBSIG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_SiteDB_SyncTransIdToCentralDB]
(
	@ServerName		VARCHAR(100)
	,@TableName		VARCHAR(200)
	,@TransIds		VARCHAR(MAX) 
	,@ErrCode		INT				= 0	 OUTPUT
	,@ErrMsg		VARCHAR(300)	= '' OUTPUT

)
AS
/*
	Created:20220913@Louisa
    Task: Sync ticket from SiteDB to Central [RedmineId:#179505]
    DB: DBSIG/bodb02

	Revisions:
		- 20230208@Louisa: Sync ticket from SiteDB to Central [RedmineId:#179505]


*/
BEGIN

	CREATE TABLE #Result(
		id [INT] IDENTITY (1,1) PRIMARY KEY,
		Transid BIGINT
	)

	INSERT INTO #Result (Transid)
	SELECT f.[value] AS transid
	FROM STRING_SPLIT(@TransIds, ',') f 

	---- 1. Validation
	IF @ServerName <> @@SERVERNAME
	BEGIN
		SELECT @ErrCode = 100
				,@ErrMsg = 'Wrong Server'
		RETURN
	END

	IF NOT EXISTS (SELECT TOP 1 1 FROM #Result)
	BEGIN
		SELECT @ErrCode = 101
				,@ErrMsg = 'No data to update'
		RETURN
	END

	IF ISNULL(@TransIds,'') =  '' OR @TableName NOT IN ('bettrans', 'bettransm')
	BEGIN
		SELECT @ErrCode = 102
				,@ErrMsg = 'Wrong input'
		RETURN
	END

	IF @TableName = 'bettrans'
	BEGIN
		IF EXISTS ( SELECT TOP 1 1 FROM #Result r
						LEFT JOIN  bettrans b WITH (NOLOCK) ON r.Transid = b.TransId
						WHERE b.TransId IS NULL
						)
		BEGIN
			SELECT @ErrCode = 103
					,@ErrMsg = 'Invalid TransID. Some TransId is not exist, please check input again'	
			RETURN
		END
	END

	IF @TableName = 'bettransm'
	BEGIN
		IF EXISTS ( SELECT TOP 1 1 FROM #Result r
						LEFT JOIN  bettransm b WITH (NOLOCK) ON r.Transid = b.TransId
						WHERE b.TransId IS NULL
						)
		BEGIN
			SELECT @ErrCode = 103
				,@ErrMsg = 'Invalid TransID. Some TransId is not exist, please check input again'
			RETURN
		END
	END
	----/END  Validation

	----2. UPDATE colum RepUpdateTime

	DECLARE @StartRow INT 
			, @StopRow INT 
			, @MaxRow INT  -- Keep the total row of your data
			, @Threshold INT  -- the number of each batch
		
	DECLARE @debug_message VARCHAR(500)
	SET @MaxRow = (SELECT MAX(ID) FROM #Result)
	SET @Threshold = 500

	IF @Threshold >= @MaxRow
		SET @Threshold = @MaxRow

	-- SET for first batch
	SELECT @StartRow = 1, @StopRow = @Threshold

	WHILE (@MaxRow IS NOT NULL)
	BEGIN
			--PRINT @StartRow
			--PRINT @StopRow
	
			-- PROCESS FOR DATA FROM @StartRow & @StopRow
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

			WAITFOR DELAY '00:00:03.000' --optional

			SET @StartRow = @StopRow + 1
			SET @StopRow = @StopRow + @Threshold

			IF @StopRow >= @MaxRow
				SET @StopRow = @MaxRow

	END

	DROP TABLE #Result
END


