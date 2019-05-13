/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_3rd_Job]
AS
/*
	Creator: Vicky
	Date: 20181228
	Task: BetBuild Auto/Manual Settlement
	DB: DBTXN/BODB02
	Original: 
	
	Revisions:
		- 20190103@Vicky: Incorporate BetBuilder  [Redmine:#106903]
		- 20190312@Vicky: add actionID  [Redmine:#106903]

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @MatchId		INT
		, @AdminId			INT
		, @IP				VARCHAR(15)
		, @Action			VARCHAR(20)
		, @ActionID			INT
		, @ErrCode			INT
		, @ErrMsg			NVARCHAR(200)
		, @sqlCommand		NVARCHAR(MAX)
		, @keyId			INT
		, @duration			INT
		, @pre_Sporttype	SMALLINT
		, @sporttype		SMALLINT

	SELECT TOP 1 @duration	= DATEDIFF(ms, execTime, GETDATE())
		, @keyId = keyid
		, @matchid = matchid
		, @sporttype = SportType
		, @sqlCommand = sqlCommand
	FROM dbo.Single_Calculate_Queue_3rd WITH (NOLOCK)
	WHERE IsCalculating = 1

	IF ISNULL(@duration, 0) > 300000 -- 5 minutes
	BEGIN
		IF @sporttype = 50 AND @sqlCommand = ''
		BEGIN
			UPDATE dbo.Single_Calculate_Queue_3rd WITH (ROWLOCK, UPDLOCK)
			SET IsCalculating = 3
			WHERE keyid = @keyId
		END
		ELSE
		BEGIN
			UPDATE dbo.Single_Calculate_Queue_3rd WITH (ROWLOCK, UPDLOCK)
			SET	IsCalculating = 0
				, execTime = NULL
			WHERE keyid = @keyId
		END
	END
	ELSE IF EXISTS (SELECT TOP 1 1
					FROM dbo.Single_Calculate_Queue_3rd WITH (NOLOCK)
					WHERE IsCalculating = 1 AND sqlCommand <> '')
	BEGIN
		RETURN
	END

	SELECT @ErrCode = 0, @ErrMsg = ''

	--Get sporttype of previous calculated match
	/*SELECT TOP 1 @pre_Sporttype = SportType
	FROM dbo.Single_Calculate_Queue_3rd WITH (NOLOCK)
	WHERE IsCalculating IN (2, 3)
	ORDER BY execTime DESC*/
	
	SELECT TOP 1 @pre_Sporttype = SportType
	FROM(
		SELECT TOP 1 SportType, execTime
		FROM dbo.Single_Calculate_Queue_3rd WITH (NOLOCK)
		WHERE IsCalculating = 2
		ORDER BY execTime DESC
		
		UNION ALL
		
		SELECT TOP 1 SportType, execTime
		FROM dbo.Single_Calculate_Queue_3rd WITH (NOLOCK)
		WHERE IsCalculating = 3
		ORDER BY execTime DESC
		) AS t
	ORDER BY execTime DESC

	--Giving priority to calcualate the match which has sporttype <> previous calculated match
	SET @keyId = (
			SELECT TOP 1 keyid
			FROM dbo.Single_Calculate_Queue_3rd WITH (NOLOCK)
			WHERE IsCalculating = 0
			ORDER BY CASE WHEN SportType = @pre_Sporttype THEN 1 ELSE 0 END
				,TryCount, starttime, keyid
	)

	UPDATE TOP (1) dbo.Single_Calculate_Queue_3rd WITH (ROWLOCK, UPDLOCK)
	SET IsCalculating	= 1
		, execTime 		= GETDATE()
		, @MatchId 		= matchid
		, @Adminid 		= AdminId
		, @IP			= IP
		, @Action		= Action
		, @ActionID		= ActionID
		, @sqlCommand	= sqlCommand
	WHERE keyid = @keyId

	IF @@ROWCOUNT = 0 RETURN

	BEGIN TRY
		EXEC sys.sp_executesql @sqlCommand
			, N'@ErrMsg VARCHAR(400) OUTPUT, @ErrCode int OUTPUT'
			, @ErrMsg	= @ErrMsg	OUTPUT
			, @ErrCode	= @ErrCode	OUTPUT
	END TRY

	BEGIN CATCH
		SET @ErrMsg = @ErrMsg + ERROR_MESSAGE()
	END CATCH

	IF (ISNULL(@ErrCode, 0) <> 0 OR ISNULL(@ErrMsg, '') <> '' ) -- calculate failed set calculating = 0 and back
		AND ISNULL(@ErrCode, 0) <> 1000006 --- 1000006: Betfair & Betdaq - Warning message
	BEGIN
		UPDATE dbo.Single_Calculate_Queue_3rd WITH (ROWLOCK, UPDLOCK)
		SET IsCalculating = 0
			, TryCount = TryCount + 1
		WHERE keyid = @keyId

		IF NOT EXISTS (SELECT 1
						FROM dbo.Settled_Message WITH (NOLOCK)
						WHERE AdminId = @AdminId
							AND MatchId = @MatchId
							AND Action = @Action
							AND @ErrMsg = CASE WHEN @ErrCode = 1000000 THEN Warning	ELSE Message END)
		BEGIN
			INSERT INTO dbo.Settled_Message (AdminId, MatchId, IP, Starttime, Action, Message, Warning)
			SELECT @AdminId, @MatchId, @IP, GETDATE(), @Action
				, CASE WHEN @ErrCode = 1000000 THEN NULL ELSE @ErrMsg END
				, CASE WHEN @ErrCode = 1000000 THEN @ErrMsg	ELSE NULL END
		END

		UPDATE dbo.Single_Calculate_Queue_3rd WITH (ROWLOCK, UPDLOCK)
		SET IsCalculating = 3
			, duration = DATEDIFF(ms, execTime, GETDATE())
		WHERE keyid = @keyId AND TryCount = 3

		IF @@ROWCOUNT > 0
		BEGIN
			--get the latest message for reference action
			SELECT TOP(1) @ErrMsg = Message
			FROM dbo.Settled_Message WITH(NOLOCK)
			WHERE AdminId = @AdminId
				AND MatchId = @MatchId
				AND Action = @Action
				AND ISNULL(Message, '') <> ''
			ORDER BY Starttime DESC

			EXEC dbo.NAP_Set_SB_ErrorHandling @Action = @Action
				, @ActionIDInput = @ActionID
				, @MatchId = @MatchId
				, @sqlCommand = @sqlCommand
				, @ErrMsg = @ErrMsg
				, @AdminId = @AdminId
				, @IP = @IP
		END
	END
	ELSE
	BEGIN
		IF @ErrCode = 1000006
		BEGIN
			INSERT INTO dbo.Settled_Message (AdminId, MatchId, IP, Starttime, Action, Message, Warning)
			SELECT @AdminId, @MatchId, @IP, GETDATE(), @Action, @ErrMsg, NULL 
		END

		UPDATE dbo.Single_Calculate_Queue_3rd WITH (ROWLOCK, UPDLOCK)
		SET	IsCalculating = 2
			, duration = DATEDIFF(ms, execTime, GETDATE())
		WHERE keyid = @keyId

	END
END

GO
