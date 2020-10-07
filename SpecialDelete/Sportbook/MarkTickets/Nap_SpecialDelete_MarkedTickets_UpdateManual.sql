/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE dbo.Nap_SpecialDelete_MarkedTickets_ManualUpdate
(
	@TransIds					VARCHAR(MAX)  = NULL,
    @UserId						INT           = 0,
    @Username					NVARCHAR(100) = '',
    @IP							VARCHAR(15)   = NULL,
	@RequestId					INT		   = NULL,
	@LogActionId				INT			= 90501,
    @ErrMsg						NVARCHAR(200) = '' OUTPUT,
    @ErrCode					INT           = 0 OUTPUT
)
AS
/*
    Created by: Max
	Date: 20200803
	Task: [TVS] Enhance Block Match of Unmark Ticket  [Redmine: #136734]
	DB: DBTXN/BODB02

	Explanation's Param:
		
	Revisions:
		- 20200730@Max: Create SP  [Redmine: #136734]
		- 20200817@Max: Add Mark/Unmark process to servicebroker [Redmine: #139340]
		- 20201007@Max: Integrate new bet type Time Machine OU [Redmine: #143032]
*/
BEGIN
     SET NOCOUNT ON;

	DECLARE @xmlLog VARCHAR(MAX)
			,@LogData VARCHAR(MAX) = '';

	CREATE TABLE #TransIds -- single + parlay tickets
					(TransId BIGINT
					PRIMARY KEY
					);

	CREATE TABLE #ParlayTransIds (TransId BIGINT PRIMARY KEY);

	CREATE TABLE #MarkedTransactionDeleted (
		TransId BIGINT
		,MatchId INT
		);

		INSERT INTO #TransIds(TransId)
			SELECT DISTINCT
					val
			FROM dbo.f_SplitString(@TransIds, ',')
			WHERE val <> '' OPTION(MAXRECURSION 0);

		CREATE TABLE #Tickets
					(TransId   BIGINT,
					MatchId   INT,
					CustId    INT,
					BetType   SMALLINT,
					Betdaqid  BIGINT,
					ExtraInfo VARCHAR(1000),
					RefCode   BIGINT,
					refno	 BIGINT,
					IsParlay  BIT DEFAULT(0),
					SubTransId BIGINT,
					IsFinish	BIT
					);
		CREATE TABLE #Cashout911Tickets
					(TransId BIGINT,
					MatchId INT
					);
		CREATE TABLE #tmpRefCodeSummary
					(RefCode BIGINT,
					custid  INT,
					matchid INT,
					bettype SMALLINT,
					transid BIGINT
					);
		CREATE INDEX IX_Data_RefCode ON #Tickets(RefCode);
		CREATE INDEX IX_tmpRefCodeSummary_Refcode ON #tmpRefCodeSummary(RefCode);
		CREATE TABLE #Match(MatchId INT);

		CREATE TABLE #tblMatchProcess
				(matchid INT,
				KeyID   TINYINT
				);
	
	-- Get tickets insert into transaction
	INSERT INTO #Tickets (
		TransId
		,MatchId
		,BetType
		,CustId
		,Betdaqid
		,ExtraInfo
		,RefCode
		,refno
		,IsParlay
		,SubTransId
		)
	SELECT t.TransId
		,b.MatchId
		,b.BetType
		,b.custid
		,b.betdaqid
		,b.ExtraInfo
		,b.RefCode
		,b.refno
		,0
		,NULL
	FROM #transIds t
		INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = t.transid
	WHERE b.matchid <> 29

	-- get only parlay tickets from @input transid
	INSERT INTO #ParlayTransIds (
		TransId
	)
	SELECT tmp.TransId
	FROM #transIds AS tmp
	WHERE NOT EXISTS (
		SELECT TOP 1 1
		FROM #Tickets AS t
		WHERE t.TransId = tmp.TransId
	)
	
		-- delete cash-out member bet tickets
	DELETE t
	FROM #Tickets t
	WHERE EXISTS (SELECT TOP (1) 1
					FROM bettrans sub911 (NOLOCK)
					WHERE sub911.bettype = 911 AND sub911.transid = t.refno)

	-- Bonus
	IF EXISTS
		(
			SELECT TOP (1) 1
			FROM #Tickets
			WHERE RefCode IS NOT NULL
		)
			BEGIN
				-- Insert more bonus or cash ticket in case only one ticket appears in #Tickets	
				INSERT INTO #tmpRefCodeSummary
					(RefCode,
						custid,
						matchid,
						bettype,
						transid
					)
					SELECT RefCode,
							custid,
							matchid,
							bettype,
							MAX(transid) AS transid
					FROM #Tickets
					WHERE RefCode IS NOT NULL
					GROUP BY RefCode,
								custid,
								matchid,
								bettype
					HAVING COUNT(*) = 1;
				IF @@ROWCOUNT > 0
					BEGIN
						INSERT INTO #Tickets(TransId, MatchId)
							SELECT b.transid, b.matchid
							FROM #tmpRefCodeSummary t
									INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.RefCode = t.RefCode
																			AND b.transid <> t.transid
																			AND b.matchid = t.matchid
																			AND b.custid = t.custid
																			AND b.bettype = t.bettype
							WHERE b.statusID IN(0, 1); -- running, waiting
					END;
			END;	

	-- get sub ticket of Cash-out (911) and cash-out member bet tickets
	IF(EXISTS
		(
			SELECT TOP (1) 1
			FROM #Tickets
			WHERE betdaqid = 0
				AND CHARINDEX('p25', extrainfo) > 0
		))
	BEGIN
			-- get sub ticket of Cash-out (911)	
				INSERT INTO #Cashout911Tickets
					(TransId,
						MatchId
					)
					SELECT sub911.transid,
							sub911.matchid
					FROM #Tickets main
							INNER JOIN dbo.bettrans sub911 WITH (NOLOCK) ON main.transid = sub911.refno
																			AND sub911.matchid = main.MatchId
																			AND sub911.custid = main.custid
																			AND main.betdaqid = 0
																			AND CHARINDEX('p25', main.extrainfo) > 0
																			AND sub911.bettype = 911;			 

			-- get cash-out member bet tickets
				INSERT INTO #Tickets(TransId, MatchId)
					SELECT b.transid, b.matchid
					FROM #Cashout911Tickets sub911
							CROSS APPLY
				(
					SELECT b.bettype
							,b.transid
							,b.matchid
							,b.BetID
							,b.refno
							,b.hdp1
							,b.hdp2
							,b.odds
							,b.oddsspread
							,b.OddsType
							,b.status
							,b.SecAcceptFlag
							,b.checktime
							,b.stake
							,b.transdate
							,b.betteam
							,b.betcheck
							,b.liveindicator
							,b.custid
							,b.livehomescore
							,b.liveawayscore
							,b.winlost
							,b.actual_stake
							,b.transdesc
							,b.betdaqid
							,b.username
							,b.recommend
							,b.ExtraInfo
							,b.CurrencyName
							,b.WalletType
							,b.RefCode
							,b.BonusID
							,b.currency
					FROM dbo.bettrans b WITH (NOLOCK)
					WHERE b.refno = sub911.transid
						AND b.matchid = sub911.MatchId
						AND b.bettype NOT IN(911, 912, 913)
						AND NOT EXISTS (SELECT TOP 1 1 FROM #Tickets r WHERE r.TransId = b.transid)
					) AS b
	END;

	-- get parlay tickets
	IF EXISTS (SELECT TOP 1 1
				FROM #ParlayTransIds)
	BEGIN
		INSERT INTO #Tickets (
			TransId
			,MatchId
			,BetType
			,CustId
			,Betdaqid
			,ExtraInfo
			,RefCode
			,refno
			,IsParlay
			,SubTransId
			)
		SELECT b.transid
			,bm.matchid
			,bm.bettype
			,bm.custid
			,NULL
			,NULL
			,NULL
			,bm.refno
			,1
			,bm.transid
		FROM #ParlayTransIds t
			INNER JOIN dbo.bettransm AS bm WITH (NOLOCK) ON bm.transid = t.TransId
			INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON b.refno = bm.refno
				AND b.matchid = 29
	END

	-- Check Lock Match
	BEGIN
		DECLARE @avaiableProcess BIT
			,@IsExistSingle BIT = 0
			,@IsExistParlay BIT = 0
			,@IsExistFM BIT = 0;

		SELECT @IsExistSingle = MAX(CASE WHEN f.GroupId <> 1 THEN 1 ELSE 0	END)
			,@IsExistFM = MAX(CASE WHEN f.GroupId = 1 THEN 1 ELSE 0 END)
		FROM #Tickets AS t
			OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = t.Bettype
			)f
		WHERE t.IsParlay = 0;

		SELECT TOP 1 @IsExistParlay = 1
		FROM #Tickets AS t
		WHERE t.IsParlay = 1

		INSERT INTO #tblMatchProcess (
			MatchId
			,KeyID
			)
		SELECT DISTINCT MatchId
			,CASE 
				WHEN f.GroupId <> 1 THEN 1 --SB
				WHEN f.GroupId = 1 THEN 6 -- Fast Market
				ELSE 0
				END AS KeyID
		FROM #Tickets
			OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = t.Bettype
			)f

		EXEC dbo.NAP_Admin_CheckingProcess @isExistMatch = @IsExistSingle
			,@isExistParlay = @IsExistParlay
			,@IsExistFM = @IsExistFM
			,@avaiableProcess = @avaiableProcess OUTPUT
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT;

		IF (@ErrCode <> 0 OR @avaiableProcess = 0)
		BEGIN
			RETURN;
		END;
	END;
	
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

	-- Release Match
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch = @IsExistSingle,
		@isExistParlay = @IsExistParlay,
		@IsExistFM = @IsExistFM,
		@IsReleased = 1;

	INSERT INTO #Match
	SELECT DISTINCT
			t.MatchId
	FROM #Tickets t;

	-- Write Log
	SET @xmlLog = CAST((
				SELECT @LogActionId AS '@LogActionId' -- 90501: Action Unmark, 90510: Unmark by autovoid System
					,@UserId AS '@UserId'
					,@IP AS '@IP'
					,@RequestId AS '@RequestId'
					,m.matchid AS '@MatchId'
					,STUFF((
							SELECT ',' + CAST(d.TransId AS NVARCHAR(100))
							FROM #Tickets AS d
							WHERE d.MatchId = m.MatchId
							FOR XML PATH('')
							), 1, 1, '')  AS '@LogData'
				FROM #Match AS m
				FOR XML PATH('r')
					,ROOT('root')
					,TYPE
				) AS VARCHAR(MAX));

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @xmlLog
		,@functionName = 'TicketVoiding'
		,@MessageType = 'MessageType_TicketVoiding_Log';

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
		LEFT JOIN match m WITH (NOLOCK) ON b.MatchId = m.MatchId;

	DROP TABLE #TransIds;
	DROP TABLE #Match;
	DROP TABLE #MarkedTransactionDeleted;
	DROP TABLE #ParlayTransIds

	SET NOCOUNT OFF;
END