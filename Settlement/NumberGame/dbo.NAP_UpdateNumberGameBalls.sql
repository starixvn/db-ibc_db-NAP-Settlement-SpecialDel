/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_UpdateNumberGameBalls]
	@MatchId int,
	@FirstBall tinyint = NULL, -- 0 means N/A	
	@SecondBall tinyint = NULL, -- 0 means N/A
	@ThirdBall tinyint = NULL, -- 0 means N/A
	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT
AS
/*
	Created by:Kathy
	Date: 20131212
	Task: change the result of numbergame
	DB: DBPRO/BODB02
	Orignal: Acc_UpdateNumberGameBalls

	Revisions:
		- 20150612@Kathy: Not allow to insert/delete table TempVariableNumber by linked server. Use SP NAP_UpdateTempVariableNumber   [Redmine:#36216](Migrate custDB to new server - DBCust)
		- 20190109@Vicky: Set Default Value of IsTest on table BingoBall from League  [Redmine:#107748]
*/
BEGIN	

SET NOCOUNT ON
-- check and not allow attempt to settlement same game while it's still not finish
IF EXISTS (SELECT 1 FROM DBTXN.bodb02.dbo.TempVariableNumber WHERE KeyID = 1 AND KeyValue = @MatchId)
BEGIN
	SELECT  @ErrCode = 103,
			@ErrMsg = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'
	RETURN
END

DECLARE @LogData NVARCHAR(300)

EXEC DBTXN.bodb02.dbo.NAP_UpdateTempVariableNumber @matchid = @matchid, @ActionId = 1, @ErrCode = @ErrCode OUTPUT
--INSERT INTO DBTXN.bodb02.dbo.TempVariableNumber (KeyID, KeyValue) VALUES (1, @MatchId)

IF (@ErrCode = 0)
BEGIN 
	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
			@UserID = 5838421, --dbaAdmin
			@Matchid = @MatchId, 
			@KeyID = 1,
			@ActionID = 0, 
			@Remark = 'ADD SUCCESS SPName = NAP_UpdateNumberGameBalls'
	END TRY
	BEGIN CATCH
		SELECT @LogData = 'ADD SUCCESS SPName = NAP_UpdateNumberGameBalls MatchID=' + @MatchId + ' KeyID=1 ErrMsg='+ left(error_message(), 70)		
		EXEC WriteLog_UserLog @UserID = 5838421, --dbaAdmin
							  @Doing = @LogData		
	END CATCH
END
ELSE 
BEGIN
	SELECT @ErrCode = 100, @ErrMsg = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'
	RETURN
