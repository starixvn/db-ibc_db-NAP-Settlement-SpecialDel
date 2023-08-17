/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Task_UserLog_Settle_WriteLog]
	@MessageBody XML
AS
/*	
	Created: 20230421@Aries
	Task: Use Service Broker to Write Log to DB Log
	DB: DBLOG-bodb_CustomerLog

	Revisions: 
        - 20230214@Aries: Created [Redmine: #187252]
		- 20230817@Kathy: Write log [Redmine:#192311]
		
	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @Remark VARCHAR(MAX)
		,@MatchId INT
		,@BroadcastSessionId VARCHAR(50)
		,@UserID INT
		,@ActionID INT
		,@finalhomescore INT
		,@finalawayscore INT
		,@hthomescore INT
		,@htawayscore INT
		,@GoalRecord VARCHAR(50)
		,@betstatus VARCHAR(50)
		,@IP VARCHAR(15)

		,@xmlRemark XML
		,@isxml BIT = 0

	SELECT	@Remark = t.c.value('@r','VARCHAR(MAX)')		
			,@MatchId =	t.c.value('@m','INT')
			,@BroadcastSessionId = t.c.value('@bs','VARCHAR(50)')	
			,@ActionID = t.c.value('@a','INT')
			,@UserID = t.c.value('@u','INT')
			,@finalhomescore = t.c.value('@fth','INT')	
			,@finalawayscore = t.c.value('@fta','INT')		
			,@hthomescore	 = t.c.value('@hth','INT')		
			,@htawayscore	 = t.c.value('@hta','INT')		
			,@GoalRecord	 = t.c.value('@g','VARCHAR(50)')	
			,@betstatus		 = t.c.value('@b','VARCHAR(50)')
			,@IP			 = t.c.value('@i','VARCHAR(15)')	
	FROM	@MessageBody.nodes('UserLog_Settle/row') t(c)

	BEGIN TRY
		SET @xmlRemark = CAST(@Remark AS XML)
		SET @isxml = 1

	END TRY
	BEGIN CATCH
		SET @isxml = 0
	END CATCH

	-- update
	IF EXISTS (SELECT TOP 1 1 FROM dbo.UserLog_Settle WITH(NOLOCK) WHERE matchId = @MatchId AND BroadcastSessionId = @BroadcastSessionId AND ActionID = @ActionID)
	BEGIN
		IF @isxml = 0
		BEGIN
			UPDATE dbo.UserLog_Settle
				SET Remark = Remark + @Remark
			WHERE	MatchID = @MatchId
					AND BroadcastSessionId = @BroadcastSessionId
					AND ActionID = @ActionID
		END
		ELSE IF @isxml = 1
		BEGIN
			SET @xmlRemark.modify('delete /distinct'); -- remove root <distinct>
			SET @xmlRemark.modify('delete /bettypes'); -- remove root <bettypes>
			SET @xmlRemark.modify('delete /eventcounters'); -- remove root <eventcounters>

			UPDATE dbo.UserLog_Settle
				SET Remark = Remark + CAST(@xmlRemark AS VARCHAR(MAX))
			WHERE	MatchID = @MatchId
					AND BroadcastSessionId = @BroadcastSessionId
					AND ActionID = @ActionID
		END
	END
	ELSE -- insert
	BEGIN
		INSERT INTO dbo.UserLog_Settle (UserID,
			MatchID,
			ActionID,
			[finalhomescore],
			[finalawayscore],  
			[hthomescore],
			[htawayscore],
			[GoalRecord],
			[betstatus],
			[Remark],
			[IP],
			LogDate,
			BroadcastSessionId
		)
		SELECT @UserID, @MatchId, @ActionID, @finalhomescore, @finalawayscore, @hthomescore, @htawayscore, @GoalRecord, @betstatus
			,@Remark
			,@IP
			,GETDATE()
			,@BroadcastSessionId

	END
END

GO