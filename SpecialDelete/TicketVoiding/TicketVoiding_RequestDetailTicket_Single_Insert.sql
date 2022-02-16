/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestDetailTicket_Single_Insert]
(	 
	@RequestId				INT
	,@MatchId				INT		= 0
	,@KickOffTime			DATETIME = NULL
	,@IssueTypeId			INT
	,@SubIssueTypeId		INT = NULL
	,@TransIds				VARCHAR(MAX) = NULL
	,@IsEditRequest			BIT = 0
	,@UserId				INT = NULL
	,@IP					VARCHAR(50) = NULL
	,@ActionId				TINYINT = 0
	,@FilterBy				TINYINT = NULL
	,@UserNames				VARCHAR(MAX) = NULL
	,@ProductIds			VARCHAR(50)  = NULL
	,@StatusIds				VARCHAR(50)  = NULL
	,@FromDate				DATETIME     = NULL
    ,@ToDate				DATETIME     = NULL
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
		- 20210201@Max: Hotfix - TVS - Abnormal Accounts [Redmine: #149697]
		- 20210222@July: Hotfix - AC Duplicated customer getting of add request validation [Redmine: #150382]
		- 20210302@July: TVS - Integrate Cricket AIO - [Redmine: #150075]
		- 20210329@Max: TVS - Correct Ticket on DBTP [Redmine: #151954]
		- 20210408@July: TVS - New Issue Type - AB (Real Member)- [Redmine: #147175]
		- 20210413@Max: [TVS] SP tuning for EC20 - P1 [Redmine: #152817]
		- 20210427@Max: TVS - New Issue Type - Wrong Score - [Redmine: #140953]
		- 20210524@Max: [TVS] Wrong Score - Void 2H tickets in range time [Redmine: #155598]
		- 20210525@July: [TVS] Exclude PinGoal from Auto Void Winning process [Redmine: #155374]
		- 20210526@July: TVS - Danger Accept Enhancement - Phase 8 [Redmine: #152051]
		- 20210525@Max: [TVS] Danger Accept Enhancement - Phase 9 [Redmine: #153216]
		- 20210621@Max: [TVS] Wrong Score Enhancement 1 [Redmine: #156349]
		- 20210714@Max: [TVS] Modify the way to get move bet date [Redmine: #154974]
		- 20210802@July: TVS - Red Card Enhancement - Phase 1 [Redmine: #157097]
		- 20210827@Max: [TVS] Wrong Score Enhancement 2 - Do not exclude ticket in other request for Take Note action [Redmine: #157096]
		- 20211012@July: TVS - Danger Accept Enhancement - Phase 10 [Redmine: #155792]
		- 20211101@July: TVS - Abnormal Bet - Void Mix Parlay Ticket [Redmine: #161337]
		- 20211118@Kathy: Tuning performance [Redmine:#164819]
		- 20211123@July: TVS - Void Archived Tickets [Redmine: #140180]
		- 20211207@July: Remove code CashOut [Redmine: #165097]
		- 20220110@July: TVS - New issue type Wrong HDP and Wrong 1H HDP [Redmine: #146717]

	Param's explanation:
		(+) @FilterBy:	
					  Danger Accepted, Red Card issuetype( 1 - by Trans time, 2 - by Accepted time)
					  Abnormal Bet issuetype (NULL - Single ticket, 1- Mix-parlay ticket)
		(+) @Products : 1 - Sportbook
						2 - Parlay
						3 - Bet Builder
						4 - Outright
						5 - Saba
						6 - NonSport
		(+) @StatusIds : All, Running, Won, Lose, Draw
		
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @UnMarkedTransIds	  VARCHAR(MAX) = NULL
			,@UserName		      VARCHAR(100) = NULL
			,@MarkedTransIds	  VARCHAR(MAX) = NULL
			,@RemoveTransIds	  VARCHAR(MAX) = ''
			,@IsSB				  BIT = 0
			,@IsParlay			  BIT = 0
			,@IsBB				  BIT = 0
			,@IsOutright		  BIT = 0
			,@IsSaba			  BIT = 0
			,@IsNonSport		  BIT = 0
			,@FromWinlostDate     DATETIME
			,@RequestDetailId_DA  INT
			,@movebetdate SMALLDATETIME
			,@maxdate 	DATETIME = '9999-01-01'

	DECLARE	 @WrongScoreInfoXML		  XML = NULL
			,@DangerAcceptedInfoXML	  XML = NULL
			,@RedCardInfoXML		  XML = NULL
			,@WrongHDPInfoXML		  XML = NULL	
			,@Wrong1stHDPInfoXML	  XML = NULL

	CREATE TABLE #SpecialDeleteBets (
			GroupID               BIGINT,
			transid               BIGINT,
			refno                 BIGINT,
			custid                INT,
			odds                  MONEY,
			oddsspread            MONEY,
			transdate             DATETIME,
			bettype               SMALLINT,
			betteam               NVARCHAR(10),
			betcheck              NVARCHAR(50),
			hdp1                  SMALLMONEY,
			hdp2                  SMALLMONEY,
			livehomescore         SMALLINT,
			liveawayscore         SMALLINT,
			Stake                 MONEY,
			STATUS                NVARCHAR(10),
			srecommend            INT,
			mrecommend            INT,
			recommend             INT,
			betid                 BIGINT DEFAULT(0),
			betdaqid              BIGINT,
			sporttype             SMALLINT,
			ExtraInfo             VARCHAR(1000),
			matchid               INT,
			WalletType            TINYINT,
			RefCode               BIGINT,
			BonusID               INT,
			MainTransId           BIGINT,
			WinLost               MONEY,
			IsMarked              BIT,
			LiveIndicator		  BIT
	)

	CREATE TABLE #tmpRefCodeSummary (
			RefCode  BIGINT,
			custid   INT,
			matchid	 INT,
			bettype  SMALLINT,
			transid  BIGINT,
			IsMarked BIT
	)

	CREATE TABLE #DangerAccept_SingleTickets (TransId BIGINT, StatusId INT, MatchId INT, isFinish BIT, VoidFromTime DATETIME, VoidToTime DATETIME, SubIssueTypeId SMALLINT, refno BIGINT, bettype SMALLINT, betid BIGINT)
	CREATE INDEX IX_TransId ON #DangerAccept_SingleTickets(TransId)

	CREATE TABLE #TransidInRequest (TransId BIGINT)

	DECLARE @tmpTransIDBatch TABLE (TransId	BIGINT, StatusId INT)
	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT, ProductID TINYINT)
	DECLARE @Status_tmp TABLE (StatusId TINYINT)

	CREATE INDEX IX_SpecialDeleteBets_RefCode ON #SpecialDeleteBets(RefCode)
	CREATE INDEX IX_tmpRefCodeSummary_Refcode ON #tmpRefCodeSummary (RefCode)

	CREATE TABLE #transIdTemp (transid BIGINT PRIMARY KEY,StatusId INT, MatchId INT, bettype SMALLINT, isFinish BIT)
	CREATE TABLE #InputUsernameList ( Username VARCHAR(30),custid INT, roleid TINYINT)
	CREATE TABLE #InputValidCustid_2 (custid INT)
	CREATE TABLE #InputValidCustid_tmp (custid INT)
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
	CREATE TABLE #TransId_tmp (RequestId INT, IssueTypeId INT, SubIssueTypeId SMALLINT, TransId BIGINT, MatchId INT, RequestDetailId INT, bettype SMALLINT, betid BIGINT)

	-- Check edit request after voided
	IF (EXISTS (SELECT TOP 1 1 FROM dbo.TicketVoiding_VoidingHistory WITH(NOLOCK) WHERE RequestId = @RequestId))
	BEGIN
		RETURN;
	END

	IF @IssueTypeId IN (1, 10)
	BEGIN
		INSERT INTO @bettype_tmp (bettype)
		SELECT DISTINCT pt.bettype
		FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
		WHERE pt.ProductID = 1 -- Sportsbook
		AND pt.bettype NOT IN (10, 9, 29) -- outright, parlay
		AND pt.bettype NOT BETWEEN 221 AND 227 -- Fast Market
		AND pt.SubProduct NOT IN ('Bet Builder', 'MG-SuperLive', 'BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet Builder, Metric Gaming, Bet trade (BT-)

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
							FROM dbo.TicketVoiding_RequestDetailTicket_Single WITH (NOLOCK)
							WHERE RequestId = req.RequestId
						) AS tmp
				INNER JOIN #tblGetLogInfo l ON l.MatchID = rd.MatchId
			WHERE req.RequestId <> @RequestId AND req.ActionId <>2

			INSERT INTO #DangerAccept_SingleTickets (TransId, StatusId, MatchId, SubIssueTypeId, refno, bettype, betid)
			SELECT b.transid
				, b.statusID
				, b.matchid
				, t.SubIssueTypeId
				, b.refno
				, b.bettype
				, b.betid
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
				INNER JOIN #tblGetLogInfo t ON t.MatchID = b.matchid 
			WHERE b.betfrom <> 'P'
				AND CASE WHEN t.FilterBy IN (0,1) THEN b.transdate
						WHEN t.FilterBy = 2 AND b.checktime IS NOT NULL THEN b.checktime
						WHEN t.FilterBy = 2 AND b.checktime IS NULL THEN b.transdate 
						END BETWEEN t.VoidFromTime AND t.VoidToTime 
				AND b.transid BETWEEN t.MinSingleTransId AND t.MaxSingleTransId
				AND 1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1
								WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
								ELSE 0 END
				AND NOT EXISTS (SELECT TOP 1 1 
								FROM dbo.f_TVS_CheckingSubIssueTypeIdExcludeBettypes() f 
								WHERE f.bettype = b.bettype 
									AND f.SubIssueTypeId = t.SubIssueTypeId )
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
							FROM dbo.TicketVoiding_RequestDetailTicket_Single WITH (NOLOCK)
							WHERE RequestId = req.RequestId
						) AS tmp
				INNER JOIN #tblGetLogInfo l ON l.MatchID = rd.MatchId
			WHERE req.RequestId <> @RequestId AND req.ActionId <>2

			INSERT INTO #DangerAccept_SingleTickets (TransId, StatusId, MatchId, SubIssueTypeId, refno, bettype, betid)
			SELECT b.transid
				, b.statusID
				, b.matchId
				, t.SubIssueTypeId
				, b.refno
				, b.bettype
				, b.betid
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
				INNER JOIN #tblGetLogInfo t ON t.MatchID = b.matchid
			WHERE b.betfrom <> 'P'
				AND CASE WHEN t.FilterBy IN (0,1) THEN b.transdate
						WHEN t.FilterBy = 2 AND b.checktime IS NOT NULL THEN b.checktime
						WHEN t.FilterBy = 2 AND b.checktime IS NULL THEN b.transdate 
						END BETWEEN t.VoidFromTime AND t.VoidToTime 
				AND b.transid BETWEEN t.MinSingleTransId AND t.MaxSingleTransId
				AND 1 = CASE WHEN @ActionId <> 2 AND b.statusID NOT IN (101, 102, 103) THEN 1
							 WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
							 ELSE 0 END
		END
							  
		SELECT @Username = (SELECT c.username FROM CustDB.dbo.Customer c WITH (NOLOCK) WHERE c.custid = @UserId)
		------------------------------------------------------------------------------------------------------------
		--Edit from to time of Danger Accepted issue -> unmark ticket change void time
		SELECT @RemoveTransIds = STUFF((SELECT ',' + CAST(rdt.transid AS VARCHAR(50)) 
											FROM dbo.TicketVoiding_RequestDetailTicket_Single rdt WITH(NOLOCK)
												INNER JOIN MarkedTransaction mt WITH(NOLOCK) ON mt.TransId = rdt.transid AND mt.MatchId = rdt.MatchId
												LEFT JOIN #DangerAccept_SingleTickets tp ON rdt.TransId=tp.transid
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
				FROM dbo.TicketVoiding_RequestDetailTicket_Single s
				WHERE s.RequestId = @RequestId

				IF @@ROWCOUNT < 4500 BREAK

				WAITFOR DELAY '00:00:00.100'
			END
		END

		INSERT INTO #TransId_tmp (RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId, bettype, betid)
		SELECT @RequestId
			, @IssueTypeId
			, t.SubIssueTypeId
			, t.TransId
			, t.MatchId
			, rd.Id AS RequestDetailId
			, t.bettype
			, t.betid
		FROM #DangerAccept_SingleTickets t
			INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) ON rd.RequestId = @RequestId AND t.MatchId = rd.MatchId  
			OUTER APPLY (
								SELECT TOP 1 rs.TransId
								FROM dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK)
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
				, DELETED.bettype
				, DELETED.betid
			INTO dbo.TicketVoiding_RequestDetailTicket_Single (RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId, bettype, betid)
			FROM #TransId_tmp d

			IF @@ROWCOUNT < 4500 BREAK
			
			WAITFOR DELAY '00:00:00.180'
		END

		IF @ActionId <> 2
		BEGIN
			--Mark Ticket
			WHILE (1=1)
			BEGIN
				DELETE @tmpTransIDBatch
					
				UPDATE TOP(2000) t
					SET isFinish = 1
				OUTPUT DELETED.TransId, DELETED.StatusId					
				INTO @tmpTransIDBatch(TransId, StatusId)
				FROM #DangerAccept_SingleTickets t 
				WHERE isFinish IS NULL
				
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
		ELSE -- take note
		BEGIN
			IF @IsEditRequest = 1
			BEGIN
				SELECT @MarkedTransIds = STUFF(
						(SELECT ',' + CONVERT(VARCHAR(50), tp.transid)
						FROM #DangerAccept_SingleTickets tp
						WHERE EXISTS (SELECT TOP 1 1 FROM dbo.MarkedTransaction mt WITH(NOLOCK) WHERE mt.TransId = tp.transid)
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
	ELSE IF @IssueTypeId IN (11,15) AND @TransIds IS NOT NULL
	BEGIN
		IF @IsEditRequest = 1
		BEGIN
			DELETE dbo.TicketVoiding_RequestDetailTicket_Single
			WHERE RequestId = @RequestId
		END

		INSERT INTO dbo.TicketVoiding_RequestDetailTicket_Single (RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId, bettype, betid)
		SELECT DISTINCT @RequestId, @IssueTypeId, @SubIssueTypeId, val, @MatchId, tmp.Id AS RequestDetailId, tmp.bettype, tmp.betid
		FROM dbo.f_SplitString(@TransIds, ',') l
			CROSS APPLY (
						SELECT rd.Id, b.bettype, b.betid
						FROM dbo.bettrans b WITH(NOLOCK) 
							INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) ON b.matchid = rd.MatchId
						WHERE b.matchid = @MatchId AND rd.RequestId = @RequestId
							AND l.val = b.transid
							AND 1 = CASE WHEN @FilterBy IS NULL THEN 1
										 WHEN @FilterBy = 1 AND b.betteam = '1' THEN 1 ELSE 0 END
						)tmp
		WHERE l.val <> ''
		OPTION (MAXRECURSION 0)
	END
	ELSE IF @IssueTypeId = 13  AND @UserNames IS NOT NULL --Abnormal Account
	BEGIN
		
		--Get Movebetdate
		EXEC dbo.NAP_Admin_GetMovebetDate @movebetdate = @movebetdate OUTPUT
	
		SELECT @FromWinlostDate	= ISNULL(@FromDate, @movebetdate)
			 , @FromWinlostDate 	= CASE WHEN @FromWinlostDate <= @movebetdate THEN DATEADD(d, 1, @movebetdate) ELSE @FromWinlostDate END
		
		IF @ToDate IS NULL
		BEGIN
	
			SET @ToDate = @maxdate
		END
	
		INSERT INTO @Status_tmp (StatusId)
		SELECT DISTINCT val 
		FROM dbo.f_SplitString(@StatusIds, ',')
		WHERE val <> ''
		OPTION (MAXRECURSION 0)

		SELECT  @IsSB = CASE WHEN CHARINDEX('1',@ProductIds) > 0 THEN 1 ELSE 0 END
				, @IsParlay = CASE WHEN CHARINDEX('2',@ProductIds) > 0 THEN 1 ELSE 0 END
				, @IsBB = CASE WHEN CHARINDEX('3',@ProductIds) > 0 THEN 1 ELSE 0 END
				, @IsOutright = CASE WHEN CHARINDEX('4',@ProductIds) > 0 THEN 1 ELSE 0 END
				, @IsSaba = CASE WHEN CHARINDEX('5',@ProductIds) > 0 THEN 1 ELSE 0 END
				, @IsNonSport = CASE WHEN CHARINDEX('6',@ProductIds) > 0 THEN 1 ELSE 0 END
	
		INSERT INTO #InputUsernameList (Username, custid, roleid)
		SELECT l.val
			  ,ci.custid
			  ,ci.roleid
		FROM dbo.f_SplitString(@UserNames, ',') l
			LEFT JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON l.val = ci.username
		WHERE ci.custid IS NOT NULL
			AND val <> ''
		OPTION (MAXRECURSION 0)

		-- get SMA roleid = 2
		INSERT INTO #InputValidCustid_2 (custid)		
		SELECT l.custid
		FROM #InputUsernameList l
		WHERE l.roleid = 2

		IF EXISTS (SELECT TOP 1 1 FROM #InputUsernameList WHERE roleid = 3)
		BEGIN
			INSERT INTO #InputValidCustid_2 (custid)	
			SELECT ci.custid
			FROM #InputUsernameList l
				INNER JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON l.custid = ci.mrecommend
			WHERE l.roleid = 3 AND ci.roleid = 2
		END

		IF EXISTS (SELECT TOP 1 1 FROM #InputUsernameList WHERE roleid = 4)
		BEGIN
			INSERT INTO #InputValidCustid_2 (custid)
			SELECT ci.custid
			FROM #InputUsernameList l
				INNER JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON l.custid = ci.srecommend
			WHERE l.roleid = 4 AND ci.roleid = 2	
		END

		-- list of member to process
		INSERT INTO #InputValidCustid_tmp (CustID)
		SELECT  CustID
		FROM #InputUsernameList l
		WHERE l.roleid =1
		UNION
		SELECT ci.CustID
		FROM #InputValidCustid_2 lt
			INNER JOIN CustDB.dbo.custInfo ci WITH (NOLOCK)
			ON lt.custid = ci.recommend
		WHERE ci.roleid = 1

		INSERT INTO @bettype_tmp (bettype, ProductID)
		SELECT DISTINCT pt.bettype, pt.ProductID
		FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
		WHERE 1 = CASE WHEN @UserNames IS NULL THEN 1
					ELSE CASE
							WHEN (@IsSB = 1 OR @IsSaba = 1) 
								AND pt.ProductID = 1 
								AND pt.BetType NOT IN (9,29,10)
								AND pt.SubProduct NOT IN ('Bet Builder') THEN 1 -- Sportsbook
							WHEN @IsOutright = 1 AND pt.bettype IN (10) THEN 1 --Outright
							WHEN @IsParlay = 1 AND pt.bettype IN (9, 29) THEN 1 --parlay, mix-parlay
							WHEN @IsBB = 1 AND pt.SubProduct IN ('Bet Builder') THEN 1 --Bet Builder
							WHEN @IsNonSport = 1 AND ProductID IN (3,5,27) AND pt.SportType NOT IN (168) THEN 1
						ELSE 0 END
				END
			AND pt.SubProduct NOT IN ('BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet trade (BT-)
			AND pt.bettype NOT IN (31,32,33,71,72,73)  -- NOT IN [Racing, Casino]
			AND pt.bettype NOT IN (911, 912, 913, 914) -- Cash-out subticket
			AND pt.bettype NOT BETWEEN 1501 AND 1599   -- NOT IN Keno

		INSERT INTO #transIdTemp (transid, statusID, MatchId, bettype)
		SELECT	b.translogid AS transid
				,b.statusID  -- add new
				,b.eventID
				,b.gameID
		FROM	dbo.translog AS b WITH (NOLOCK)
			INNER JOIN #InputValidCustid_tmp c ON c.CustId = b.custid
		WHERE	b.winlostdate BETWEEN @FromWinlostDate AND @ToDate 
				AND b.GameID BETWEEN 801 AND 806
				AND 1 = CASE WHEN EXISTS (SELECT 1 FROM @Status_tmp WHERE statusID IN(0,1)) AND statusID = 0 THEN 1 ELSE 0 END
				AND @IsSB = 1
				
		UNION ALL
		SELECT CASE WHEN b.bettype BETWEEN 801 AND 806 THEN b.refno ELSE b.transid END
				,b.statusID
				,b.matchid
				,b.bettype
		FROM dbo.bettrans AS b WITH (NOLOCK)
			OUTER APPLY (
				SELECT TOP 1 1 LeagueGroupID 
				FROM dbo.match m WITH (NOLOCK)
					INNER JOIN dbo.League l WITH (NOLOCK) ON l.leagueid = m.leagueid
				WHERE m.matchid = b.matchid
					AND ISNULL(l.LeagueGroupID,0) IN (42,74,108,113)
			)ml
			OUTER APPLY (
				SELECT TOP 1 m.sporttype 
				FROM dbo.match m WITH (NOLOCK)
				WHERE m.matchid = b.matchid
					AND m.sporttype = 50
			)mc
			INNER JOIN #InputValidCustid_tmp c ON c.CustId = b.custid
			INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
		WHERE b.winlostdate BETWEEN @FromWinlostDate AND @ToDate 
			AND 1 = CASE 
						WHEN @IsSB = 1 
							AND b.bettype BETWEEN 801 AND 806 
							AND b.statusID NOT IN (0, 101, 102, 103) THEN 1 
						WHEN (@IsSB = 1 OR @IsBB = 1 OR @IsOutright = 1 OR @IsParlay = 1 OR @IsNonSport = 1)
							AND b.bettype NOT BETWEEN 801 AND 806-- MG
							AND ml.LeagueGroupID IS NULL 
							AND mc.sporttype IS NULL --exclude cricket
							THEN 1
						WHEN @IsSaba = 1 
							AND ml.LeagueGroupID IS NOT NULL THEN 1								
					ELSE 0 END	
			AND statusID IN (SELECT statusID FROM @Status_tmp)

		-- Check exists in the request
		INSERT INTO #TransidInRequest (TransId)
		SELECT DISTINCT rs.TransId
		FROM  dbo.TicketVoiding_Request r WITH (NOLOCK) 
			INNER JOIN dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK)
						ON rs.RequestId = r.RequestId
			CROSS APPLY (
						SELECT TOP 1 t.MatchId, t.transid
						FROM #transIdTemp t
						WHERE t.MatchId = rs.MatchId 
							AND rs.TransId = t.transid
				)t
		WHERE r.RequestId <> @RequestId AND r.ActionId NOT IN (2)
			
		--Edit from to time of Abnormal account issue -> unmark ticket change void time
		SELECT @RemoveTransIds = STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
											FROM dbo.TicketVoiding_RequestDetailTicket_Single rdt WITH(NOLOCK)
											WHERE NOT EXISTS( SELECT TOP 1 1 FROM #transIdTemp tp WHERE rdt.TransId = tp.transid)
												  AND NOT EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = rdt.TransId)-- exist in # request
												  AND EXISTS (SELECT TOP 1 1 FROM dbo.MarkedTransaction mt WITH(NOLOCK) WHERE mt.TransId = rdt.transid)
												  AND rdt.RequestId = @RequestId
											FOR XML PATH('')
										), 1,1,'')
		IF @RemoveTransIds IS NOT NULL
		BEGIN
			EXEC dbo.Nap_SpecialDelete_MarkedTickets_Update @TransIds = @RemoveTransIds, @UserId = @UserId, @Username = @Username, @IP = @IP
																, @RequestId = @RequestId, @LogActionId = 90501, @IsLockMatch = 0
		END

		--If all data are valid, Mark all running tickets
		IF @ActionId <> 2 -- store tickets of 'Manual Void', 'Waiting' & 'Void Instant' request
		BEGIN
			-- Remove transid exists request
			DELETE 
			FROM #transIdTemp
			WHERE transid IN ( SELECT transid FROM #TransidInRequest) 

			-- Mark Ticket
			WHILE (1=1)
			BEGIN
				DELETE @tmpTransIDBatch
					
				UPDATE TOP(2000) t
					SET isFinish = 1
				OUTPUT DELETED.TransId, DELETED.StatusId					
				INTO @tmpTransIDBatch(TransId, StatusId)
				FROM #transIdTemp t
					INNER JOIN @bettype_tmp pt ON t.bettype = pt.bettype
				WHERE isFinish IS NULL
					AND t.bettype NOT BETWEEN 801 AND 806 AND pt.ProductID NOT IN (3,5,27) -- Not mark ticket Metric Gaming, Number Game, Virtual Sport, Virtual Sports 2
					AND t.bettype NOT IN (38, 9, 29, 10) -- Bet Builder, Main Parlay, Outright
					  
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
		ELSE -- take note
		BEGIN
			IF @IsEditRequest = 1
			BEGIN
				SELECT @MarkedTransIds = STUFF(
						(SELECT ',' + CONVERT(VARCHAR(50), tp.transid)
						FROM #transIdTemp tp
						WHERE EXISTS (SELECT TOP 1 1 FROM dbo.MarkedTransaction mt WITH(NOLOCK) WHERE mt.TransId = tp.transid)
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

			--Search by TransIds
		IF (EXISTS(SELECT TOP 1 1 FROM #transIdTemp))
		BEGIN
			-- MG running tickets in translog
			INSERT INTO #SpecialDeleteBets(
				GroupID
				,bettype
				,transid
				,betid
				,refno	
				,hdp1
				,hdp2
				,odds
				,oddsspread
				,STATUS
				,stake
				,transdate
				,betteam
				,betcheck
				,liveindicator	
				,custid
				,livehomescore	
				,liveawayscore
				,matchid
				,winlost
				,betdaqid
				,recommend
				,IsMarked	
			)
			SELECT	
				b.translogID AS GroupID
				,b.GameID
				,b.translogID as transid
				,0 AS BetID
				,b.translogID refno	
				,0 hdp1
				,0 hdp2
				,b.odds
				,0 AS oddsspread
				,b.STATUS
				,b.stake
				,b.transdate
				,NULL betteam
				,NULL betcheck
				,b.liveindicator liveindicator
				,b.custid
				,NULL livehomescore
				,NULL liveawayscore
				,b.EventID
				,- b.actual_stake as winlost
				,-1 -- normal ticket
				,recommend
				,CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
			FROM dbo.translog AS b WITH (NOLOCK)
				INNER JOIN #transIdTemp temp
				ON b.translogid = temp.transid
				OUTER APPLY (
							SELECT TOP (1) TransId
							FROM dbo.MarkedTransaction WITH(NOLOCK) 
							WHERE b.translogid = TransId
						)m
			WHERE b.winlostdate >= @FromWinlostDate
				AND b.GameID BETWEEN 801 AND 806
				AND b.statusID = 0
				
			-- bettrans tickets	
			INSERT INTO #SpecialDeleteBets (
				GroupID			
				,bettype		
				,transid		
				,betid			
				,refno		
				,hdp1			
				,hdp2			
				,odds
				,oddsspread				
				,STATUS					
				,stake							
				,transdate		
				,betteam		
				,betcheck		
				,liveindicator	
				,custid						
				,livehomescore	
				,liveawayscore						
				,matchid					
				,winlost		
				,betdaqid
				,recommend
				,ExtraInfo
				,WalletType
				,RefCode
				,BonusID
				,IsMarked
			)
			SELECT	
				b.refno AS GroupId
				,b.bettype
				,b.transid
				,isnull(b.BetID, 0) AS BetID
				,b.refno			
				,b.hdp1
				,b.hdp2
				,b.odds
				,b.oddsspread
				,CASE 
					WHEN b.STATUS = 'running'
						AND IsNull(b.SecAcceptFlag, 0) = 1
						AND IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					ELSE b.STATUS END AS STATUS
				,b.stake
				,b.transdate
				,b.betteam
				,b.betcheck
				,b.liveindicator
				,b.custid
				,b.livehomescore
				,b.liveawayscore
				,b.matchid				
				,(b.winlost - b.actual_stake) winlost
				,b.betdaqid
				,b.recommend			
				,b.ExtraInfo
				,b.WalletType
				,b.RefCode
				,b.BonusID
				,CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.translog tl WITH(NOLOCK)
				ON b.custid 		= tl.custid
					AND b.refno 	= tl.translogid
					AND b.matchid 	= tl.eventid
				INNER JOIN #transIdTemp temp
				ON tl.translogid 	= temp.transid			
				OUTER APPLY (
							SELECT TOP (1) TransId
							FROM dbo.MarkedTransaction WITH(NOLOCK) 
							WHERE b.transid = TransId
						)m
				INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
			WHERE	b.winlostdate >= @FromWinlostDate				
				AND b.bettype BETWEEN 801 AND 806 
				AND b.statusID NOT IN (0, 101, 102, 103)
			
			UNION ALL
			SELECT	
				b.transid AS GroupId
				,b.bettype
				,b.transid
				,isnull(b.BetID, 0) AS BetID
				,b.refno			
				,b.hdp1
				,b.hdp2
				,b.odds
				,b.oddsspread
				,CASE 
					WHEN b.STATUS = 'running'
						AND IsNull(b.SecAcceptFlag, 0) = 1
						AND IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					ELSE b.STATUS END AS STATUS
				,b.stake				
				,b.transdate
				,b.betteam
				,b.betcheck
				,b.liveindicator
				,b.custid
				,b.livehomescore
				,b.liveawayscore				
				,b.matchid				
				,(b.winlost - b.actual_stake) winlost
				,b.betdaqid
				,b.recommend			
				,b.ExtraInfo
				,b.WalletType
				,b.RefCode
				,b.BonusID
				,CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN #transIdTemp temp
					ON b.transid = temp.transid
				OUTER APPLY (
							SELECT TOP (1) TransId
							FROM dbo.MarkedTransaction WITH(NOLOCK) 
							WHERE b.transid = TransId
						)m
				INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype				
			WHERE	b.winlostdate >= @FromWinlostDate				
				AND b.bettype NOT BETWEEN 801 AND 806-- MG
				AND b.statusID NOT IN (101, 102, 103)				
		END		
	
		-- update MainTransId
		IF EXISTS (SELECT TOP 1 1 FROM #SpecialDeleteBets WHERE refno IS NOT NULL)
		BEGIN
			UPDATE sub
			SET MainTransId = main.transid
			FROM #SpecialDeleteBets main
				 INNER JOIN #SpecialDeleteBets sub
						 ON main.RefCode = sub.RefCode	
							AND main.transid <> sub.transid					
							AND main.custid = sub.custid
							AND main.matchid = sub.matchid
							AND main.bettype = sub.bettype											
			WHERE main.WalletType = 1			
	  
			-- Insert more bonus or cash ticket in case only one ticket appears in #SpecialDeleteBets	
			INSERT INTO #tmpRefCodeSummary (RefCode, custid, matchid, bettype, IsMarked, transid)
			SELECT RefCode, custid, matchid, bettype,IsMarked
				 , MAX(transid) AS transid
			FROM #SpecialDeleteBets
			WHERE	RefCode IS NOT NULL
			GROUP BY RefCode, custid, matchid, bettype,IsMarked
			HAVING COUNT(*) = 1
		
			IF @@ROWCOUNT > 0
			BEGIN
				INSERT INTO #SpecialDeleteBets (
						GroupID			
						,bettype		
						,transid		
						,betid			
						,refno		
						,hdp1			
						,hdp2			
						,odds					
						,STATUS					
						,stake							
						,transdate		
						,betteam		
						,betcheck		
						,liveindicator	
						,custid						
						,livehomescore	
						,liveawayscore							
						,matchid					
						,winlost		
						,betdaqid
						,recommend		
						,ExtraInfo
						,WalletType
						,RefCode
						,BonusID
						,MainTransId
						,IsMarked
					)
					SELECT	
						b.refno AS GroupId
						,b.bettype
						,b.transid
						,isnull(b.BetID, 0) AS BetID
						,b.refno			
						,b.hdp1
						,b.hdp2
						,b.odds
						,CASE 
							WHEN b.STATUS = 'running'
								AND IsNull(b.SecAcceptFlag, 0) = 1
								AND IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
							ELSE b.STATUS END AS STATUS
						,b.stake
						,b.transdate
						,b.betteam
						,b.betcheck
						,b.liveindicator
						,b.custid
						,b.livehomescore
						,b.liveawayscore				
						,b.matchid				
						,(b.winlost - b.actual_stake) winlost
						,b.betdaqid
						,b.recommend			
						,b.ExtraInfo
						,b.WalletType
						,b.RefCode
						,b.BonusID
						,t.transid AS MainTransId
						,t.IsMarked
				FROM #tmpRefCodeSummary t
					 INNER JOIN dbo.bettrans b WITH (NOLOCK)
							 ON b.RefCode = t.RefCode
								AND b.transid <> t.transid					
								AND b.custid = t.custid
								AND b.matchid = t.matchid
								AND b.bettype = t.bettype
				WHERE b.statusID NOT IN (101, 102, 103) -- reject, void, refund	
			END	    			    				    					    				    					    
		END

		IF @IsEditRequest = 1
		BEGIN
			DELETE dbo.TicketVoiding_RequestDetailTicket_Single
			WHERE RequestId = @RequestId
		END

		INSERT INTO dbo.TicketVoiding_RequestDetailTicket_Single (RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId, bettype, betid)
		SELECT @RequestId
			,@IssueTypeId
			,@SubIssueTypeId
			,CASE WHEN s.bettype BETWEEN 801 AND 806 THEN s.refno ELSE s.transid END 
			,s.matchid
			,rd.Id AS RequestDetailId
			,s.bettype
			,s.betid
		FROM #SpecialDeleteBets s
				INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) 
					ON rd.RequestId = @RequestId AND s.MatchId = rd.MatchId

	END
	ELSE IF @IssueTypeId IN (3) --WC
	BEGIN
		INSERT INTO #TransidInRequest (TransId)
		SELECT tmp.transid
		FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) 
			INNER JOIN dbo.TicketVoiding_Request req WITH (NOLOCK) ON req.RequestId = rd.RequestId 
			CROSS APPLY (
						SELECT TransId
						FROM dbo.TicketVoiding_RequestDetailTicket_Single WITH (NOLOCK)
						WHERE RequestId = req.RequestId
					) AS tmp
		WHERE rd.MatchId = @MatchId AND req.RequestId <> @RequestId AND req.ActionId <>2

		INSERT INTO @bettype_tmp (bettype)
		SELECT DISTINCT pt.bettype
		FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
		WHERE pt.ProductID = 1 -- Sportsbook
		AND pt.bettype NOT IN (10, 9, 29) -- outright, parlay
		AND pt.bettype NOT BETWEEN 221 AND 227 -- Fast Market
		AND pt.SubProduct NOT IN ('Bet Builder', 'MG-SuperLive', 'BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet Builder, Metric Gaming, Bet trade (BT-)

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
		
		INSERT INTO #DangerAccept_SingleTickets (TransId, StatusId, MatchId, VoidFromTime, VoidToTime, refno, bettype, betid)
		SELECT b.transid
			, b.statusID
			, @MatchId
			, s.VoidFromTime
			, s.VoidToTime
			, b.refno
			, b.bettype
			, b.betid
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
			INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = b.BetType
			CROSS APPLY (
				SELECT TOP(1) t.VoidFromTime, t.VoidToTime 
				FROM #tblGetLogInfo t
				WHERE matchid = @MatchId
					AND ISNULL(b.checktime, b.transdate) BETWEEN VoidFromTime AND VoidToTime	
					AND b.transid BETWEEN MinSingleTransId AND MaxSingleTransId
			)s
		WHERE b.matchid = @MatchId
			AND 1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1
						 WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
						 ELSE 0 END
			AND b.betfrom <> 'P'
			AND 1 = CASE WHEN b.livehomescore = 0 AND b.liveawayscore = 0 AND b.liveindicator = 0 AND f.GroupName <> '2H' THEN 0 ELSE 1 END

		SELECT @Username = (SELECT c.username FROM CustDB.dbo.Customer c WITH (NOLOCK) WHERE c.custid = @UserId)
		------------------------------------------------------------------------------------------------------------
		--Edit from to time of Danger Accepted issue -> unmark ticket change void time
		SELECT @RemoveTransIds = STUFF((SELECT ',' + CAST(rdt.transid AS VARCHAR(50)) 
											FROM dbo.TicketVoiding_RequestDetailTicket_Single rdt WITH(NOLOCK)
												INNER JOIN MarkedTransaction mt WITH(NOLOCK) ON mt.TransId = rdt.transid AND mt.MatchId = rdt.MatchId
												LEFT JOIN #DangerAccept_SingleTickets tp ON rdt.TransId=tp.transid
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
			FROM dbo.TicketVoiding_RequestDetailTicket_Single s
			WHERE s.matchid = @MatchId AND s.RequestId = @RequestId		
		END

		INSERT INTO dbo.TicketVoiding_RequestDetailTicket_Single (RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId, bettype, betid)
		SELECT @RequestId
			, @IssueTypeId
			, @SubIssueTypeId
			, t.TransId
			, t.MatchId
			, rd.Id AS RequestDetailId
			, t.bettype
			, t.betid
		FROM #DangerAccept_SingleTickets t
			INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) ON t.MatchId = rd.MatchId  AND rd.VoidFromTime = t.VoidFromTime AND rd.VoidToTime = t.VoidToTime
			OUTER APPLY (
								SELECT TOP 1 rs.TransId
								FROM dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK)
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
				OUTPUT DELETED.TransId, DELETED.StatusId					
				INTO @tmpTransIDBatch(TransId, StatusId)
				FROM #DangerAccept_SingleTickets t 
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
		ELSE -- take note
		BEGIN
			IF @IsEditRequest = 1
			BEGIN
				SELECT @MarkedTransIds = STUFF(
						(SELECT ',' + CONVERT(VARCHAR(50), tp.transid)
						FROM #DangerAccept_SingleTickets tp
						WHERE EXISTS (SELECT TOP 1 1 FROM dbo.MarkedTransaction mt WITH(NOLOCK) WHERE mt.TransId = tp.transid)
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
	ELSE IF @IssueTypeId = 17 AND @TransIds IS NOT NULL --Archived Ticket
	BEGIN
		IF @IsEditRequest = 1
		BEGIN
			DELETE dbo.TicketVoiding_RequestDetailTicket_Single WITH(ROWLOCK)
			WHERE RequestId = @RequestId
		END

		INSERT INTO dbo.TicketVoiding_RequestDetailTicket_Single (RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId, Bettype, BetId)
		SELECT DISTINCT @RequestId, @IssueTypeId, @SubIssueTypeId, l.val, tmp.matchid , tmp.Id AS RequestDetailId, tmp.bettype, tmp.betid
		FROM dbo.f_SplitString(@TransIds, ',') l
			CROSS APPLY (
						SELECT rd.Id, b14.matchid, b14.bettype, b14.betid
						FROM dbo.bettrans14 b14 WITH(NOLOCK) 
							INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) ON b14.matchid = rd.MatchId
						WHERE  rd.RequestId = @RequestId AND CAST(l.val AS BIGINT) = b14.transid
						)tmp
		WHERE l.val <> ''
		OPTION (MAXRECURSION 0)
	END
	ELSE IF @IssueTypeId IN (8,9)--EKO,WKO
	BEGIN
		IF @IsEditRequest = 1
		BEGIN
			DELETE dbo.TicketVoiding_RequestDetailTicket_Single
			WHERE RequestId = @RequestId
		END
		-- search tickets : not metric gaming tickets, mix parlay tickets
		INSERT INTO #SpecialDeleteBets(
				GroupID			
				,transid		
				,refno			
				,custid			
				,odds			
				,oddsspread			
				,transdate		
				,bettype 		
				,betteam 		
				,betcheck	
				,hdp1 			
				,hdp2 			
				,livehomescore 	
				,liveawayscore 	
				,Stake			
				,STATUS			
				,srecommend
				,mrecommend		
				,recommend		
				,betid			
				,betdaqid	
				,ExtraInfo
				,WalletType
				,RefCode
				,BonusID
				,WinLost
				,IsMarked
				,LiveIndicator
				,matchid
			)
		SELECT 
				b.transid AS GroupID
				,b.transid
				,b.refno
				,b.custid
				,b.odds
				,b.oddsspread			
				,b.transdate
				,b.bettype
				,b.betteam
				,b.betcheck
				,b.hdp1
				,b.hdp2
				,b.livehomescore
				,b.liveawayscore
				,b.stake
				,CASE WHEN b.STATUS = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
						ELSE b.STATUS
					END AS STATUS
				,b.srecommend
				,b.mrecommend
				,b.recommend
				,b.betid
				,b.betdaqid
				,b.ExtraInfo
				,b.WalletType
				,b.RefCode
				,b.BonusID
				,b.WinLost - b.actual_stake AS WinLost
				,CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
				,b.liveindicator
				,b.matchid
		FROM	bettrans b WITH (NOLOCK)	
		   LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.transid = m.TransId	
			OUTER APPLY (
							SELECT TOP 1 rs.TransId
							FROM dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK)
								INNER JOIN TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = rs.RequestId 
							WHERE rs.TransId = b.transid
								AND rs.MatchId = @MatchId
								AND r.ActionId NOT IN (2)
					)tmp
		WHERE	b.matchid = @matchid
				AND b.transdate >= @KickOffTime
				AND b.statusID NOT IN (101, 102, 103) -- reject, void, refund
				AND b.liveindicator = 0
				AND b.bettype NOT IN (805, 806, 9, 29)			
				AND b.bettype NOT BETWEEN 901 AND 920
				AND b.betfrom <> 'P'
				AND tmp.TransId IS NULL
			    	
		-- update MainTransId
		IF EXISTS (SELECT TOP 1 1 FROM #SpecialDeleteBets WHERE RefCode IS NOT NULL)
		BEGIN
			UPDATE sub
			SET MainTransId = main.transid
			FROM #SpecialDeleteBets main
				 INNER JOIN #SpecialDeleteBets sub
						 ON main.RefCode = sub.RefCode
							AND main.transid <> sub.transid	
							AND main.custid = sub.custid
							AND main.bettype = sub.bettype
			WHERE main.WalletType = 1					
		  
			-- Insert more bonus or cash ticket in case only one ticket appears in #SpecialDeleteBets  
			INSERT INTO #tmpRefCodeSummary(RefCode, custid, bettype, IsMarked, transid)
			SELECT RefCode, custid, bettype, IsMarked
				 , MAX(transid) AS transid
			FROM #SpecialDeleteBets
			WHERE	RefCode IS NOT NULL
			GROUP BY RefCode, custid, bettype, IsMarked
			HAVING COUNT(*) = 1

			IF @@ROWCOUNT > 0
			BEGIN	
				INSERT INTO #SpecialDeleteBets(
							GroupID			
							,transid		
							,refno			
							,custid			
							,odds			
							,oddsspread
							,transdate		
							,bettype 		
							,betteam 		
							,betcheck	
							,hdp1 			
							,hdp2 			
							,livehomescore 	
							,liveawayscore 	
							,Stake			
							,STATUS			
							,srecommend
							,mrecommend		
							,recommend		
							,betid			
							,betdaqid
							,ExtraInfo	
							,WalletType
							,RefCode
							,BonusID
							,MainTransId
							,WinLost
							,IsMarked
							,LiveIndicator
							,matchid
						)
					SELECT 
							b.transid AS GroupID
							,b.transid
							,b.refno
							,b.custid
							,b.odds
							,b.oddsspread
							,b.transdate
							,b.bettype
							,b.betteam
							,b.betcheck
							,b.hdp1
							,b.hdp2
							,b.livehomescore
							,b.liveawayscore
							,b.stake
							,CASE WHEN b.STATUS = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
								  ELSE b.STATUS
							 END AS STATUS
							,b.srecommend
							,b.mrecommend
							,b.recommend
							,b.betid
							,b.betdaqid
							,b.ExtraInfo
							,b.WalletType
							,b.RefCode
							,b.BonusID
							,t.transid AS MainTransId
							,b.winlost - b.actual_stake AS WinLost
							,t.IsMarked
							,b.liveindicator
							,b.matchid
				FROM #tmpRefCodeSummary t
					 INNER JOIN dbo.bettrans b WITH (NOLOCK)
							 ON b.RefCode = t.RefCode
								AND b.transid <> t.transid
								AND b.matchid = @MatchId
								AND b.custid = t.custid
								AND b.bettype = t.bettype 
				WHERE b.statusID NOT IN (101,102, 103 ) -- reject, void, refund	
			END  			    				    					    				    					    	
		END

		INSERT INTO dbo.TicketVoiding_RequestDetailTicket_Single (RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId, bettype, betid)
		SELECT @RequestId
			,@IssueTypeId
			,@SubIssueTypeId
			,s.transid
			,s.matchid
			,rd.Id AS RequestDetailId
			,s.bettype
			,s.betid
		FROM #SpecialDeleteBets s
			INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) 
					ON rd.RequestId = @RequestId AND rd.MatchId = s.matchid
	END
	ELSE IF @IssueTypeId IN (4,5) --Wrong HDP, Wrong 1stHDP
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
		END
		
		INSERT INTO #TransidInRequest (TransId)
		SELECT tmp.transid
		FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) 
			INNER JOIN dbo.TicketVoiding_Request req WITH (NOLOCK) ON req.RequestId = rd.RequestId 
			CROSS APPLY (
						SELECT TransId
						FROM dbo.TicketVoiding_RequestDetailTicket_Single WITH (NOLOCK)
						WHERE RequestId = req.RequestId
					) AS tmp
			INNER JOIN #tblGetLogInfo l ON l.MatchID = rd.MatchId
		WHERE req.RequestId <> @RequestId AND req.ActionId <>2

		INSERT INTO #DangerAccept_SingleTickets (TransId, StatusId, MatchId, SubIssueTypeId, refno, bettype, betid)
		SELECT b.transid
			, b.statusID
			, b.matchId
			, t.SubIssueTypeId
			, b.refno
			, b.bettype
			, b.betid
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN #tblGetLogInfo t ON t.MatchID = b.matchid
			OUTER APPLY (
				SELECT DISTINCT val 
				FROM dbo.f_SplitString(t.HomeFavorite, '&')
				WHERE val <> ''				
			)xHDPHome
			OUTER APPLY (
				SELECT DISTINCT val 
				FROM dbo.f_SplitString(t.AwayFavorite, '&')
				WHERE val <> ''				
			)xHDPAway
			OUTER APPLY (
				SELECT DISTINCT val 
				FROM dbo.f_SplitString(t.HdpValue, '&')
				WHERE val <> ''				
			)xHDPvalue
		WHERE b.betfrom <> 'P' 
			AND 1 = CASE WHEN @IssueTypeId = 4 AND b.bettype = 1 THEN 1
						 WHEN @IssueTypeId = 5 AND b.bettype = 7 THEN 1
						 ELSE 0 END
			AND b.transdate BETWEEN t.VoidFromTime AND t.VoidToTime 
			AND b.transid BETWEEN t.MinSingleTransId AND t.MaxSingleTransId
			AND 1 = CASE WHEN @ActionId <> 2 AND b.statusID NOT IN (101, 102, 103) THEN 1
							WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
							ELSE 0 END
			AND 1 = CASE WHEN t.SubIssueTypeId IN (8,9) AND b.hdp1 = xHDPHome.val AND t.HomeFavorite IS NOT NULL THEN 1
						 WHEN t.SubIssueTypeId IN (8,9) AND b.hdp2 = xHDPAway.val AND t.AwayFavorite IS NOT NULL THEN 1
						 WHEN t.SubIssueTypeId IN (22,24) AND b.hdp2 = xHDPvalue.val AND t.HdpValue IS NOT NULL THEN 1 --Away Virtual Head Reversed
						 WHEN t.SubIssueTypeId IN (23,25) AND b.hdp1 = xHDPvalue.val AND t.HdpValue IS NOT NULL THEN 1 --Home Virtual Head Reversed
						 ELSE 0 END 
			OPTION (MAXRECURSION 0)
		
		SELECT @Username = (SELECT c.username FROM CustDB.dbo.Customer c WITH (NOLOCK) WHERE c.custid = @UserId)
		------------------------------------------------------------------------------------------------------------
		--Edit from to time of Danger Accepted issue -> unmark ticket change void time
		SELECT @RemoveTransIds = STUFF((SELECT ',' + CAST(rdt.transid AS VARCHAR(50)) 
											FROM dbo.TicketVoiding_RequestDetailTicket_Single rdt WITH(NOLOCK)
												INNER JOIN MarkedTransaction mt WITH(NOLOCK) ON mt.TransId = rdt.transid AND mt.MatchId = rdt.MatchId
												LEFT JOIN #DangerAccept_SingleTickets tp ON rdt.TransId=tp.transid
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
				FROM dbo.TicketVoiding_RequestDetailTicket_Single s
				WHERE s.RequestId = @RequestId

				IF @@ROWCOUNT < 4500 BREAK

				WAITFOR DELAY '00:00:00.100'
			END
		END

		INSERT INTO #TransId_tmp (RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId, bettype, betid)
		SELECT @RequestId
			, @IssueTypeId
			, t.SubIssueTypeId
			, t.TransId
			, t.MatchId
			, rd.Id AS RequestDetailId
			, t.bettype
			, t.betid
		FROM #DangerAccept_SingleTickets t
			INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) ON rd.RequestId = @RequestId AND t.MatchId = rd.MatchId  
			OUTER APPLY (
								SELECT TOP 1 rs.TransId
								FROM dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK)
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
				, DELETED.bettype
				, DELETED.betid
			INTO dbo.TicketVoiding_RequestDetailTicket_Single (RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId, bettype, betid)
			FROM #TransId_tmp d

			IF @@ROWCOUNT < 4500 BREAK
			
			WAITFOR DELAY '00:00:00.180'
		END

		IF @ActionId <> 2
		BEGIN
			--Mark Ticket
			WHILE (1=1)
			BEGIN
				DELETE @tmpTransIDBatch
					
				UPDATE TOP(2000) t
					SET isFinish = 1
				OUTPUT DELETED.TransId, DELETED.StatusId					
				INTO @tmpTransIDBatch(TransId, StatusId)
				FROM #DangerAccept_SingleTickets t 
				WHERE isFinish IS NULL
				
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
		ELSE -- take note
		BEGIN
			IF @IsEditRequest = 1
			BEGIN
				SELECT @MarkedTransIds = STUFF(
						(SELECT ',' + CONVERT(VARCHAR(50), tp.transid)
						FROM #DangerAccept_SingleTickets tp
						WHERE EXISTS (SELECT TOP 1 1 FROM dbo.MarkedTransaction mt WITH(NOLOCK) WHERE mt.TransId = tp.transid)
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

	DROP TABLE #SpecialDeleteBets
	DROP TABLE #tmpRefCodeSummary
	DROP TABLE #DangerAccept_SingleTickets
	DROP TABLE #TransidInRequest
	DROP TABLE #InputUsernameList
	DROP TABLE #InputValidCustid_2
	DROP TABLE #InputValidCustid_tmp
	DROP TABLE #transIdTemp
	DROP TABLE #tblGetLogInfo
	DROP TABLE #TransId_tmp
END