END
---------
	DECLARE @IsTest BIT, @SportType SMALLINT
	
	SELECT @IsTest = lg.IsTest
			,@SportType = m.SportType
	FROM dbo.Match m WITH (NOLOCK)
		INNER JOIN dbo.League lg WITH (NOLOCK) ON m.leagueID = lg.LeagueID
	WHERE m.matchID = @matchID
	

	UPDATE match with(rowlock, updlock)
	SET hthomescore = @FirstBall
	WHERE matchid = @MatchId
		
	UPDATE match with(rowlock, updlock)
	SET livehomescore = @ThirdBall
		,finalhomescore = @ThirdBall  
	WHERE matchid = @MatchId
						
	DELETE bingoball
	WHERE matchid = @MatchId

	-- FIRST ball
	IF @FirstBall IS NULL 
	BEGIN 
		--DELETE FROM DBTXN.bodb02.dbo.TempVariableNumber WITH (ROWLOCK,UPDLOCK) 
		--WHERE KeyID = 1 AND KeyValue = @MatchId	
		--IF (@@Error = 0)
		EXEC DBTXN.bodb02.dbo.NAP_UpdateTempVariableNumber @matchid = @matchid, @ActionId = 0, @ErrCode = @ErrCode OUTPUT
		IF @ErrCode = 0
		BEGIN	
			BEGIN TRY
				EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
					@UserID = 5838421, --dbaAdmin
					@Matchid = @MatchId, 
					@KeyID = 1,
					@ActionID = 0, 
					@Remark = 'DEL SUCCESS SPName = NAP_UpdateNumberGameBalls'
			END TRY
			BEGIN CATCH
				SELECT @LogData = 'DEL SUCCESS SPName = NAP_UpdateNumberGameBalls MatchID=' + @MatchId + ' KeyID=1 ErrMsg='+ left(error_message(), 70)		
				EXEC WriteLog_UserLog @UserID = 5838421, --dbaAdmin
									  @Doing = @LogData	
			END CATCH	
		END				
		ELSE
		BEGIN
			BEGIN TRY
				EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
					@UserID = 5838421, --dbaAdmin
					@Matchid = @MatchId, 
					@KeyID = 1,
					@ActionID = 0, 
					@Remark = 'DEL FAILED SPName = NAP_UpdateNumberGameBalls'
			END TRY
			BEGIN CATCH
				SELECT @LogData = 'DEL FAILED SPName = NAP_UpdateNumberGameBalls MatchID=' + @MatchId + ' KeyID=1 ErrMsg='+ left(error_message(), 70)		
				EXEC WriteLog_UserLog @UserID = 5838421, --dbaAdmin
									  @Doing = @LogData	
			END CATCH					
		END
		RETURN
	END
	ELSE	
	INSERT INTO bingoball(matchid, seq, number, updatetime, SportType, isTest)
	VALUES(@MatchId, 1, @FirstBall, CURRENT_TIMESTAMP, @SportType, @IsTest)

	-- SECOND ball
	IF @SecondBall IS NULL 
	BEGIN 
		--DELETE FROM DBTXN.bodb02.dbo.TempVariableNumber WITH (ROWLOCK,UPDLOCK) 
		--WHERE KeyID = 1 AND KeyValue = @MatchId	
		--IF (@@Error = 0)
		EXEC DBTXN.bodb02.dbo.NAP_UpdateTempVariableNumber @matchid = @matchid, @ActionId = 0, @ErrCode = @ErrCode OUTPUT
		
		IF @ErrCode = 0
		BEGIN	
			BEGIN TRY
				EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
					@UserID = 5838421, --dbaAdmin
					@Matchid = @MatchId, 
					@KeyID = 1,
					@ActionID = 0, 
					@Remark = 'DEL SUCCESS SPName = NAP_UpdateNumberGameBalls'
			END TRY
			BEGIN CATCH
				SELECT @LogData = 'DEL SUCCESS SPName = NAP_UpdateNumberGameBalls MatchID=' + @MatchId + ' KeyID=1 ErrMsg='+ left(error_message(), 70)		
				EXEC WriteLog_UserLog @UserID = 5838421, --dbaAdmin
									  @Doing = @LogData	
			END CATCH	
		END				
		ELSE
		BEGIN
			BEGIN TRY
				EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
					@UserID = 5838421, --dbaAdmin
					@Matchid = @MatchId, 
					@KeyID = 1,
					@ActionID = 0, 
					@Remark = 'DEL FAILED SPName = NAP_UpdateNumberGameBalls'
			END TRY
			BEGIN CATCH
				SELECT @LogData = 'DEL FAILED SPName = NAP_UpdateNumberGameBalls MatchID=' + @MatchId + ' KeyID=1 ErrMsg='+ left(error_message(), 70)		
				EXEC WriteLog_UserLog @UserID = 5838421, --dbaAdmin
									  @Doing = @LogData	
			END CATCH					
		END
		RETURN
	END	
	ELSE
	INSERT INTO bingoball(matchid, seq, number, updatetime, SportType, isTest)
	VALUES(@MatchId, 2, @SecondBall, CURRENT_TIMESTAMP, @SportType, @isTest)

	-- THIRD ball
	IF @ThirdBall IS NULL 
	BEGIN 
		--DELETE FROM DBTXN.bodb02.dbo.TempVariableNumber WITH (ROWLOCK,UPDLOCK) 
		--WHERE KeyID = 1 AND KeyValue = @MatchId	
		--IF (@@Error = 0)
		EXEC DBTXN.bodb02.dbo.NAP_UpdateTempVariableNumber @matchid = @matchid, @ActionId = 0, @ErrCode = @ErrCode OUTPUT
		
		IF @ErrCode = 0
		BEGIN	
			BEGIN TRY
				EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
					@UserID = 5838421, --dbaAdmin
					@Matchid = @MatchId, 
					@KeyID = 1,
					@ActionID = 0, 
					@Remark = 'DEL SUCCESS SPName = NAP_UpdateNumberGameBalls'
			END TRY
			BEGIN CATCH
				SELECT @LogData = 'DEL SUCCESS SPName = NAP_UpdateNumberGameBalls MatchID=' + @MatchId + ' KeyID=1 ErrMsg='+ left(error_message(), 70)		
				EXEC WriteLog_UserLog @UserID = 5838421, --dbaAdmin
									  @Doing = @LogData	
			END CATCH	
		END				
		ELSE
		BEGIN
			BEGIN TRY
				EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
					@UserID = 5838421, --dbaAdmin
					@MatchId = @MatchId, 
					@KeyID = 1,
					@ActionID = 0, 
					@Remark = 'DEL FAILED SPName = NAP_UpdateNumberGameBalls'
			END TRY
			BEGIN CATCH
				SELECT @LogData = 'DEL FAILED SPName = NAP_UpdateNumberGameBalls MatchID=' + @MatchId + ' KeyID=1 ErrMsg='+ left(error_message(), 70)		
				EXEC WriteLog_UserLog @UserID = 5838421, --dbaAdmin
									  @Doing = @LogData	
			END CATCH					
		END
		RETURN
	END	
	ELSE	
	INSERT INTO bingoball(matchid, seq, number, updatetime, SportType, isTest)
	VALUES(@MatchId, 3, @ThirdBall, CURRENT_TIMESTAMP, @SportType, @isTest)
	
	   
