/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_RequestDetailTicket_Single_Insert]
(	 
	@RequestId			INT
	,@MatchId			INT
	,@KickOffTime		DATETIME = NULL
	,@IssueTypeId		INT
	,@SubIssueTypeId	INT
	,@MinSingleTransId	BIGINT = NULL
	,@MaxSingleTransId	BIGINT = NULL
	,@TransIds			VARCHAR(MAX) = NULL
	,@IsEditRequest		BIT = 0
	,@UserId			INT = NULL
	,@IP				VARCHAR(50) = NULL
	,@ActionId			TINYINT = 0
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
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @UnMarkedTransIds	VARCHAR(MAX) = NULL
			,@UserName		VARCHAR(100) = NULL
			,@MarkedTransIds	VARCHAR(MAX) = NULL
			,@RemoveTransIds	VARCHAR(MAX) = ''
			,@IsCheckedHomeTeam  BIT = 0
			,@IsCheckedAwayTeam  BIT = 0

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

	CREATE TABLE #DangerAccept_SingleTickets (TransId BIGINT, StatusId INT, MatchId INT, isFinish BIT)
	DECLARE @tmpTransIDBatch TABLE (TransId	BIGINT, StatusId INT)

	CREATE INDEX IX_SpecialDeleteBets_RefCode ON #SpecialDeleteBets(RefCode)
	CREATE INDEX IX_tmpRefCodeSummary_Refcode ON #tmpRefCodeSummary (RefCode)

	SELECT  @IsCheckedHomeTeam  = ISNULL(IsCheckedHomeTeam,0)
		   ,@IsCheckedAwayTeam  = ISNULL(IsCheckedAwayTeam,0)
	FROM dbo.TicketVoiding_RequestDetail WITH(NOLOCK) 
	WHERE RequestId= @RequestId

	IF @IssueTypeId = 1 AND @MinSingleTransId IS NOT NULL
	BEGIN
		INSERT INTO #DangerAccept_SingleTickets (TransId, StatusId, MatchId)
		SELECT b.transid
			, b.statusID
			, @MatchId
		FROM dbo.bettrans b WITH (NOLOCK)
		WHERE b.matchid = @MatchId
			AND b.transid BETWEEN @MinSingleTransId AND @MaxSingleTransId
			AND 1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1
						 WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
						 ELSE 0 END
			AND (1= CASE WHEN @SubIssueTypeId NOT IN (1,2) THEN 1
							ELSE CASE WHEN (@IsCheckedHomeTeam = 0 AND @IsCheckedAwayTeam = 0) OR (@IsCheckedHomeTeam = 1 AND @IsCheckedAwayTeam = 1) THEN 1
									  WHEN @IsCheckedAwayTeam = 1 AND b.bettype NOT IN (401,403,407,482,484) THEN 1 
									  WHEN @IsCheckedHomeTeam = 1 AND b.bettype NOT IN (402,404,409,483,485) THEN 1
									  ELSE 0 END
							END)

		SELECT @Username = (SELECT c.username FROM CustDB.dbo.Customer c WITH (NOLOCK) WHERE c.custid = @UserId)
		------------------------------------------------------------------------------------------------------------
		--Edit from to time of Danger Accepted issue -> unmark ticket change void time
		SELECT @RemoveTransIds = STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
											FROM dbo.TicketVoiding_RequestDetailTicket_Single rdt WITH(NOLOCK)
											WHERE NOT EXISTS( SELECT TOP 1 1 FROM #DangerAccept_SingleTickets tp WHERE rdt.TransId=tp.transid)
												  AND EXISTS (SELECT TOP 1 1 FROM dbo.MarkedTransaction mt WITH(NOLOCK) WHERE mt.TransId = rdt.transid)
												  AND rdt.RequestId=@RequestId
											FOR XML PATH('')
										), 1,1,'')
		IF @RemoveTransIds IS NOT NULL
		BEGIN
			EXEC dbo.Nap_SpecialDelete_MarkedTickets_ManualUpdate @TransIds = @RemoveTransIds, @UserId = @UserId, @Username = @Username, @IP = @IP, @RequestId = @RequestId, @LogActionId = 90501
		END

		IF @IsEditRequest = 1
		BEGIN
			DELETE dbo.TicketVoiding_RequestDetailTicket_Single
			WHERE RequestId = @RequestId
		END

		INSERT INTO dbo.TicketVoiding_RequestDetailTicket_Single (RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId)
		SELECT @RequestId
			, @IssueTypeId
			, @SubIssueTypeId
			, t.TransId
			, t.MatchId
		FROM #DangerAccept_SingleTickets t
			OUTER APPLY (
								SELECT TOP 1 rs.TransId
								FROM dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK)
									INNER JOIN TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = rs.RequestId 
								WHERE rs.TransId = t.transid
									AND rs.MatchId = @MatchId
									AND r.ActionId NOT IN (2)
						)tmp
		WHERE tmp.TransId IS NULL

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
																	, @MarkType = 1, @LogActionId = 90508
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
							AND  tp.StatusId IN (0, 1) 
						GROUP BY TransId for XML PATH('')), 1, 1, ''
						)
				--Unmark ticket
				IF @MarkedTransIds IS NOT NULL
					BEGIN
						EXEC dbo.Nap_SpecialDelete_MarkedTickets_ManualUpdate @TransIds = @MarkedTransIds, @UserId = @UserId, @Username = @Username, @IP = @IP, @RequestId = @RequestId, @LogActionId = 90501
					END												

					SET @MarkedTransIds = ''
			END
		END
	END
	ELSE IF @IssueTypeId = 11 AND @TransIds IS NOT NULL
	BEGIN
		IF @IsEditRequest = 1
		BEGIN
			DELETE dbo.TicketVoiding_RequestDetailTicket_Single
			WHERE RequestId = @RequestId
		END

		INSERT INTO dbo.TicketVoiding_RequestDetailTicket_Single (RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId)
		SELECT DISTINCT @RequestId, @IssueTypeId, @SubIssueTypeId, val, @MatchId
		FROM dbo.f_SplitString(@TransIds, ',')
		WHERE val <> ''
		OPTION (MAXRECURSION 0)
	END
	ELSE
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
				,betid			
				,Transdesc		
				,betdaqid	
				,ExtraInfo
				,MainCashoutId
				,WalletType
				,RefCode
				,BonusID
				,WinLost
				,IsMarked
				,LiveIndicator
			)
		SELECT 
				b.transid AS GroupID
				,b.transid
				,b.transid AS SubTransID
				,b.refno
				,b.custid
				,b.odds
				,b.odds AS SubOdds
				,b.oddsspread			
				,b.OddsType
				,b.transdate
				,b.bettype
				,b.betteam
				,b.betteam AS SubBetteam
				,b.betcheck
				,b.betcheck AS SubBetcheck
				,b.hdp1
				,b.hdp2
				,b.livehomescore
				,b.liveawayscore
				,b.creator
				,b.stake
				,b.CurrencyName
				,CASE WHEN b.STATUS = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
						ELSE b.STATUS
					END AS STATUS
				,CASE WHEN b.STATUS = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
						ELSE b.STATUS
					END AS SubStatus
				,b.srecommend
				,b.mrecommend
				,b.recommend
				,b.betid
				,b.Transdesc
				,b.betdaqid
				,b.ExtraInfo
				,CASE
					WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0
							THEN b.transid
					ELSE NULL
				 END AS MainCashoutId
				,b.WalletType
				,b.RefCode
				,b.BonusID
				,b.WinLost - b.actual_stake AS WinLost
				,CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
				,b.liveindicator
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

		-- delete cash-out member bet tickets
		DELETE t
		FROM #SpecialDeleteBets t
		WHERE EXISTS (SELECT TOP 1 1
					  FROM bettrans sub911 (NOLOCK)
					  WHERE sub911.bettype = 911
						AND sub911.transid = t.refno)				    	
		
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
							,betid			
							,Transdesc		
							,betdaqid
							,ExtraInfo	
							,MainCashoutId
							,WalletType
							,RefCode
							,BonusID
							,MainTransId
							,WinLost
							,IsMarked
							,LiveIndicator
						)
					SELECT 
							b.transid AS GroupID
							,b.transid
							,b.transid AS SubTransID
							,b.refno
							,b.custid
							,b.odds
							,b.odds AS SubOdds
							,b.oddsspread
							,b.OddsType
							,b.transdate
							,b.bettype
							,b.betteam
							,b.betteam AS SubBetteam
							,b.betcheck
							,b.betcheck AS SubBetcheck
							,b.hdp1
							,b.hdp2
							,b.livehomescore
							,b.liveawayscore
							,b.creator
							,b.stake
							,b.CurrencyName
							,CASE WHEN b.STATUS = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
								  ELSE b.STATUS
							 END AS STATUS
							,CASE WHEN b.STATUS = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
								  ELSE b.STATUS
							 END AS SubStatus
							,b.srecommend
							,b.mrecommend
							,b.recommend
							,b.betid
							,b.Transdesc
							,b.betdaqid
							,b.ExtraInfo
							,CASE
								WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0
										THEN b.transid
								ELSE NULL
							 END AS MainCashoutId
							,b.WalletType
							,b.RefCode
							,b.BonusID
							,t.transid AS MainTransId
							,b.winlost - b.actual_stake AS WinLost
							,t.IsMarked
							,b.liveindicator
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

		UPDATE	main
			SET main.SoldId = sub.transid
		OUTPUT INSERTED.SoldId
		INTO #tblSoldTicket(transid)
		FROM #SpecialDeleteBets main 
			INNER JOIN dbo.bettrans sub WITH(NOLOCK)
				ON	main.transid = sub.refno
					AND main.betdaqid = 0 -- main ticket is BTrade
					AND main.extrainfo is null
					AND sub.matchid = @MatchId
					AND sub.bettype = 901
			
		-- get sub ticket of BetTrade (901)
		INSERT INTO #SpecialDeleteBets (
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
				,OriginalBetType 		
				,betteam 		
				,SubBetTeam
				,betcheck	
				,SubBetcheck	
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
				,betid			
				,Transdesc		
				,betdaqid
				,ExtraInfo
				,WalletType
				,RefCode
				,BonusID
				,MainTransId
				,WinLost
				,IsMarked
				,LiveIndicator
			)
		SELECT  main.transid AS GroupTransId
				,sub.transid AS transId
				,sub.transid AS SubTransId
				,sub.refno
				,sub.custid
				,main.odds
				,main.odds AS SubOdds
				,main.oddsspread
				,main.OddsType
				,sub.transdate
				,sub.bettype
				,main.bettype  AS OriginalBetType
				,main.betteam
				,main.SubBetTeam
				,main.betcheck
				,main.SubBetcheck
				,main.hdp1
				,main.hdp2			
				,main.livehomescore
				,main.liveawayscore
				,sub.creator
				,main.Stake
				,main.CurrencyName
				,'SOLD'
				,'SOLD' AS SubStatus
				,main.srecommend
				,main.mrecommend
				,main.recommend			
				,main.bettype AS betid
				,sub.transdesc
				,sub.betdaqid
				,sub.ExtraInfo
				,sub.WalletType
				,sub.RefCode
				,sub.BonusID
				,main.transid AS MainTransId
				,sub.winlost - sub.actual_stake AS WinLost
				,main.IsMarked
				,main.LiveIndicator
		FROM	#SpecialDeleteBets main
			INNER JOIN dbo.bettrans sub WITH(NOLOCK)
				ON	main.transid = sub.refno
					AND sub.matchid = @MatchId
					AND sub.bettype = 901
			INNER JOIN #tblSoldTicket sold 
				ON sold.transid = sub.transid
				
		-- get sub ticket of Cash-out (911)
		INSERT INTO #SpecialDeleteBets (
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
				,OriginalBetType 		
				,betteam 		
				,SubBetTeam
				,betcheck	
				,SubBetcheck	
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
				,betid			
				,Transdesc		
				,betdaqid
				,ExtraInfo	
				,MainCashoutId
				,matchid
				,WalletType
				,RefCode
				,BonusID
				,MainTransId
				,WinLost
				,IsMarked
				,LiveIndicator
			)
		SELECT  sub911.transid AS GroupTransId
				,sub911.transid AS transId
				,sub911.transid AS SubTransId
				,sub911.refno
				,sub911.custid
				,main.odds
				,main.odds AS SubOdds
				,main.oddsspread
				,main.OddsType
				,sub911.transdate
				,sub911.bettype
				,main.bettype AS OriginalBetType
				,main.betteam
				,main.SubBetTeam
				,main.betcheck
				,main.SubBetcheck
				,main.hdp1
				,main.hdp2			
				,main.livehomescore
				,main.liveawayscore
				,sub911.creator
				,sub911.Stake
				,main.CurrencyName
				,'Cash out'
				,'Cash out' AS SubStatus
				,main.srecommend
				,main.mrecommend
				,main.recommend			
				,main.bettype AS betid
				,sub911.transdesc
				,sub911.betdaqid
				,sub911.ExtraInfo
				,main.transid AS MainCashoutId
				,sub911.matchid	
				,sub911.WalletType
				,sub911.RefCode
				,sub911.BonusID
				,main.transid AS MainTransId
				,sub911.winlost - sub911.actual_stake AS WinLost
				,main.IsMarked
				,main.LiveIndicator
		FROM dbo.bettrans sub911 WITH(NOLOCK)
			 INNER JOIN #SpecialDeleteBets main 
					ON	sub911.refno = main.transid	
						AND sub911.custid = main.custid					
						AND main.betdaqid = 0
						AND charindex ('p25',main.extrainfo)> 0			
						AND sub911.bettype = 911
						AND sub911.matchid = @matchid
		WHERE sub911.statusID NOT IN (102, 101, 103) -- VOID, REJECT, refund					
		
		-- get cash-out member bet tickets	
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
					,OriginalBetType		
					,betteam 		
					,SubBetTeam
					,betcheck	
					,SubBetcheck	
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
					,betid			
					,Transdesc		
					,betdaqid
					,ExtraInfo
					,IsCashOutMemberTicket
					,MainCashoutId
					,WalletType
					,RefCode
					,BonusID
					,MainTransId
					,WinLost
					,IsMarked
					,LiveIndicator
				)
			SELECT  sub911.transid AS GroupID
					,b.transid
					,b.transid AS SubTransID
					,b.refno
					,b.custid
					,b.odds
					,b.odds AS SubOdds
					,b.oddsspread
					,b.OddsType
					,b.transdate
					,b.bettype
					,sub911.OriginalBetType
					,b.betteam
					,b.betteam AS SubBetteam
					,b.betcheck
					,b.betcheck AS SubBetcheck
					,b.hdp1
					,b.hdp2
					,b.livehomescore
					,b.liveawayscore
					,b.creator
					,b.stake
					,b.CurrencyName
					,CASE WHEN b.STATUS = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
						  ELSE b.STATUS
					 END AS STATUS
					,CASE WHEN b.STATUS = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
						  ELSE b.STATUS
					 END AS SubStatus
					,b.srecommend
					,b.mrecommend
					,b.recommend
					,b.betid
					,b.Transdesc
					,b.betdaqid
					,b.ExtraInfo
					,CAST(1 AS BIT)  AS IsCashOutMemberTicket
					,sub911.MainCashoutId AS MainCashoutId
					,b.WalletType
					,b.RefCode
					,b.BonusID
					,sub911.MainTransId
					,b.winlost - b.actual_stake AS WinLost
					,sub911.IsMarked
					,b.liveindicator
		FROM #SpecialDeleteBets sub911
			 CROSS APPLY (
							  SELECT b.transid, b.refno, b.custid, b.oddsid, b.oddsspread, b.oddstype, b.transdate, b.bettype, b.betteam, b.betcheck, b.status
									,b.hdp1, b.hdp2, b.livehomescore, b.liveawayscore, b.creator, b.stake, b.CurrencyName, b.SecAcceptFlag, b.checktime, b.odds
									,b.srecommend, b.mrecommend, b.recommend, b.betid, b.transdesc, b.betdaqid, b.ExtraInfo, b.WalletType, b.RefCode, b.BonusID, b.winlost, b.actual_stake,liveindicator
							  FROM dbo.bettrans b WITH (NOLOCK)
							  WHERE b.refno = sub911.transid
								AND b.matchid = sub911.matchid					
								AND b.bettype = sub911.OriginalBetType
								AND b.statusID NOT IN (102, 101, 103) -- VOID, REJECT, refund
						 ) AS b
		WHERE sub911.bettype = 911

		INSERT INTO dbo.TicketVoiding_RequestDetailTicket_Single (RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId)
		SELECT @RequestId
			,@IssueTypeId
			,@SubIssueTypeId
			,s.transid
			,@MatchId
		FROM #SpecialDeleteBets s
	END

	DROP TABLE #SpecialDeleteBets
	DROP TABLE #tblSoldTicket
	DROP TABLE #tmpRefCodeSummary
	DROP TABLE #DangerAccept_SingleTickets
END