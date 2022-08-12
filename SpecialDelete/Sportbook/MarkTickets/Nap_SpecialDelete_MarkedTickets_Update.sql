/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.Nap_SpecialDelete_MarkedTickets_Update 
(
	@TransIds			VARCHAR(MAX)	= NULL,
    @UserId				INT				= 0,
    @IP					VARCHAR(15)		= NULL,
	@LogActionId		INT				= 90501,
    @ErrMsg				NVARCHAR(200)	= ''	OUTPUT,
    @ErrCode			INT				= 0		OUTPUT
)
AS
/*
    Created by: Alan
	Date: 20190325
	Task: Mark Ticket for Settlement Exclusion
	DB: DBTXN/BODB02

	Explanation's Param:
		
	Revisions:
		- 20190325@Alan: - Mark Ticket for Settlement Exclusion	[108826]
		- 20190606@Raymond.Le: Mark Tickets Enhancement - Phase 4, change write log for mark/unmark [114596]
		- 20200216@Max: Abnormal Void Bets Automation - Log [Redmine: #128359]
		- 20200304@Max: Auto Void Winning Bets - [Redmine: #129184]
		- 20200323@Max: Highlight Abnormal Voiding Request [Redmine: #129639]
		- 20200415@Raymond: Mark/Unmark Parlay Tickets and remaing sports [131670]
		- 20200609@Charles: Remove notify when mark/unmark tickets [131865]
		- 20200629@Max: HotFix - Cash-Out member is not unmarked [Redmine: #136580]
		- 20210329@Max: TVS - Correct Ticket on DBTP [Redmine: #151954]
		- 20210527@July: DB Enhancement for troubleshoot & Enhance SP for Lock Process [Redmine: #155678]
		- 20210720@July: [TVS] Modify the way to get move bet date [Redmine: #154974]
		- 20210812@July: TVS - Apply new way to lock parlay tickets [Redmine: #157970]
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
			, @Session	NVARCHAR(50) = CONVERT(NVARCHAR(50),NEWID())
	SET @ID =  NEWID()
	BEGIN TRY
		IF OBJECT_ID (N'TVS_UserActionLog') IS NOT NULL 
		BEGIN		
			SET @sqlCommand = 'EXEC dbo.Nap_SpecialDelete_MarkedTickets_Update '
				+ CASE WHEN @UserId IS NULL THEN '' ELSE '@UserId = ' + CONVERT(NVARCHAR(50), @UserId) END
				+ CASE WHEN @TransIds IS NULL THEN '' ELSE ',@TransIds = ''' + CONVERT(NVARCHAR(MAX), @TransIds) + '''' END
				+ CASE WHEN @IP IS NULL THEN '' ELSE ',@IP = ''' + CONVERT(NVARCHAR(50), @IP) + '''' END
				+ CASE WHEN @LogActionId IS NULL THEN '' ELSE ',@LogActionId = ' + CONVERT(NVARCHAR(50), @LogActionId) END

			INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
			VALUES (@ID, @spName, @sqlCommand, @UserId, NULL, GETDATE(),@SubmittedDate)
		END	
	END TRY
	BEGIN CATCH
	END CATCH 

	DECLARE @xmlLog VARCHAR(MAX)
			,@LogData VARCHAR(MAX) = ''
			,@transInfo			XML

	DECLARE @ThreadHold			INT = 0 
		   ,@totalParlay		INT = 0
	       ,@SiteDBGroupID SMALLINT = 0 
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	CREATE TABLE #tblMatchParlayProcess (matchId INT, RefNo BIGINT)
	CREATE TABLE #TransIds (TransId BIGINT PRIMARY KEY); -- single + parlay tickets
	CREATE TABLE #ParlayTransIds (TransId BIGINT PRIMARY KEY);

	CREATE TABLE #MarkedTransactionDeleted (TransId BIGINT, MatchId INT)

	INSERT INTO #TransIds(TransId)
	SELECT DISTINCT value
	FROM STRING_SPLIT(@TransIds, ',')
	WHERE value <> '';

	CREATE TABLE #Tickets
				(TransId   BIGINT,
				MatchId   INT,
				CustId    INT,
				BetType   SMALLINT,
				refno	 BIGINT,
				IsParlay  BIT DEFAULT(0),
				SubTransId BIGINT,
				SiteDBGroupID SMALLINT,
				IsFinish	BIT
				);
	
	CREATE TABLE #Match(MatchId INT, IsFinish BIT);
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)

	-- Get tickets insert into transaction
	INSERT INTO #Tickets (
		TransId
		,MatchId
		,BetType
		,CustId
		,refno
		,IsParlay
		,SubTransId
		,SiteDBGroupID
		)
	SELECT t.TransId
		,b.MatchId
		,b.BetType
		,b.custid
		,b.refno
		,0
		,NULL
		,@SiteDBGroupID
	FROM #transIds t
		INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = t.transid
	WHERE  b.matchid <> 29
	AND b.SiteDBGroupID = @SiteDBGroupID

	-- get only parlay tickets from @input transid
	INSERT INTO #ParlayTransIds (TransId)
	SELECT tmp.TransId
	FROM #transIds AS tmp
	WHERE NOT EXISTS ( SELECT TOP 1 1 FROM #Tickets AS t WHERE t.TransId = tmp.TransId)

	-- get parlay tickets
	IF EXISTS (SELECT TOP 1 1 FROM #ParlayTransIds)
	BEGIN
		INSERT INTO #Tickets (
			TransId
			,MatchId
			,BetType
			,CustId
			,refno
			,IsParlay
			,SubTransId
			,SiteDBGroupID
			)
		SELECT b.transid
			,bm.matchid
			,bm.bettype
			,bm.custid
			,bm.refno
			,1
			,bm.transid
			,@SiteDBGroupID
		FROM #ParlayTransIds t
			INNER JOIN dbo.bettransm AS bm WITH (NOLOCK) ON bm.transid = t.TransId
			INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON b.refno = bm.refno AND b.matchid = 29
		WHERE b.SiteDBGroupID = @SiteDBGroupID AND bm.SiteDBGroupID = @SiteDBGroupID
	END
	--check no data
	IF NOT EXISTS( SELECT TOP (1) 1 FROM #Tickets)
	BEGIN
		RETURN;
	END;

	-- Check Lock Match
	DECLARE @avaiableProcess BIT
		,@IsExistSingle BIT = 0
		,@IsExistParlay BIT = 0
		,@IsExistFM BIT = 0
		,@IsExistFM2 BIT = 0

	SELECT @IsExistSingle = MAX(CASE WHEN f.GroupId IS NULL THEN 1 ELSE 0	END)
			,@IsExistFM = MAX(CASE WHEN f.GroupId = 1 THEN 1 ELSE 0 END)
			,@IsExistFM2 = MAX(CASE WHEN f.GroupId = 2 THEN 1 ELSE 0 END)
	FROM #Tickets AS t
		OUTER APPLY (
				SELECT GroupId
				FROM dbo.f_TVS_CheckingProcessGroupBettypes()
				WHERE Bettype = t.Bettype
		)f
	WHERE t.IsParlay = 0

	EXEC dbo.NAP_Set_GlobalSettingSel 
			@LockName = 'ParlayRefno'
		   ,@ThreadHold = @ThreadHold OUTPUT

	INSERT INTO #tblMatchParlayProcess ( matchId, RefNo)
	SELECT 0, t.refno  --Many matches with same Refno  
	FROM #Tickets AS t
	WHERE t.IsParlay = 1
	GROUP BY t.Refno  
	HAVING COUNT(*) > 1
	SET @totalParlay = @@ROWCOUNT

	INSERT INTO #tblMatchParlayProcess ( matchId, RefNo)
	SELECT t.MatchId, t.refno
	FROM #Tickets AS t
	WHERE t.IsParlay = 1 AND NOT EXISTS (SELECT 1 FROM #tblMatchParlayProcess m WHERE m.RefNo = t.refno) 

	SELECT  @totalParlay = @totalParlay + @@ROWCOUNT
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
					@isExistMatch = @IsExistSingle,
					@IsExistFM = @IsExistFM,
					@IsExistFM2 = @IsExistFM2,
					@IsReleased = 1;
				RETURN;	
			END
		END

	END
	ELSE IF @totalParlay > @ThreadHold
	BEGIN
		-- checking SD proccess
		EXEC dbo.NAP_Admin_CheckingProcess 
				@isExistMatch = @IsExistSingle
			   ,@isExistParlay = @IsExistParlay
			   ,@IsExistFM = @IsExistFM
			   ,@IsExistFM2 = @IsExistFM2
			   ,@spName = @spName
			   ,@avaiableProcess = @avaiableProcess OUTPUT
			   ,@ErrCode = @ErrCode OUTPUT
			   ,@ErrMsg = @ErrMsg OUTPUT;

		IF (@ErrCode <> 0 OR @avaiableProcess = 0)
		BEGIN
			RETURN;
		END
	END

	-- Delete Transaction
	DECLARE @TransIds_SB VARCHAR(MAX)
	WHILE (0=0)
	BEGIN
		DELETE #MarkedTransactionDeleted

		UPDATE TOP (2000) t
			SET t.IsFinish = 1
		OUTPUT DELETED.TransId
			,DELETED.MatchId
		INTO #MarkedTransactionDeleted (TransId, MatchId)
		FROM #Tickets t
		WHERE t.IsFinish IS NULL 

		IF @@ROWCOUNT = 0 BREAK	

		SELECT @TransIds_SB = CAST((
									SELECT m.TransId AS '@id'
										,m.MatchId AS '@match'
									FROM #MarkedTransactionDeleted m
									FOR XML PATH('r')
										,ROOT('root')
										,TYPE
								) AS VARCHAR(MAX));

		EXEC dbo.TicketVoiding_Admin_VoidingTransId
			@TransIds = @TransIds_SB,
			@UserId = @UserId,
			@CalledByBrokerService = 0,
			@IsUseServiceBroker = 1,
			@ActionType = 2
		
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

	INSERT INTO #Match (MatchId)
	SELECT DISTINCT MatchId
	FROM #Tickets

	-- Write Log
	SET @xmlLog = CAST((
				SELECT @LogActionId AS '@LogActionId' 
					,@UserId AS '@UserId'
					,@IP AS '@IP'
					,m.matchid AS '@MatchId'
					,STUFF((
							SELECT ',' + CAST(d.TransId AS NVARCHAR(100))
							FROM #Tickets AS d
							WHERE d.MatchId = m.MatchId AND d.SiteDBGroupID = @SiteDBGroupID
							FOR XML PATH('')
							), 1, 1, '')  AS '@LogData'
				FROM #Match AS m
				FOR XML PATH('r')
					,ROOT('root')
					,TYPE
				) AS VARCHAR(MAX));

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @xmlLog, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log';

	DELETE b
	FROM #Match b
		INNER JOIN dbo.MarkedTransaction m WITH (NOLOCK) ON b.MatchId = m.MatchId;

	-- Return matches don't have marked ticket ??
	SELECT b.MatchId,
		m.HomeId,
		m.AwayId,
		m.SportType,
		m.IsNeutral
	FROM #Match b
		LEFT JOIN dbo.match m WITH (NOLOCK) ON b.MatchId = m.MatchId;
	
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

	DROP TABLE #Tickets
	DROP TABLE #TransIds;
	DROP TABLE #Match;
	DROP TABLE #MarkedTransactionDeleted;
	DROP TABLE #ParlayTransIds
	DROP TABLE #tblMatchProcess
	DROP TABLE #tblMatchParlayProcess

	SET NOCOUNT OFF;
END