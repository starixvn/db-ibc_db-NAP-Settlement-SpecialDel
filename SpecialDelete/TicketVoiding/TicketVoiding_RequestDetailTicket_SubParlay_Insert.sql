/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestDetailTicket_SubParlay_Insert]
(	 
	@RequestId				INT
	,@MatchId				INT
	,@KickOffTime			DATETIME = NULL
	,@IssueTypeId			INT
	,@SubIssueTypeId		INT
	,@IsEditRequest			BIT = 0
	,@UserId				INT = NULL
	,@IP					VARCHAR(50) = NULL
	,@ActionId				TINYINT = 0
	,@WrongScoreInfo		VARCHAR(MAX) = NULL
	,@DangerAcceptedInfo	VARCHAR(MAX) = NULL
	,@RedCardInfo			VARCHAR(MAX) = NULL
	,@WrongHDPInfo			VARCHAR(MAX) = NULL
	,@Wrong1stHDPInfo		VARCHAR(MAX) = NULL
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
		- 20210525@Max: [TVS] Danger Accept Enhancement - Phase 9 [Redmine: #153216]
		- 20210621@Max: [TVS] Wrong Score Enhancement 1 [Redmine: #156349]
		- 20210714@July: [TVS] Modify the way to get move bet date [Redmine: #154974]
		- 20210802@July: TVS - Red Card Enhancement - Phase 1 [Redmine: #157097]
		- 20210827@Max: [TVS] Wrong Score Enhancement 2 - Do not exclude ticket in other request for Take Note action [Redmine: #157096]
		- 20211012@July: TVS - Danger Accept Enhancement - Phase 10 [Redmine: #155792]
		- 20211213@July: TVS - Remove code [Redmine: #165097]
		- 20220110@July: TVS - New issue type Wrong HDP and Wrong 1H HDP [Redmine: #146717]

	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @UnMarkedTransIds	  VARCHAR(MAX) = NULL
			,@UserName			  VARCHAR(100) = NULL
			,@MarkedTransIds	  VARCHAR(MAX) = NULL
			,@RemoveTransIds	  VARCHAR(MAX) = ''

	DECLARE	 @WrongScoreInfoXML		  XML = NULL
			,@DangerAcceptedInfoXML	  XML = NULL
			,@RedCardInfoXML		  XML = NULL
			,@WrongHDPInfoXML		  XML = NULL	
			,@Wrong1stHDPInfoXML	  XML = NULL

	CREATE TABLE #SpecialDeleteBets (
			GroupID               BIGINT,
			transid               BIGINT,
			SubTransid            BIGINT,
			refno                 BIGINT,
			custid                INT,
			odds                  MONEY,
			SubOdds               MONEY,
			oddsspread            MONEY,
			OddsType              INT,
			transdate             DATETIME,
			bettype               SMALLINT,
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
			Stake                 MONEY,
			currencyname          VARCHAR(20),
			STATUS                NVARCHAR(10),
			SubStatus             NVARCHAR(10),
			srecommend            INT,
			mrecommend            INT,
			recommend             INT,
			Transdesc             NVARCHAR(1000),
			ParlayType            SMALLINT DEFAULT(0), 
			IsMixParlay           BIT DEFAULT(0),
			modds                 MONEY,
			matchid               INT,
			MainTransId           BIGINT,
			WinLost               MONEY,
			IsMarked              BIT,
			LiveIndicator		  BIT
	)

	CREATE TABLE #DangerAccept_SubParlayTickets (TransId BIGINT, StatusId INT, MatchId INT, MainTransId BIGINT, isFinish BIT, VoidFromTime DATETIME, VoidToTime DATETIME, SubIssueTypeId SMALLINT)
	CREATE INDEX IX_TransId ON #DangerAccept_SubParlayTickets(TransId)

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
			,SubIssueTypeId			SMALLINT
			,HomeFavorite			VARCHAR(50)
			,AwayFavorite			VARCHAR(50)
			,HDPValue				VARCHAR(50)
			)

	DECLARE @tmpTransIDBatch TABLE (TransId	BIGINT, StatusId INT, MatchId INT, MainTransId BIGINT)

	CREATE TABLE #TransId_tmp (RequestId INT, IssueTypeId INT, SubIssueTypeId SMALLINT, TransId BIGINT, MatchId INT, RequestDetailId INT, MainTransId BIGINT)

	-- Check edit request after voided
	IF (EXISTS (SELECT TOP 1 1 FROM dbo.TicketVoiding_VoidingHistory WHERE RequestId = @RequestId))
	BEGIN
		RETURN;
	END

	IF @IssueTypeId IN (1, 10)
	BEGIN
		IF @IssueTypeId = 1
		BEGIN
			SET @DangerAcceptedInfoXML = CONVERT(XML, @DangerAcceptedInfo)
			INSERT INTO #tblGetLogInfo( 
					RequestID				
					,MatchID				
					,FilterFromTransTime	
					,FilterToTransTime			
					,FilterBy				
					,SingleCount			
					,MainParlayCount		
					,MinSingleTransId		
					,MaxSingleTransId		
					,MinMainParlayTransId	
					,MaxMainParlayTransId	
					,VoidFromTime			
					,VoidToTime				
					,LiveScores					
					,TypeAccept
					,SubIssueTypeId
				)
			SELECT @RequestId AS RequestId
					,t.c.value('@MatchId','INT') AS MatchID
					,t.c.value('@FilterFromTransTime','DATETIME') AS FilterFromTransTime
					,t.c.value('@FilterToTransTime','DATETIME') AS FilterToTransTime
					,t.c.value('@FilterBy','TINYINT') AS FilterBy
					,t.c.value('@SingleCount','INT') AS SingleCount
					,t.c.value('@MainParlayCount','INT') AS MainParlayCount
					,t.c.value('@MinSingleTransId','BIGINT') AS MinSingleTransId
					,t.c.value('@MaxSingleTransId','BIGINT') AS MaxSingleTransId
					,t.c.value('@MinMainParlayTransId','BIGINT') AS MinMainParlayTransId
					,t.c.value('@MaxMainParlayTransId','BIGINT') AS MaxMainParlayTransId
					,t.c.value('@VoidFromTime','DATETIME') AS VoidFromTime
					,t.c.value('@VoidToTime','DATETIME') AS VoidToTime
					,t.c.value('@LiveScores','VARCHAR(50)') AS LiveScores
					,'<r AA="' + t.c.value('@AATime','VARCHAR(10)') + '" PA="'+ t.c.value('@PATime','VARCHAR(10)') 
						+ '" SA="' + t.c.value('@SATime','VARCHAR(10)') + + '" IsMainMatch="' + t.c.value('@IsMainMatch','VARCHAR(10)') + '" />' AS TypeAccept
					,t.c.value('@SubIssueTypeId','SMALLINT') AS SubIssueTypeId
			FROM @DangerAcceptedInfoXML.nodes('root/r') t(c)
			OPTION (OPTIMIZE FOR (@DangerAcceptedInfoXML = NULL))
			
			INSERT INTO #TransidInRequest (TransId)
			SELECT tmp.transid
			FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) 
				INNER JOIN dbo.TicketVoiding_Request req WITH (NOLOCK) ON req.RequestId = rd.RequestId 
				CROSS APPLY (
							SELECT TransId
							FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay WITH (NOLOCK)
							WHERE RequestId = req.RequestId
						) AS tmp
				INNER JOIN #tblGetLogInfo l ON l.MatchID = rd.MatchId
			WHERE req.RequestId <> @RequestId AND req.ActionId <>2

			INSERT INTO #DangerAccept_SubParlayTickets (TransId, StatusId, MatchId, MainTransId, SubIssueTypeId)
			SELECT sub.transid
				, sub.statusID
				, sub.matchid
				, main.transid
				, l.SubIssueTypeId
			FROM #tblGetLogInfo l
				INNER LOOP JOIN dbo.bettransm sub WITH (NOLOCK) ON sub.matchid = l.MatchId
				INNER HASH JOIN bettrans AS main WITH (NOLOCK) ON main.refno = sub.refno 
			WHERE CASE WHEN l.FilterBy IN (0,1) THEN sub.transdate
							WHEN l.FilterBy = 2 AND sub.checktime IS NOT NULL THEN sub.checktime
							WHEN l.FilterBy = 2 AND sub.checktime IS NULL THEN sub.transdate
							END BETWEEN l.VoidFromTime AND l.VoidToTime
				AND main.transid BETWEEN l.MinMainParlayTransId AND l.MaxMainParlayTransId
				AND 1 = CASE WHEN @ActionId <>2 AND sub.statusID NOT IN (101, 102, 103) THEN 1
							 WHEN @ActionId =2 AND sub.statusID NOT IN (101, 103) THEN 1
							 ELSE 0 END
				AND sub.betfrom <> 'P'
				AND NOT EXISTS (SELECT TOP 1 1 
								FROM dbo.f_TVS_CheckingSubIssueTypeIdExcludeBettypes() f 
								WHERE f.bettype = sub.bettype 
									AND f.SubIssueTypeId = l.SubIssueTypeId )
		END
		IF @IssueTypeId = 10
		BEGIN
			SET @RedCardInfoXML = CONVERT(XML, @RedCardInfo)
			INSERT INTO #tblGetLogInfo( 
					RequestID				
					,MatchID				
					,FilterFromTransTime	
					,FilterToTransTime			
					,FilterBy				
					,SingleCount			
					,MainParlayCount		
					,MinSingleTransId		
					,MaxSingleTransId		
					,MinMainParlayTransId	
					,MaxMainParlayTransId	
					,VoidFromTime			
					,VoidToTime				
					,LiveScores					
					,TypeAccept
					,SubIssueTypeId
				)
			SELECT @RequestId AS RequestId
					,t.c.value('@MatchId','INT') AS MatchID
					,t.c.value('@FilterFromTransTime','DATETIME') AS FilterFromTransTime
					,t.c.value('@FilterToTransTime','DATETIME') AS FilterToTransTime
					,t.c.value('@FilterBy','TINYINT') AS FilterBy
					,t.c.value('@SingleCount','INT') AS SingleCount
					,t.c.value('@MainParlayCount','INT') AS MainParlayCount
					,t.c.value('@MinSingleTransId','BIGINT') AS MinSingleTransId
					,t.c.value('@MaxSingleTransId','BIGINT') AS MaxSingleTransId
					,t.c.value('@MinMainParlayTransId','BIGINT') AS MinMainParlayTransId
					,t.c.value('@MaxMainParlayTransId','BIGINT') AS MaxMainParlayTransId
					,t.c.value('@VoidFromTime','DATETIME') AS VoidFromTime
					,t.c.value('@VoidToTime','DATETIME') AS VoidToTime
					,t.c.value('@LiveScores','VARCHAR(50)') AS LiveScores
					,'<r AA="' + t.c.value('@AATime','VARCHAR(10)') + '" PA="'+ t.c.value('@PATime','VARCHAR(10)') 
						+ '" SA="' + t.c.value('@SATime','VARCHAR(10)') + + '" IsMainMatch="' + t.c.value('@IsMainMatch','VARCHAR(10)') + '" />' 
						AS TypeAccept
					,t.c.value('@SubIssueTypeId','SMALLINT') AS SubIssueTypeId
			FROM @RedCardInfoXML.nodes('root/r') t(c)
			OPTION (OPTIMIZE FOR (@RedCardInfoXML = NULL))

			INSERT INTO #TransidInRequest (TransId)
			SELECT tmp.transid
			FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) 
				INNER JOIN dbo.TicketVoiding_Request req WITH (NOLOCK) ON req.RequestId = rd.RequestId 
				CROSS APPLY (
							SELECT TransId
							FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay WITH (NOLOCK)
							WHERE RequestId = req.RequestId
						) AS tmp
				INNER JOIN #tblGetLogInfo l ON l.MatchID = rd.MatchId
			WHERE req.RequestId <> @RequestId AND req.ActionId <>2

			INSERT INTO #DangerAccept_SubParlayTickets (TransId, StatusId, MatchId, MainTransId, SubIssueTypeId)
			SELECT sub.transid
				, sub.statusID
				, sub.matchid
				, main.transid
				, l.SubIssueTypeId
			FROM #tblGetLogInfo l
				INNER LOOP JOIN dbo.bettransm sub WITH (NOLOCK) ON sub.matchid = l.MatchId
				INNER HASH JOIN bettrans AS main WITH (NOLOCK) ON main.refno = sub.refno 
			WHERE CASE WHEN l.FilterBy IN (0,1) THEN sub.transdate
							WHEN l.FilterBy = 2 AND sub.checktime IS NOT NULL THEN sub.checktime
							WHEN l.FilterBy = 2 AND sub.checktime IS NULL THEN sub.transdate
							END BETWEEN l.VoidFromTime AND l.VoidToTime
				AND main.transid BETWEEN l.MinMainParlayTransId AND l.MaxMainParlayTransId
				AND 1 = CASE WHEN @ActionId <>2 AND sub.statusID NOT IN (101, 102, 103) THEN 1
							 WHEN @ActionId =2 AND sub.statusID NOT IN (101, 103) THEN 1
							 ELSE 0 END
				AND sub.betfrom <> 'P'
		END

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
			WHILE (1=1)
			BEGIN
				DELETE TOP(4500) s 
				FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay s
				WHERE s.RequestId = @RequestId

				IF @@ROWCOUNT < 4500 BREAK

				WAITFOR DELAY '00:00:00.100'
			END
		END

		INSERT INTO #TransId_tmp(RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId, MainTransId)
		SELECT @RequestId
			, @IssueTypeId
			, t.SubIssueTypeId
			, t.TransId
			, t.MatchId
			, rd.Id AS RequestDetailId
			, t.MainTransId
		FROM #DangerAccept_SubParlayTickets t
			INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) ON rd.RequestId = @RequestId AND t.MatchId = rd.MatchId 
			OUTER APPLY (
								SELECT TOP 1 rs.TransId
								FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rs WITH (NOLOCK)
									INNER JOIN TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = rs.RequestId 
								WHERE rs.TransId = t.transid
									AND rs.MatchId = t.MatchId
									AND r.ActionId NOT IN (2)
									AND @ActionId <> 2
						)tmp
		WHERE tmp.TransId IS NULL

		WHILE (1=1)
		BEGIN
			DELETE TOP(4500) d
			OUTPUT DELETED.RequestId
				, DELETED.IssueTypeId
				, DELETED.SubIssueTypeId
				, DELETED.TransId
				, DELETED.MatchId
				, DELETED.RequestDetailId
				, DELETED.MainTransId
			INTO dbo.TicketVoiding_RequestDetailTicket_SubParlay (RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId, MainTransId)
			FROM #TransId_tmp d

			IF @@ROWCOUNT < 4500 BREAK
			
			WAITFOR DELAY '00:00:00.180'
		END
		
		--Mark Ticket
		IF @ActionId <>2
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
		ELSE --other action to take note
		BEGIN
			IF @IsEditRequest = 1
			BEGIN
				--Unmark ticket
				SELECT @MarkedTransIds = STUFF(
						(SELECT ',' + CONVERT(VARCHAR(50), tp.transid)
						FROM #DangerAccept_SubParlayTickets tp
						WHERE EXISTS (SELECT TOP 1 1 FROM dbo.MarkedTransaction mt WITH(NOLOCK) WHERE mt.TransId = tp.MainTransId AND mt.MatchId = tp.MatchId)
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

		INSERT INTO #DangerAccept_SubParlayTickets (TransId, StatusId, MatchId, MainTransId, VoidFromTime, VoidToTime)
		SELECT sub.transid
			, sub.statusID
			, @MatchId
			, main.transid
			, s.VoidFromTime
			, s.VoidToTime
		FROM dbo.bettransm sub WITH (NOLOCK)
			INNER HASH JOIN bettrans AS main WITH (NOLOCK) 
							ON	main.refno = sub.refno				
								AND sub.matchid = @matchid
			INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = sub.BetType
			CROSS APPLY (
				SELECT TOP(1) t.VoidFromTime, t.VoidToTime
				FROM #tblGetLogInfo t
				WHERE matchid = @MatchId
					AND ISNULL(sub.checktime, sub.transdate) BETWEEN VoidFromTime AND VoidToTime 	
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
			DELETE dbo.TicketVoiding_RequestDetailTicket_SubParlay
			WHERE RequestId = @RequestId
		END
	
		INSERT INTO dbo.TicketVoiding_RequestDetailTicket_SubParlay(RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId, MainTransId)
		SELECT @RequestId
			, @IssueTypeId
			, @SubIssueTypeId
			, t.TransId
			, t.MatchId
			, rd.Id AS RequestDetailId
			, t.MainTransId
		FROM #DangerAccept_SubParlayTickets t
			INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) ON t.MatchId = rd.MatchId  AND rd.VoidFromTime = t.VoidFromTime AND rd.VoidToTime = t.VoidToTime
			OUTER APPLY (
								SELECT TOP 1 rs.TransId
								FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rs WITH (NOLOCK)
									INNER JOIN TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = rs.RequestId 
								WHERE rs.TransId = t.transid
									AND rs.MatchId = @MatchId
									AND r.ActionId NOT IN (2)
									AND @ActionId <> 2
						)tmp
		WHERE rd.RequestId = @RequestId AND tmp.TransId IS NULL

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
	ELSE IF @IssueTypeId IN (8,9)
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
	ELSE IF @IssueTypeId IN (4, 5)
	BEGIN
		IF @IssueTypeId = 4
		BEGIN
			SET @WrongHDPInfoXML = CONVERT(XML, @WrongHDPInfo)
			INSERT INTO #tblGetLogInfo( 
					RequestID				
					,MatchID				
					,FilterFromTransTime	
					,FilterToTransTime			
					,FilterFromBetId
					,FilterToBetId
					,FilterBy				
					,SingleCount			
					,MainParlayCount		
					,MinSingleTransId		
					,MaxSingleTransId		
					,MinMainParlayTransId	
					,MaxMainParlayTransId	
					,VoidFromTime			
					,VoidToTime				
					,SubIssueTypeId
					,LiveScores
					,HomeFavorite
					,AwayFavorite
					,HDPValue
				)
			SELECT @RequestId AS RequestId
					,t.c.value('@MatchId','INT') AS MatchID
					,CASE WHEN t.c.value('@FilterFromTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterFromTransTime','DATETIME') END AS FilterFromTransTime
					,CASE WHEN t.c.value('@FilterToTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterToTransTime','DATETIME') END AS FilterToTransTime
					,CASE WHEN t.c.value('@FilterFromBetId','BIGINT') = 0 THEN NULL ELSE t.c.value('@FilterFromBetId','BIGINT') END AS FilterFromBetId
					,CASE WHEN t.c.value('@FilterToBetId','BIGINT') = 0 THEN NULL ELSE t.c.value('@FilterToBetId','BIGINT') END AS FilterToBetId
					,t.c.value('@FilterBy','TINYINT') AS FilterBy
					,t.c.value('@SingleCount','INT') AS SingleCount
					,t.c.value('@MainParlayCount','INT') AS MainParlayCount
					,t.c.value('@MinSingleTransId','BIGINT') AS MinSingleTransId
					,t.c.value('@MaxSingleTransId','BIGINT') AS MaxSingleTransId
					,t.c.value('@MinMainParlayTransId','BIGINT') AS MinMainParlayTransId
					,t.c.value('@MaxMainParlayTransId','BIGINT') AS MaxMainParlayTransId
					,t.c.value('@VoidFromTime','DATETIME') AS VoidFromTime
					,t.c.value('@VoidToTime','DATETIME') AS VoidToTime
					,t.c.value('@SubIssueTypeId','SMALLINT') AS SubIssueTypeId
					,t.c.value('@LiveScores','VARCHAR(50)') AS LiveScores
				    ,CASE WHEN ISNULL(t.c.value('@HomeFavorite','VARCHAR(50)'),'') ='' THEN NULL ELSE t.c.value('@HomeFavorite','VARCHAR(50)')  END AS HomeFavorite
			        ,CASE WHEN ISNULL(t.c.value('@AwayFavorite','VARCHAR(50)'),'') = '' THEN NULL ELSE t.c.value('@AwayFavorite','VARCHAR(50)')  END AS AwayFavorite
			        ,CASE WHEN ISNULL(t.c.value('@HdpValue','VARCHAR(50)'),'') = '' THEN NULL ELSE t.c.value('@HdpValue','VARCHAR(50)')  END AS HdpValue
			FROM @WrongHDPInfoXML.nodes('root/r') t(c)
			OPTION (OPTIMIZE FOR (@WrongHDPInfoXML = NULL))

			INSERT INTO #TransidInRequest (TransId)
			SELECT tmp.transid
			FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) 
				INNER JOIN dbo.TicketVoiding_Request req WITH (NOLOCK) ON req.RequestId = rd.RequestId 
				CROSS APPLY (
							SELECT TransId
							FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay WITH (NOLOCK)
							WHERE RequestId = req.RequestId
						) AS tmp
				INNER JOIN #tblGetLogInfo l ON l.MatchID = rd.MatchId
			WHERE req.RequestId <> @RequestId AND req.ActionId <>2

			INSERT INTO #DangerAccept_SubParlayTickets (TransId, StatusId, MatchId, MainTransId, SubIssueTypeId)
			SELECT sub.transid
				, sub.statusID
				, sub.matchid
				, main.transid
				, l.SubIssueTypeId
			FROM #tblGetLogInfo l
				INNER LOOP JOIN dbo.bettransm sub WITH (NOLOCK) ON sub.matchid = l.MatchId
				INNER HASH JOIN bettrans AS main WITH (NOLOCK) ON main.refno = sub.refno 
				OUTER APPLY (
					SELECT DISTINCT val 
					FROM dbo.f_SplitString(l.HomeFavorite, '&')
					WHERE val <> ''				
				)xHDPHome
				OUTER APPLY (
					SELECT DISTINCT val 
					FROM dbo.f_SplitString(l.AwayFavorite, '&')
					WHERE val <> ''				
				)xHDPAway
				OUTER APPLY (
					SELECT DISTINCT val 
					FROM dbo.f_SplitString(l.HdpValue, '&')
					WHERE val <> ''				
				)xHDPvalue
			WHERE sub.transdate BETWEEN l.VoidFromTime AND l.VoidToTime
				AND main.transid BETWEEN l.MinMainParlayTransId AND l.MaxMainParlayTransId
				AND 1 = CASE WHEN @ActionId <> 2 AND sub.statusID NOT IN (101, 102, 103) THEN 1
							 WHEN @ActionId = 2 AND sub.statusID NOT IN (101, 103) THEN 1
							 ELSE 0 END
				AND sub.betfrom <> 'P'
				AND 1 = CASE WHEN l.SubIssueTypeId = 8 AND sub.hdp1 = xHDPHome.val AND l.HomeFavorite IS NOT NULL THEN 1
							 WHEN l.SubIssueTypeId = 8 AND sub.hdp2 = xHDPAway.val AND l.AwayFavorite IS NOT NULL THEN 1
							 WHEN l.SubIssueTypeId = 22 AND sub.hdp2 = xHDPvalue.val AND l.HdpValue IS NOT NULL THEN 1 --Away Virtual Head Reversed
							 WHEN l.SubIssueTypeId = 23 AND sub.hdp1 = xHDPvalue.val AND l.HdpValue IS NOT NULL THEN 1 --Home Virtual Head Reversed
							 ELSE 0 END
				OPTION (MAXRECURSION 0)
		END
		IF @IssueTypeId = 5
		BEGIN
			SET @Wrong1stHDPInfoXML = CONVERT(XML, @Wrong1stHDPInfo)
			INSERT INTO #tblGetLogInfo( 
					RequestID				
					,MatchID				
					,FilterFromTransTime	
					,FilterToTransTime			
					,FilterFromBetId
					,FilterToBetId
					,FilterBy				
					,SingleCount			
					,MainParlayCount		
					,MinSingleTransId		
					,MaxSingleTransId		
					,MinMainParlayTransId	
					,MaxMainParlayTransId	
					,VoidFromTime			
					,VoidToTime				
					,SubIssueTypeId
					,LiveScores
					,HomeFavorite
					,AwayFavorite
					,HDPValue
				)
			SELECT @RequestId AS RequestId
					,t.c.value('@MatchId','INT') AS MatchID
					,CASE WHEN t.c.value('@FilterFromTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterFromTransTime','DATETIME') END AS FilterFromTransTime
					,CASE WHEN t.c.value('@FilterToTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterToTransTime','DATETIME') END AS FilterToTransTime
					,CASE WHEN t.c.value('@FilterFromBetId','BIGINT') = 0 THEN NULL ELSE t.c.value('@FilterFromBetId','BIGINT') END AS FilterFromBetId
					,CASE WHEN t.c.value('@FilterToBetId','BIGINT') = 0 THEN NULL ELSE t.c.value('@FilterToBetId','BIGINT') END AS FilterToBetId
					,t.c.value('@FilterBy','TINYINT') AS FilterBy
					,t.c.value('@SingleCount','INT') AS SingleCount
					,t.c.value('@MainParlayCount','INT') AS MainParlayCount
					,t.c.value('@MinSingleTransId','BIGINT') AS MinSingleTransId
					,t.c.value('@MaxSingleTransId','BIGINT') AS MaxSingleTransId
					,t.c.value('@MinMainParlayTransId','BIGINT') AS MinMainParlayTransId
					,t.c.value('@MaxMainParlayTransId','BIGINT') AS MaxMainParlayTransId
					,t.c.value('@VoidFromTime','DATETIME') AS VoidFromTime
					,t.c.value('@VoidToTime','DATETIME') AS VoidToTime
					,t.c.value('@SubIssueTypeId','SMALLINT') AS SubIssueTypeId
					,t.c.value('@LiveScores','VARCHAR(50)') AS LiveScores
				    ,CASE WHEN ISNULL(t.c.value('@HomeFavorite','VARCHAR(50)'),'') ='' THEN NULL ELSE t.c.value('@HomeFavorite','VARCHAR(50)')  END AS HomeFavorite
			        ,CASE WHEN ISNULL(t.c.value('@AwayFavorite','VARCHAR(50)'),'') = '' THEN NULL ELSE t.c.value('@AwayFavorite','VARCHAR(50)')  END AS AwayFavorite
			        ,CASE WHEN ISNULL(t.c.value('@HdpValue','VARCHAR(50)'),'') = '' THEN NULL ELSE t.c.value('@HdpValue','VARCHAR(50)')  END AS HdpValue
			FROM @Wrong1stHDPInfoXML.nodes('root/r') t(c)
			OPTION (OPTIMIZE FOR (@Wrong1stHDPInfoXML = NULL))

			INSERT INTO #TransidInRequest (TransId)
			SELECT tmp.transid
			FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) 
				INNER JOIN dbo.TicketVoiding_Request req WITH (NOLOCK) ON req.RequestId = rd.RequestId 
				CROSS APPLY (
							SELECT TransId
							FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay WITH (NOLOCK)
							WHERE RequestId = req.RequestId
						) AS tmp
				INNER JOIN #tblGetLogInfo l ON l.MatchID = rd.MatchId
			WHERE req.RequestId <> @RequestId AND req.ActionId <>2

			INSERT INTO #DangerAccept_SubParlayTickets (TransId, StatusId, MatchId, MainTransId, SubIssueTypeId)
			SELECT sub.transid
				, sub.statusID
				, sub.matchid
				, main.transid
				, l.SubIssueTypeId
			FROM #tblGetLogInfo l
				INNER LOOP JOIN dbo.bettransm sub WITH (NOLOCK) ON sub.matchid = l.MatchId
				INNER HASH JOIN bettrans AS main WITH (NOLOCK) ON main.refno = sub.refno 
				OUTER APPLY (
					SELECT DISTINCT val 
					FROM dbo.f_SplitString(l.HomeFavorite, '&')
					WHERE val <> ''				
				)xHDPHome
				OUTER APPLY (
					SELECT DISTINCT val 
					FROM dbo.f_SplitString(l.AwayFavorite, '&')
					WHERE val <> ''				
				)xHDPAway
				OUTER APPLY (
					SELECT DISTINCT val 
					FROM dbo.f_SplitString(l.HdpValue, '&')
					WHERE val <> ''				
				)xHDPvalue
			WHERE sub.transdate BETWEEN l.VoidFromTime AND l.VoidToTime
				AND main.transid BETWEEN l.MinMainParlayTransId AND l.MaxMainParlayTransId
				AND 1 = CASE WHEN @ActionId <> 2 AND sub.statusID NOT IN (101, 102, 103) THEN 1
							 WHEN @ActionId = 2 AND sub.statusID NOT IN (101, 103) THEN 1
							 ELSE 0 END
				AND sub.betfrom <> 'P' AND sub.bettype = 7
				AND 1 = CASE WHEN l.SubIssueTypeId = 9 AND sub.hdp1 = xHDPHome.val AND l.HomeFavorite IS NOT NULL THEN 1
							 WHEN l.SubIssueTypeId = 9 AND sub.hdp2 = xHDPAway.val AND l.AwayFavorite IS NOT NULL THEN 1
							 WHEN l.SubIssueTypeId = 24 AND sub.hdp2 = xHDPvalue.val AND l.HdpValue IS NOT NULL THEN 1 --Away Virtual Head Reversed
							 WHEN l.SubIssueTypeId = 25 AND sub.hdp1 = xHDPvalue.val AND l.HdpValue IS NOT NULL THEN 1 --Home Virtual Head Reversed
							 ELSE 0 END
				OPTION (MAXRECURSION 0)
		END

		SELECT @Username = (SELECT c.username FROM CustDB.dbo.Customer c WITH (NOLOCK) WHERE c.custid = @UserId)
		------------------------------------------------------------------------------------------------------------
		--Edit from to time of Danger Accepted issue -> unmark ticket change void time
		SELECT @RemoveTransIds = STUFF((SELECT ',' + CAST(rdt.transid AS VARCHAR(50)) 
											FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rdt WITH(NOLOCK)
												INNER JOIN MarkedTransaction mt WITH(NOLOCK) ON mt.TransId = rdt.MainTransId AND mt.MatchId = rdt.MatchId
												LEFT JOIN #DangerAccept_SubParlayTickets tp ON rdt.TransId=tp.transid
												LEFT JOIN #TransidInRequest tr on tr.TransId = rdt.TransId
											WHERE tp.TransId IS NULL
												  AND tr.TransId IS NULL
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
			WHILE (1=1)
			BEGIN
				DELETE TOP(4500) s 
				FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay s
				WHERE s.RequestId = @RequestId

				IF @@ROWCOUNT < 4500 BREAK

				WAITFOR DELAY '00:00:00.100'
			END
		END

		INSERT INTO #TransId_tmp(RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId, MainTransId)
		SELECT @RequestId
			, @IssueTypeId
			, t.SubIssueTypeId
			, t.TransId
			, t.MatchId
			, rd.Id AS RequestDetailId
			, t.MainTransId
		FROM #DangerAccept_SubParlayTickets t
			INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) ON rd.RequestId = @RequestId AND t.MatchId = rd.MatchId 
			OUTER APPLY (
								SELECT TOP 1 rs.TransId
								FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rs WITH (NOLOCK)
									INNER JOIN TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = rs.RequestId 
								WHERE rs.TransId = t.transid
									AND rs.MatchId = t.MatchId
									AND r.ActionId NOT IN (2)
									AND @ActionId <> 2
						)tmp
		WHERE tmp.TransId IS NULL

		WHILE (1=1)
		BEGIN
			DELETE TOP(4500) d
			OUTPUT DELETED.RequestId
				, DELETED.IssueTypeId
				, DELETED.SubIssueTypeId
				, DELETED.TransId
				, DELETED.MatchId
				, DELETED.RequestDetailId
				, DELETED.MainTransId
			INTO dbo.TicketVoiding_RequestDetailTicket_SubParlay (RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId, MainTransId)
			FROM #TransId_tmp d

			IF @@ROWCOUNT < 4500 BREAK
			
			WAITFOR DELAY '00:00:00.180'
		END
		
		--Mark Ticket
		IF @ActionId <>2
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
		ELSE --other action to take note
		BEGIN
			IF @IsEditRequest = 1
			BEGIN
				--Unmark ticket
				SELECT @MarkedTransIds = STUFF(
						(SELECT ',' + CONVERT(VARCHAR(50), tp.transid)
						FROM #DangerAccept_SubParlayTickets tp
						WHERE EXISTS (SELECT TOP 1 1 FROM dbo.MarkedTransaction mt WITH(NOLOCK) WHERE mt.TransId = tp.MainTransId AND mt.MatchId = tp.MatchId)
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
	DROP TABLE #SpecialDeleteBets
	DROP TABLE #DangerAccept_SubParlayTickets
	DROP TABLE #TransidInRequest
	DROP TABLE #tblGetLogInfo
	DROP TABLE #TransId_tmp 
END
GO