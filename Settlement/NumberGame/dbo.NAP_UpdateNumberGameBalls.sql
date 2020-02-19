/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_UpdateNumberGameBalls]
	@MatchId int,
	@BallResults VARCHAR(MAX) = '<Balls></Balls>',
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
		- 20200218@Sol: : Incorporate Number Game - Color Ball [Redmine:#128203]
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
	DECLARE @tblResult TABLE(Seq TINYINT, Number TINYINT, Color VARCHAR(1))
	DECLARE @handle INT,
			@FirstBall TINYINT = NULL, -- 0 means N/A	
			@SecondBall TINYINT = NULL, -- 0 means N/A
			@ThirdBall TINYINT = NULL -- 0 means N/A

	EXEC sp_xml_preparedocument @handle OUTPUT, @BallResults
	INSERT INTO @tblResult(Seq, Number, Color)
	SELECT Seq, Number, Color
	FROM OPENXML(@handle,'Balls/Ball',1) WITH( Seq	TINYINT
												,Number TINYINT
												,Color VARCHAR(1)
										) AS tbl
	EXEC sp_xml_removedocument @handle

	SELECT 
		@FirstBall = CASE WHEN Seq = 1 THEN Number ELSE @FirstBall END,
		@SecondBall = CASE WHEN Seq = 2 THEN Number ELSE @SecondBall END,
		@ThirdBall = CASE WHEN Seq = 3 THEN Number ELSE @ThirdBall END
	FROM @tblResult

	SELECT @IsTest = lg.IsTest
			,@SportType = m.SportType
	FROM dbo.Match m WITH (NOLOCK)
		INNER JOIN dbo.League lg WITH (NOLOCK) ON m.leagueID = lg.LeagueID
	WHERE m.matchID = @matchID
	
	UPDATE match WITH(ROWLOCK, UPDLOCK)
		SET 
			hthomescore = @FirstBall
			,livehomescore = @ThirdBall
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
	INSERT INTO bingoball(matchid, seq, number, updatetime, SportType, isTest, Color)
	SELECT @MatchId, Seq, Number, CURRENT_TIMESTAMP, @SportType, @IsTest, Color
	FROM @tblResult
	WHERE Seq = 1

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
	INSERT INTO bingoball(matchid, seq, number, updatetime, SportType, isTest, Color)
	SELECT @MatchId, Seq, Number, CURRENT_TIMESTAMP, @SportType, @IsTest, Color
	FROM @tblResult
	WHERE Seq = 2

	-- THIRD ball
	IF @ThirdBall IS NULL 
	BEGIN 
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
	INSERT INTO bingoball(matchid, seq, number, updatetime, SportType, isTest, Color)
	SELECT @MatchId, Seq, Number, CURRENT_TIMESTAMP, @SportType, @IsTest, Color
	FROM @tblResult
	WHERE Seq = 3
	
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
