/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestDetailTicket_SubParlay_Insert]
(	 
	@RequestId				INT
	,@MatchId				INT
	,@KickOffTime			DATETIME = NULL
	,@IssueTypeId			INT
	,@SubIssueTypeId		INT
	,@MinMainParlayTransId	BIGINT = NULL
	,@MaxMainParlayTransId	BIGINT = NULL
	,@IsEditRequest			BIT = 0
	,@UserId				INT = NULL
	,@IP					VARCHAR(50) = NULL
	,@ActionId				TINYINT = 0
	,@FilterFromTransTime	DATETIME = NULL
	,@FilterToTransTime		DATETIME = NULL
	,@FilterBy				TINYINT = 1 
	,@WrongScoreInfo		VARCHAR(MAX) = NULL
)
AS
/*	
	Created by: Max
	Date 20200701
	Task: [TVS] Danger Accept Bets Issue Type [Redmine: #111573]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20200701@Max: Create new SP [Redmine: #135947]
		- 20200901@July: [TVS] - Enhance for Danger Accept - Phase 2 [Redmine: #140785]
		- 20201002@Max: [TVS] - Modify bet type list on Home/Away Team filter of Danger Accept [Redmine: #142883]
		- 20201013@July: [TVS] - HotFix - Danger accept add by accept time can add ticket super live [Redmine: #143308]
		- 20201021@July: [TVS] - Wrong Red Card [Redmine: #140951]
		- 20201106@July: [TVS] - Abnormal Account + Check lock match before add request [Redmine: #143666]
		- 20210329@Max: TVS - Correct Ticket on DBTP [Redmine: #151954]
		- 20210427@Max: TVS - New Issue Type - Wrong Score - [Redmine: #140953]
		- 20210521@July: TVS - Check parlay count = 0 [Redmine:#155575]
		- 20210524@Max: [TVS] Wrong Score - Void 2H tickets in range time [Redmine: #155598]
		- 20210525@July: TVS - Danger Accept Enhancement - Phase 8 [Redmine: #152051]
	
	Param's explanation:
		@WrongScoreInfo: 
		<root>
			<r RequestId="" MatchId="" FilterFromTransTime="1" FilterToTransTime ="2" SingleCount="5" MainParlayCount="1" MinSingleTransId="" MaxMainParlayTransId="" VoidFromTime="" VoidToTime="" LiveHomeScore ="" LiveAwayScore="" LiveScores=""/>
		</root>
		
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @UnMarkedTransIds	  VARCHAR(MAX) = NULL
			,@UserName			  VARCHAR(100) = NULL
			,@MarkedTransIds	  VARCHAR(MAX) = NULL
			,@RemoveTransIds	  VARCHAR(MAX) = ''
			,@IsLockMatch		  BIT = 0
			,@WrongScoreInfoXML XML = NULL

	CREATE TABLE #SpecialDeleteBets (
			GroupID               BIGINT,
			transid               BIGINT,
			SubTransid            BIGINT,
			refno                 BIGINT,
			custid                INT,
			username              VARCHAR(30),
			odds                  MONEY,
			SubOdds               MONEY,
			oddsspread            MONEY,
			OddsType              INT,
			transdate             DATETIME,
			bettype               SMALLINT,
			OriginalBetType       SMALLINT,
			betteam               NVARCHAR(10),
			SubBetTeam            NVARCHAR(10),
			betcheck              NVARCHAR(50),
			SubBetcheck           NVARCHAR(50),
			Subhdp1               SMALLMONEY,
			Subhdp2               SMALLMONEY,
			hdp1                  SMALLMONEY,
			hdp2                  SMALLMONEY,
			livehomescore         SMALLINT,
			liveawayscore         SMALLINT,
			creator               INT,
			creatorName           VARCHAR(30),
			Stake                 MONEY,
			currencyname          VARCHAR(20),
			IsDeposit             BIT DEFAULT(0),
			STATUS                NVARCHAR(10),
			SubStatus             NVARCHAR(10),
			srecommend            INT,
			mrecommend            INT,
			recommend             INT,
			SubLeagueId           INT,
			betid                 BIGINT DEFAULT(0),
			Transdesc             NVARCHAR(1000),
			betdaqid              BIGINT,
			ParlayType            SMALLINT DEFAULT(0)
			, -- sub bettype of parlay 
			IsMixParlay           BIT DEFAULT(0),
			SoldId                BIGINT,
			sporttype             SMALLINT,
			modds                 MONEY,
			ExtraInfo             VARCHAR(1000),
			IsCashOutMemberTicket BIT DEFAULT 0,
			MainCashoutId         BIGINT,
			matchid               INT,
			WalletType            TINYINT,
			RefCode               BIGINT,
			BonusID               INT,
			MainTransId           BIGINT,
			WinLost               MONEY,
			IsMarked              BIT,
			LiveIndicator			BIT
	)

	CREATE TABLE #tmpRefCodeSummary (
			RefCode  BIGINT,
			custid   INT,
			bettype  SMALLINT,
			transid  BIGINT,
			IsMarked BIT
	)

	CREATE TABLE #tblSoldTicket (transid BIGINT PRIMARY KEY)
	CREATE TABLE #DangerAccept_SubParlayTickets (TransId BIGINT, StatusId INT, MatchId INT, MainTransId BIGINT, isFinish BIT, LiveHomeScore SMALLINT, LiveAwayScore SMALLINT)
	CREATE TABLE #TransidInRequest (TransId BIGINT)
	CREATE TABLE #tblGetLogInfo (
			 RequestID				INT
			,MatchID				INT
			,FilterFromTransTime	DATETIME 
			,FilterToTransTime		DATETIME 
			,FilterFromBetId		BIGINT 
			,FilterToBetId			BIGINT 
			,FilterBy				TINYINT 
			,SingleCount			INT 
			,MainParlayCount		INT 
			,MinSingleTransId		BIGINT 
			,MaxSingleTransId		BIGINT 
			,MinMainParlayTransId	BIGINT 
			,MaxMainParlayTransId	BIGINT 
			,VoidFromTime			DATETIME 
			,VoidToTime				DATETIME
			,LiveHomeScore			INT
			,LiveAwayScore			INT
			,LiveScores				NVARCHAR(300)
			,TypeAccept				VARCHAR(50)
			)

	DECLARE @tmpTransIDBatch TABLE (TransId	BIGINT, StatusId INT, MatchId INT, MainTransId BIGINT)

	CREATE INDEX IX_SpecialDeleteBets_RefCode ON #SpecialDeleteBets(RefCode)
	CREATE INDEX IX_tmpRefCodeSummary_Refcode ON #tmpRefCodeSummary (RefCode)

	-- Check edit request after voided
	IF (EXISTS (SELECT TOP 1 1 FROM dbo.TicketVoiding_VoidingHistory WHERE RequestId = @RequestId))
	BEGIN
		RETURN;
	END

	INSERT INTO #TransidInRequest (TransId)
	SELECT tmp.transid
	FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) 
		INNER JOIN dbo.TicketVoiding_Request req WITH (NOLOCK) ON req.RequestId = rd.RequestId 
		CROSS APPLY (
					SELECT TransId
					FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay WITH (NOLOCK)
					WHERE RequestId = req.RequestId
				) AS tmp
	WHERE rd.MatchId = @MatchId AND req.RequestId <> @RequestId AND req.ActionId <>2

	IF @IssueTypeId IN (1, 10)
	BEGIN
		INSERT INTO #DangerAccept_SubParlayTickets (TransId, StatusId, MatchId, MainTransId)
		SELECT sub.transid
			, sub.statusID
			, @MatchId
			, main.transid
		FROM dbo.bettransm sub WITH (NOLOCK)
			INNER HASH JOIN bettrans AS main WITH (NOLOCK) 
							ON	main.refno = sub.refno				
								AND sub.matchid = @matchid
		WHERE 1 = CASE WHEN @FilterBy IN (0,1) AND main.transid BETWEEN @MinMainParlayTransId AND @MaxMainParlayTransId THEN 1
						WHEN @FilterBy = 2 AND sub.checktime IS NOT NULL AND sub.checktime BETWEEN @FilterFromTransTime AND @FilterToTransTime THEN 1
						WHEN @FilterBy = 2 AND sub.checktime IS NULL AND sub.transdate BETWEEN @FilterFromTransTime AND @FilterToTransTime THEN 1
						ELSE 0 END
			AND 1 = CASE WHEN @ActionId <>2 AND sub.statusID NOT IN (101, 102, 103) THEN 1
						 WHEN @ActionId =2 AND sub.statusID NOT IN (101, 103) THEN 1
						 ELSE 0 END
			AND sub.betfrom <> 'P'
			AND 1 = CASE WHEN @IssueTypeId NOT IN (1) THEN 1 --NOT Danger Accept
						  ELSE CASE WHEN @SubIssueTypeId IN (55,57,60,75,79,82) AND sub.bettype NOT IN (402,404,409,462,464) THEN 1 
									WHEN @SubIssueTypeId IN (68,70) AND sub.bettype NOT IN (483,485) THEN 1
									WHEN @SubIssueTypeId IN (56,58,61,69,71,76) AND sub.bettype NOT IN (401,403,407,461,463) THEN 1
									WHEN @SubIssueTypeId IN (69,71) AND sub.bettype NOT IN (482,484) THEN 1
									WHEN @SubIssueTypeId IN (1,2,3,4,5,26,59,62,63,64,65,66,67,72,73,74,77,78,81,84,85) THEN 1
								    ELSE 0
							  END
					END

		SELECT @Username = (SELECT c.username FROM CustDB.dbo.Customer c WITH (NOLOCK) WHERE c.custid = @UserId)
		------------------------------------------------------------------------------------------------------------
		--Edit from to time of Danger Accepted issue -> unmark ticket change void time
		SELECT @RemoveTransIds = STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
											FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rdt WITH(NOLOCK)
											WHERE NOT EXISTS( SELECT TOP 1 1 FROM #DangerAccept_SubParlayTickets t WHERE rdt.TransId=t.transid)
												  AND NOT EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = rdt.TransId)-- exist in # request
												  AND rdt.RequestId=@RequestId
											FOR XML PATH('')
										), 1,1,'')
		IF @RemoveTransIds IS NOT NULL
		BEGIN
			EXEC dbo.Nap_SpecialDelete_MarkedTickets_Update @TransIds = @RemoveTransIds, @UserId = @UserId, @Username = @Username, @IP = @IP
																, @RequestId = @RequestId, @LogActionId = 90501, @IsLockMatch = 0
		END

		IF @IsEditRequest = 1
		BEGIN
			DELETE dbo.TicketVoiding_RequestDetailTicket_SubParlay
			WHERE RequestId = @RequestId
		END

		INSERT INTO dbo.TicketVoiding_RequestDetailTicket_SubParlay (RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId, MainTransId)
		SELECT @RequestId
			, @IssueTypeId
			, @SubIssueTypeId
			, t.TransId
			, t.MatchId
			, rd.Id
			, t.MainTransId 
		FROM #DangerAccept_SubParlayTickets t
			INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) ON t.MatchId = rd.MatchId
			OUTER APPLY (
								SELECT TOP 1 rs.TransId
								FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rs WITH (NOLOCK)
									INNER JOIN TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = rs.RequestId
								WHERE rs.TransId = t.transid
									AND rs.MatchId = @MatchId
									AND r.ActionId NOT IN (2)
							)tmp
		WHERE rd.RequestId = @RequestId 
			AND tmp.TransId IS NULL
		
		--Mark Ticket
		IF @ActionId <>2
		BEGIN
			--Mark Ticket
			WHILE (1=1)
			BEGIN
				DELETE @tmpTransIDBatch
					
				UPDATE TOP(2000) t
					SET isFinish = 1
				OUTPUT DELETED.TransId, DELETED.StatusId					
				INTO @tmpTransIDBatch(TransId, StatusId)
				FROM #DangerAccept_SubParlayTickets t 
				WHERE isFinish IS NULL
					AND t.Matchid = @matchid
				
				IF @@ROWCOUNT = 0 BREAK
				
				SELECT @UnMarkedTransIds = STUFF(
					(SELECT ',' + CONVERT(VARCHAR(50), tp.transid)
					FROM @tmpTransIDBatch tp
					WHERE NOT EXISTS (SELECT TOP 1 1 FROM dbo.MarkedTransaction mt WITH(NOLOCK) WHERE mt.TransId = tp.transid)
						AND  tp.StatusId IN (0, 1) 
					GROUP BY TransId for XML PATH('')), 1, 1, ''
					)
		
				IF @UnMarkedTransIds IS NOT NULL
				BEGIN
					EXEC dbo.Nap_SpecialDelete_UnMarkedTickets_Update @TransIds = @UnMarkedTransIds, @UserId = @UserId, @Username = @Username, @IP = @IP, @RequestId = @RequestId
																	, @MarkType = 1, @LogActionId = 90508, @IsLockMatch = 0
				END	

				SET @UnMarkedTransIds = ''
				
			END
		END
		ELSE --other action to take note
		BEGIN
			IF @IsEditRequest = 1
			BEGIN
				--Unmark ticket
				SELECT @MarkedTransIds = STUFF(
						(SELECT ',' + CONVERT(VARCHAR(50), tp.transid)
						FROM #DangerAccept_SubParlayTickets tp
						WHERE EXISTS (SELECT TOP 1 1 FROM dbo.MarkedTransaction mt WITH(NOLOCK) WHERE mt.TransId = tp.MainTransId)
							  AND NOT EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = tp.TransId)
							  AND  tp.StatusId IN (0, 1) 
						GROUP BY TransId for XML PATH('')), 1, 1, ''
						)
			
				IF @MarkedTransIds IS NOT NULL
					BEGIN
						EXEC dbo.Nap_SpecialDelete_MarkedTickets_Update @TransIds = @MarkedTransIds, @UserId = @UserId, @Username = @Username, @IP = @IP
																			, @RequestId = @RequestId, @LogActionId = 90501, @IsLockMatch = 0
					END												

					SET @MarkedTransIds = ''
			END
		END

	END
	ELSE IF @IssueTypeId IN (3)
	BEGIN
		SET @WrongScoreInfoXML = CONVERT(xml, @WrongScoreInfo)
		INSERT INTO #tblGetLogInfo( 
			   RequestID				
			  ,MatchID				
			  ,FilterFromTransTime	
			  ,FilterToTransTime							
			  ,SingleCount			
			  ,MainParlayCount		
			  ,MinSingleTransId		
			  ,MaxSingleTransId		
			  ,MinMainParlayTransId	
			  ,MaxMainParlayTransId	
			  ,VoidFromTime			
			  ,VoidToTime
			  ,LiveHomeScore
			  ,LiveAwayScore				
			)

		SELECT @RequestId AS RequestId
			  ,@MatchId AS MatchID
			  ,t.c.value('@FilterFromTransTime','DATETIME') AS FilterFromTransTime
			  ,t.c.value('@FilterToTransTime','DATETIME') AS FilterToTransTime
			  ,t.c.value('@SingleCount','INT') AS SingleCount
			  ,t.c.value('@MainParlayCount','INT') AS MainParlayCount
			  ,t.c.value('@MinSingleTransId','BIGINT') AS MinSingleTransId
			  ,t.c.value('@MaxSingleTransId','BIGINT') AS MaxSingleTransId
			  ,t.c.value('@MinMainParlayTransId','BIGINT') AS MinMainParlayTransId
			  ,t.c.value('@MaxMainParlayTransId','BIGINT') AS MaxMainParlayTransId
			  ,t.c.value('@VoidFromTime','DATETIME') AS VoidFromTime
			  ,t.c.value('@VoidToTime','DATETIME') AS VoidToTime
			  ,t.c.value('@LiveHomeScore','INT') AS LiveHomeScore
			  ,t.c.value('@LiveAwayScore','INT') AS LiveAwayScore
		FROM @WrongScoreInfoXML.nodes('root/r') t(c)
		OPTION (OPTIMIZE FOR (@WrongScoreInfoXML = NULL))

		INSERT INTO #DangerAccept_SubParlayTickets (TransId, StatusId, MatchId, MainTransId, LiveHomeScore, LiveAwayScore)
		SELECT sub.transid
			, sub.statusID
			, @MatchId
			, main.transid
			, CASE WHEN f.GroupName = '2H' THEN s.LiveHomeScore ELSE sub.livehomescore END AS livehomescore
			, CASE WHEN f.GroupName = '2H' THEN s.LiveAwayScore ELSE sub.liveawayscore END AS liveawayscore
		FROM dbo.bettransm sub WITH (NOLOCK)
			INNER HASH JOIN bettrans AS main WITH (NOLOCK) 
							ON	main.refno = sub.refno				
								AND sub.matchid = @matchid
			INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = sub.BetType
			CROSS APPLY (
				SELECT TOP(1) t.LiveHomeScore, t.LiveAwayScore
				FROM #tblGetLogInfo t
				WHERE matchid = @MatchId
					AND 1 = CASE WHEN sub.livehomescore = LiveHomeScore AND sub.liveawayscore = LiveAwayScore AND sub.transdate BETWEEN VoidFromTime AND VoidToTime THEN 1
								WHEN sub.transdate BETWEEN VoidFromTime AND VoidToTime AND f.GroupName = '2H' THEN 1
							ELSE 0 END	
					AND main.transid BETWEEN MinMainParlayTransId AND MaxMainParlayTransId
			)s
		WHERE 1 = CASE WHEN @ActionId <>2 AND sub.statusID NOT IN (101, 102, 103) THEN 1
						 WHEN @ActionId =2 AND sub.statusID NOT IN (101, 103) THEN 1
						 ELSE 0 END
			AND sub.betfrom <> 'P'
			AND 1 = CASE WHEN sub.livehomescore = 0 AND sub.liveawayscore = 0 AND sub.liveindicator = 0 AND f.GroupName <> '2H' THEN 0 ELSE 1 END

		SELECT @Username = (SELECT c.username FROM CustDB.dbo.Customer c WITH (NOLOCK) WHERE c.custid = @UserId)
		------------------------------------------------------------------------------------------------------------
		--Edit from to time of Danger Accepted issue -> unmark ticket change void time
		SELECT @RemoveTransIds = STUFF((SELECT ',' + CAST(rdt.transid AS VARCHAR(50)) 
											FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rdt WITH(NOLOCK)
												INNER JOIN MarkedTransaction mt WITH(NOLOCK) ON mt.TransId = rdt.MainTransId AND mt.MatchId = rdt.MatchId
												LEFT JOIN #DangerAccept_SubParlayTickets tp ON rdt.TransId=tp.transid
												LEFT JOIN #TransidInRequest tr on tr.TransId = rdt.TransId
											WHERE tp.TransId IS NULL
												  AND tr.TransId is NULL
												  AND rdt.RequestId=@RequestId
											FOR XML PATH('')
										), 1,1,'')
		IF @RemoveTransIds IS NOT NULL
		BEGIN
			EXEC dbo.Nap_SpecialDelete_MarkedTickets_Update @TransIds = @RemoveTransIds, @UserId = @UserId, @Username = @Username, @IP = @IP
																, @RequestId = @RequestId, @LogActionId = 90501, @IsLockMatch = 0
		END

		IF @IsEditRequest = 1
		BEGIN			
			DELETE s
			FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay s
				LEFT JOIN #DangerAccept_SubParlayTickets t ON s.transid = t.transid AND t.matchid = @MatchId
			WHERE s.matchid = @MatchId AND s.RequestId = @RequestId AND t.transid IS NULL
			
			INSERT INTO dbo.TicketVoiding_RequestDetailTicket_SubParlay(RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId, MainTransId)
			SELECT @RequestId
				, @IssueTypeId
				, @SubIssueTypeId
				, t.TransId
				, t.MatchId
				, rd.Id AS RequestDetailId
				, t.MainTransId
			FROM #DangerAccept_SubParlayTickets t
				INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) ON t.MatchId = rd.MatchId  AND rd.LiveHomeScore = t.LiveHomeScore AND rd.LiveAwayScore = t.LiveAwayScore
				OUTER APPLY (
									SELECT TOP 1 rs.TransId
									FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rs WITH (NOLOCK)
										INNER JOIN TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = rs.RequestId 
									WHERE rs.TransId = t.transid
										AND rs.MatchId = @MatchId
										AND r.ActionId NOT IN (2)
							)tmp
			WHERE rd.RequestId = @RequestId AND tmp.TransId IS NULL
		END
		ELSE
		BEGIN
			INSERT INTO dbo.TicketVoiding_RequestDetailTicket_SubParlay(RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId, MainTransId)
			SELECT @RequestId
				, @IssueTypeId
				, @SubIssueTypeId
				, t.TransId
				, t.MatchId
				, rd.Id AS RequestDetailId
				, t.MainTransId
			FROM #DangerAccept_SubParlayTickets t
				INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) ON t.MatchId = rd.MatchId  AND rd.LiveHomeScore = t.LiveHomeScore AND rd.LiveAwayScore = t.LiveAwayScore
				OUTER APPLY (
									SELECT TOP 1 rs.TransId
									FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rs WITH (NOLOCK)
										INNER JOIN TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = rs.RequestId 
									WHERE rs.TransId = t.transid
										AND rs.MatchId = @MatchId
										AND r.ActionId NOT IN (2)
							)tmp
			WHERE rd.RequestId = @RequestId AND tmp.TransId IS NULL
		END

		IF @ActionId <> 2
		BEGIN
			--Mark Ticket
			WHILE (1=1)
			BEGIN
				DELETE @tmpTransIDBatch
					
				UPDATE TOP(2000) t
					SET isFinish = 1
				OUTPUT DELETED.TransId, DELETED.StatusId, DELETED.MatchId, DELETED.MainTransId				
				INTO @tmpTransIDBatch(TransId, StatusId, MatchId, MainTransId)
				FROM #DangerAccept_SubParlayTickets t 
				WHERE isFinish IS NULL
					AND t.Matchid = @matchid
				
				IF @@ROWCOUNT = 0 BREAK
				
				SELECT @UnMarkedTransIds = STUFF(
					(SELECT ',' + CONVERT(VARCHAR(50), tp.transid)
					FROM @tmpTransIDBatch tp
					WHERE NOT EXISTS (SELECT TOP 1 1 FROM dbo.MarkedTransaction mt WITH(NOLOCK) WHERE mt.TransId = tp.MainTransId AND mt.MatchId = tp.MatchId)
						AND  tp.StatusId IN (0, 1) 
					GROUP BY TransId for XML PATH('')), 1, 1, ''
					)
		
				IF @UnMarkedTransIds IS NOT NULL
				BEGIN
					EXEC dbo.Nap_SpecialDelete_UnMarkedTickets_Update @TransIds = @UnMarkedTransIds, @UserId = @UserId, @Username = @Username, @IP = @IP, @RequestId = @RequestId
																	, @MarkType = 1, @LogActionId = 90508, @IsLockMatch = 0
				END	

				SET @UnMarkedTransIds = ''
			END
		END
		ELSE -- take note
		BEGIN
			IF @IsEditRequest = 1
			BEGIN
				SELECT @MarkedTransIds = STUFF(
						(SELECT ',' + CONVERT(VARCHAR(50), tp.transid)
						FROM #DangerAccept_SubParlayTickets tp
						WHERE EXISTS (SELECT TOP 1 1 FROM dbo.MarkedTransaction mt WITH(NOLOCK) WHERE mt.TransId = tp.MainTransId)
							  AND NOT EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = tp.TransId)
							AND  tp.StatusId IN (0, 1) 
						GROUP BY TransId for XML PATH('')), 1, 1, ''
						)
				--Unmark ticket
				IF @MarkedTransIds IS NOT NULL
					BEGIN
						EXEC dbo.Nap_SpecialDelete_MarkedTickets_Update @TransIds = @MarkedTransIds, @UserId = @UserId, @Username = @Username, @IP = @IP
																			, @RequestId = @RequestId, @LogActionId = 90501, @IsLockMatch = 0
					END												

					SET @MarkedTransIds = ''
			END
		END
	END
	ELSE
	BEGIN
		IF @IsEditRequest = 1
		BEGIN
			DELETE dbo.TicketVoiding_RequestDetailTicket_SubParlay
			WHERE RequestId = @RequestId
		END
		---get sub ticket of a mix parlay	
			IF EXISTS (
					SELECT 1
					FROM dbo.bettransm AS bm WITH (NOLOCK)
					WHERE bm.matchid = @matchid
						AND bm.transdate >= @KickOffTime
						AND bm.statusID NOT IN (101, 102, 103)
						AND bm.liveindicator = 0
						AND bm.betfrom <> 'P'
					)
			BEGIN		
				INSERT INTO #SpecialDeleteBets(
						GroupID			
						,transid		
						,SubTransid		
						,refno			
						,custid					
						,odds			
						,SubOdds	
						,oddsspread
						,OddsType		
						,transdate		
						,bettype		
						,betteam		
						,SubBetTeam
						,betcheck	
						,SubBetcheck	
						,Subhdp1
						,Subhdp2
						,hdp1 			
						,hdp2 			
						,livehomescore	
						,liveawayscore	
						,creator		
						,Stake			
						,currencyname						
						,STATUS			
						,SubStatus	
						,srecommend		
						,mrecommend		
						,recommend						
						,Transdesc		
						,ParlayType		
						,IsMixParlay
						,modds
						,WinLost
						,IsMarked
						,LiveIndicator
						,MainTransId
						,matchid
					)
				SELECT 
						main.transid AS GroupID
						,main.transid AS TransId
						,sub.transid AS SubTransID
						,sub.refno
						,sub.custid				
						,main.odds
						,sub.odds AS SubOdds
						,sub.oddsspread
						,main.OddsType
						,sub.transdate
						,main.bettype
						,main.betteam
						,sub.betteam
						,main.betcheck				
						,sub.betcheck
						,sub.hdp1
						,sub.hdp2
						,main.hdp1
						,main.hdp2
						,sub.livehomescore
						,sub.liveawayscore
						,main.creator
						,main.stake
						,main.currencyname				
						,main.STATUS
						,sub.STATUS AS SubStatus
						,main.srecommend
						,main.mrecommend
						,main.recommend
						,sub.Transdesc
						,sub.bettype AS parlaytype
						,1 AS IsMixParlay
						,main.modds
						,main.winlost - main.actual_stake AS WinLost
						,0
						,sub.liveindicator
						,main.transid AS MainTransId
						,sub.matchid AS matchid
				FROM	dbo.bettransm sub WITH (NOLOCK)				
						INNER HASH JOIN bettrans AS main WITH (NOLOCK) 
							ON	main.refno = sub.refno				
								AND sub.matchid = @matchid
						 OUTER APPLY (
								SELECT TOP 1 rs.TransId
								FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rs WITH (NOLOCK)
									INNER JOIN TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = rs.RequestId
								WHERE rs.TransId = sub.transid
									AND rs.MatchId = @MatchId
									AND r.ActionId NOT IN (2)
							)tmp
				WHERE	sub.transdate >= @KickOffTime
						AND sub.statusID NOT IN (101, 102, 103) -- reject, void, refund
						AND sub.liveindicator = 0
						AND sub.betfrom <> 'P'
						AND main.matchid = 29
						AND main.bettype = 29
						AND main.liveindicator = 0
						AND main.transdate >= @KickOffTime
						AND main.statusID NOT IN (101, 102, 103)
						AND tmp.TransId IS NULL
			END

		INSERT INTO dbo.TicketVoiding_RequestDetailTicket_SubParlay(RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId, MainTransId)
		SELECT @RequestId
			 , @IssueTypeId
			 , @SubIssueTypeId
			 , s.SubTransid
			 , s.matchid
			 , rd.Id
			 , s.MainTransId
		FROM #SpecialDeleteBets s
			INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) 
					ON rd.RequestId = @RequestId AND s.MatchId = rd.MatchId
	END

	DROP TABLE #SpecialDeleteBets
	DROP TABLE #tblSoldTicket
	DROP TABLE #tmpRefCodeSummary
	DROP TABLE #DangerAccept_SubParlayTickets
	DROP TABLE #TransidInRequest
END
GO