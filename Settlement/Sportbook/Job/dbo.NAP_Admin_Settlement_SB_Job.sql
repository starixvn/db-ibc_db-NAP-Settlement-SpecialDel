/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_SB_Job]
AS
/*
	Created: 20130109@Kathy
	Task: select a match from list to perform calculating (Sportsbook)
	DB: DBTXN/bodb02
	
	Revisions:
		- 20140326@Kathy: Get match values from DBPRO
		- 20140502@Kathy: Add new column execTime, duration for Single_Calculate_Queue
		- 20140505@Kathy: Re-run match if time of execution more than 5 minutes
		- 20140507@Kathy: - Add more settlement actions
						  - Modify betstatus, goalrecord format before send to Apollo site
		- 20140528@Kathy: rotate calculating sports in queue
		- 20140825@Kathy: Support 1H FGLG (127) for Apollo [Redmine:#16276]
		- 20151210@Patrick: Database - Change datatype [Redmine: #48660]
		- 20160106@Kathy: Integrate Cricket [Redmine:#49727]
		- 20160315@Patrick: Auto payout [Redmine: #53262]
		-20161013@Bobby: #65178 - Implement Instant calculation process - remove redundant code Apolo
		- 20200212@Helen:[TVS] Abnormal Void Bets Automation [Redmine:#127398]
		- 20200225@Helen:[TVS] Auto Void winning bet [Redmine:#128836]
		- 20200406@Helen:[TVS] Auto Void winning bet  for Tennis[Redmine:#131516]
		- 20200609@Max: [TVS] Auto Void for remaining sports - [Redmine: #135574]
		- 20210809@Kathy: Settle by custid [Redmine:159486]
		- 20211215@Kathy: Soccer - Include calculate parlay into calculate single tickets process [Redmine:#166072]
		- 20220404@Kathy: Allow to Settle Determined FT Ticket When Calculate HT [Redmine:#170551]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
		- 20221103@Helen: SP Enhancement [Redmine:#180092]
		- 20230406@Aries: Un-calculate FT Only [Redmine: #146737]
		- 20230404@Kathy: Merge single and parlay [Redmine:#175202]
		- 20230523@Kathy: remove un-used table [Redmine:#188452]
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @MatchId		INT
		, @AdminId			INT
		, @IP				VARCHAR(15)
		, @Action			VARCHAR(20)
		, @ErrCode			INT
		, @ErrMsg			NVARCHAR(200)
		, @sqlCommand		NVARCHAR(max)
		, @keyId			INT
		, @fth 				SMALLINT
		, @fta 				SMALLINT
		, @hth 				SMALLINT
		, @hta 				SMALLINT
		, @GoalRecord		VARCHAR(50)
		, @BetStatus		NVARCHAR(50)
		, @ActionId			INT
		, @duration			INT
		, @pre_Sporttype	SMALLINT
		, @sporttype		SMALLINT
		, @SSBStatus		TINYINT
		, @SSBCommand		NVARCHAR(MAX)
		, @IsRunBySSB		BIT
		, @BroadcastSessionId VARCHAR(50)
	
	DECLARE @date DATETIME
	SET @date = DATEADD (MINUTE, -5, GETDATE())
	
	SELECT	@ErrCode = 0
			,@ErrMsg = ''
			,@SSBStatus = 0
			,@IsRunBySSB = 0

	;WITH cteCricketRunning
	AS(
		SELECT	keyid
		FROM	dbo.Single_Calculate_Queue WITH (NOLOCK)
		WHERE	IsCalculating = 1
				AND SportType = 50
				AND sqlCommand = ''
				AND DATEDIFF(ms, execTime, GETDATE()) > 300000
	)
	UPDATE	q
		SET IsCalculating = 3
	FROM	 dbo.Single_Calculate_Queue q WITH (ROWLOCK, UPDLOCK)
		INNER JOIN cteCricketRunning c
			ON q.keyid = c.keyId

	SELECT	@keyId = keyid
			,@SSBStatus = ISNULL(SSBStatus,0)
			,@SSBCommand = SSBCommand
			,@sporttype = SportType
			,@Action = Action
			,@AdminId = AdminId
			,@MatchId = matchid
			,@IP = IP
			,@BroadcastSessionId = BroadcastSessionId
	FROM	dbo.Single_Calculate_Queue WITH (NOLOCK)
	WHERE	IsCalculating = 1 
			AND sqlCommand <> ''

	IF  @@ROWCOUNT <> 0 AND @SSBStatus = 0
		RETURN

	IF @SSBStatus = 1
	BEGIN
		SET @IsRunBySSB = 1

		BEGIN TRY
			EXEC sys.sp_executesql @SSBCommand
				, N'@ErrMsg VARCHAR(400) OUTPUT, @ErrCode int OUTPUT, @SSBStatus tinyint OUTPUT'
				, @ErrMsg	= @ErrMsg	OUTPUT
				, @ErrCode	= @ErrCode	OUTPUT
				, @SSBStatus= @SSBStatus OUTPUT
		END TRY

		BEGIN CATCH
			SET @ErrMsg = @ErrMsg + ERROR_MESSAGE()
			SET @ErrCode = ERROR_NUMBER()
			SET @SSBStatus = 3
		END CATCH
		
		IF @SSBStatus = 1
			RETURN
			
		IF @ErrCode <> 0 AND @ErrCode <> 1000006 -- Betfair & Betdaq - Warning message
			SET @SSBStatus = 3
		ELSE
			SET @SSBStatus = 2

	END
	ELSE
	BEGIN
		SELECT @ErrCode = 0, @ErrMsg = ''
		--Get sporttype of previous calculated match
		SELECT TOP 1 @pre_Sporttype = SportType
		FROM dbo.Single_Calculate_Queue WITH (NOLOCK)
		WHERE IsCalculating IN (2, 3) AND starttime>= @date
		ORDER BY execTime DESC

		--Giving priority to calcualate the match which has sporttype <> previous calculated match
		SELECT TOP 1 @keyId =  keyid
				,@sporttype = SportType
				,@Action = Action
		FROM	dbo.Single_Calculate_Queue WITH (NOLOCK)
		WHERE	IsCalculating = 0
		ORDER BY CASE WHEN SportType = @pre_Sporttype THEN 1 ELSE 0 END
			,TryCount, starttime, keyid
	
		SET @IsRunBySSB = CASE WHEN @sporttype = 1 AND (@Action IN ('CAL', 'CAL-HT', 'CAL-FT', 'REFUND', 'REFUND-HT', 'REFUND-FT', 'SDT-FT', 'UNDO-FT') OR @Action LIKE '%INST%') THEN 1 ELSE 0 END

		IF @IsRunBySSB = 1
			SET @SSBStatus = 1

		UPDATE TOP (1) dbo.Single_Calculate_Queue WITH (ROWLOCK, UPDLOCK)
		SET IsCalculating	= 1
			, SSBStatus		= CASE WHEN @IsRunBySSB = 1 THEN @SSBStatus ELSE SSBStatus END
			, execTime 		= GETDATE()
			, @MatchId 		= matchid
			, @Adminid 		= AdminId
			, @IP			= IP
			, @Action		= Action
			, @sqlCommand	= sqlCommand
			, @BroadcastSessionId = BroadcastSessionId
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
		
		IF @IsRunBySSB = 1 AND @ErrCode <> 0 AND @ErrCode <> 1000006 -- Betfair & Betdaq - Warning message
			SET @SSBStatus = 3
	END

	IF @SSBStatus = 1
		RETURN
	
	IF (ISNULL(@ErrCode, 0) <> 0 OR ISNULL(@ErrMsg, '') <> '' ) -- calculate failed set calculating = 0 and back
		AND ISNULL(@ErrCode, 0) <> 1000006 --- 1000006: Betfair & Betdaq - Warning message
	BEGIN
		IF @IsRunBySSB = 0
			UPDATE dbo.Single_Calculate_Queue WITH (ROWLOCK, UPDLOCK)
				SET IsCalculating = 0
					,TryCount = TryCount + 1
			WHERE	keyid = @keyId
				
		UPDATE dbo.Single_Calculate_Queue WITH (ROWLOCK, UPDLOCK)
		SET IsCalculating = 3
			, duration = DATEDIFF(ms, execTime, GETDATE())
			, SSBStatus = CASE WHEN @SSBStatus = 3 THEN 3 ELSE SSBStatus END
		WHERE keyid = @keyId AND (TryCount = 3 OR @SSBStatus = 3)

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
				, @MatchId = @MatchId
				, @sqlCommand = @sqlCommand
				, @ErrMsg = @ErrMsg
				, @AdminId = @AdminId
				, @IP = @IP
		END

		IF NOT EXISTS (SELECT 1
						FROM dbo.Settled_Message WITH (NOLOCK)
						WHERE AdminId = @AdminId
							AND MatchId = @MatchId
							AND Action = @Action
							AND @ErrMsg = CASE WHEN @ErrCode = 1000000 THEN Warning	ELSE Message END)
			INSERT INTO dbo.Settled_Message (AdminId, MatchId, IP, Starttime, Action, Message, Warning)
			SELECT @AdminId, @MatchId, @IP, GETDATE(), @Action
				, CASE WHEN @ErrCode = 1000000 THEN NULL ELSE @ErrMsg END
				, CASE WHEN @ErrCode = 1000000 THEN @ErrMsg	ELSE NULL END
	END
	ELSE
	BEGIN
		IF @ErrCode = 1000006
		BEGIN
			INSERT INTO dbo.Settled_Message (AdminId, MatchId, IP, Starttime, Action, Message, Warning)
			SELECT @AdminId, @MatchId, @IP, GETDATE(), @Action, @ErrMsg, NULL 
		END

		IF @IsRunBySSB = 0 OR (@IsRunBySSB = 1 AND @SSBStatus = 2)
		BEGIN
			UPDATE	dbo.Single_Calculate_Queue WITH (ROWLOCK, UPDLOCK)
				SET	IsCalculating = 2
					,duration = DATEDIFF(ms, execTime, GETDATE())
					,SSBStatus = CASE WHEN @SSBStatus = 2 THEN 2 ELSE SSBStatus END
			WHERE	keyid = @keyId			
		END
	END
END
GO

