/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_AutoMarkProblemAccount_Job]
(
	@UserId		INT = 10278938
	,@UserName		VARCHAR(100) = 'starixIT'
	,@IP			VARCHAR(50)		= '125.227.140.97'
	
)
AS
/*
	Created by: Helen
	Date 20200225
	Task: [TVS] Abnormal Void Bets Automation
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20200225@Helen:[TVS] Auto Void winning bet [Redmine:#128836]
		- 20200323@Max: Highlight Abnormal Voiding Request [Redmine: #129639]
		- 20200406@Helen:[TVS] Auto Void winning bet  for Tennis [Redmine:#131516]
		- 20200601@Helen: [TVS] Apply new policy into Void Abnormal Bet rules - [Redmine: #134269]
		- 20200609@Max: [TVS] Auto Void for remaining sports - [Redmine: #135574]
		- 20200727@Max: [TVS] Danger Accept Bets Issue Type [Redmine: #135947]
		- 20201001@Zane: Exclude Virtual Futsal from auto void bet [Redmine: #142512]
		- 20201007@Max: Integrate new bet type Time Machine OU [Redmine: #143032]
		- 20210302@Max: TVS - Integrate Cricket AIO [Redmine: #150075]

	Param's explanation:	
	
	Sample execution:
		DECLARE @ErrCode			INT				= 0		
				,@ErrMsg			VARCHAR(300)	= ''	
		EXEC TicketVoiding_AutoMarkProblemAccount_Job @ErrCode = @ErrCode OUT,@ErrMsg = @ErrMsg 

*/
BEGIN
	DECLARE @query NVARCHAR(MAX) = ''
		, @ExecuteSQL NVARCHAR(MAX) = ''
		, @IsActiveVoidWinning BIT = 0
		, @TransIds_tmp VARCHAR(MAX) = ''
		, @start INT  = 1
		, @end INT = 0
		, @matchid INT
		, @Mark_cnt INT
		, @Unmark_cnt INT
		------------ FOR Error LOG ----------
		, @ErrMsg_tmp VARCHAR(200) = ''
		, @ErrMsg_Mark			VARCHAR(300)	= ''	
		, @ErrMsg_UMark			VARCHAR(300)	= ''	
		, @ErrCode	INT
		, @StartTime		DATETIME
		, @EndTime			DATETIME
		, @LogActionId		INT = 90505
		, @LogData			VARCHAR(MAX)
		, @SB_Error			BIT
			
	SET @StartTime = GETDATE()
	SET @IsActiveVoidWinning = (SELECT TOP (1) IsActive 
								FROM DBCUST.CUSTDB.dbo.ProblemAccountAction WITH (NOLOCK) 
								WHERE ActionID = 2)
								
	IF ISNULL(@IsActiveVoidWinning,0) = 0
		RETURN

	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT PRIMARY KEY)
	DECLARE @Matchid_Final AS TABLE (Matchid INT, ID INT IDENTITY(1,1))
	
	DECLARE @tmpAutoTransIDBatch TABLE (TransId	BIGINT)
	DECLARE @transid_Mark AS TABLE (Matchid INT, Transid BIGINT,custID INT, IsFinish BIT)
	DECLARE @Transid_UnMark AS TABLE (Transid BIGINT, IsFinish BIT)
	CREATE TABLE #Transid_UnMark_tmp (Transid BIGINT)
	
	DECLARE @ProblemAccount_tmp AS TABLE (CustID INT, isFinish BIT)
	DECLARE @ProblemAccountByBatch_tmp AS TABLE (CustID INT)
		
	INSERT INTO @bettype_tmp (bettype)
	SELECT DISTINCT pt.bettype
	FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
	WHERE pt.ProductID = 1 -- Sportsbook
		AND pt.bettype NOT IN (10, 9, 29) -- outright, parlay
		AND pt.bettype NOT BETWEEN 221 AND 227 -- Fast Market
		AND pt.SubProduct NOT IN ('Bet Builder', 'MG-SuperLive', 'BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet Builder, Metric Gaming, Bet trade (BT-)
		AND 1 = CASE WHEN pt.SportType IN (50) THEN 0
					WHEN pt.SportType <= 99 THEN 1 END
	
	SELECT  @query = N''		
	SELECT	@query = @query + N'SELECT Custid 
								FROM dbo.ProblemAccount WITH (NOLOCK)	
								WHERE Actionid = 2 and SubIssueTypeId = 38'
	SELECT	@ExecuteSQL = N'EXECUTE DBCUST.CUSTDB.dbo.sp_executesql @query'

	INSERT INTO @ProblemAccount_tmp (CustID)
	EXECUTE	sys.sp_executesql @ExecuteSQL, N'@query NVARCHAR(MAX)', @query
	
	IF @@ROWCOUNT > 0
	BEGIN
		WHILE (1=1)
		BEGIN
			DELETE @ProblemAccountByBatch_tmp
					
			UPDATE TOP(2000) t
				SET isFinish = 1
			OUTPUT DELETED.CustID
					
			INTO @ProblemAccountByBatch_tmp(CustID)
			FROM @ProblemAccount_tmp t 
			WHERE isFinish IS NULL
			
			IF @@ROWCOUNT = 0 BREAK
					
			INSERT INTO @Transid_Mark (transid, Matchid)
			SELECT b.transid, b.matchid
			FROM @ProblemAccountByBatch_tmp t
				INNER JOIN dbo.bettrans b WITH (NOLOCK) ON t.custid = b.custid
				INNER JOIN dbo.match m WITH (NOLOCK) ON b.matchid = m.matchid AND m.sporttype <= 99 AND m.eventstatus <> 'completed' AND m.sporttype <> 50 --Exclude Cricket for TVS
				INNER JOIN dbo.league l WITH (NOLOCK) ON m.leagueid = l.leagueid 
				OUTER APPLY (SELECT TOP 1 transid
							FROM dbo.MarkedTransaction mt WITH (NOLOCK)
							WHERE  mt.transid = b.transid
							) AS mt_tmp
				OUTER APPLY (SELECT TOP 1 au.[Enabled]
							 FROM dbo.TicketVoiding_AutoMarkService_AutoSetting au WITH (NOLOCK)
							 WHERE m.matchid = au.MatchID 
							 ) AS m_auto			
			WHERE b.statusID = 0 AND mt_tmp.TransId IS NULL
					AND EXISTS (SELECT TOP 1 1 FROM @bettype_tmp bt WHERE bt.bettype = b.bettype)
					AND ISNULL(m_auto.[Enabled],1) = 1
					AND ISNULL(l.LeagueGroupID,0) NOT IN (42,74,108)
					
			OPTION (MAXDOP 1)
			
		END	
			
	END
	
	SET @Mark_cnt = (SELECT COUNT(1) FROM @Transid_Mark)
				
	--Step 1: Mark Ticket Problem Account
	IF @Mark_cnt > 0
	BEGIN
		INSERT INTO @Matchid_Final(Matchid)
		SELECT DISTINCT m.Matchid
		FROM @Transid_Mark m
			LEFT JOIN dbo.TempVariableNumber tv WITH (NOLOCK) ON m.matchid = tv.KeyValue AND tv.KeyID IN (1,7)
		WHERE tv.KeyValue IS NULL
		
		SET @end = (SELECT MAX(ID) FROM @Matchid_Final )
		-- LOOP BY matchid
		WHILE @start <= @end
		BEGIN
		
			SET @matchid = (SELECT matchid FROM @Matchid_Final WHERE ID = @start)
			
			WHILE (1=1)
			BEGIN
				DELETE @tmpAutoTransIDBatch
					
				UPDATE TOP(2000) t
					SET isFinish = 1
				OUTPUT DELETED.TransId
						
				INTO @tmpAutoTransIDBatch(TransId)
				FROM @Transid_Mark t 
				WHERE isFinish IS NULL
					AND t.Matchid = @matchid
				
				IF @@ROWCOUNT = 0 BREAK
				
				SELECT @TransIds_tmp = STUFF((SELECT ',' + CONVERT(VARCHAR(50), tp.transid)
												FROM @tmpAutoTransIDBatch tp
												GROUP BY TransId for XML PATH('')), 1, 1, '')
					
				BEGIN TRY
				
					EXEC dbo.Nap_SpecialDelete_UnMarkedTickets_Update @TransIds = @TransIds_tmp, @UserId = @UserId
																	, @Username = @UserName, @IP = @IP
																	, @MarkType = 2
																	, @LogActionId = 90509
																	, @ErrMsg = @ErrMsg_tmp OUTPUT
																	, @ErrCode = @ErrCode OUTPUT;
																	
				END TRY
				BEGIN CATCH
					SET @ErrMsg_Mark= @ErrMsg_Mark + @ErrMsg_tmp + ' Matchid:' + CAST(@matchid AS VARCHAR(50))
				END CATCH
					
				SET @TransIds_tmp = ''	 
				SET @ErrMsg_tmp = ''
				
			END
			
			SET @start = @start + 1
			
		END	
	END
	--Step 2: Unmark ticket not belong problem account, status running only, mark by auto system
	INSERT INTO #Transid_UnMark_tmp (transid)
	SELECT mt.transid
	FROM dbo.MarkedTransaction mt WITH (NOLOCK) 
		LEFT JOIN @ProblemAccount_tmp t ON t.custid = mt.custid
		OUTER APPLY (SELECT TOP 1 au.[Enabled]
					 FROM dbo.TicketVoiding_AutoMarkService_AutoSetting au WITH (NOLOCK)
					 WHERE mt.matchid = au.MatchID 
					 ) AS m_auto
	WHERE t.CustID IS NULL 
		AND mt.MarkType = 2
		AND ISNULL(m_auto.[Enabled],1) = 1
	
	IF @@ROWCOUNT > 0
	BEGIN
		INSERT INTO @Transid_UnMark (Transid)
		SELECT b.transid
		FROM #Transid_UnMark_tmp um
			INNER JOIN dbo.bettrans b WITH (NOLOCK) ON um.Transid = b.transid
			OUTER APPLY (SELECT TOP (1) RequestId 
						 FROM TicketVoiding_RequestDetailTicket_Single td WITH (NOLOCK)
						 WHERE td.matchid = b.matchid AND td.TransId = b.transid
						) AS tmp		 
		WHERE b.statusID = 0
			AND tmp.RequestId IS NULL
		
		SET @Unmark_cnt = @@ROWCOUNT	
	END
	
	IF @Unmark_cnt > 0
	BEGIN	
		WHILE (1=1)
		BEGIN
			
			DELETE @tmpAutoTransIDBatch
				
			UPDATE TOP(2000) t
				SET isFinish = 1
			OUTPUT DELETED.TransId
					
			INTO @tmpAutoTransIDBatch(TransId)
			FROM @Transid_UnMark t 
			WHERE isFinish IS NULL
			
			IF @@ROWCOUNT = 0 BREAK
			
			SELECT @TransIds_tmp = STUFF((SELECT ',' + CONVERT(VARCHAR(50), tp.transid)
											FROM @tmpAutoTransIDBatch tp
											GROUP BY TransId for XML PATH('')), 1, 1, '')
			
			BEGIN TRY
				EXEC [dbo].[Nap_SpecialDelete_MarkedTickets_Update] @TransIds = @TransIds_tmp
					,@UserId = @UserId
					,@Username = @UserName
					,@IP = @IP
					,@LogActionId = 90510
					,@IsLockMatch	= 1
					,@ErrMsg = @ErrMsg_tmp OUTPUT
					,@ErrCode = @ErrCode OUTPUT
			END TRY
			BEGIN CATCH
				SET @ErrMsg_UMark = @ErrMsg_UMark + @ErrMsg_tmp + ' Matchid:'  + CAST(@matchid AS VARCHAR(50)) 
			END CATCH	
			
			SET @TransIds_tmp = ''	 
			SET @ErrMsg_tmp = ''
		END
	END
	
	IF @ErrMsg_UMark <> '' OR @ErrMsg_Mark <> ''
	BEGIN
		-- Write Erro Log for trace issue later
		SET @EndTime = GETDATE()
		
		SET @LogData = CAST((SELECT	
								 @LogActionId AS '@LogActionId'
								,@UserId AS '@UserId'
								,@IP AS '@IP'
								,'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms.' 
									+ CASE WHEN @ErrMsg_Mark <> '' THEN + ' Mark:' + @ErrMsg_Mark ELSE '' END
									+ CASE WHEN @ErrMsg_UMark <> '' THEN +' UnMark:' + @ErrMsg_UMark ELSE '' END
									AS  '@LogData'
						FOR XML PATH ('r'), ROOT ('root'), TYPE
		) AS VARCHAR(MAX))
		
		EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT
		
	END
	
	DROP TABLE #Transid_UnMark_tmp
	
END		
GO		
					


