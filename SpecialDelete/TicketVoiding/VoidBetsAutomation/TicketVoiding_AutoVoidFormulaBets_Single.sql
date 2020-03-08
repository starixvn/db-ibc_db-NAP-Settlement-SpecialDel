/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_AutoVoidFormulaBets_Single]
(	
	@SMAList			VARCHAR(MAX) = ''
	,@fromDate			DATETIME
	,@todate			DATETIME
	,@UserId			INT = NULL
	,@UserName			VARCHAR(50) = NULL
	,@IP				VARCHAR(50)		= ''
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			VARCHAR(300)	= ''	OUTPUT
)
AS
/*	Created by: Helen
	Date 20200308
	Task:  Auto Void Settled Tickets of Formula Bet Feature [Redmine:#129971]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20200308@Helen: Create new SP [Redmine:#129971]
		
	Param's explanation:	
		
*/      
BEGIN
	SET NOCOUNT ON
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.SystemSettings WHERE VName = 'AutoVoidFormula' AND VValue = 1)
	BEGIN
		SET @ErrCode = 100
		SET @ErrMsg = 'Another auto void formula Bets is running, please wait and try it later.'
		
		RETURN
		
	END
	
	-- Lock auto void process
	UPDATE SystemSettings SET VValue = 1
	WHERE VName = 'AutoVoidFormula'
	
	DECLARE @InputUsernameList AS TABLE (username NVARCHAR(50))
	DECLARE @tmpAutoTransIDBatch TABLE (TransId	BIGINT)
	CREATE TABLE #tblTransIds_autovoidformula_pre (matchid INT, transid BIGINT)
	CREATE TABLE #tblTransIds_autovoidformula (matchid INT, transid BIGINT, Isfinish BIT )
	CREATE TABLE #InputValidCustid  (custid INT)
	
	DECLARE @invalidUserName VARCHAR(MAX) =''
	DECLARE @TransIds VARCHAR(MAX) = ''
			, @TransIds_tmp VARCHAR(MAX) = ''
			, @ErrMsg_tmp VARCHAR (MAX) = ''
			, @StartTime		DATETIME = GETDATE()
			, @StartTime_tmp		DATETIME 
			, @EndTime			DATETIME
			, @LogActionId		INT = 90506
			, @LogData			VARCHAR(MAX)
			, @InvalidTransIds	VARCHAR(MAX) = ''
			, @InvalidTransIds_tmp	VARCHAR(MAX) = ''
			, @SB_Error			BIT
			, @autoMatchList	VARCHAR(MAX)  = ''
			, @suspendMatchList VARCHAR(MAX)  = ''
			
	INSERT INTO @InputUsernameList (username)
	SELECT DISTINCT f.val
	FROM dbo.f_SplitString (@SMAList, ',') AS f
	
	SET @invalidUserName = STUFF((SELECT  ',' + l.username
					FROM @InputUsernameList l
						LEFT JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON l.username = ci.username
					WHERE ci.custid IS NULL	
					),1,1,'')
	
	IF @invalidUserName <> '' 
	BEGIN
		SET @ErrMsg = 'Invalid UserName: ' + @invalidUserName
		SET @ErrCode = 100
		RETURN
		
	END			
		
	INSERT INTO #InputValidCustid (custid)		
	SELECT ci.custid
	FROM @InputUsernameList l
		INNER JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON l.username = ci.username
	
	DECLARE @session NVARCHAR(50) = CAST (NEWID() AS NVARCHAR(50))					
	
	CREATE TABLE #match_autovoidformula (matchid INT)
	
	INSERT INTO #match_autovoidformula (matchid)
	SELECT matchid
	FROM dbo.match m WITH (NOLOCK)
	WHERE eventdate BETWEEN @fromDate AND @todate
		AND sporttype < 99
	
	INSERT INTO #tblTransIds_autovoidformula_pre (matchid, transid)
	SELECT m.matchid, t.transid
	FROM #match_autovoidformula m
		CROSS APPLY (SELECT CASE WHEN b.bettype BETWEEN 801 AND 899 THEN b.refno ELSE b.transid END AS transid
					 FROM dbo.bettrans b WITH (NOLOCK)
					 WHERE b.matchid = m.matchid AND b.statusid = 112
							AND b.bettype NOT IN (29,9,2799)
							AND b.bettype NOT IN (911, 912, 913, 914) -- Cash-out subticket
							AND EXISTS ( SELECT TOP (1) 1 
										 FROM #InputValidCustid c 
										 WHERE c.custid IN (b.custid, b.srecommend, b.mrecommend, b.recommend)
										)
					) AS t
	GROUP BY m.matchid, t.transid
	
	INSERT INTO #tblTransIds_autovoidformula (matchid, transid)
	SELECT p.matchid, p.transid
	FROM #tblTransIds_autovoidformula_pre p
		LEFT JOIN dbo.TempVariableNumber m WITH (NOLOCK) ON p.matchid = m.KeyValue
	WHERE m.KeyID IS NULL
	GROUP BY p.matchid, p.transid
	
	SET @autoMatchList = STUFF((SELECT DISTINCT ',' + CAST(t.matchid AS VARCHAR(50))
						  FROM #tblTransIds_autovoidformula t
						  FOR XML PATH ('')
						  ),1,1,'')
	
	SET @suspendMatchList = STUFF((SELECT DISTINCT ',' + CAST(t.matchid AS VARCHAR(50))
						  FROM #tblTransIds_autovoidformula_pre t
								LEFT JOIN #tblTransIds_autovoidformula a ON t.matchid = a.matchid AND t.transid = a.transid
						  WHERE a.matchid IS NULL		
						  FOR XML PATH ('')
						  ),1,1,'')					   
	
		
	WHILE (1=1)
	BEGIN
		DELETE @tmpAutoTransIDBatch
			
		UPDATE TOP(2000) t
			SET isFinish = 1
		OUTPUT DELETED.TransId
				
		INTO @tmpAutoTransIDBatch(TransId)
		FROM #tblTransIds_autovoidformula t 
		WHERE isFinish IS NULL
		
		IF @@ROWCOUNT = 0 BREAK
		
		SELECT @TransIds = STUFF((SELECT ',' + CONVERT(VARCHAR(50), tp.transid)
										FROM @tmpAutoTransIDBatch tp
										GROUP BY TransId for XML PATH('')), 1, 1, '')
		
		BEGIN TRY
			SET @ErrMsg_tmp = ''
			
			SET @StartTime_tmp = GETDATE()
			
			EXEC dbo.TicketVoiding_AutoVoidFormulaBets_Single_Update @TransIds = @TransIds, @UserId = @UserId
															, @Username = @UserName, @IP = @IP
															, @IsAbnormalBet = 1
															, @InvalidTransIds = @InvalidTransIds OUTPUT
															, @ErrMsg = @ErrMsg_tmp OUTPUT
															, @ErrCode = @ErrCode OUTPUT;
															
			-- Write Log for trace issue later
			SET @EndTime = GETDATE()
			
			SET @LogData = CAST((SELECT	
									 90506 AS '@LogActionId'
									,@UserId AS '@UserId'
									,@IP AS '@IP'
									,'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime_tmp, @EndTime) AS VARCHAR(50)) + ' ms.' 
										+ 'TransidInput: ' + @TransIds
										+ 'Invalid Transid: ' + @InvalidTransIds
										+ 'Session:' + @session
										+ 'Err Message:' + @ErrMsg_tmp
										AS  '@LogData'
							FOR XML PATH ('r'), ROOT ('root'), TYPE
			) AS VARCHAR(MAX))
			
			EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT
	
		END TRY
		BEGIN CATCH
		
			SET @ErrMsg= @ErrMsg + @ErrMsg_tmp 
			
		END CATCH
			
		SET @TransIds = ''
		SET @InvalidTransIds = ''	 
		
	END

	-- release auto void process
	UPDATE SystemSettings SET VValue = 0
	WHERE VName = 'AutoVoidFormula'
	
	SET @EndTime = GETDATE()
			
	SET @LogData = CAST((SELECT	
							 90507 AS '@LogActionId'
							,@UserId AS '@UserId'
							,@IP AS '@IP'
							,'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms.' 
								+ 'Auto matchid: ' + @autoMatchList
								+ 'suspended matchid: ' + @suspendMatchList
								+ 'Session:' + @session
								AS  '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS VARCHAR(MAX))
	
	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT
	
	DROP TABLE #match_autovoidformula
	DROP TABLE #tblTransIds_autovoidformula
	DROP TABLE #InputValidCustid
	DROP TABLE #tblTransIds_autovoidformula_pre
	
END

GO