----
--DELETE FROM DBTXN.bodb02.dbo.TempVariableNumber WITH (ROWLOCK,UPDLOCK) 
--WHERE KeyID = 1 AND KeyValue = @MatchId	
--IF (@@Error = 0)
EXEC DBTXN.bodb02.dbo.NAP_UpdateTempVariableNumber @matchid = @matchid, @ActionId = 0, @ErrCode = @ErrCode OUTPUT
IF @ErrCode = 0
BEGIN	
	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
			@UserID = 5838421, --dbaAdmin
			@Matchid = @MatchId, 
			@KeyID = 1,
			@ActionID = 0, 
			@Remark = 'DEL SUCCESS SPName = NAP_UpdateNumberGameBalls'
	END TRY
	BEGIN CATCH
		SELECT @LogData = 'DEL SUCCESS SPName = NAP_UpdateNumberGameBalls MatchID=' + @MatchId + ' KeyID=1 ErrMsg='+ left(error_message(), 70)		
		EXEC WriteLog_UserLog @UserID = 5838421, --dbaAdmin
							  @Doing = @LogData	
	END CATCH	
END				
ELSE
BEGIN
	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
			@UserID = 5838421, --dbaAdmin
			@Matchid = @MatchId, 
			@KeyID = 1,
			@ActionID = 0, 
			@Remark = 'DEL FAILED SPName = NAP_UpdateNumberGameBalls'
	END TRY
	BEGIN CATCH
		SELECT @LogData = 'DEL FAILED SPName = NAP_UpdateNumberGameBalls MatchID=' + @MatchId + ' KeyID=1 ErrMsg='+ left(error_message(), 70)		
		EXEC WriteLog_UserLog @UserID = 5838421, --dbaAdmin
							  @Doing = @LogData	
	END CATCH					
END

END

GO
