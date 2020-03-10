/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_AutoVoidFormulaBets_Single]
(	
	@SMAList			VARCHAR(MAX) = ''
	,@eventdate			DATETIME
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
		- 20200309@Helen: Tuning [Redmine:#129971]
		
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
	
	DECLARE @InputUsernameList AS TABLE (username NVARCHAR(50))
	DECLARE @tmpAutoTransIDBatch TABLE (TransId	BIGINT)
	
	CREATE TABLE #tblTransIds_autovoidformula_pre (matchid INT, transid BIGINT)
	CREATE TABLE #tblTransIds_autovoidformula (matchid INT, transid BIGINT, Isfinish BIT )
	CREATE TABLE #InputValidCustid_tmp  (custid INT, roleid TINYINT)
	CREATE TABLE #InputValidCustid_1 (custid INT)
	CREATE TABLE #InputValidCustid_2_pre (custid INT)
	CREATE TABLE #InputValidCustid_2 (custid INT)
	CREATE TABLE #match_autovoidformula (matchid INT)
	CREATE TABLE #match_autotemp (matchid INT)
	
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
			, @recommend_cnt	INT = 0
			, @custid_cnt		INT = 0
			
	INSERT INTO @InputUsernameList (username)
	SELECT DISTINCT f.val
	FROM dbo.f_SplitString (@SMAList, ',') AS f
	OPTION (maxrecursion 0)	
	
	SET @invalidUserName = STUFF((SELECT  ',' + l.username
					FROM @InputUsernameList l
						LEFT JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON l.username = ci.username
					WHERE ci.custid IS NULL	
					FOR XML PATH ('')
					),1,1,'')
	
	IF @invalidUserName <> '' 
	BEGIN
		SET @ErrMsg = 'Invalid UserName: ' + @invalidUserName
		SET @ErrCode = 100
	
		RETURN
		
	END		
		
	INSERT INTO #InputValidCustid_tmp (custid, roleid)		
	SELECT ci.custid, ci.roleid
	FROM @InputUsernameList l
		INNER JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON l.username = ci.username
	
	INSERT INTO #InputValidCustid_2_pre (custid)		
	SELECT l.custid
	FROM #InputValidCustid_tmp l
	WHERE l.roleid = 2	
	
	IF EXISTS (SELECT TOP 1 1 FROM #InputValidCustid_tmp WHERE roleid = 3)
	BEGIN
		INSERT INTO #InputValidCustid_2_pre (custid)	
		SELECT ci.custid
		FROM #InputValidCustid_tmp l
			INNER JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON l.custid = ci.mrecommend
		WHERE l.roleid = 3 AND ci.roleid = 2
		
	END
	IF EXISTS (SELECT TOP 1 1 FROM #InputValidCustid_tmp WHERE roleid = 4)
	BEGIN
		INSERT INTO #InputValidCustid_2_pre (custid)
		SELECT ci.custid
		FROM #InputValidCustid_tmp l
			INNER JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON l.custid = ci.srecommend
		WHERE l.roleid = 4 AND ci.roleid = 2	
		
	END
	--list of recommend to process
	INSERT INTO #InputValidCustid_2
	SELECT custid
	FROM #InputValidCustid_2_pre
	GROUP BY custid
	
	SET @recommend_cnt = (SELECT COUNT(1) FROM #InputValidCustid_2)
	
	IF @recommend_cnt > 5000
	BEGIN
		SET @ErrMsg = 'Sorry, Can not process this due to serveral customers. Please contact with IT administrator to be supported.'
		SET @ErrCode = 100
	
		RETURN
	END
	-- list of member to process
	INSERT INTO #InputValidCustid_1 (custid)		
	SELECT l.custid
	FROM #InputValidCustid_tmp l
		INNER JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON l.custid = ci.custid
		LEFT JOIN #InputValidCustid_2 lt ON lt.custid = ci.recommend
	WHERE l.roleid = 1 AND lt.custid IS NULL
	
	SET @custid_cnt = (SELECT COUNT(1) FROM #InputValidCustid_1)
	
	IF @custid_cnt > 5000
	BEGIN
		SET @ErrMsg = 'Sorry, Can not process this due to serveral customers. Please contact with IT administrator to be supported.'
		SET @ErrCode = 100
	
		RETURN
	END
	
	INSERT INTO #match_autovoidformula (matchid)
	SELECT matchid
	FROM dbo.match m WITH (NOLOCK)
	WHERE eventdate = @eventdate
		AND sporttype < 99
	
	IF EXISTS (SELECT TOP 1 1 FROM #InputValidCustid_2)
	BEGIN
		INSERT INTO #tblTransIds_autovoidformula_pre (matchid, transid)
		SELECT b.matchid, CASE WHEN b.bettype BETWEEN 801 AND 899 THEN b.refno ELSE b.transid END AS transid
		FROM #InputValidCustid_2  rt 
			INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.recommend = rt.custid
			INNER JOIN #match_autovoidformula m ON m.matchid = b.matchid
		WHERE b.winlostdate = @eventdate	 
			AND b.bettype NOT IN (29,9,2799)
			AND b.bettype NOT IN (911, 912, 913, 914)
			AND b.statusid = 112
			
	END
	IF EXISTS (SELECT TOP (1) 1 FROM #InputValidCustid_1)
	BEGIN
		INSERT INTO #tblTransIds_autovoidformula_pre (matchid, transid)
		SELECT b.matchid, CASE WHEN b.bettype BETWEEN 801 AND 899 THEN b.refno ELSE b.transid END AS transid
		FROM #InputValidCustid_1  rt 
			INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.custid = rt.custid
			INNER JOIN #match_autovoidformula m ON m.matchid = b.matchid
		WHERE b.winlostdate = @eventdate	 
			AND b.bettype NOT IN (29,9,2799)
			AND b.bettype NOT IN (911, 912, 913, 914)
			AND b.statusid = 112
	END
	
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
	
	DECLARE @session NVARCHAR(50) = CAST (NEWID() AS NVARCHAR(50))
	-- Lock auto void process
	UPDATE SystemSettings SET VValue = 1
	WHERE VName = 'AutoVoidFormula'
		
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
															, @IP = @IP
															, @IsAbnormalBet = 1
															, @InvalidTransIds = @InvalidTransIds OUTPUT
															, @ErrMsg = @ErrMsg_tmp OUTPUT
															, @ErrCode = @ErrCode OUTPUT;
															
			-- Write Log for trace issue later
			SET @EndTime = GETDATE()
			
			SET @LogData = ''
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
	SET @LogData = ''		
	SET @LogData = CAST((SELECT	
							 90507 AS '@LogActionId'
							,@UserId AS '@UserId'
							,@IP AS '@IP'
							,'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms.' 
								+ 'Auto matchid: ' + ISNULL(@autoMatchList,' N/A')
								+ 'suspended matchid: ' + ISNULL(@suspendMatchList,' N/A')
								+ 'Session:' + @session
								AS  '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS VARCHAR(MAX))
	
	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT
	
	DROP TABLE #match_autovoidformula
	DROP TABLE #tblTransIds_autovoidformula
	DROP TABLE #tblTransIds_autovoidformula_pre
	DROP TABLE #InputValidCustid_1
	DROP TABLE #InputValidCustid_2
	DROP TABLE #InputValidCustid_tmp
	DROP TABLE #match_autotemp
	DROP TABLE #InputValidCustid_2_pre
	
END

GO


