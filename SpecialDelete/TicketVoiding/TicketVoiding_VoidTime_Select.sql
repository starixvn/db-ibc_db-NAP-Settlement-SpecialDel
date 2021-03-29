/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_VoidTime_Select]
(	
	 @MatchId             INT
	,@RequestId			  INT = 0
	,@FilterFromTransTime DATETIME = NULL
	,@FilterToTransTime	  DATETIME = NULL
	,@FilterBy			  TINYINT = 1
	,@IssueTypeId		  INT = 1
	,@SubIssueTypeId	  INT = NULL
	,@IsCheckedHomeTeam   BIT = 0
	,@IsCheckedAwayTeam   BIT = 0
	,@AATime			  TINYINT 
	,@PATime			  TINYINT 
	,@SATime			  TINYINT 
	,@VoidFromTime		  DATETIME = NULL OUTPUT
	,@VoidToTime		  DATETIME = NULL OUTPUT	
)
AS 
/*	
	Created by: July
	Date 20210329
	Task: [TVS] Danger Accept/Red Card Enhancement - Phase 7
	DB: DBTXN/bodb02
	
	Revisions:
		- 20201106@July: Create new SP [Redmine: #150459] 

	Param's explanation:
		
*/

BEGIN
	SET NOCOUNT ON
	
	DECLARE @AutoAcceptTime		DATETIME = NULL,
			@PendingAcceptTime	DATETIME = NULL,
			@SecondAcceptTime	DATETIME = NULL,
			@MinFromTime		DATETIME = NULL,
			@MaxFromTime		DATETIME = NULL,
			@MinAccept			TINYINT = 0,
			@MaxAccept			TINYINT = 0,
			@MinTicketFromTime	DATETIME = NULL
			
	
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
			LiveIndicator		  BIT,
			StatusId			  TINYINT,
			checktime			  DATETIME,
			TypeAccept			  TINYINT
	)

	CREATE INDEX IX_SpecialDeleteBets_RefCode ON #SpecialDeleteBets(RefCode)
	
	CREATE TABLE #tblGroupTypeAccept (TypeAccept TINYINT, MinTicket DATETIME)
	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)

	IF @RequestId <> 0 --Edit
	BEGIN
		SELECT @VoidFromTime = VoidFromTime
			  ,@VoidToTime = VoidToTime
		FROM dbo.TicketVoiding_RequestDetail WITH (NOLOCK)
		WHERE RequestId = @RequestId

		RETURN;
	END

	IF @IssueTypeId IN (1,10)
	BEGIN
		SELECT @MinAccept = @AATime
			 , @MaxAccept = @AATime
			 

		IF @MinAccept > @PATime SET @MinAccept = @PATime
		IF @MinAccept > @SATime SET @MinAccept = @SATime
	
		IF @MaxAccept < @PATime SET @MaxAccept = @PATime
		IF @MaxAccept < @SATime SET @MaxAccept = @SATime

		SELECT @AutoAcceptTime = DATEADD (SECOND,@AATime,@FilterFromTransTime)
			  ,@PendingAcceptTime = DATEADD (SECOND,@PATime,@FilterFromTransTime)
			  ,@SecondAcceptTime = DATEADD (SECOND,@SATime,@FilterFromTransTime)
			  ,@MinFromTime = DATEADD (SECOND,@MinAccept,@FilterFromTransTime)
			  ,@MaxFromTime = DATEADD (SECOND,@MaxAccept,@FilterFromTransTime)

		SELECT @FilterFromTransTime = @MinFromTime
			 , @VoidToTime = @FilterToTransTime
			   
		INSERT INTO @bettype_tmp (bettype)
		SELECT DISTINCT pt.bettype
		FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
		WHERE pt.ProductID = 1 -- Sportsbook
			AND pt.bettype NOT IN (10, 9, 29) -- outright, parlay
			AND pt.bettype NOT BETWEEN 221 AND 227 -- Fast Market
			AND pt.SubProduct NOT IN ('Bet Builder', 'MG-SuperLive', 'BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet Builder, Metric Gaming, Bet trade (BT-)

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
				,matchid
				,StatusId
				,checktime
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
				,@MatchId
				,b.statusID
				,b.checktime
		FROM	bettrans b WITH (NOLOCK)	
			LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.transid = m.TransId	
			INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
		WHERE	b.matchid = @matchid
				AND b.betfrom <> 'P'
				AND 1 = CASE WHEN @FilterBy = 1 AND b.transdate BETWEEN @FilterFromTransTime AND @FilterToTransTime THEN 1
							WHEN @FilterBy = 2 AND b.checktime IS NOT NULL AND b.checktime BETWEEN @FilterFromTransTime AND @FilterToTransTime THEN 1
							WHEN @FilterBy = 2 AND b.checktime IS NULL AND b.transdate BETWEEN @FilterFromTransTime AND @FilterToTransTime THEN 1
							ELSE 0 END
				AND (1= CASE WHEN @SubIssueTypeId NOT IN (1,2) THEN 1
							ELSE CASE WHEN (@IsCheckedHomeTeam = 0 AND @IsCheckedAwayTeam = 0) OR (@IsCheckedHomeTeam = 1 AND @IsCheckedAwayTeam = 1) THEN 1
									  WHEN @IsCheckedAwayTeam = 1 AND b.bettype NOT IN (401,403,407,482,484,461,463) THEN 1 
									  WHEN @IsCheckedHomeTeam = 1 AND b.bettype NOT IN (402,404,409,483,485,462,464) THEN 1
									  ELSE 0 END
							END)
		
		---get sub ticket of a mix parlay	
		IF EXISTS (
				SELECT 1
				FROM dbo.bettransm AS bm WITH (NOLOCK)
				WHERE bm.matchid = @matchid
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
					,matchid
					,StatusId
					,checktime
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
					,@MatchId
					,main.statusID
					,sub.checktime
			FROM	dbo.bettransm sub WITH (NOLOCK)				
					INNER HASH JOIN bettrans AS main WITH (NOLOCK) 
						ON	main.refno = sub.refno				
							AND sub.matchid = @matchid
			WHERE sub.betfrom <> 'P'
					AND main.matchid = 29
					AND main.bettype = 29
					AND CASE WHEN @FilterBy = 1 THEN sub.transdate
							WHEN @FilterBy = 2 AND sub.checktime IS NOT NULL THEN sub.checktime
							WHEN @FilterBy = 2 AND sub.checktime IS NULL THEN sub.transdate
						END BETWEEN @FilterFromTransTime AND @FilterToTransTime
				        AND (1= CASE WHEN @SubIssueTypeId NOT IN (1,2) THEN 1
							ELSE CASE WHEN (@IsCheckedHomeTeam = 0 AND @IsCheckedAwayTeam = 0) OR (@IsCheckedHomeTeam = 1 AND @IsCheckedAwayTeam = 1) THEN 1
										   WHEN @IsCheckedAwayTeam = 1 AND sub.bettype NOT IN (401,403,407,482,484,461,463) THEN 1 
										   WHEN @IsCheckedHomeTeam = 1 AND sub.bettype NOT IN (402,404,409,483,485,462,464) THEN 1
										   ELSE 0 END
							END)
		END 

		UPDATE b
		SET TypeAccept = CASE WHEN b.transdate = b.checktime THEN 1 --Auto Accept
							  WHEN ISNULL(b.checktime,0) = DATEADD(SECOND,ISNULL(bi.LiveBetAcceptTime,0),DATEADD( SECOND,ISNULL(bi.SecAcceptTime,0),b.transdate)) THEN 2 --Second Accept
							  WHEN ISNULL(b.checktime,0) ! = DATEADD(SECOND,ISNULL(bi.LiveBetAcceptTime,0),DATEADD( SECOND,ISNULL(bi.SecAcceptTime,0),b.transdate)) THEN 3 --Pending Accept
							  END
		FROM #SpecialDeleteBets b
			LEFT JOIN dbo.BettransInfo bi WITH(NOLOCK) ON b.transid = bi.transid

		INSERT INTO #tblGroupTypeAccept (TypeAccept , MinTicket )
		SELECT TypeAccept, MIN(CASE WHEN @FilterBy = 1 THEN transdate 
									WHEN @FilterBy = 2 AND checktime IS NOT NULL THEN checktime 
									WHEN @FilterBy = 2 AND checktime IS NULL THEN transdate 
									END )
		FROM #SpecialDeleteBets 
		WHERE CASE WHEN @FilterBy = 1 THEN transdate
				   WHEN @FilterBy = 2 AND checktime IS NOT NULL THEN checktime
				   WHEN @FilterBy = 2 AND checktime IS NULL THEN transdate
				END BETWEEN @MinFromTime AND @MaxFromTime
		GROUP BY TypeAccept

		DELETE FROM #tblGroupTypeAccept 
		WHERE 1 = CASE WHEN typeaccept = 1 AND MinTicket < @AutoAcceptTime THEN 1
					   WHEN typeaccept = 2 AND MinTicket < @SecondAcceptTime THEN 1
					   WHEN typeaccept = 3 AND MinTicket < @PendingAcceptTime THEN 1
					   ELSE 0 END

		SELECT @MinTicketFromTime = MIN(MinTicket) 
		FROM #tblGroupTypeAccept

		IF (@MinTicketFromTime IS NOT NULL)
		BEGIN
			DELETE FROM  #SpecialDeleteBets 
			WHERE CASE WHEN @FilterBy = 1 THEN transdate
					   WHEN @FilterBy = 2 AND checktime IS NOT NULL THEN checktime
					   WHEN @FilterBy = 2 AND checktime IS NULL THEN transdate
					END < @MinTicketFromTime

			SELECT @VoidFromTime = @MinTicketFromTime
		END
		ELSE
		BEGIN
			SELECT @MinTicketFromTime = MIN(CASE WHEN @FilterBy = 1 THEN transdate 
												 WHEN @FilterBy = 2 AND checktime IS NOT NULL THEN checktime 
												 WHEN @FilterBy = 2 AND checktime IS NULL THEN transdate 
											END)
			FROM #SpecialDeleteBets 
			WHERE CASE WHEN @FilterBy = 1 THEN transdate
					   WHEN @FilterBy = 2 AND checktime IS NOT NULL THEN checktime
					   WHEN @FilterBy = 2 AND checktime IS NULL THEN transdate
					END >= @MaxFromTime

			DELETE FROM  #SpecialDeleteBets 
			WHERE CASE WHEN @FilterBy = 1 THEN transdate
						WHEN @FilterBy = 2 AND checktime IS NOT NULL THEN checktime
						WHEN @FilterBy = 2 AND checktime IS NULL THEN transdate
					END < @MaxFromTime

			SELECT @VoidFromTime = @MinTicketFromTime
		END

	END
	SELECT @VoidFromTime AS VoidFromTime
		  ,@VoidToTime AS VoidToTime

	DROP TABLE #SpecialDeleteBets
	DROP TABLE #tblGroupTypeAccept

END
GO