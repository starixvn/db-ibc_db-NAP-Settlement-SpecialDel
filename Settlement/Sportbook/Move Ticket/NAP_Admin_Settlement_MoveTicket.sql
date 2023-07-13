/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Admin_Settlement_MoveTicket
	 @MatchId	INT
	,@DestinationMatchId INT = 0
	,@IsOverrideResult BIT = 0
	,@AdminId	INT
	,@IP		VARCHAR(50) = ''
	,@ErrCode	INT = 0 OUTPUT
	,@ErrMsg	VARCHAR(300) = '' OUTPUT
AS
/*	
	Creator: Louisa
	Date: 20210930
	Task: Move ticket
	DB: DBTXN/bodb02

	Revisions:
		- 20210930@Louisa: Move running single tickets for E-Sports [Redmine:#159271]
		- 20220513@Louisa: Change write log from exec dbo.WriteLog_UserLog  to exec LogDB.dbo.Logfile_V2 [Redmine:#172708]	
		- 20220719@Louisa: Scale out DBTRANS [Redmine:#175251]
		- 20230214@Aries: Use Service Broker to Write Log to DB Log [Redmine: #187252]
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @remoteQuery	NVARCHAR(MAX) = ''				
			,@logData		VARCHAR(500) = ''
			,@Action		VARCHAR(20) = 'MoveTicket'
			,@Mode			VARCHAR(15) = 'SingleRunning'
			,@ActionID		INT = 81035
			,@totalTicket	INT
			,@batch			INT = 1000
			,@rowId			INT
			,@avaiableProcess BIT
			,@strTransIds	VARCHAR(MAX) = ''
			,@NewAccumTurnover MONEY
			,@NewMatchCode	NVARCHAR(100)
			,@IsCentral		BIT = 0
	
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	DECLARE @tmpCustLimit TABLE ( CustID INT, AccumTurnover MONEY, AccumPayout MONEY, SiteType TINYINT )

	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	CREATE TABLE #tmpTransIds	( RowId INT IDENTITY(1,1) PRIMARY KEY, custid INT, transid BIGINT, oddsid INT,  bettype SMALLINT, BetId INT, liveindicator BIT, StatusId TINYINT, srecommend INT )
	CREATE TABLE #tmpNewOdds	( oddsid INT, bettype SMALLINT, liveindicator BIT, ResourceId VARCHAR(20) )
	
	INSERT INTO #tblMatchProcess(matchid, KeyID)
	VALUES (@MatchId, 1)
		 ,(@DestinationMatchId, 1)

	EXEC dbo.NAP_Admin_CheckingProcess		
	@isExistMatch		= 1		
	, @avaiableProcess 	= @avaiableProcess OUTPUT
	, @ErrCode			= @ErrCode OUTPUT
	, @ErrMsg			= @ErrMsg OUTPUT

	IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
	RETURN

	INSERT INTO #tmpTransIds ( custid, transid, oddsid,  bettype, BetId, liveindicator, StatusId, srecommend )
	SELECT b.custid, b.transid, b.oddsid,  b.bettype, b.BetId, b.liveindicator, b.statusID, b.srecommend
	FROM dbo.bettrans b WITH(NOLOCK)
		LEFT JOIN dbo.MarkedTransaction mk WITH(NOLOCK)
			ON b.transid = mk.TransId
	WHERE b.matchid = @MatchId
		AND b.statusID = 0
		AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
		AND mk.TransId IS NULL

	SET @remoteQuery = 'SELECT oddsid, bettype, liveindicator, ResourceId 
						FROM DBPRO.bodb02.dbo.OddsES o WITH(NOLOCK)
						WHERE o.matchid = ' + CAST (@DestinationMatchId AS NVARCHAR(20) )
						+' AND ISNULL(o.IsDeleted,0) = 0 '
		
	INSERT INTO #tmpNewOdds ( oddsid, bettype, liveindicator, ResourceId )
	EXEC sys.sp_executesql @remoteQuery
	
	--backup old info before moving: this table can be removed after data stable
	IF EXISTS (SELECT TOP 1 1 FROM sys.tables WHERE name = 'SettlementMoveTicketHistoryTemp' )
	BEGIN
		INSERT INTO dbo.SettlementMoveTicketHistoryTemp ( matchid, transid, oddsid, CreatedBy, CreatedDate )
		SELECT @MatchId, tmp.transid, tmp.oddsid, @AdminId AS CreatedBy, GETDATE() AS CreatedDate
		FROM #tmpTransIds tmp
	END

	--Start: Move single ticket
	UPDATE tr
	SET oddsid = o.oddsid
	FROM #tmpTransIds tr
	INNER JOIN #tmpNewOdds o
		ON tr.bettype = o.bettype
		AND tr.liveindicator = o.liveindicator
		AND ( tr.BetId = 0 OR CHARINDEX(o.ResourceId, CAST(tr.betid AS VARCHAR(20) )) > 0 )

	SET @rowId = 1

	WHILE ( 1 = 1)
	BEGIN

		SET @strTransIds = (
			SELECT	TOP (@batch) 
					tr.transid AS '@t'
					,tr.oddsid AS '@o'
			FROM	#tmpTransIds tr
			WHERE	tr.RowId >= @rowId AND tr.RowId < @rowId + @batch 
			FOR XML PATH('r'), ROOT('root'))

		IF ISNULL(@strTransIds,'')  = ''
			BREAK

		EXEC dbo.NAP_Admin_Calculate_Main
			@matchid = @DestinationMatchId
			,@Action = @Action
			,@Mode   = @Mode
			,@strTransIds = @strTransIds

		SET @rowId = @rowId + @batch

	END
	--End/ Move single ticket


			 
	--Start: Update MaxPayout
	--ESports hasn's PayoutAdjust, AccumPayout, not support Deposite

	DELETE tr
	FROM #tmpTransIds tr
		INNER JOIN CustDB.dbo.Dep_CustSuper cus WITH(NOLOCK)
			ON tr.srecommend = cus.custid

	INSERT INTO  @tmpCustLimit ( CustID, AccumTurnover, AccumPayout, SiteType )
	SELECT ch.CustID
			,SUM(ch.TurnoverAdjust) AS AccumTurnover
			,SUM(ch.PayoutAdjust) AS AccumPayout
			, 1
	FROM dbo.CustLimitBetHistory_MBC ch WITH(NOLOCK)
		INNER JOIN #tmpTransIds tr
			ON ch.Transid = tr.transid	
	WHERE ch.Matchid = @MatchId
		AND ch.EventTypeID = 1
	GROUP BY ch.custid

	INSERT INTO  @tmpCustLimit ( CustID, AccumTurnover, AccumPayout, SiteType )
	SELECT ch.CustID
			,SUM(ch.TurnoverAdjust) AS AccumTurnover
			,SUM(ch.PayoutAdjust) AS AccumPayout
			, 2
	FROM dbo.CustLimitBetHistory_789 ch WITH(NOLOCK)
		INNER JOIN #tmpTransIds tr
			ON ch.Transid = tr.transid
	WHERE ch.Matchid = @MatchId
		AND ch.EventTypeID = 1
	GROUP BY ch.custid
	
	IF EXISTS (SELECT TOP 1 1 FROM @tmpCustLimit WHERE SiteType = 1) --MBC
	BEGIN
		UPDATE c
		SET AccumTurnover	= c.AccumTurnover - tmp.AccumTurnover
			,AccumPayout	= c.AccumPayout - tmp.AccumPayout	 
			,ModifiedDate	=  GETDATE()
		FROM dbo.CustLimitBet_MBC c
			INNER JOIN @tmpCustLimit tmp
				ON c.CustID = tmp.CustID
		WHERE Matchid = @MatchId
			AND tmp.SiteType = 1

		MERGE dbo.CustLimitBet_MBC AS TARGET
		USING (
				SELECT CustID, AccumTurnover, AccumPayout FROM @tmpCustLimit WHERE SiteType = 1
			  ) AS SOURCE ON TARGET.Matchid = @DestinationMatchId AND TARGET.CustID = SOURCE.CustID
		WHEN MATCHED THEN
			UPDATE SET AccumTurnover = TARGET.AccumTurnover + SOURCE.AccumTurnover
					 , AccumPayout	 = TARGET.AccumPayout + SOURCE.AccumPayout
					 , ModifiedDate  = GETDATE()
		WHEN NOT MATCHED BY TARGET THEN
			INSERT (Matchid, CustID, AccumTurnover, AccumPayout, EventTypeID, LastQueueID, ModifiedDate )
			VALUES (@DestinationMatchId, SOURCE.CustID, SOURCE.AccumTurnover, SOURCE.AccumPayout, 1, 0, GETDATE() );


		SET @rowId = 1
		WHILE ( 1 = 1)
		BEGIN
			UPDATE TOP (@batch) ch
			SET matchid = @DestinationMatchId
				,CreatedDate = GETDATE()
			FROM dbo.CustLimitBetHistory_MBC ch
				INNER JOIN #tmpTransIds tr
					ON ch.Transid =tr.transid
			WHERE ch.Matchid = @MatchId
				AND tr.RowId >= @rowId AND tr.RowId < @rowId + @batch
		
			IF @@ROWCOUNT = 0
			BREAK

			SET @rowId = @rowId + @batch
		END

	END


	IF EXISTS (SELECT TOP 1 1 FROM @tmpCustLimit WHERE SiteType = 2) --789y
	BEGIN
		UPDATE c
		SET AccumTurnover	= c.AccumTurnover - tmp.AccumTurnover
			,AccumPayout	= c.AccumPayout - tmp.AccumPayout	 
			,ModifiedDate	=  GETDATE()
		FROM dbo.CustLimitBet_789 c
			INNER JOIN @tmpCustLimit tmp
				ON c.CustID = tmp.CustID
		WHERE Matchid = @MatchId
			AND tmp.SiteType = 2

		MERGE dbo.CustLimitBet_789 AS TARGET
		USING (
				SELECT CustID, AccumTurnover, AccumPayout FROM @tmpCustLimit WHERE SiteType = 2
			  ) AS SOURCE ON TARGET.Matchid = @DestinationMatchId AND TARGET.CustID = SOURCE.CustID
		WHEN MATCHED THEN
			UPDATE SET AccumTurnover = TARGET.AccumTurnover + SOURCE.AccumTurnover
					 , AccumPayout	 = TARGET.AccumPayout + SOURCE.AccumPayout
					 , ModifiedDate  = GETDATE()
		WHEN NOT MATCHED BY TARGET THEN
			INSERT (Matchid, CustID, AccumTurnover, AccumPayout, EventTypeID, LastQueueID, ModifiedDate )
			VALUES (@DestinationMatchId, SOURCE.CustID, SOURCE.AccumTurnover, SOURCE.AccumPayout, 1, 0, GETDATE() );


		SET @rowId = 1
		WHILE ( 1 = 1)
		BEGIN
			UPDATE TOP (@batch) ch
			SET matchid = @DestinationMatchId
				,CreatedDate = GETDATE()
			FROM dbo.CustLimitBetHistory_789 ch
				INNER JOIN #tmpTransIds tr
					ON ch.Transid =tr.transid
			WHERE ch.Matchid = @MatchId
				AND tr.RowId >= @rowId AND tr.RowId < @rowId + @batch
		
			IF @@ROWCOUNT = 0
			BREAK

			SET @rowId = @rowId + @batch
		END

	END
	--/End: update MaxPayout

	--release lock
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch		= 1
		,@IsReleased		= 1

	SELECT @totalTicket = COUNT(1) FROM #tmpTransIds
	SET @logData = CAST(@MatchId AS VARCHAR(20)) +' TC: ' + CAST(@totalTicket AS VARCHAR(12) )

	IF @IsCentral = 1
	BEGIN
		EXEC bodb_CustomerLog.dbo.WriteLog_SSB_UserLog_Settle 
			@UserID             = @AdminId
			,@Matchid           = @matchid
			,@ActionID			= @ActionID
			,@Remark            = @logData
			,@IP                = @IP
	END
									   
	
	DROP TABLE #tmpTransIds
	DROP TABLE #tmpNewOdds

END
GO