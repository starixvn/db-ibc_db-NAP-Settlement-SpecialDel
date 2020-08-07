/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_RequestDetailTicket_SubParlay_Insert]
(	 
	@RequestId INT
	,@MatchId INT
	,@KickOffTime	DATETIME = NULL
	,@IssueTypeId INT
	,@SubIssueTypeId INT
	,@MinMainParlayTransId BIGINT = NULL
	,@MaxMainParlayTransId BIGINT = NULL
	,@IsEditRequest BIT = 0
	,@UserId		INT = NULL
	,@IP			VARCHAR(50) = NULL
)
AS
/*	
	Created by: Max
	Date 20200701
	Task: [TVS] Danger Accept Bets Issue Type [Redmine: #111573]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20200701@Max: Create new SP [Redmine: #135947]
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @UnMarkedTransIds	VARCHAR(MAX) = NULL
		,@UserName		VARCHAR(100) = NULL
	
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
	CREATE TABLE #DangerAccept_SubParlayTickets (TransId BIGINT, StatusId INT, MatchId INT, MainTransId BIGINT, isFinish BIT)
	DECLARE @tmpTransIDBatch TABLE (TransId	BIGINT, StatusId INT)

	CREATE INDEX IX_SpecialDeleteBets_RefCode ON #SpecialDeleteBets(RefCode)
	CREATE INDEX IX_tmpRefCodeSummary_Refcode ON #tmpRefCodeSummary (RefCode)

	IF @IsEditRequest = 1
	BEGIN
		DELETE dbo.TicketVoiding_RequestDetailTicket_SubParlay
		WHERE RequestId = @RequestId
	END

	IF @IssueTypeId = 1 AND @MinMainParlayTransId IS NOT NULL
	BEGIN
		INSERT INTO #DangerAccept_SubParlayTickets (TransId, StatusId, MatchId, MainTransId)
		SELECT sub.transid
			, sub.statusID
			,@MatchId
			,main.transid
		FROM dbo.bettransm sub WITH (NOLOCK)
			INNER HASH JOIN bettrans AS main WITH (NOLOCK) 
							ON	main.refno = sub.refno				
								AND sub.matchid = @matchid
		WHERE main.transid BETWEEN @MinMainParlayTransId AND @MaxMainParlayTransId
			AND sub.statusID NOT IN (101, 102, 103)

		INSERT INTO dbo.TicketVoiding_RequestDetailTicket_SubParlay (RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId)
		SELECT @RequestId
			, @IssueTypeId
			, @SubIssueTypeId
			, t.TransId
			, t.MatchId
		FROM #DangerAccept_SubParlayTickets t
		
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
				SELECT @Username = (SELECT c.username FROM CustDB.dbo.Customer c WITH (NOLOCK) WHERE c.custid = @UserId)
				EXEC dbo.Nap_SpecialDelete_UnMarkedTickets_Update @TransIds = @UnMarkedTransIds, @UserId = @UserId, @Username = @Username, @IP = @IP, @RequestId = @RequestId
																, @MarkType = 1, @LogActionId = 90508
			END	

			SET @UnMarkedTransIds = ''
				
		END

	END
	ELSE
	BEGIN
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
						,main.winlost -main.actual_stake AS WinLost
						,0
						,sub.liveindicator
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
									AND r.ActionId NOT IN (2,3)
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

		INSERT INTO dbo.TicketVoiding_RequestDetailTicket_SubParlay(RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId)
		SELECT @RequestId
			,@IssueTypeId
			,@SubIssueTypeId
			,s.SubTransid
			,@MatchId
		FROM #SpecialDeleteBets s
	END

	DROP TABLE #SpecialDeleteBets
	DROP TABLE #tblSoldTicket
	DROP TABLE #tmpRefCodeSummary
	DROP TABLE #DangerAccept_SubParlayTickets
END