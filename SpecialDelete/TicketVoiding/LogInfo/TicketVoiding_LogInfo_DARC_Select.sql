/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_LogInfo_DARC_Select]
(	
	 @RequestId			  INT = 0
	,@IssueTypeId		  INT = 1
	,@ActionId			  INT = 5
	,@IsShowLogOnly		  BIT = 0
	,@DARCInfo			  VARCHAR(MAX) = NULL
	,@TransInfo		      XML = NULL
)
AS
/*	
	Created by: July
	Date 20220808
	Task: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20220808@July: Create new SP - Refactor code issue type Danger Accept & Red card [Redmine: #175412]

	Param's explanation:
		+ @DangerAcceptedInfo, @RedCardInfo:
			<root><r MatchId="0" FilterFromTransTime="1" FilterToTransTime ="" FilterBy="" SubIssueTypeId="" AATime="" PATime="" SATime=""/></root>
		(1: By Transdate, 2: By Checktime)
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @SingleCount			INT = 0
			,@MainParlayCount		INT = 0
			,@UnmarkTransIds		VARCHAR(MAX) =''
			,@MarkTransIds		    VARCHAR(MAX) =''
			,@OldActionId			TINYINT

	DECLARE	@DARCInfoInfoXML		XML = NULL
		   ,@MinAccept				TINYINT	= 0	
		   ,@VoidFromTime			DATETIME = NULL
		   ,@VoidToTime				DATETIME = NULL
		   ,@MatchId				INT	= 0
		   ,@FilterFromTransTime	DATETIME = NULL
		   ,@FilterToTransTime		DATETIME = NULL
		   ,@FilterBy				TINYINT = 1
		   ,@SubIssueTypeId			INT	= NULL
		   ,@AATime					TINYINT	= 0 
		   ,@PATime					TINYINT	= 0
		   ,@SATime					TINYINT	= 0

	CREATE TABLE #TVSTicketBets (
			transid               BIGINT,
			SubTransid            BIGINT,
			refno                 BIGINT,
			custid                INT,
			transdate             DATETIME,
			bettype               SMALLINT,
			livehomescore         SMALLINT,
			liveawayscore         SMALLINT,
			betdaqid              BIGINT,
			IsMixParlay           BIT DEFAULT(0),
			matchid               INT,
			StatusId			  TINYINT,
			SubStatusId			  TINYINT,
			checktime			  DATETIME,
			accepttype			  TINYINT,
			SubIssueTypeId		  SMALLINT,
			FilterBy			  TINYINT		
	)

	CREATE TABLE #logInfo (
		 MatchId				INT
		,LiveScores				NVARCHAR(300)
		,VoidFromTime			DATETIME
		,VoidToTime				DATETIME
		,SingleCount			INT
		,CashOutCount			INT
		,InstantlySettleCount	INT
		,SettleCount            INT
		,MainParlayCount		INT
		,HighLightMinTime		DATETIME
		,HighlightAcceptType	TINYINT
	)

	CREATE TABLE #TransidInRequest (TransId BIGINT, RequestId INT, MainTransId BIGINT, MatchId INT)
	CREATE TABLE #logInfoVoidPage (RequestId INT, MatchId INT, CashOutCount INT, InstantlySettleCount INT, SettleCount INT)

	CREATE TABLE #FilterInfo (
		 MatchId				INT
		,FilterFromTransTime	DATETIME
		,FilterToTransTime		DATETIME
		,FilterBy				TINYINT
		,SubIssueTypeId			SMALLINT
		,AATime					TINYINT
		,PATime					TINYINT
		,SATime					TINYINT
		,FilterVoidFromTime		DATETIME
		,FilterVoidToTime		DATETIME
		,isFinish				BIT
	)

	CREATE TABLE #tmpTransInfo(
	   matchid INT
	  ,transid BIGINT 
	  ,Subtransid BIGINT
	  ,refno BIGINT
	  ,custid INT	
      ,hdp1 SMALLMONEY
      ,hdp2 SMALLMONEY
      ,livehomescore SMALLINT
      ,liveawayscore SMALLINT
      ,liveindicator BIT
	  ,odds MONEY
	  ,oddsspread MONEY
      ,betfrom NVARCHAR(1)
      ,bettype SMALLINT
      ,betteam NVARCHAR(10)
	  ,betcheck NVARCHAR(50)
	  ,Status NVARCHAR(10)
      ,transdate DATETIME
	  ,checktime DATETIME
	  ,betid BIGINT
	  ,Transdesc NVARCHAR(1000)
	  ,statusID TINYINT
	  ,Subcustid INT
	  ,Subhdp1 SMALLMONEY
      ,Subhdp2 SMALLMONEY
	  ,Sublivehomescore SMALLINT
      ,Subliveawayscore SMALLINT
	  ,Subliveindicator BIT
	  ,Subodds MONEY
	  ,Suboddsspread MONEY
	  ,Subbetfrom NVARCHAR(1)
	  ,Subbettype SMALLINT
	  ,Subbetteam  NVARCHAR(10)
	  ,Subbetcheck NVARCHAR(50)
	  ,SubStatus NVARCHAR(10)
	  ,Subtransdate DATETIME
	  ,Subchecktime DATETIME
	  ,SubTransdesc  NVARCHAR(1000)
	  ,SubstatusID TINYINT
	  ,srecommend INT
	  ,mrecommend INT
	  ,recommend INT
      ,creator INT
	  ,stake MONEY
	  ,oddstype TINYINT
	  ,CurrencyName NVARCHAR(50)
	  ,betdaqid BIGINT
	  ,ExtraInfo VARCHAR(1000)
	  ,BonusID INT
	  ,winlost	MONEY
	  ,actual_stake MONEY
	  ,winlostdate SMALLDATETIME
	  ,modds MONEY
	  ,statuswinlost MONEY
	  ,LiveBetAcceptTime SMALLINT
	  ,SecAcceptTime TINYINT
	  ,SubLiveBetAcceptTime SMALLINT
	  ,SubSecAcceptTime TINYINT
      ,IsMixParlay BIT
	  ,SiteDBGroupID SMALLINT
	  ,IsMove14 BIT
	)
	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)
	DECLARE @tblHighlightTransId TABLE (MatchId INT, Transid BIGINT, AcceptType TINYINT, VoidTime DATETIME)
	DECLARE @tblScoreMessage AS TABLE (MatchId INT, ScoreNormalTicket VARCHAR(100), ScoreOfMatch VARCHAR(100))

	DECLARE @Validation AS TABLE (
			 IsInValidTotalTickets   BIT DEFAULT(0) 
			,IsExistedInOtherRequest BIT DEFAULT(0) 
			,MatchId                 INT
		)

	SET @DARCInfoInfoXML = CONVERT(XML, @DARCInfo)
	INSERT INTO #FilterInfo (MatchID, FilterFromTransTime, FilterToTransTime, FilterBy, SubIssueTypeId, AATime, PATime, SATime)
	SELECT t.c.value('@MatchId','INT') AS MatchID
			,t.c.value('@FilterFromTransTime','DATETIME') AS FilterFromTransTime
			,t.c.value('@FilterToTransTime','DATETIME') AS FilterToTransTime
			,t.c.value('@FilterBy','TINYINT') AS FilterBy
			,t.c.value('@SubIssueTypeId','SMALLINT') AS SubIssueTypeId
			,CASE WHEN t.c.value('@AATime', 'VARCHAR(100)') = '' THEN NULL ELSE t.c.value('@AATime', 'TINYINT') END 
			,CASE WHEN t.c.value('@PATime', 'VARCHAR(100)') = '' THEN NULL ELSE t.c.value('@PATime', 'TINYINT') END 
			,CASE WHEN t.c.value('@SATime', 'VARCHAR(100)') = '' THEN NULL ELSE t.c.value('@SATime', 'TINYINT') END 
	FROM @DARCInfoInfoXML.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@DARCInfoInfoXML = NULL))

	INSERT INTO #tmpTransInfo( 
		    matchid 
	       ,transid 
		   ,Subtransid 
	       ,refno 
	       ,custid 	
           ,hdp1 
           ,hdp2 
           ,livehomescore 
           ,liveawayscore 
           ,liveindicator 
	       ,odds 
	       ,oddsspread 
           ,betfrom 
           ,bettype 
           ,betteam 
	       ,betcheck 
	       ,Status 
           ,transdate 
	       ,checktime 
	       ,betid 
	       ,Transdesc 
	       ,statusID 
	       ,Subcustid 
	       ,Subhdp1 
           ,Subhdp2 
	       ,Sublivehomescore 
           ,Subliveawayscore 
	       ,Subliveindicator 
	       ,Subodds 
	       ,Suboddsspread 
	       ,Subbetfrom 
	       ,Subbettype 
	       ,Subbetteam  
	       ,Subbetcheck 
	       ,SubStatus 
	       ,Subtransdate 
	       ,Subchecktime 
	       ,SubTransdesc  
	       ,SubstatusID 
	       ,srecommend 
	       ,mrecommend 
	       ,recommend 
           ,creator 
	       ,stake 
	       ,oddstype 
	       ,CurrencyName 
	       ,betdaqid 
	       ,ExtraInfo 
	       ,BonusID 
	       ,winlost	
	       ,actual_stake 
	       ,winlostdate 
	       ,modds 
	       ,statuswinlost 
	       ,LiveBetAcceptTime 
	       ,SecAcceptTime 
	       ,SubLiveBetAcceptTime 
	       ,SubSecAcceptTime 
           ,IsMixParlay 
	       ,SiteDBGroupID 
	       ,IsMove14 
	)
	SELECT t.c.value('@mid','INT') AS matchid	
		,t.c.value('@t','BIGINT') AS transid
		,t.c.value('@s_t','BIGINT') AS Subtransid
		,t.c.value('@ref','BIGINT') AS refno
		,t.c.value('@c','INT') AS custid
		,t.c.value('@hdp1','SMALLMONEY') AS hdp1
		,t.c.value('@hdp2','SMALLMONEY') AS hdp2
		,t.c.value('@lh','SMALLINT') AS livehomescore
		,t.c.value('@la','SMALLINT') AS liveawayscore
		,t.c.value('@li','BIT') AS liveindicator
		,t.c.value('@o','MONEY') AS odds
		,t.c.value('@os','MONEY') AS oddsspread
		,t.c.value('@bfr','NVARCHAR(1)') AS betfrom
		,t.c.value('@btype','SMALLINT') AS bettype
		,t.c.value('@bteam','NVARCHAR(10)') AS betteam
		,t.c.value('@bcheck','NVARCHAR(50)') AS betcheck
		,t.c.value('@s','NVARCHAR(10)') AS Status
		,t.c.value('@tdate','DATETIME') AS transdate
		,CASE WHEN t.c.value('@checkt','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@checkt','DATETIME') END AS checktime
		,t.c.value('@bid','BIGINT') AS betid
		,t.c.value('@tdes','NVARCHAR(1000)') AS Transdesc
		,t.c.value('@sid','TINYINT') AS statusID
		,t.c.value('@s_c','INT') AS Subcustid
		,t.c.value('@s_hdp1','SMALLMONEY') AS Subhdp1
		,t.c.value('@s_hdp2','SMALLMONEY') AS Subhdp2
		,t.c.value('@s_lh','SMALLINT') AS Sublivehomescore
		,t.c.value('@s_la','SMALLINT') AS Subliveawayscore
		,t.c.value('@s_li','BIT') AS Subliveindicator
		,t.c.value('@s_o','MONEY') AS Subodds
		,t.c.value('@s_os','MONEY') AS Suboddsspread
		,t.c.value('@s_bfr','NVARCHAR(1)') AS Subbetfrom
		,t.c.value('@s_btype','SMALLINT') AS Subbettype
		,t.c.value('@s_bteam','NVARCHAR(10)') AS Subbetteam
		,t.c.value('@s_bcheck','NVARCHAR(50)') AS Subbetcheck
		,t.c.value('@s_s','NVARCHAR(10)') AS SubStatus
		,t.c.value('@s_tdate','DATETIME') AS Subtransdate
		,CASE WHEN t.c.value('@s_checkt','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@s_checkt','DATETIME') END AS Subchecktime
		,t.c.value('@s_tdes','NVARCHAR(1000)') AS SubTransdesc
		,t.c.value('@s_sid', 'MONEY') AS SubstatusID
		,t.c.value('@sre','INT') AS srecommend
		,t.c.value('@mre','INT') AS mrecommend
		,t.c.value('@re','INT') AS recommend
		,t.c.value('@cr','INT') AS creator
		,t.c.value('@stake','MONEY') AS stake
		,t.c.value('@ost','TINYINT') AS oddstype
		,t.c.value('@curr','NVARCHAR(50)') AS CurrencyName
		,t.c.value('@bdaq','BIGINT') AS betdaqid
		,t.c.value('@ex','VARCHAR(1000)') AS ExtraInfo
		,t.c.value('@bo','INT') AS BonusID
		,t.c.value('@w','MONEY') AS winlost
		,t.c.value('@acstake','MONEY') AS actual_stake
		,CASE WHEN t.c.value('@wld','SMALLDATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@wld','SMALLDATETIME') END AS winlostdate
		,t.c.value('@m', 'MONEY') AS modds
		,t.c.value('@statuswl', 'MONEY') AS statuswinlost
		,t.c.value('@lbat', 'SMALLINT') AS LiveBetAcceptTime
		,t.c.value('@sat', 'TINYINT') AS SecAcceptTime
		,t.c.value('@s_lbat', 'SMALLINT') AS SubLiveBetAcceptTime
		,t.c.value('@s_sat', 'TINYINT') AS SubSecAcceptTime
		,t.c.value('@isP','BIT') AS IsMixParlay
		,t.c.value('@sitedb','SMALLINT') AS SiteDBGroupID
		,t.c.value('@isM','BIT') AS IsMoved14 
	FROM @TransInfo.nodes('root/r') t(c)	
	OPTION (OPTIMIZE FOR (@TransInfo = NULL))

	BEGIN -- Instant Settlement declaration
		DECLARE @eventstatus_completed NVARCHAR(50) = 'completed'
		CREATE TABLE #InstantSettlementBettypes (matchid INT, bettype SMALLINT)	

		--> Get status of match
		;WITH cte_match AS
		(
			SELECT DISTINCT t.matchid
			FROM #FilterInfo t
				INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = t.matchid and m.eventstatus <> @eventstatus_completed
		)
		,cte_isCalHT AS
		(
			SELECT m.matchid, ISNULL(mr.IsHTCal, 0) AS IsHTCal
			FROM cte_match m
				LEFT JOIN dbo.match_remark mr WITH (NOLOCK) ON mr.matchid = m.matchid
		)
		--> Build bettype list supported for instant settlement based on settlement status of match
		INSERT INTO #InstantSettlementBettypes (matchid, bettype)
		SELECT c.matchid,  f.bettype
		FROM cte_isCalHT c
			CROSS APPLY (
					SELECT bettype
					FROM dbo.f_TVS_GetInstantBettypes() 
					WHERE 1 = CASE WHEN c.IsHTCal = 0 AND InstantType IN (1, 3) THEN 1
								   WHEN c.IsHTCal > 0 AND InstantType IN (2, 3) THEN 1
							       ELSE 0 END
			)f	 	
	END	

	INSERT INTO @bettype_tmp (bettype)
	SELECT DISTINCT pt.bettype
	FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
	WHERE pt.ProductID = 1 -- Sportsbook
		AND pt.bettype NOT IN (10, 9, 29) -- outright, parlay
		AND pt.bettype NOT BETWEEN 221 AND 227 -- Fast Market
		AND pt.SubProduct NOT IN ('Bet Builder', 'MG-SuperLive', 'BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet Builder, Metric Gaming, Bet trade (BT-)

	------Get Return VoidFromTime/VoidToTime
	WHILE (1=1) 
	BEGIN
		SELECT @MinAccept				= 0	
			, @VoidFromTime				= NULL
			, @VoidToTime				= NULL
			, @MatchId					= 0
			, @FilterFromTransTime		= NULL
			, @FilterToTransTime		= NULL
			, @FilterBy					= 1
			, @SubIssueTypeId			= NULL
			, @AATime					= 0 
			, @PATime					= 0
			, @SATime					= 0

		UPDATE TOP(1) m SET
			m.isFinish = 1
			,@MatchId = m.MatchId
			,@FilterFromTransTime = m.FilterFromTransTime
			,@FilterToTransTime = m.FilterToTransTime
			,@FilterBy = m.FilterBy
			,@SubIssueTypeId = m.SubIssueTypeId
			,@AATime = m.AATime
			,@PATime = m.PATime
			,@SATime = m.SATime
		FROM #FilterInfo m
		WHERE m.isFinish IS NULL

		IF @@ROWCOUNT = 0 BREAK;
		
		IF @AATime IS NULL AND @PATime IS NULL AND @SATime IS NULL --case AA,PA,SA fields blank
		BEGIN
			UPDATE #FilterInfo
			SET FilterVoidFromTime = @FilterFromTransTime, FilterVoidToTime = @FilterToTransTime
			WHERE MatchId = @MatchId
		END 
		ELSE IF @IsShowLogOnly = 0
		BEGIN
			SELECT @MinAccept = @AATime

			IF @MinAccept > @PATime SET @MinAccept = @PATime
			IF @MinAccept > @SATime SET @MinAccept = @SATime

			SELECT @VoidFromTime = DATEADD (SECOND,@MinAccept,@FilterFromTransTime)

			SELECT @VoidFromTime = MIN(CASE WHEN act.FromDate >= DATEADD (SECOND,CASE WHEN act.AcceptType = 1 THEN @AATime
																					  WHEN act.AcceptType = 2 THEN @SATime
																					  ELSE @PATime --act.AcceptType = 3
																				 END
																				,@FilterFromTransTime
																			  )
												 THEN act.FromDate ELSE NULL END
											)
				  ,@VoidToTime = MAX(act.FromDate)
			FROM (
				SELECT b.transid, NULL AS subtransid, b.bettype, b.transdate, b.checktime, b.LiveBetAcceptTime, b.SecAcceptTime, b.statusID
				FROM #tmpTransInfo b 
				WHERE b.matchid = @MatchId AND b.IsMixParlay = 0
					AND b.betfrom <> 'P'
					AND ISNULL(b.betdaqid,-1) NOT IN (1)
				UNION ALL
				SELECT NULL AS transid, bm.Subtransid, bm.Subbettype AS bettype, bm.Subtransdate AS transdate, bm.Subchecktime AS checktime, bm.SubLiveBetAcceptTime AS LiveBetAcceptTime, bm.SubSecAcceptTime AS SecAcceptTime, bm.SubstatusID AS statusID
				FROM #tmpTransInfo bm 
				WHERE bm.matchid = @MatchId AND bm.IsMixParlay = 1
					AND bm.Subbetfrom <> 'P'
			)b
			CROSS APPLY (
					SELECT CASE WHEN b.checktime IS NULL THEN 1 --Auto Accept
								ELSE CASE WHEN b.checktime = DATEADD(SECOND,ISNULL(b.LiveBetAcceptTime,0) + ISNULL(b.SecAcceptTime,0), b.transdate) THEN 2 --Second Accept
										  ELSE 3 --Pending Accept
									 END
							END AS AcceptType
						  ,CASE 
								WHEN @FilterBy = 1 THEN b.transdate
								WHEN @FilterBy = 2 AND b.checktime IS NOT NULL THEN b.checktime
								WHEN @FilterBy = 2 AND b.checktime IS NULL THEN b.transdate
						   END AS FromDate
			)act
			INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
			WHERE act.FromDate BETWEEN @VoidFromTime AND @FilterToTransTime
				AND NOT EXISTS (SELECT TOP 1 1 
								FROM dbo.f_TVS_CheckingSubIssueTypeIdExcludeBettypes() f 
								WHERE f.bettype = b.bettype AND f.SubIssueTypeId = @SubIssueTypeId AND f.IssueTypeId = @IssueTypeId)
				AND 1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
							 WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
							 ELSE 0 END
		
			IF @VoidFromTime IS NULL
			BEGIN
				SELECT @VoidFromTime = NULL ,@VoidToTime = NULL
			END

			UPDATE #FilterInfo
			SET FilterVoidFromTime = @VoidFromTime, FilterVoidToTime = @VoidToTime
			WHERE MatchId = @MatchId
		END 
	END
	
	--Init Validation
	INSERT INTO @Validation (MatchId)
	SELECT MatchId
	FROM #FilterInfo
		
	INSERT INTO #TVSTicketBets(
			transid		
			,SubTransid		
			,refno			
			,custid				
			,transdate		
			,bettype 					
			,livehomescore 	
			,liveawayscore 			
			,betdaqid	
			,matchid
			,StatusId
			,SubStatusId
			,checktime
			,accepttype
			,SubIssueTypeId
			,FilterBy
		)
	SELECT   b.transid
			,b.SubTransID
			,b.refno
			,b.custid
			,b.transdate
			,b.bettype
			,b.livehomescore
			,b.liveawayscore
			,b.betdaqid
			,b.matchid
			,b.statusID
			,b.SubstatusID
			,b.checktime
			,CASE 
					WHEN b.checktime IS NULL THEN 1 --Auto Accept
						ELSE CASE 
									WHEN b.checktime = DATEADD(SECOND,ISNULL(b.LiveBetAcceptTime,0) + ISNULL(b.SecAcceptTime,0), b.transdate) THEN 2 --Second Accept
									ELSE 3 --Pending Accept
								END
					END AS accepttype
			,d.SubIssueTypeId
			,d.FilterBy
	FROM #tmpTransInfo b
		INNER JOIN #FilterInfo d ON d.MatchId = b.matchid
		INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
	WHERE 1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
					WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
					ELSE 0 END
		AND b.betfrom <> 'P' AND b.IsMixParlay = 0 
		AND CASE WHEN d.FilterBy = 1 THEN b.transdate 
				 WHEN d.FilterBy = 2 AND b.checktime IS NOT NULL THEN b.checktime 
				 WHEN d.FilterBy = 2 AND b.checktime IS NULL THEN b.transdate 
			END BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime
		AND NOT EXISTS (SELECT TOP 1 1 
						FROM dbo.f_TVS_CheckingSubIssueTypeIdExcludeBettypes() f 
						WHERE f.bettype = b.bettype 
							AND f.SubIssueTypeId = d.SubIssueTypeId 
							AND f.IssueTypeId = @IssueTypeId)
		
	---get sub ticket of a mix parlay	
	IF EXISTS ( SELECT TOP 1 1 FROM #tmpTransInfo bm  WHERE bm.IsMixParlay = 1)
	BEGIN		
		INSERT INTO #TVSTicketBets(
				transid		
				,SubTransid		
				,refno			
				,custid						
				,transdate		
				,bettype					
				,livehomescore	
				,liveawayscore			
				,IsMixParlay
				,matchid
				,StatusId
				,SubStatusId
				,checktime
				,accepttype
				,SubIssueTypeId
				,FilterBy
			)
		SELECT   b.transid AS TransId
				,b.SubTransID
				,b.refno
				,b.Subcustid				
				,b.Subtransdate
				,b.bettype
				,b.Sublivehomescore
				,b.Subliveawayscore
				,b.IsMixParlay
				,b.matchid
				,b.statusID
				,b.SubstatusID
				,b.Subchecktime
				,CASE 
						WHEN b.Subchecktime IS NULL THEN 1 --Auto Accept
						ELSE CASE 
									WHEN b.Subchecktime = DATEADD(SECOND,ISNULL(b.LiveBetAcceptTime,0) + ISNULL(b.SecAcceptTime,0), b.Subtransdate) THEN 2 --Second Accept
									ELSE 3 --Pending Accept
								END
					END AS accepttype
				,d.SubIssueTypeId
				,d.FilterBy
		FROM	#FilterInfo d
				INNER JOIN #tmpTransInfo b ON b.matchid = d.MatchId AND b.IsMixParlay = 1 
		WHERE 1 = CASE WHEN @ActionId <>2 AND b.SubstatusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
					   WHEN @ActionId = 2 AND b.SubstatusID NOT IN (101, 103) THEN 1
					   ELSE 0 END
				AND b.Subbetfrom <> 'P' 
				AND CASE WHEN d.FilterBy = 1 THEN b.Subtransdate
						 WHEN d.FilterBy = 2 AND b.Subchecktime IS NOT NULL THEN b.Subchecktime
						 WHEN d.FilterBy = 2 AND b.Subchecktime IS NULL THEN b.Subtransdate
					END BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime
				AND NOT EXISTS (SELECT TOP 1 1 
								FROM dbo.f_TVS_CheckingSubIssueTypeIdExcludeBettypes() f 
								WHERE f.bettype = b.Subbettype AND f.SubIssueTypeId = d.SubIssueTypeId AND f.IssueTypeId = @IssueTypeId)
	END 

	IF @IssueTypeId = 10 --Red Card issue type 
	BEGIN
		--User selects the "Replacement of Sent-Off player" subtype -> When the system searches ticket, it will get from a ticket that has "Handicap/1H Handicap" bet type.
		DECLARE @MinTimeHDP DATETIME
		SELECT @MinTimeHDP = MIN (CASE WHEN b.FilterBy = 1 THEN b.transdate 
										WHEN b.FilterBy = 2 AND b.checktime IS NOT NULL THEN b.checktime 
										WHEN b.FilterBy = 2 AND b.checktime IS NULL THEN b.transdate 
									END)
		FROM #TVSTicketBets b
		WHERE b.SubIssueTypeId = 21 AND b.bettype IN (1,7)
			
		IF @MinTimeHDP IS NULL
		BEGIN
			DELETE b FROM #TVSTicketBets b WHERE b.SubIssueTypeId = 21
		END
		ELSE 
		BEGIN
			DELETE b FROM #TVSTicketBets b 
			WHERE b.SubIssueTypeId = 21
			AND (CASE WHEN b.FilterBy = 1 THEN b.transdate 
						WHEN b.FilterBy = 2 AND b.checktime IS NOT NULL THEN b.checktime 
						WHEN b.FilterBy = 2 AND b.checktime IS NULL THEN b.transdate 
					END) < @MinTimeHDP
		END
	END

	/*Get Transid in Request of range Transid*/
	IF @ActionId NOT IN (2)
	BEGIN
		INSERT INTO #TransidInRequest (TransId, RequestId, MainTransId, MatchId)
		SELECT tmp.transid, r.RequestId, tmp.MainTransId, t.matchid
		FROM #TVSTicketBets t
			CROSS APPLY (
						SELECT rs.TransId, rs.TransId AS MainTransId, rs.RequestId
						FROM dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK)
						WHERE rs.TransId = t.transid AND rs.MatchId = t.MatchId
						UNION ALL
						SELECT rp.TransId, rp.MainTransId, rp.RequestId
						FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rp WITH (NOLOCK)
						WHERE rp.TransId = t.SubTransid AND rp.MatchId = t.matchid
				)tmp
			INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = tmp.RequestId
		WHERE r.RequestId <> @RequestId AND r.ActionId NOT IN (2)

		IF @@ROWCOUNT <> 0
		BEGIN
			UPDATE v SET v.IsExistedInOtherRequest = 1
			FROM @Validation v
			WHERE EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest t WHERE t.MatchId = v.MatchId)
		END
	END

	--Data Section
	INSERT INTO #logInfo (MatchId, LiveScores, VoidFromTime, VoidToTime, SingleCount, CashOutCount, InstantlySettleCount, SettleCount, MainParlayCount, HighLightMinTime)
	SELECT b.matchid AS MatchId
		,CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2)) AS LiveScores
		,MIN(act.VoidTime) AS VoidFromTime
		,MAX(act.VoidTime) AS VoidToTime
		,COUNT(CASE WHEN b.transid = b.SubTransid THEN b.transid ELSE NULL END) AS SingleCount
		,COUNT(CASE WHEN b.transid = b.SubTransid AND b.StatusId IN (111, 112, 113) AND ISNULL(b.betdaqid,-1) = -2 THEN b.transid ELSE NULL END) AS CashOutCount
		,COUNT(CASE WHEN b.transid = b.SubTransid AND b.StatusId IN (111, 112, 113) AND i.bettype IS NOT NULL AND ISNULL(b.betdaqid,-1) <> -2 THEN  b.transid ELSE NULL END) AS InstantlySettleCount
		,COUNT(CASE WHEN b.transid = b.SubTransid AND b.StatusId IN (111, 112, 113) AND i.bettype IS NULL AND ISNULL(b.betdaqid,-1) <> -2 THEN  b.transid ELSE NULL END) AS SettleCount --Exclude InstantlySettleCount,CO
		,COUNT(CASE WHEN b.transid <> b.SubTransid THEN b.transid ELSE NULL END) AS MainParlayCount
		,MIN(act.VoidTime) AS HighLightMinTime
	FROM #TVSTicketBets b
		LEFT JOIN #InstantSettlementBettypes i ON i.bettype = b.bettype AND i.matchid = b.matchid
		LEFT JOIN #TransidInRequest t ON t.TransId = b.SubTransid
		CROSS APPLY (SELECT CASE 
								WHEN b.FilterBy = 1 THEN b.transdate
								WHEN b.FilterBy = 2 AND b.checktime IS NOT NULL THEN b.checktime
								WHEN b.FilterBy = 2 AND b.checktime IS NULL THEN b.transdate
							 END AS VoidTime
					)act
	WHERE t.TransId IS NULL
	GROUP BY CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2)), b.matchid
	ORDER BY CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2))

	--For case no ticket valid
	SELECT @SingleCount = ISNULL(SUM(SingleCount),0)
		,@MainParlayCount = ISNULL(SUM(MainParlayCount),0)
	FROM #logInfo

	IF @SingleCount = 0 AND @MainParlayCount = 0
	BEGIN
		-- 1. Validate table
		SELECT MatchId, 1 AS IsInValidTotalTickets, IsExistedInOtherRequest
		FROM @Validation

		-- 2. TransId in request table
		IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
		BEGIN
			SELECT RequestId,
				STUFF((
				SELECT ', ' + CAST(MainTransId AS VARCHAR(MAX)) 
				FROM #TransidInRequest
				WHERE (RequestId = r.RequestId AND MatchId = r.MatchId)
				ORDER BY TransId
				FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
				,1,2,'') AS TransIds
				,MatchId
			FROM #TransidInRequest r
			GROUP BY r.RequestId, r.MatchId
		END
		ELSE
		BEGIN
			SELECT RequestId, MatchId, CAST(TransId AS VARCHAR(MAX)) AS TransIds
			FROM #TransidInRequest 
		END
			
		-- 3. Loginfo Table
		DELETE #logInfo
		SELECT MatchId FROM #logInfo

		-- 4. Unmark table
		SELECT NULL AS UnmarkTransIds
		
		-- 5. Transinfo table
		DELETE #tmpTransInfo
		SELECT Matchid FROM #tmpTransInfo

		RETURN;
	END

	IF @IsShowLogOnly = 1 AND @RequestId <> 0
	BEGIN
		-- 1. Validate table
		SELECT MatchId, IsInValidTotalTickets, IsExistedInOtherRequest
		FROM @Validation

		-- 2. TransId in request table
		SELECT CAST(TransId AS VARCHAR(MAX)) AS TransIds, RequestId, MatchId
		FROM #TransidInRequest

		/*Get log info for Void Page*/
		INSERT INTO #logInfoVoidPage (RequestId, MatchId, CashOutCount, InstantlySettleCount, SettleCount)
		SELECT @RequestId
			  ,b.matchid
			  ,COUNT(CASE WHEN ISNULL(b.betdaqid, -1) = -2 THEN s.TransId ELSE NULL END) AS CashOutCount
			  ,COUNT(CASE WHEN i.bettype IS NOT NULL AND ISNULL(b.betdaqid, -1) <> -2 THEN s.TransId ELSE NULL END) AS InstantlySettleCount
			  ,COUNT(CASE WHEN i.bettype IS NULL AND ISNULL(b.betdaqid, -1) <> -2 THEN s.TransId ELSE NULL END) AS SettleCount
		FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
			INNER JOIN #tmpTransInfo b ON b.transid = s.transid AND b.matchid = s.MatchId AND b.IsMixParlay = 0
			LEFT JOIN #InstantSettlementBettypes i ON i.bettype = b.bettype AND i.matchid = s.MatchId
		WHERE s.RequestId = @RequestId
			AND b.StatusId IN (111, 112, 113)
		GROUP BY b.matchid

		--Check score for void message
		IF EXISTS (SELECT TOP(1) 1 FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK) WHERE s.RequestId = @RequestId)
		BEGIN
				INSERT INTO @tblScoreMessage (MatchId, ScoreNormalTicket)
				SELECT s.MatchId, CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2))
				FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
					INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = s.bettype
					INNER JOIN #tmpTransInfo b ON b.transid = s.TransId AND b.IsMixParlay = 0 
				WHERE s.RequestId = @RequestId
					AND f.GroupName <> '2H'
		END

		IF EXISTS (SELECT TOP(1) 1 FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay s WITH (NOLOCK) WHERE s.RequestId = @RequestId)
		BEGIN
				INSERT INTO @tblScoreMessage (MatchId, ScoreNormalTicket)
				SELECT s.MatchId, CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2))
				FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay s WITH (NOLOCK)
					INNER JOIN #tmpTransInfo b ON b.transid = s.TransId AND b.IsMixParlay = 1
					INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = b.bettype			
				WHERE s.RequestId = @RequestId
					AND f.GroupName <> '2H'
		END

		IF NOT EXISTS (SELECT TOP(1) 1 FROM @tblScoreMessage)
		BEGIN
			INSERT INTO @tblScoreMessage (MatchId, ScoreOfMatch) 
			SELECT rd.MatchId, CAST(m.livehomescore AS VARCHAR(2)) + '-' + CAST(m.liveawayscore AS VARCHAR(2))
			FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
				INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = rd.MatchId
			WHERE rd.RequestId = @RequestId
		END

		-- 3. Loginfo Table
		SELECT rd.MatchId
			,SUBSTRING(rd.IssueDetail, CHARINDEX('Live:',rd.IssueDetail) + 5, CHARINDEX(';Act:',rd.IssueDetail) - 6) AS LiveScores
			,rd.VoidFromTime
			,rd.VoidToTime
			,rd.SingleCount
			,t.CashOutCount
			,t.InstantlySettleCount
			,t.SettleCount
			,rd.MainParlayCount
			,rd.VoidFromTime AS HighLightMinTime
			,h.HighlightAcceptType
			,STUFF(s2.ScoreTicket2H,1,1,'') AS ScoreNormalTicket
			,STUFF(sm.ScoreOfMatch,1,1,'') AS ScoreOfMatch
		FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
			OUTER APPLY (SELECT TOP 1 b.accepttype HighlightAcceptType
						 FROM #TVSTicketBets b 
					     WHERE rd.MatchId = b.matchid 
						 AND rd.VoidFromTime = (CASE WHEN b.FilterBy = 1 THEN b.transdate
													 WHEN b.FilterBy = 2 AND b.checktime IS NOT NULL THEN b.checktime
													 WHEN b.FilterBy = 2 AND b.checktime IS NULL THEN b.transdate END
												)
			) AS h
			LEFT JOIN #logInfoVoidPage t ON t.RequestId = rd.RequestId AND t.MatchId = rd.MatchId
			CROSS APPLY(
				SELECT DISTINCT '|' + l.ScoreNormalTicket FROM @tblScoreMessage l WHERE l.MatchId = rd.MatchId FOR XML PATH('')
			)s2(ScoreTicket2H)
			CROSS APPLY(
				SELECT DISTINCT '|' + l.ScoreOfMatch FROM @tblScoreMessage l WHERE l.MatchId = rd.MatchId FOR XML PATH('')
			)sm(ScoreOfMatch)
		WHERE rd.RequestId = @RequestId

		-- 4. Unmark table
		SELECT NULL AS UnmarkTransIds
		
		-- 5. Transinfo table (No need return data)
		DELETE #tmpTransInfo
		SELECT Matchid FROM #tmpTransInfo

		RETURN;
	END

	UPDATE v SET v.IsInValidTotalTickets = CASE WHEN ISNULL(l.SingleCount,0) = 0 AND ISNULL(l.MainParlayCount,0) = 0 THEN 1 ELSE 0 END
	FROM @Validation v
	OUTER APPLY( 
			SELECT SUM(SingleCount) AS SingleCount
				,SUM(MainParlayCount) AS MainParlayCount
			FROM #logInfo
			WHERE MatchId = v.MatchId
			GROUP BY MatchId
		)l
	
	IF @RequestId = 0 AND @ActionId <> 2
	BEGIN
		--Mark ticket when add request
		SELECT @MarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(tp.transid AS VARCHAR(50)) 
											FROM #TVSTicketBets tp   
											WHERE tp.IsMixParlay = 0 AND tp.StatusId IN (0,1)
											AND NOT EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = tp.TransId)-- exist in # request
											FOR XML PATH('')), 1,1,'')
										,'')

		IF @MarkTransIds <> ''
				SET @MarkTransIds = @MarkTransIds + ','

		SELECT @MarkTransIds += ISNULL(STUFF((SELECT ',' + CAST(tp.SubTransid AS VARCHAR(50)) 
											FROM #TVSTicketBets tp   
											WHERE tp.IsMixParlay = 1 AND tp.SubStatusId IN (0,1)
											AND NOT EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = tp.SubTransid)-- exist in # request
											FOR XML PATH('')), 1,1,'')
										,'')

	END
	ELSE IF @IsShowLogOnly = 0 AND @RequestId <> 0 
	BEGIN
		SELECT @OldActionId = ISNULL(ActionId,0) FROM dbo.TicketVoiding_Request WITH(NOLOCK) WHERE RequestId = @RequestId
		
		IF @ActionId <> 2 AND @OldActionId <> 2
		BEGIN
			--Edit request filter on UI -> unmark ticket 
			SELECT @UnmarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(rdt.transid AS VARCHAR(50)) 
											FROM dbo.TicketVoiding_RequestDetailTicket_Single rdt WITH(NOLOCK)
												LEFT JOIN #TVSTicketBets tp ON rdt.TransId=tp.transid AND tp.IsMixParlay = 0
												LEFT JOIN #TransidInRequest tr on tr.TransId = rdt.TransId
											WHERE tp.TransId IS NULL AND tr.TransId is NULL
												AND rdt.RequestId = @RequestId
											FOR XML PATH('')), 1,1,'')
										,'')

			IF @UnmarkTransIds <> ''
				SET @UnmarkTransIds = @UnmarkTransIds + ','

			SELECT @UnmarkTransIds += ISNULL(STUFF((SELECT ',' + CAST(rdt.transid AS VARCHAR(50)) 
											 FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rdt WITH(NOLOCK)
													LEFT JOIN #TVSTicketBets tp ON rdt.TransId=tp.SubTransid AND tp.IsMixParlay = 1
													LEFT JOIN #TransidInRequest tr on tr.TransId = rdt.TransId
											  WHERE tp.SubTransid IS NULL AND tr.TransId IS NULL
													  AND rdt.RequestId=@RequestId
											  FOR XML PATH('')
											), 1,1,'')
										,'')
			
			--Add mark ticket when edit request (mark all again -> support case unmark by function SD)
			SELECT @MarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(tp.transid AS VARCHAR(50))
											FROM #TVSTicketBets tp
												LEFT JOIN #TransidInRequest tr on tr.TransId = tp.transid
											WHERE tp.IsMixParlay = 0 AND tr.TransId IS NULL AND tp.StatusId IN (0,1)
											FOR XML PATH('')), 1, 1, '')
									, '')

			IF @MarkTransIds <> ''
				SET @MarkTransIds = @MarkTransIds + ','

			SELECT @MarkTransIds += ISNULL(STUFF((SELECT ',' + CAST(tp.SubTransid AS VARCHAR(50))
											FROM #TVSTicketBets tp
												LEFT JOIN #TransidInRequest tr on tr.TransId = tp.SubTransid
											WHERE tp.IsMixParlay = 1 AND tr.TransId IS NULL AND tp.SubStatusId IN (0,1)
											FOR XML PATH('')), 1, 1, '')
									, '')
		END
		ELSE IF @ActionId <> 2 AND @OldActionId = 2
		BEGIN
			--Mark ticket when add request
			SELECT @MarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(tp.transid AS VARCHAR(50)) 
												FROM #TVSTicketBets tp   
												WHERE tp.IsMixParlay = 0 AND tp.StatusId IN (0,1)
												AND NOT EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = tp.TransId)-- exist in # request
												FOR XML PATH('')), 1,1,'')
											,'')

			IF @MarkTransIds <> ''
					SET @MarkTransIds = @MarkTransIds + ','

			SELECT @MarkTransIds += ISNULL(STUFF((SELECT ',' + CAST(tp.SubTransid AS VARCHAR(50)) 
												FROM #TVSTicketBets tp   
												WHERE tp.IsMixParlay = 1 AND tp.SubStatusId IN (0,1)
												AND NOT EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = tp.SubTransid)-- exist in # request
												FOR XML PATH('')), 1,1,'')
											,'')
		END
		ELSE IF @ActionId = 2 AND @ActionId <> @OldActionId -- Take note
		BEGIN
			SELECT @UnmarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(rdt.transid AS VARCHAR(50)) 
											FROM dbo.TicketVoiding_RequestDetailTicket_Single rdt WITH(NOLOCK)
											WHERE rdt.RequestId = @RequestId
											FOR XML PATH('')), 1,1,'')
										,'')
			IF @UnmarkTransIds <> ''
				SET @UnmarkTransIds = @UnmarkTransIds + ','
			
			SELECT @UnmarkTransIds += ISNULL(STUFF((SELECT ',' + CAST(rdt.transid AS VARCHAR(50)) 
											 FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rdt WITH(NOLOCK)
											  WHERE rdt.RequestId=@RequestId
											  FOR XML PATH('')
											), 1,1,'')
										,'')
		END
	END

	/*****************Return table **************************/
	-- 1. Validate table
	SELECT MatchId
		, IsInValidTotalTickets
		, IsExistedInOtherRequest
	FROM @Validation

	-- 2. TransId exists in other request table
	IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
	BEGIN
		SELECT RequestId,
			STUFF((
			SELECT ', ' + CAST(MainTransId AS VARCHAR(MAX)) 
			FROM #TransidInRequest
			WHERE (RequestId = r.RequestId AND MatchId = r.MatchId)
			ORDER BY TransId
			FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
			,1,2,'') AS TransIds
			,MatchId
		FROM #TransidInRequest r
		GROUP BY r.RequestId, r.MatchId
	END
	ELSE
	BEGIN
		SELECT RequestId, MatchId, CAST(TransId AS VARCHAR(MAX)) AS TransIds
		FROM #TransidInRequest
	END

	-- 3. Loginfo table
	;WITH _cte AS (
			SELECT MatchId
				,STUFF(w.scores,1,1,'') AS LiveScores
				,MIN(VoidFromTime) AS VoidFromTime
				,MAX(VoidToTime) AS VoidToTime
				,SUM(SingleCount) AS SingleCount
				,SUM(CashOutCount) AS CashOutCount
				,SUM(InstantlySettleCount) AS InstantlySettleCount
				,SUM(SettleCount) AS SettleCount
				,SUM(MainParlayCount) AS MainParlayCount
				,MIN(HighLightMinTime) AS HighLightMinTime
			FROM #logInfo l
				CROSS APPLY(
							SELECT '|' + LiveScores
							FROM #logInfo rd
							where l.MatchId = rd.MatchId
							FOR XML PATH('')
							)w (scores) 
			GROUP BY MatchId, w.scores
		)
	SELECT MatchId
		, LiveScores
		,VoidFromTime
		,VoidToTime
		,SingleCount
		,CashOutCount
		,InstantlySettleCount
		,SettleCount
		,MainParlayCount
		,HighLightMinTime 
		,h.HighlightAcceptType
	FROM _cte l
		OUTER APPLY (SELECT TOP 1 b.accepttype HighlightAcceptType
						 FROM #TVSTicketBets b 
					     WHERE L.MatchId = b.matchid 
						 AND l.HighLightMinTime = (CASE WHEN b.FilterBy = 1 THEN b.transdate
													    WHEN b.FilterBy = 2 AND b.checktime IS NOT NULL THEN b.checktime
													    WHEN b.FilterBy = 2 AND b.checktime IS NULL THEN b.transdate END
												)
			) AS h

	-- 4. List ticket unmark/mark   (if any)
	SELECT @UnmarkTransIds AS UnmarkTransIds
	      ,@MarkTransIds AS MarkTransIds

	-- 5. Transinfo table
	SELECT  t.matchid
		    ,t.transid
			,t.Subtransid
			,t.refno
			,b.custid 
			,b.bettype 
			,b.betid 
			,b.statusID 
			,b.Subcustid 
			,b.Subbettype
			,b.IsMixParlay 
			,b.SiteDBGroupID 
	FROM #TVSTicketBets t
		INNER JOIN #tmpTransInfo b ON t.matchid = b.matchid AND t.transid = b.transid
	WHERE NOT EXISTS (SELECT 1 FROM #TransidInRequest r WHERE r.TransId = t.SubTransid)

	DROP TABLE #TVSTicketBets
	DROP TABLE #TransidInRequest
	DROP TABLE #logInfo
	DROP TABLE #logInfoVoidPage
	DROP TABLE #InstantSettlementBettypes
	DROP TABLE #FilterInfo
	DROP TABLE #tmpTransInfo
END
GO

