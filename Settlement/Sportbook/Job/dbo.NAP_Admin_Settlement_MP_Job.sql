/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_MP_Job]
AS
/*
	Created: 20140114@Kathy
	Task: select a match from list to perform calculating
	DB: DBTXN\bodb02
	Original: Admin_Settlement_Parlay_Job

	Revisions:
		- 20140502@Kathy: Add new columns execTime, duration for Parlay_Calculate_Queue
		- 20140505@Kathy: Re-run match if time of execution more than 5 minutes
		- 20140528@Kathy: rotate calculating sports in queue
		- 20150916@Kathy: update IsCalculating = 2 when settlement is done (remove NAP_Task_Calculate_Parlay job) [Redmine:#43566]
		- 20151210@Patrick: Database - Change datatype [Redmine: #48660]
		- 20160419@Kathy: change main SP to NAP_Admin_Settlem [Redmine:#52426]
		- 20161205@Bobby: #61352 - Apply settle determined for parlay bet types
		- 20210514@Kathy: settle parlay ticket [Redmine:#154737]
		- 20210904@Kathy: Data is Inserted into Table Settled_Message Continuously [Redmine:#161175]
		- 20211122@Max: Support Settlement Exclusion for Parlay Sub Tickets [Redmine: #163172]
		- 20220404@Kathy: Allow to Settle Determined FT Ticket When Calculate HT [Redmine:#170551]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
		- 20230214@Louisa: Remove unuse code [Redmine:#182677]
		- 20230523@Kathy: remove un-used table [Redmine:#188452]
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @matchid VARCHAR(2000)
		,@creator INT
		,@action VARCHAR(20)
		,@IP VARCHAR(15)
		,@ErrCode INT
		,@ErrMsg NVARCHAR(200)
		,@keyId INT
		,@ActionId INT
		,@pre_Sporttype smallint 
		,@Sporttype SMALLINT
		,@sqlCommand NVARCHAR(MAX)
		,@LockedByRefno BIT = 0
		,@LockedBySystemSetting BIT = 0
		,@BroadcastSessionId VARCHAR(50)
	
	IF EXISTS (
			SELECT TOP 1 1
			FROM Parlay_Calculate_Queue WITH (NOLOCK)
			WHERE IsCalculating = 1
			)
	BEGIN
		--- check Starttime if needed		
		RETURN
	END 

	-- get sporttype of previous calculated match
	SELECT TOP 1 @pre_Sporttype = m.SportType 
	FROM Parlay_Calculate_Queue p with(NOLOCK)
	INNER JOIN match m WITH(NOLOCK) ON m.matchid = p.matchid
	WHERE p.IsCalculating IN (2,3)
	ORDER BY p.execTime DESC

	-- giving priority to calcualate the match which has sporttype <> previous calculated match
	SELECT TOP 1 @keyId =  p.keyid
		,@Sporttype = p.Sporttype
		,@LockedByRefno = p.LockedByRefno
		,@BroadcastSessionId = BroadcastSessionId
	FROM dbo.Parlay_Calculate_Queue p WITH (NOLOCK)
	INNER JOIN match m WITH(NOLOCK) ON m.matchid = p.matchid
	WHERE p.IsCalculating = 0
	ORDER BY CASE WHEN m.SportType = @pre_Sporttype THEN 1 ELSE 0 END
		,p.TryCount DESC
		,p.starttime
		,p.keyid

	IF ISNULL(@keyId,0) <> 0 AND ISNULL(@LockedByRefno,0) = 0 -- lock by systemsetting
	BEGIN
		IF EXISTS (SELECT TOP 1 1 FROM dbo.SystemSettings WHERE VName = 'isCalculatingParlay' AND VValue = 0)
			AND NOT EXISTS (SELECT TOP 1 1 FROM dbo.ParlayLocking)
		BEGIN
			UPDATE dbo.SystemSettings WITH (ROWLOCK, UPDLOCK)
				SET VValue = 1
			WHERE VName = 'isCalculatingParlay'
		
			SET @LockedBySystemSetting = 1
		END
		ELSE
			RETURN
	END
	
	UPDATE TOP (1) dbo.Parlay_Calculate_Queue WITH (ROWLOCK, UPDLOCK)
		SET IsCalculating = 1
			,execTime = GETDATE()
			,@matchID = matchid
			,@action = [action]
			,@creator = creator
			,@IP = IP
			,@sqlCommand = sqlCommand
	WHERE keyid = @keyId

	IF @@ROWCOUNT = 0
	BEGIN
		IF @LockedBySystemSetting = 1
			UPDATE dbo.SystemSettings WITH (ROWLOCK, UPDLOCK)
				SET VValue = 0
			WHERE VName = 'isCalculatingParlay'

		RETURN
	END

	BEGIN TRY

		IF @LockedByRefno = 1  
			SET @sqlCommand = @sqlCommand + ', @LockedByRefno = 1 '
								
		EXEC sys.sp_executesql @sqlCommand
			, N'@ErrMsg VARCHAR(400) OUTPUT, @ErrCode int OUTPUT'
			, @ErrMsg	= @ErrMsg	OUTPUT
			, @ErrCode	= @ErrCode	OUTPUT
	END TRY

	BEGIN CATCH
		SET @ErrMsg = ERROR_MESSAGE()
	END CATCH
	
	IF ISNULL(@ErrCode, 0) <> 0 OR ISNULL(@ErrMsg, '') <> '' --- calculate failed set calculating = 0 back
	BEGIN
		UPDATE Parlay_Calculate_Queue WITH (ROWLOCK, UPDLOCK)
		SET IsCalculating = 0
			,TryCount = TryCount + 1
			,LockedByRefno = CASE WHEN @ErrCode = 1000000 AND LockedByRefno IS NOT NULL THEN NULL ELSE LockedByRefno END
		WHERE keyid = @keyId

		IF NOT EXISTS (
				SELECT 1
				FROM Settled_Message WITH (NOLOCK)
				WHERE AdminId = @creator AND MatchId = @MatchId AND Action = @Action 
				AND @ErrMsg = CASE WHEN @ErrCode = 1000000 THEN Warning
								   ELSE Message
							  END
				)
		BEGIN
			INSERT INTO Settled_Message (
				AdminId
				,MatchId
				,IP
				,Starttime
				,Action
				,Message
				,Warning
				)
			SELECT @creator
				,@MatchId
				,@IP
				,GETDATE()
				,@Action
				,case when @ErrCode = 1000000 then NULL ELSE @ErrMsg END 
				,case when @ErrCode = 1000000 then @ErrMsg ELSE NULL END 
		END

		UPDATE Parlay_Calculate_Queue WITH (ROWLOCK, UPDLOCK)
		SET IsCalculating = 3
			,duration = DATEDIFF(ms, execTime, GETDATE())
		WHERE keyid = @keyId
		AND TryCount = 3
	END
	ELSE
	BEGIN
		UPDATE	dbo.Parlay_Calculate_Queue WITH (UPDLOCK, ROWLOCK)
			SET IsCalculating = 2,
				duration = DATEDIFF(ms,execTime,GETDATE())
		WHERE	matchid = @matchid 
				AND IsCalculating = 1
	END

	---
	IF @LockedBySystemSetting = 1
		UPDATE dbo.SystemSettings WITH (ROWLOCK, UPDLOCK)
			SET VValue = 0
		WHERE VName = 'isCalculatingParlay'
END
