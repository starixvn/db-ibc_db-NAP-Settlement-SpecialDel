/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.Nap_SpecialDelete_UnMarkedTickets_Update @TransIds        VARCHAR(MAX)  = NULL,
                                                             @UserId          INT           = 0,
                                                             @Username        NVARCHAR(100) = '',
                                                             @IP              VARCHAR(15)   = NULL,
                                                             @MarkType		  TINYINT		= 0,
															 @RequestId		  INT			= NULL,
															 @LogActionId	  INT			= 90500,
															 @CalledByBrokerService      BIT         = 0,
                                                             @ErrMsg          NVARCHAR(200) = '' OUTPUT,
                                                             @ErrCode         INT           = 0 OUTPUT
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
*/
BEGIN
     SET NOCOUNT ON;

	 IF @@SERVERNAME IN ('DB052', 'DB053', 'DB054', 'DB06', 'DBTP', 'DB042', 'DB061', 'DB062'
            , 'DB231', 'DB231\SQLSERVER2008R2', 'DB232', 'DB232\SQLSERVER2008R2'
            , 'DB215', 'DB215\SQLSERVER2008R2', 'DB234', 'DB233\SQLSERVER2008R2'
            , 'SITDB052', 'SITDB053','SITDB06', 'SITDB055'
            , 'DBLicAPI', 'SITDBLicAPI', 'DBLicAPI02', 'DB055')
        AND @CalledByBrokerService = 0
    BEGIN
        -- DB052/DB053/DB054/DB06: got servicebroker, then just send a message to service broker and then let it to handle the rest.
        DECLARE @sMessage NVARCHAR(MAX)

        SET @sMessage = 'EXEC dbo.Nap_SpecialDelete_UnMarkedTickets_Update 
			@TransIds = ' + CASE
                WHEN @TransIds IS NULL THEN 'NULL'
                ELSE '''' + CONVERT(NVARCHAR(50), @TransIds) + ''''
                END + '
            ,@UserId = ' + CASE
                WHEN @UserId = 0 THEN '0'
                ELSE '''' + CONVERT(NVARCHAR(50), @UserId) + ''''
                END + '
            ,@Username = ' + CASE
                WHEN @Username = '' THEN ''''
                ELSE '''' + CONVERT(NVARCHAR(50), @Username) + ''''
                END + '
            ,@IP = ' + CASE
                WHEN @IP = '' THEN ''''
                ELSE CONVERT(NVARCHAR(50), @IP)
                END + '
            ,@RequestId = ' + CASE
                WHEN @RequestId IS NULL THEN 'NULL'
                ELSE CONVERT(NVARCHAR(50), @RequestId)
                END + '
            ,@LogActionId = ' + CASE
                WHEN @LogActionId = 90501 THEN '90501'
                ELSE CONVERT(NVARCHAR(50), @LogActionId)
                END
            + ',@CalledByBrokerService = 1'

        EXEC [sb].[SBInputMessage] @fromService = N'//Service/Calculation_send'
            ,@toService = N'//Service/Calculation_receive'
            ,@onContract = N'//Contract/Calculation'
            ,@messageType = N'//Message/Calculation'
            ,@messageBody = @sMessage

        RETURN
    END
    ELSE
	BEGIN
		DECLARE @xmlLog VARCHAR(MAX)
			,@LogData VARCHAR(MAX) = '';

		CREATE TABLE #transIds -- single + sub parlay Id
					(TransId BIGINT
					PRIMARY KEY
					);
		INSERT INTO #transIds(TransId)
			SELECT DISTINCT
					val
			FROM dbo.f_SplitString(@TransIds, ',')
			WHERE val <> '' OPTION(MAXRECURSION 0);

		CREATE TABLE #ParlayTransIds (TransId BIGINT PRIMARY KEY);

		DECLARE @tblInvalidTrans TABLE(transid BIGINT);

		CREATE TABLE #Match(matchid INT);

		CREATE TABLE #tblMatchProcess
					(matchid INT,
					KeyID   TINYINT
					);

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
					SubTransId BIGINT
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
		SELECT t.TransId,
		b.MatchId
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
		LEFT JOIN dbo.MarkedTransaction m WITH (NOLOCK) ON m.TransId = t.TransId
		WHERE m.TransId IS NULL
		AND b.matchid <> 29
	
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
						INSERT INTO #Tickets
							(TransId,
								MatchId,
								BetType,
								CustId,
								Betdaqid,
								ExtraInfo,
								RefCode
							)
							SELECT b.transid,
									b.matchid,
									b.bettype,
									b.custid,
									b.betdaqid,
									b.ExtraInfo,
									b.RefCode
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
		INSERT INTO #Tickets
			(TransId,
				MatchId,
				BetType,
				CustId,
				Betdaqid,
				ExtraInfo
			)
			SELECT b.transid,
				b.matchid,
				b.bettype,
				b.custid,
				b.betdaqid,
				b.ExtraInfo
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
				) AS b
		END;

		-- check if exists parlay tickets
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
		SELECT b.TransId
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
			INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON b.refno = bm.refno AND b.matchid = 29
			LEFT JOIN dbo.MarkedTransaction AS m WITH (NOLOCK) ON m.TransId = b.TransId AND m.MatchId = bm.matchid
		WHERE m.TransId IS NULL
		END

		--check no data
		IF NOT EXISTS
		(
		SELECT TOP (1) 1
		FROM #Tickets
		)
		BEGIN
		SELECT @ErrCode = 99,
			@ErrMsg = 'No ticket found.';
		RETURN;
		END;
	
		-- Check Lock Match
		BEGIN
		DECLARE @avaiableProcess BIT
			,@IsExistSingle BIT = 0
			,@IsExistParlay BIT = 0
			,@IsExistFM BIT = 0;

		SELECT @IsExistSingle = MAX(CASE WHEN BetType NOT BETWEEN 221 AND 227 THEN 1 ELSE 0	END)
			,@IsExistFM = MAX(CASE WHEN BetType BETWEEN 221 AND 227 THEN 1 ELSE 0 END)
		FROM #Tickets AS t
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
				WHEN BetType NOT BETWEEN 221
						AND 227 THEN 1 --SB
				WHEN BetType BETWEEN 221
						AND 227 THEN 6 -- Fast Market
				ELSE 0
				END AS KeyID
		FROM #Tickets;

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

		INSERT INTO #Match
		SELECT DISTINCT
			t.MatchId
		FROM #Tickets t;
    
		-- Insert Transaction
		INSERT INTO dbo.MarkedTransaction
			(TransId,
				MatchId,
				BetType,
				CustId,
				UserId,
				CreatedDate,
				MarkType 
			)
		SELECT t.TransId,
			t.MatchId,
			t.BetType,
			t.CustId,
			@UserId,
			CURRENT_TIMESTAMP,
			@MarkType
		FROM #Tickets t;

		-- Release Match
		EXEC dbo.NAP_Admin_CheckingProcess
			@isExistMatch = @IsExistSingle,
			@isExistParlay = @IsExistParlay,
			@IsExistFM = @IsExistFM,
			@IsReleased = 1;

		SELECT b.MatchId,
			m.HomeId,
			m.AwayId,
			m.SportType,
			m.IsNeutral
		FROM #Match b
			LEFT JOIN dbo.match m WITH (NOLOCK) ON b.MatchId = m.MatchId;

		-- Write Log
		SET @xmlLog = CAST((
				SELECT @LogActionId AS '@LogActionId' -- 90500: Action Mark, 90508: Mark by add request, 90509: Mark by auto void system
					,@UserId AS '@UserId'
					,@IP AS '@IP'
					,@RequestId AS '@RequestId'
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

		EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @xmlLog
		,@functionName = 'TicketVoiding'
		,@MessageType = 'MessageType_TicketVoiding_Log';

		DROP TABLE #Tickets;
		DROP TABLE #Cashout911Tickets;
		DROP TABLE #tmpRefCodeSummary;
		DROP TABLE #transIds;
		DROP TABLE #Match;
		DROP TABLE #ParlayTransIds;

		SET NOCOUNT OFF;
	END
END