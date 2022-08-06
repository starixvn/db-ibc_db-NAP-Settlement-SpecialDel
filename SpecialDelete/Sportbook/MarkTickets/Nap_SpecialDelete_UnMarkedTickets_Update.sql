/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.Nap_SpecialDelete_UnMarkedTickets_Update 
(	
		@TransIds        VARCHAR(MAX)  = NULL,
        @UserId          INT           = 0,
        @IP              VARCHAR(15)   = NULL,
        @MarkType		 TINYINT	   = 0,
		@LogActionId	 INT		   = 90500,
		@TransInfo       XML  = NULL,
		@IssueTypeId     INT           = NULL,
        @ErrMsg          NVARCHAR(200) = '' OUTPUT,
        @ErrCode         INT           = 0 OUTPUT
)
AS
/*
    Created by: Alan
	Date: 20190325
	Task: Mark Ticket for Settlement Exclusion
	DB: DBTXN/BODB02

	Explanation's Param:
		
	Revisions:
		- 20190325@Alan: - Mark Ticket for Settlement Exclusion [108826]
		- 20190606@Raymond.Le: Mark Tickets Enhancement - Phase 4, change write log for mark/unmark [114596]
		- 20200216@Max: Abnormal Void Bets Automation - Log [Redmine: #128359]
		- 20200225@Helen:[TVS] Auto Void winning bet [Redmine:#128836]
		- 20200323@Max: Highlight Abnormal Voiding Request [Redmine: #129639]
		- 20200415@Raymond: Mark/Unmark Parlay Tickets and remaing sports [131670]
		- 20200609@Charles: Remove notify when mark/unmark tickets [131865]
		- 20200817@Max: Add Mark/Unmark process to servicebroker [Redmine: #139340]
		- 20201007@Max: Integrate new bet type Time Machine OU [Redmine: #143032]
		- 20201130@July: TVS - Check lock match before add request [Redmine: #143666]
		- 20210527@July: DB Enhancement for troubleshoot & Enhance SP for Lock Process [Redmine: #155678]
		- 20210720@July: [TVS] Modify the way to get move bet date [Redmine: #154974]
		- 20210801@July: TVS - Apply new way to lock parlay tickets [Redmine: #157970]
		- 20211117@July: TVS - Abnormal Bet - Void Mix Parlay Ticket [Redmine: #161337]
		- 20211210@July: Remove code CashOut [Redmine: #165097]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220808@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
*/
BEGIN
     SET NOCOUNT ON;

	-- Write useraction log 
	DECLARE @sqlCommand NVARCHAR(MAX), @ID UNIQUEIDENTIFIER
			, @SubmittedDate DATETIME = GETDATE()
			, @spName VARCHAR(500) = OBJECT_NAME(@@PROCID)
			, @Session NVARCHAR(50) = CONVERT(NVARCHAR(50),NEWID())
	SET @ID =  NEWID()
	BEGIN TRY
		IF OBJECT_ID (N'TVS_UserActionLog') IS NOT NULL 
		BEGIN		
			SET @sqlCommand = 'EXEC dbo.Nap_SpecialDelete_UnMarkedTickets_Update '
				+ CASE WHEN @UserID IS NULL THEN '' ELSE '@UserID = ' + CONVERT(NVARCHAR(50), @UserID) END
				+ CASE WHEN @TransIds IS NULL THEN '' ELSE ',@TransIds = ''' + CONVERT(NVARCHAR(MAX), @TransIds) + '''' END
				+ CASE WHEN @IP IS NULL THEN '' ELSE ',@IP = ''' + CONVERT(NVARCHAR(50), @IP) + '''' END
				+ CASE WHEN @MarkType IS NULL THEN '' ELSE ',@MarkType = ' + CONVERT(NVARCHAR(50), @MarkType) END 
				+ CASE WHEN @LogActionId IS NULL THEN '' ELSE ',@LogActionId = ' + CONVERT(NVARCHAR(50), @LogActionId) END
				+ CASE WHEN @TransInfo IS NULL THEN '' ELSE ',@TransInfo = ' + CONVERT(NVARCHAR(MAX), @TransInfo) END
				+ CASE WHEN @IssueTypeId IS NULL THEN '' ELSE ',@IssueTypeId = ' + CONVERT(NVARCHAR(50), @IssueTypeId) END

			INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
			VALUES (@ID, @spName, @sqlCommand, @UserId, NULL, GETDATE(),@SubmittedDate)
		END	
	END TRY
	BEGIN CATCH
	END CATCH 

	DECLARE @xmlLog VARCHAR(MAX)
		   ,@LogData VARCHAR(MAX) = ''
		   ,@ThreadHold	INT = 0 
		   ,@totalParlay INT = 0
           ,@IsCentral	BIT, @IsSiteDB BIT

	EXEC dbo.NAP_Set_ServerInfo @IsCentral = @IsCentral OUTPUT

	CREATE TABLE #transIds  (TransId BIGINT PRIMARY KEY );     -- single + sub parlay Id
	INSERT INTO #transIds(TransId)
	SELECT DISTINCT value
	FROM STRING_SPLIT(@TransIds, ',')
	WHERE value <> '';

	CREATE TABLE #ParlayTransIds (TransId BIGINT PRIMARY KEY);
	CREATE TABLE #tblMatchParlayProcess (matchId INT, RefNo BIGINT)
	CREATE TABLE #Match(matchid INT);
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT);

	CREATE TABLE #Tickets
				(TransId   BIGINT,
				MatchId   INT,
				CustId    INT,
				BetType   SMALLINT,
				RefCode   BIGINT,
				refno	 BIGINT,
				IsParlay  BIT DEFAULT(0),
				SubTransId BIGINT,
				IsFinish	BIT
				);
	CREATE INDEX IX_Tickets_RefCode ON #Tickets(RefCode);
	CREATE TABLE #tmpTransInfo(
		matchid INT
		,transid BIGINT PRIMARY KEY
		,Subtransid BIGINT
		,custid INT	
		,refno BIGINT
		,bettype SMALLINT
		,statusID TINYINT
		,Subcustid INT
		,Subbettype SMALLINT
		,IsMixParlay BIT
		,SiteDBGroupID SMALLINT
	)
	IF @TransIds IS NOT NULL
	BEGIN
		-- Get tickets insert into transaction
		INSERT INTO #Tickets (
				TransId
				,MatchId
				,BetType
				,CustId
				,RefCode
				,refno
				,IsParlay
				,SubTransId
		)
		SELECT t.TransId,
			   b.MatchId
			  ,b.BetType
			  ,b.custid
			  ,b.RefCode
			  ,b.refno
			  ,0
			  ,NULL
		FROM #transIds t
		INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = t.transid
		LEFT JOIN dbo.MarkedTransaction m WITH (NOLOCK) ON m.TransId = t.TransId AND b.matchid = m.matchid --check case mark same ticket main & sub-match
		WHERE m.TransId IS NULL AND b.matchid <> 29 
		AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
	
		-- get only parlay tickets from @input transid
		INSERT INTO #ParlayTransIds (TransId)
		SELECT tmp.TransId
		FROM #transIds AS tmp
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #Tickets AS t WHERE t.TransId = tmp.TransId)

		-- check if exists parlay tickets
		IF EXISTS (SELECT TOP 1 1 FROM #ParlayTransIds)
		BEGIN
			INSERT INTO #Tickets (
				TransId
				,MatchId
				,BetType
				,CustId
				,RefCode
				,refno
				,IsParlay
				,SubTransId
			)
			SELECT b.TransId
				,bm.matchid
				,bm.bettype
				,bm.custid
				,NULL
				,bm.refno
				,1
				,bm.transid
			FROM #ParlayTransIds t
				INNER JOIN dbo.bettransm AS bm WITH (NOLOCK) ON bm.transid = t.TransId
				INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON b.refno = bm.refno AND b.matchid = 29
				LEFT JOIN dbo.MarkedTransaction AS m WITH (NOLOCK) ON m.TransId = b.TransId AND m.MatchId = bm.matchid
			WHERE m.TransId IS NULL
				AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
				AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
		END

		--check no data
		IF NOT EXISTS( SELECT TOP (1) 1 FROM #Tickets)
		BEGIN
			SELECT @ErrCode = 99, @ErrMsg = 'No ticket found.';
			RETURN;
		END;
	END

	IF @TransInfo IS NOT NULL 
	BEGIN
		INSERT INTO #tmpTransInfo( 
			   matchid
			  ,transid 
			  ,Subtransid
			  ,refno
			  ,custid		
			  ,bettype
			  ,statusID
			  ,Subcustid
			  ,Subbettype
			  ,IsMixParlay
			  ,SiteDBGroupID
			)
		SELECT t.c.value('@mid','INT') AS matchid
				,t.c.value('@t','BIGINT') AS transid
				,t.c.value('@s_t','BIGINT') AS Subtransid
				,t.c.value('@ref','BIGINT') AS refno
				,t.c.value('@c','INT') AS custid
				,t.c.value('@btype','SMALLINT') AS bettype
				,t.c.value('@sid','TINYINT') AS statusID
				,t.c.value('@s_c','INT') AS Subcustid
				,t.c.value('@s_btype','SMALLINT') AS Subbettype
				,t.c.value('@isP','BIT') AS IsMixParlay
				,t.c.value('@sitedb','SMALLINT') AS SiteDBGroupID
		FROM @TransInfo.nodes('root/r') t(c)
		OPTION (OPTIMIZE FOR (@TransInfo = NULL))

		INSERT INTO #Tickets (
			TransId
			,MatchId
			,BetType
			,CustId
			,RefCode
			,refno
			,IsParlay
			,SubTransId
		)
		SELECT TransId
		  ,b.MatchId
		  ,b.BetType
		  ,b.custid
		  ,NULL
		  ,b.refno
		  ,0
		  ,NULL
		FROM #tmpTransInfo b
		WHERE IsMixParlay = 0 AND b.statusID IN (0,1) 
		AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
		AND 1 = CASE WHEN @IssueTypeId = 13 AND b.bettype NOT IN (9,29,10) THEN 1  --Abnormal account :not mark parlay,outright
					 WHEN ISNULL(@IssueTypeId,0) <> 13 THEN 1 
					 ELSE 0 END 
		AND NOT EXISTS (SELECT TOP 1 1 FROM dbo.MarkedTransaction mt WITH(NOLOCK) WHERE mt.TransId = b.transid)

		INSERT INTO #Tickets (
			TransId
			,MatchId
			,BetType
			,CustId
			,RefCode
			,refno
			,IsParlay
			,SubTransId
		)
		SELECT b.TransId
			,b.matchid
			,b.Subbettype
			,b.Subcustid
			,NULL
			,b.refno
			,1
			,b.Subtransid
		FROM #tmpTransInfo b
		WHERE IsMixParlay = 1
		AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
		AND NOT EXISTS (SELECT TOP 1 1 FROM dbo.MarkedTransaction mt WITH(NOLOCK) WHERE mt.TransId = b.transid)
	END
	
	-- Check Lock Match
	DECLARE @avaiableProcess	BIT
		   ,@IsExistSingle		BIT = 0
		   ,@IsExistParlay		BIT = 0
		   ,@IsExistFM			BIT = 0
		   ,@IsExistFM2			BIT = 0;

	SELECT @IsExistSingle = MAX(CASE WHEN f.GroupId IS NULL THEN 1 ELSE 0	END)
			,@IsExistFM = MAX(CASE WHEN f.GroupId = 1 THEN 1 ELSE 0 END)
			,@IsExistFM2 = MAX(CASE WHEN f.GroupId = 2 THEN 1 ELSE 0 END)
	FROM #Tickets AS t
		OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = t.Bettype
			)f
	WHERE t.IsParlay = 0;

	EXEC dbo.NAP_Set_GlobalSettingSel 
			@LockName = 'ParlayRefno'
		   ,@ThreadHold = @ThreadHold OUTPUT

	INSERT INTO #tblMatchParlayProcess ( matchId, RefNo)
	SELECT t.MatchId, t.refno
	FROM #Tickets AS t
	WHERE t.IsParlay = 1

	SET @totalParlay = @@ROWCOUNT
	IF @totalParlay > 0 
		SET @isExistParlay = 1

	INSERT INTO #tblMatchProcess (MatchId, KeyID)
	SELECT DISTINCT MatchId
		,CASE 
			WHEN f.GroupId IS NULL THEN 1 --SB
			WHEN f.GroupId = 1 THEN 6 -- Fast Market
			WHEN f.GroupId = 2 THEN 7 -- Fast market 228
			ELSE 0
			END AS KeyID
	FROM #Tickets t
		OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = t.Bettype
			)f
	WHERE 1 = CASE WHEN @totalParlay <= @ThreadHold AND t.IsParlay <> 1 THEN 1
				    WHEN @totalParlay > @ThreadHold THEN 1
				    ELSE 0 END
		
	-- Apply new way to lock parlay tickets
	IF @totalParlay = 0 OR @totalParlay <= @ThreadHold
	BEGIN
		DELETE FROM #tblMatchProcess WHERE KeyID = 0
		IF EXISTS (SELECT TOP 1 1 FROM #tblMatchProcess)
		BEGIN
			-- checking single proccess
			EXEC dbo.NAP_Admin_CheckingProcess 
					@isExistMatch = @IsExistSingle
				   ,@IsExistFM = @IsExistFM
				   ,@IsExistFM2 = @IsExistFM2
				   ,@spName = @spName
				   ,@avaiableProcess = @avaiableProcess OUTPUT
				   ,@ErrCode = @ErrCode OUTPUT
				   ,@ErrMsg = @ErrMsg OUTPUT;

			IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
			BEGIN	
				RETURN;		
			END
		END

		IF @totalParlay > 0 
		BEGIN
			-- checking Refno parlay proccess
			EXEC dbo.NAP_Admin_CheckingProcess
					@IsLockingByRefno	= 1
				   ,@spName				= @spName
				   ,@Session			= @Session
				   ,@avaiableProcess 	= @avaiableProcess OUTPUT
				   ,@ErrCode			= @ErrCode OUTPUT
				   ,@ErrMsg				= @ErrMsg OUTPUT
				
			IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
			BEGIN	
				-- releasing single process
				EXEC dbo.NAP_Admin_CheckingProcess
					@isExistMatch	= @IsExistSingle,
					@IsExistFM		= @IsExistFM,
					@IsExistFM2		= @IsExistFM2,
					@IsReleased		= 1;
				RETURN;		
			END

		END
	END
	ELSE IF @totalParlay > @ThreadHold
	BEGIN
		-- checking SD proccess
		EXEC dbo.NAP_Admin_CheckingProcess 
				@isExistMatch		= @IsExistSingle
			   ,@isExistParlay		= @IsExistParlay
			   ,@IsExistFM			= @IsExistFM
			   ,@IsExistFM2			= @IsExistFM2
			   ,@spName				= @spName
			   ,@avaiableProcess	= @avaiableProcess OUTPUT
			   ,@ErrCode			= @ErrCode OUTPUT
			   ,@ErrMsg				= @ErrMsg OUTPUT

		IF (@ErrCode <> 0 OR @avaiableProcess = 0)
		BEGIN
			RETURN;
		END;
	END

	INSERT INTO #Match (matchid)
	SELECT DISTINCT MatchId
	FROM #Tickets;
    
	-- Insert Transaction
	DECLARE @TransIds_SB VARCHAR(MAX)
	DECLARE @MarkedTransactionDeleted TABLE (TransId BIGINT, MatchId INT, BetType SMALLINT, CustId INT);
	WHILE (0=0)
	BEGIN
		DELETE @MarkedTransactionDeleted
		UPDATE TOP (2000) t
			SET t.IsFinish = 1
		OUTPUT DELETED.TransId
			,DELETED.MatchId
			,DELETED.BetType
			,DELETED.CustId
		INTO @MarkedTransactionDeleted (TransId, MatchId, BetType, CustId)
		FROM #Tickets t
		WHERE t.IsFinish IS NULL

		IF @@ROWCOUNT = 0 BREAK	

		SELECT @TransIds_SB = CAST((
									SELECT t.TransId AS '@id'
										,t.MatchId AS '@match'
										,t.BetType AS '@bettype'
										,t.CustId AS '@cust'
										,@MarkType AS '@type'
									FROM @MarkedTransactionDeleted t
									FOR XML PATH('r')
										,ROOT('root')
										,TYPE
								) AS VARCHAR(MAX));
	
		EXEC dbo.TicketVoiding_Admin_VoidingTransId
			@TransIds = @TransIds_SB,
			@UserId = @UserId,
			@CalledByBrokerService = 0,
			@IsUseServiceBroker = 1,
			@ActionType = 1

		SET @TransIds_SB = ''
	END

	IF @totalParlay = 0 OR @totalParlay <= @ThreadHold
	BEGIN
		IF EXISTS (SELECT TOP 1 1 FROM #tblMatchProcess)
		BEGIN
			-- releasing single process
			EXEC dbo.NAP_Admin_CheckingProcess
				@isExistMatch = @IsExistSingle,
				@IsExistFM = @IsExistFM,
				@IsExistFM2 = @IsExistFM2,
				@IsReleased = 1;
		END

		IF @totalParlay > 0 
		BEGIN
			-- releasing Refno parlay proccess
			EXEC dbo.NAP_Admin_CheckingProcess
				@IsLockingByRefno = 1
				,@Session	= @Session
				,@IsReleased = 1
		END
	END
	ELSE IF @totalParlay > @ThreadHold
	BEGIN
		-- Release Match
		EXEC dbo.NAP_Admin_CheckingProcess
			@isExistMatch = @IsExistSingle,
			@isExistParlay = @IsExistParlay,
			@IsExistFM = @IsExistFM,
			@IsExistFM2 = @IsExistFM2,
			@IsReleased = 1;
	END

	SELECT b.MatchId,
		m.HomeId,
		m.AwayId,
		m.SportType,
		m.IsNeutral
	FROM #Match b
		LEFT JOIN dbo.match m WITH (NOLOCK) ON b.MatchId = m.MatchId;

	IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL 
	BEGIN
		SET @IsSiteDB = 1

		INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfo)
		SELECT 'TVS', 'Mark', 'MarkedTransaction', 'I', m.MatchId
						, STUFF((SELECT ',' + CAST(d.TransId AS NVARCHAR(100))
							FROM #Tickets AS d
							WHERE d.MatchId = m.MatchId
							FOR XML PATH('')
							), 1, 1, '')
		FROM #Match m
	END

	-- Write Log
	SET @xmlLog = CAST((
			SELECT @LogActionId AS '@LogActionId' -- 90500: Action Mark, 90508: Mark by add request, 90509: Mark by auto void system
				,@UserId AS '@UserId'
				,@IP AS '@IP'
				,m.matchid AS '@MatchId'
				,STUFF((
						SELECT ',' + CAST(t.TransId AS NVARCHAR(100))
						FROM #Tickets AS t
						WHERE t.MatchId = m.MatchId
						FOR XML PATH('')
						), 1, 1, '')  AS '@LogData'
			FROM #Match AS m
			FOR XML PATH('r')
				,ROOT('root')
				,TYPE
			) AS VARCHAR(MAX));

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @xmlLog, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log';

	-- Write useraction log	
	BEGIN TRY
        IF OBJECT_ID (N'TVS_UserActionLog') IS NOT NULL 
		BEGIN	      
            INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
            VALUES (@ID, @spName, NULL, @UserId, NULL, GETDATE(),@SubmittedDate)
        END       
	END TRY
	BEGIN CATCH
	END CATCH

	DROP TABLE #Tickets;
	DROP TABLE #transIds;
	DROP TABLE #Match;
	DROP TABLE #ParlayTransIds;
	DROP TABLE #tblMatchProcess
	DROP TABLE #tblMatchParlayProcess
	DROP TABLE #tmpTransInfo

	SET NOCOUNT OFF;
END