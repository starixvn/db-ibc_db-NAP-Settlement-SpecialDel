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

	CREATE INDEX IX_SpecialDeleteBets_RefCode ON #SpecialDeleteBets(RefCode)
	CREATE INDEX IX_tmpRefCodeSummary_Refcode ON #tmpRefCodeSummary (RefCode)

	IF @IsEditRequest = 1
	BEGIN
		DELETE dbo.TicketVoiding_RequestDetailTicket_Single
		WHERE RequestId = @RequestId
	END

	IF @IssueTypeId = 1
	BEGIN
		INSERT INTO dbo.TicketVoiding_RequestDetailTicket_SubParlay (RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId)
		SELECT @RequestId
			,@IssueTypeId
			,@SubIssueTypeId
			,sub.transid
			,@MatchId
		FROM dbo.bettransm sub WITH (NOLOCK)
			INNER HASH JOIN bettrans AS main WITH (NOLOCK) 
							ON	main.refno = sub.refno				
								AND sub.matchid = @matchid
		WHERE main.transid BETWEEN @MinMainParlayTransId AND @MaxMainParlayTransId
			AND sub.statusID NOT IN (101, 102, 103)
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
				WHERE	sub.transdate >= @KickOffTime
						AND sub.statusID NOT IN (101, 102, 103) -- reject, void, refund
						AND sub.liveindicator = 0
						AND sub.betfrom <> 'P'
						AND main.matchid = 29
						AND main.bettype = 29
						AND main.liveindicator = 0
						AND main.transdate >= @KickOffTime
						AND main.statusID NOT IN (101, 102, 103)
			END

		INSERT INTO dbo.TicketVoiding_RequestDetailTicket_SubParlay(RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId)
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
END