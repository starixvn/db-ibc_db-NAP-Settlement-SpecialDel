/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_LogInfo_WC_Select]
(	
	 @RequestId			  INT = 0
	,@ActionId			  INT = 5
	,@IsShowLogOnly		  BIT = 0
	,@IssueTypeId		  INT = 3
	,@WrongScoreInfo	  VARCHAR(MAX) = NULL
	,@TransInfoJson			VARCHAR(MAX) = NULL
)
AS
/*	
	Created by: 20220808@July
	Task: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20220808@July: Create new SP - Refactor code issue type Wrong score [Redmine: #175412]
		- 20220808@July: HF- Request only sub parlay ticket get wrong score show for template message [Redmine: #179752]
		- 20221124@July: [TVS] Increase data size when sending data between web and DB [Redmine: #180863]
		- 20230116@July: HF - Edit Request: Log Info has the difference between START TIME void and MIM TIME highlight [Redmine: #182910]
		- 20230112@July: Wrong Score - No need to exclude Home/Away bet types [Redmine: #182805]
		- 20230120@Max: Change JSON input [Redmine: #180625]

	Param's explanation:
		+ @WrongScoreInfo:
				<root><r MatchId ="" LiveHomeScore="0" LiveAwayScore="1" FilterFromTransTime ="" FilterToTransTime="" FilterBy="" ScoreId='3966607' AATime="" PATime ="" SATime="" SubIssueTypeId ="" /></root>
		(1: By Transdate, 2: By Checktime, 4: Filter by Transdate & Checktime)
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE  @SingleCount			  INT = 0
			,@MainParlayCount		  INT = 0
			,@FilterBy				  TINYINT = 0
			,@MarkTransIds		      VARCHAR(MAX) =''
			,@UnmarkTransIds		  VARCHAR(MAX) = ''
			,@OldActionId			  TINYINT
			,@TransInfoJson_Output	VARBINARY(MAX) = NULL

	DECLARE	 @WrongScoreInfoXML		  XML = NULL
			,@MinAccept				  TINYINT = 0	
		    ,@VoidFromTime			  DATETIME = NULL
		    ,@VoidToTime			  DATETIME = NULL
		    ,@FilterFromTransTime	  DATETIME = NULL
		    ,@FilterToTransTime		  DATETIME = NULL
		    ,@AATime				  TINYINT = 0 
		    ,@PATime				  TINYINT = 0
		    ,@SATime				  TINYINT = 0
			,@ScoreId				  INT = NULL
			,@MatchId				  INT = 0

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
			LiveIndicator		  BIT,
			StatusId			  TINYINT,
			SubStatusId			  TINYINT,
			checktime			  DATETIME,
			accepttype			  TINYINT,
			ScoreId				  INT
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
		,ScoreId				INT
	)

	CREATE TABLE #TransidInRequest (TransId BIGINT, RequestId INT, MainTransId BIGINT, MatchId INT, ScoreId INT)
	CREATE TABLE #FilterInfo (
		 MatchId				INT
		,FilterFromTransTime	DATETIME
		,FilterToTransTime		DATETIME
		,FilterBy				TINYINT
		,ScoreId				INT
		,LiveHomeScore			SMALLINT
		,LiveAwayScore			SMALLINT
		,AATime					TINYINT
		,PATime					TINYINT
		,SATime					TINYINT
		,SubIssueTypeId		    INT
		,FilterVoidFromTime		DATETIME
		,FilterVoidToTime		DATETIME
		,isFinish				BIT
	)
	CREATE TABLE #logInfoVoidPage (RequestId INT, MatchId INT, CashOutCount INT, InstantlySettleCount INT, SettleCount INT, ScoreId INT)
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
	  ,odds SMALLMONEY
	  ,oddsspread MONEY
      ,betfrom NVARCHAR(3)
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
	  ,Subodds SMALLMONEY
	  ,Suboddsspread MONEY
	  ,Subbetfrom NVARCHAR(3)
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
	  ,modds SMALLMONEY
	  ,statuswinlost TINYINT
      ,IsMixParlay BIT
	  ,SiteDBGroupID SMALLINT
	  ,LiveBetAcceptTime SMALLINT
	  ,SecAcceptTime TINYINT
	  ,SubLiveBetAcceptTime SMALLINT
	  ,SubSecAcceptTime TINYINT
	)

	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)
	DECLARE @tblScoreMessage AS TABLE (MatchId INT, ScoreNormalTicket VARCHAR(100), ScoreOfMatch VARCHAR(100))

	DECLARE @Validation AS TABLE (
			 IsInValidTotalTickets   BIT DEFAULT(0)
			,IsExistedInOtherRequest BIT DEFAULT(0)
			,LiveScores				 NVARCHAR(300)
			,MatchId                 INT
			,ScoreId                 INT
		)
	SET @WrongScoreInfoXML = CONVERT(XML, @WrongScoreInfo)
		
	INSERT INTO #FilterInfo(MatchId, LiveHomeScore, LiveAwayScore, FilterFromTransTime, FilterToTransTime, FilterBy, ScoreId, AATime, PATime, SATime, SubIssueTypeId)
	SELECT	T.C.value('./@MatchId', 'INT')
			,T.C.value('./@LiveHomeScore', 'SMALLINT')
			,T.C.value('./@LiveAwayScore', 'SMALLINT')
			,T.C.value('./@FilterFromTransTime', 'DATETIME')
			,T.C.value('./@FilterToTransTime', 'DATETIME')
			,T.C.value('./@FilterBy', 'TINYINT')
			,T.C.value('./@ScoreId', 'INT')
			,CASE WHEN T.C.value('@AATime', 'VARCHAR(100)') = '' THEN NULL ELSE T.C.value('@AATime', 'TINYINT') END 
			,CASE WHEN T.C.value('@PATime', 'VARCHAR(100)') = '' THEN NULL ELSE T.C.value('@PATime', 'TINYINT') END 
			,CASE WHEN T.C.value('@SATime', 'VARCHAR(100)') = '' THEN NULL ELSE T.C.value('@SATime', 'TINYINT') END 
			,T.C.value('./@SubIssueTypeId', 'INT')
	FROM @WrongScoreInfoXML.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@WrongScoreInfoXML = NULL ))

	SELECT TOP (1) @FilterBy = FilterBy 
				 , @MatchId = MatchId 
	FROM #FilterInfo
	
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
        ,IsMixParlay 
	    ,SiteDBGroupID
		,LiveBetAcceptTime 
	    ,SecAcceptTime 
	    ,SubLiveBetAcceptTime 
	    ,SubSecAcceptTime 
	)
	SELECT mid ,t ,s_t ,ref ,c ,hdp1 ,hdp2 ,lh ,la ,li
		,o ,os ,bfr ,btype ,bteam ,bcheck ,s ,tdate ,checkt ,bid
		,tdes ,sid ,s_c ,s_hdp1 ,s_hdp2 ,s_lh ,s_la ,s_li ,s_o ,s_os
		,s_bfr ,s_btype ,s_bteam ,s_bcheck ,s_s ,s_tdate ,s_checkt ,s_tdes ,s_sid ,sre
		,mre ,re ,cr ,stake ,ost ,curr ,bdaq ,ex ,bo ,w
		,acstake ,wld ,m ,statuswl ,isP ,sitedb
		,lbat ,sat ,s_lbat ,s_sat 
	FROM string_split(@TransInfoJson, ',') f
		CROSS APPLY (SELECT CAST(DECOMPRESS(CONVERT(VARBINARY(MAX), f.value, 1)) AS NVARCHAR(MAX)) AS Decompress_TransInfoJson) t
		CROSS APPLY (
				SELECT mid ,t ,s_t ,ref ,c ,hdp1 ,hdp2 ,lh ,la ,li
					  ,o ,os ,bfr ,btype ,bteam ,bcheck ,s ,tdate ,CASE WHEN checkt = '1900-01-01 00:00:00.000' THEN NULL ELSE checkt END AS checkt ,bid
					  ,tdes ,sid ,s_c ,s_hdp1 ,s_hdp2 ,s_lh ,s_la ,s_li ,s_o ,s_os
					  ,s_bfr ,s_btype ,s_bteam ,s_bcheck ,s_s ,s_tdate ,CASE WHEN s_checkt = '1900-01-01 00:00:00.000' THEN NULL ELSE s_checkt END AS s_checkt ,s_tdes ,s_sid ,sre
					  ,mre ,re ,cr ,stake ,ost ,curr ,bdaq ,ex ,bo ,w
					  ,acstake ,CASE WHEN wld = '1900-01-01 00:00:00.000' THEN NULL ELSE wld END AS wld ,m ,statuswl ,isP ,sitedb
					  ,lbat ,sat ,s_lbat ,s_sat 
				FROM OPENJSON(t.Decompress_TransInfoJson) 
				WITH( mid INT, t BIGINT, s_t BIGINT, ref BIGINT, c INT, hdp1 SMALLMONEY, hdp2 SMALLMONEY, lh SMALLINT, la SMALLINT ,li BIT 
					 ,o SMALLMONEY ,os MONEY ,bfr NVARCHAR(3) ,btype SMALLINT ,bteam NVARCHAR(10) ,bcheck NVARCHAR(50) ,s NVARCHAR(10) ,tdate DATETIME ,checkt DATETIME ,bid BIGINT
					 ,tdes NVARCHAR(1000) ,sid TINYINT ,s_c INT ,s_hdp1 SMALLMONEY ,s_hdp2 SMALLMONEY ,s_lh SMALLINT ,s_la SMALLINT ,s_li BIT ,s_o SMALLMONEY ,s_os MONEY 
					 ,s_bfr NVARCHAR(3) ,s_btype SMALLINT ,s_bteam NVARCHAR(10) ,s_bcheck NVARCHAR(50) ,s_s NVARCHAR(10) ,s_tdate DATETIME ,s_checkt DATETIME ,s_tdes NVARCHAR(1000) ,s_sid  TINYINT ,sre INT
					 ,mre INT ,re INT ,cr INT ,stake MONEY ,ost TINYINT ,curr NVARCHAR(50) ,bdaq BIGINT ,ex VARCHAR(1000) ,bo INT ,w MONEY
					 ,acstake MONEY ,wld SMALLDATETIME ,m SMALLMONEY ,statuswl TINYINT ,isP BIT ,sitedb SMALLINT
					 ,lbat SMALLINT ,sat TINYINT ,s_lbat SMALLINT ,s_sat TINYINT 
				)
		) tbl

	BEGIN -- Instant Settlement declaration
		DECLARE @eventstatus_completed NVARCHAR(50) = 'completed'
		CREATE TABLE #InstantSettlementBettypes(matchid INT, bettype SMALLINT)	

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
	
	--Init Validation
	INSERT INTO @Validation (MatchId, ScoreId, LiveScores)
	SELECT DISTINCT MatchId, ScoreId, CAST(livehomescore AS VARCHAR(10)) + '-' + CAST(liveawayscore AS VARCHAR(10)) AS LiveScores
	FROM #FilterInfo

	WHILE (1=1) 
	BEGIN
		SELECT @MinAccept				= 0	
			, @VoidFromTime				= NULL
			, @VoidToTime				= NULL
			, @FilterFromTransTime		= NULL
			, @FilterToTransTime		= NULL
			, @AATime					= 0 
			, @PATime					= 0
			, @SATime					= 0
			, @ScoreId					= NULL
		
		UPDATE TOP(1) m SET
			m.isFinish = 1
			,@FilterFromTransTime = m.FilterFromTransTime
			,@FilterToTransTime = m.FilterToTransTime
			,@AATime = m.AATime
			,@PATime = m.PATime
			,@SATime = m.SATime
			,@ScoreId = m.ScoreId
		FROM #FilterInfo m
		WHERE m.isFinish IS NULL

		IF @@ROWCOUNT = 0 BREAK;
		
		IF (@FilterBy <> 2) OR (@AATime IS NULL AND @PATime IS NULL AND @SATime IS NULL) --case AA,PA,SA fields blank
		BEGIN
			UPDATE #FilterInfo
			SET FilterVoidFromTime = @FilterFromTransTime, FilterVoidToTime = @FilterToTransTime
			WHERE MatchId = @MatchId AND ScoreId = @ScoreId
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
						  ,CASE WHEN @FilterBy = 2 AND b.checktime IS NOT NULL THEN b.checktime
								WHEN @FilterBy = 2 AND b.checktime IS NULL THEN b.transdate
						   END AS FromDate
			)act
			INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
			WHERE act.FromDate BETWEEN @VoidFromTime AND @FilterToTransTime
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
			,LiveIndicator
			,matchid
			,StatusId
			,SubStatusId
			,ScoreId
			,checktime
			,accepttype
		)
	SELECT   b.transid
			,b.transid AS SubTransID
			,b.refno
			,b.custid
			,b.transdate
			,b.bettype
			,b.livehomescore
			,b.liveawayscore
			,b.betdaqid
			,b.liveindicator
			,@MatchId
			,b.statusID
			,b.SubstatusID
			,d.ScoreId
			,b.checktime
			,CASE WHEN b.checktime IS NULL THEN 1 --Auto Accept
				  ELSE CASE WHEN b.checktime = DATEADD(SECOND,ISNULL(b.LiveBetAcceptTime,0) + ISNULL(b.SecAcceptTime,0), b.transdate) THEN 2 --Second Accept
							ELSE 3 END --Pending Accept
				  END AS accepttype
	FROM #tmpTransInfo b
		INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
		INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = b.bettype
		INNER JOIN #FilterInfo d ON d.MatchId = b.matchid
	WHERE	b.matchid = @matchid AND b.IsMixParlay = 0 
			AND 1= CASE WHEN @ActionId <> 2 AND b.statusID NOT IN (101, 102, 103) THEN 1
						WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
						ELSE 0 END
			AND b.betfrom <> 'P'
			AND 1 = CASE WHEN b.livehomescore = 0 AND b.liveawayscore = 0 AND b.liveindicator = 0 AND f.GroupName <> '2H' THEN 0 ELSE 1 END
			AND 1 = CASE WHEN @FilterBy = 1 AND b.transdate BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime THEN 1
						 WHEN @FilterBy = 2 AND ISNULL(b.checktime, b.transdate) BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime THEN 1
						 WHEN @FilterBy = 4 AND ((b.checktime BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime) OR (b.transdate BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime))THEN 1
					   ELSE 0 END 
				
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
				,LiveIndicator
				,matchid
				,StatusId
				,SubStatusId
				,ScoreId
				,checktime
				,accepttype
			)
		SELECT b.transid 
				,b.SubTransID
				,b.refno
				,b.Subcustid				
				,b.Subtransdate
				,b.bettype
				,b.Sublivehomescore
				,b.Subliveawayscore
				,b.IsMixParlay
				,b.Subliveindicator
				,@MatchId
				,b.statusID
				,b.SubstatusID
				,d.ScoreId
				,b.Subchecktime
				,CASE WHEN b.Subchecktime IS NULL THEN 1 --Auto Accept
						ELSE CASE 
									WHEN b.Subchecktime = DATEADD(SECOND,ISNULL(b.SubLiveBetAcceptTime,0) + ISNULL(b.SubSecAcceptTime,0), b.Subtransdate) THEN 2 --Second Accept
									ELSE 3 --Pending Accept
								END
					END AS accepttype
		FROM	#FilterInfo d
				INNER JOIN #tmpTransInfo b ON d.MatchId = b.matchid AND b.IsMixParlay = 1
				INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = b.Subbettype
				INNER JOIN @bettype_tmp bt ON bt.bettype = b.Subbettype
		WHERE 1= CASE WHEN @ActionId <> 2 AND b.SubstatusID NOT IN (101, 102, 103) THEN 1
							WHEN @ActionId = 2 AND b.SubstatusID NOT IN (101, 103) THEN 1
							ELSE 0 END
				AND b.Subbetfrom <> 'P'
				AND b.liveindicator = 0
				AND b.statusID NOT IN (102, 103)
				AND 1 = CASE WHEN b.Sublivehomescore = 0 AND b.Subliveawayscore = 0 AND b.Subliveindicator = 0 AND f.GroupName <> '2H' THEN 0 ELSE 1 END
				AND 1 = CASE WHEN @FilterBy = 1 AND b.Subtransdate BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime THEN 1
						     WHEN @FilterBy = 2 AND ISNULL(b.Subchecktime, b.Subtransdate) BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime THEN 1
						     WHEN @FilterBy = 4 AND ((b.Subchecktime BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime) OR (b.Subtransdate BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime)) THEN 1
							ELSE 0 END 
	END

	/*Get Transid in Request of range Transid*/
	IF @ActionId NOT IN (2)
	BEGIN
		INSERT INTO #TransidInRequest (TransId, RequestId, MainTransId, MatchId, ScoreId)
		SELECT tmp.transid, r.RequestId, tmp.MainTransId, t.matchid, t.ScoreId
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
				INNER JOIN #TransidInRequest t ON t.MatchId = v.MatchId
			WHERE 1 = CASE WHEN @FilterBy = 2 THEN 1
						   WHEN @FilterBy <> 2 AND t.ScoreId = v.ScoreId THEN 1
						   ELSE 0 END
		END
	END

	--Data Section
	INSERT INTO #logInfo (MatchId, LiveScores, VoidFromTime, VoidToTime, SingleCount, CashOutCount, InstantlySettleCount, SettleCount, MainParlayCount, ScoreId, HighLightMinTime)
	SELECT @MatchId AS MatchId
		,CASE WHEN @FilterBy = 2 THEN CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2)) ELSE NULL END AS LiveScores
		,MIN(act.VoidTime) AS VoidFromTime
		,MAX(act.VoidTime) AS VoidToTime
		,COUNT(CASE WHEN b.transid = b.SubTransid THEN b.transid ELSE NULL END) AS SingleCount
		,COUNT(CASE WHEN b.transid = b.SubTransid AND b.StatusId IN (111, 112, 113) AND ISNULL(b.betdaqid,-1) = -2 THEN b.transid ELSE NULL END) AS CashOutCount
		,COUNT(CASE WHEN b.transid = b.SubTransid AND b.StatusId IN (111, 112, 113) AND i.bettype IS NOT NULL AND ISNULL(b.betdaqid,-1) <> -2 THEN  b.transid ELSE NULL END) AS InstantlySettleCount
		,COUNT(CASE WHEN b.transid = b.SubTransid AND b.StatusId IN (111, 112, 113) AND i.bettype IS NULL AND ISNULL(b.betdaqid,-1) <> -2 THEN  b.transid ELSE NULL END) AS SettleCount --Exclude InstantlySettleCount,CO
		,COUNT(CASE WHEN b.transid <> b.SubTransid THEN b.transid ELSE NULL END) AS MainParlayCount
		,b.ScoreId
		,MIN(act.VoidTime) AS HighLightMinTime
	FROM #TVSTicketBets b
		LEFT JOIN #InstantSettlementBettypes i ON i.bettype = b.bettype AND i.matchid = b.matchid
		LEFT JOIN #TransidInRequest t ON t.TransId = b.SubTransid
		CROSS APPLY (SELECT CASE 
								WHEN @FilterBy IN (1,4) THEN b.transdate
								WHEN @FilterBy = 2 AND b.checktime IS NOT NULL THEN b.checktime
								WHEN @FilterBy = 2 AND b.checktime IS NULL THEN b.transdate
							 END AS VoidTime
					)act
	WHERE t.TransId IS NULL
	GROUP BY CASE WHEN @FilterBy = 2 THEN CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2)) ELSE NULL END, b.ScoreId
	ORDER BY CASE WHEN @FilterBy = 2 THEN CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2)) ELSE NULL END, b.ScoreId

	IF @IsShowLogOnly = 1 AND @RequestId <> 0
	BEGIN
		INSERT INTO #logInfoVoidPage (RequestId, MatchId, CashOutCount, InstantlySettleCount, SettleCount, ScoreId)
		SELECT @RequestId
			  ,b.matchid
			  ,COUNT(CASE WHEN ISNULL(b.betdaqid, -1) = -2 THEN s.TransId ELSE NULL END) AS CashOutCount
			  ,COUNT(CASE WHEN i.bettype IS NOT NULL AND ISNULL(b.betdaqid, -1) <> -2 THEN s.TransId ELSE NULL END) AS InstantlySettleCount
			  ,COUNT(CASE WHEN i.bettype IS NULL AND ISNULL(b.betdaqid, -1) <> -2 THEN s.TransId ELSE NULL END) AS SettleCount
			  ,tmp.ScoreId
		FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
			CROSS APPLY (
						SELECT CONVERT(XML, r.TransIds)
						FROM dbo.TicketVoiding_RequestDetail r WITH (NOLOCK)
						WHERE r.Id = s.RequestDetailId
							AND r.RequestId = @RequestId
				)AS t(xDATA)
			CROSS APPLY (
					SELECT t.c.value('@ScoreId','INT') AS ScoreId
					FROM t.xDATA.nodes('/r') t(c)
				) tmp (ScoreId)
			INNER JOIN #tmpTransInfo b ON s.MatchId = b.matchid AND s.TransId = b.transid AND b.IsMixParlay = 0
			LEFT JOIN #InstantSettlementBettypes i ON i.bettype = b.bettype AND i.matchid = s.MatchId
		WHERE s.RequestId = @RequestId
			AND b.StatusId IN (111, 112, 113)
		GROUP BY b.matchid, tmp.ScoreId

		IF @FilterBy <> 2
		BEGIN
			-- 1. Validate table
			SELECT LiveScores
				,IsInValidTotalTickets
				,IsExistedInOtherRequest
				,ScoreId
			FROM @Validation

			-- 2. TransId in request table
			SELECT RequestId, ScoreId, CAST(TransId AS VARCHAR(MAX)) AS TransIds
			FROM #TransidInRequest

			-- 3.Loginfo table
			SELECT rd.MatchId
				,CAST(rd.livehomescore AS VARCHAR(2)) + '-' + CAST(rd.liveawayscore AS VARCHAR(2)) AS LiveScores
				,rd.IssueDetail AS ActualScore
				,rd.VoidFromTime
				,rd.VoidToTime
				,rd.SingleCount
				,tmp.CashOutCount
				,tmp.InstantlySettleCount
				,tmp.SettleCount
				,rd.MainParlayCount
				,a.ScoreId AS ScoreId
			FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
				CROSS APPLY (
						SELECT CONVERT(XML, rd.TransIds)
					)AS t1(xDATA)
				CROSS APPLY (
						SELECT t.c.value('@ScoreId','INT') AS ScoreId
						FROM t1.xDATA.nodes('/r') t(c)
					) a (ScoreId)
				LEFT JOIN #logInfoVoidPage tmp ON rd.RequestId = tmp.RequestId AND rd.MatchId = tmp.MatchId AND tmp.ScoreId = a.ScoreId
			WHERE rd.RequestId = @RequestId 

		END
		ELSE IF @FilterBy = 2
		BEGIN
			-- 1. Validate table
			SELECT MatchId
				,IsInValidTotalTickets
				,IsExistedInOtherRequest
			FROM @Validation

			-- 2. TransId in request table
			SELECT RequestId, MatchId, CAST(TransId AS VARCHAR(MAX)) AS TransIds
			FROM #TransidInRequest
			
			--Check score for void message
			IF EXISTS (SELECT TOP(1) 1 FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK) WHERE s.RequestId = @RequestId)
			BEGIN
					INSERT INTO @tblScoreMessage (MatchId, ScoreNormalTicket)
					SELECT s.MatchId, CAST(b.livehomescore AS VARCHAR(10)) + '-' + CAST(b.liveawayscore AS VARCHAR(10))
					FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
						INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = s.bettype
						INNER JOIN #tmpTransInfo b ON b.transid = s.TransId AND b.IsMixParlay = 0
					WHERE s.RequestId = @RequestId AND f.GroupName <> '2H'
			END

			IF EXISTS (SELECT TOP(1) 1 FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay s WITH (NOLOCK) WHERE s.RequestId = @RequestId)
			BEGIN
					INSERT INTO @tblScoreMessage (MatchId, ScoreNormalTicket)
					SELECT s.MatchId, CAST(b.Sublivehomescore AS VARCHAR(10)) + '-' + CAST(b.Subliveawayscore AS VARCHAR(10))
					FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay s WITH (NOLOCK)
						INNER JOIN #tmpTransInfo b ON b.Subtransid = s.TransId AND b.IsMixParlay = 1
						INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = b.Subbettype			
					WHERE s.RequestId = @RequestId AND f.GroupName <> '2H'
			END

			IF NOT EXISTS (SELECT TOP(1) 1 FROM @tblScoreMessage)
			BEGIN
				INSERT INTO @tblScoreMessage (MatchId, ScoreOfMatch) 
				SELECT rd.MatchId, CAST(m.livehomescore AS VARCHAR(10)) + '-' + CAST(m.liveawayscore AS VARCHAR(10))
				FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
					INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = rd.MatchId
				WHERE rd.RequestId = @RequestId
			END

			SELECT rd.MatchId
				,SUBSTRING(rd.IssueDetail, CHARINDEX('Live:',rd.IssueDetail) + 5, CHARINDEX(';Act:',rd.IssueDetail) - 6) AS LiveScores
				,rd.VoidFromTime
				,rd.VoidToTime
				,rd.SingleCount
				,tmp.CashOutCount AS CashOutCount
				,tmp.InstantlySettleCount
				,tmp.SettleCount
				,rd.MainParlayCount
				,li.HighLightMinTime
				,h.HighlightAcceptType
				,STUFF(s2.ScoreTicket2H,1,1,'') AS ScoreNormalTicket
				,STUFF(sm.ScoreOfMatch,1,1,'') AS ScoreOfMatch
			FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
			   OUTER APPLY (
					SELECT TOP 1 li.HighLightMinTime
					FROM #logInfo li 
					WHERE li.MatchId = rd.MatchId
					ORDER BY li.HighLightMinTime ASC
					) li 
			   LEFT JOIN #logInfoVoidPage tmp ON rd.RequestId = tmp.RequestId AND rd.MatchId = tmp.MatchId
			   OUTER APPLY (
						SELECT  TOP 1 b.accepttype AS HighlightAcceptType
						FROM #TVSTicketBets b
						WHERE b.matchId = rd.MatchId
						AND li.HighLightMinTime = (CASE WHEN b.checktime IS NOT NULL THEN b.checktime
													WHEN b.checktime IS NULL THEN b.transdate END)
				)h
				CROSS APPLY(
					SELECT DISTINCT '|' + l.ScoreNormalTicket FROM @tblScoreMessage l WHERE l.MatchId = rd.MatchId FOR XML PATH('')
				)s2(ScoreTicket2H)
				CROSS APPLY(
					SELECT DISTINCT '|' + l.ScoreOfMatch FROM @tblScoreMessage l WHERE l.MatchId = rd.MatchId FOR XML PATH('')
				)sm(ScoreOfMatch)
			WHERE rd.RequestId = @RequestId

		END
			
		-- 4.Unmark table
		SELECT NULL AS UnmarkTransIds
		
		-- 5. Transinfo table (No need return data)
		SELECT @TransInfoJson_Output AS TransInfoJson

		RETURN;
	END

	--For case no ticket valid
	SELECT @SingleCount = ISNULL(SUM(SingleCount),0)
		  ,@MainParlayCount = ISNULL(SUM(MainParlayCount),0)
	FROM #logInfo
	IF @SingleCount = 0 AND @MainParlayCount = 0
	BEGIN
		IF @FilterBy = 2
		BEGIN
			-- 1. Validate table
			SELECT MatchId
				,1 AS IsInValidTotalTickets
				,IsExistedInOtherRequest
			FROM @Validation

			-- 2. TransId in request table
			IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
			BEGIN
				SELECT RequestId, MatchId,
					STUFF((
					SELECT ', ' + CAST(MainTransId AS VARCHAR(MAX)) 
					FROM #TransidInRequest
					WHERE (RequestId = r.RequestId AND MatchId = r.MatchId)
					ORDER BY TransId
					FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
					,1,2,'') AS TransIds
				FROM #TransidInRequest r
				GROUP BY r.RequestId, r.MatchId
			END
			ELSE
			BEGIN 
				SELECT r.RequestId, r.MatchId, CAST(r.TransId AS VARCHAR(MAX)) AS TransIds
				FROM #TransidInRequest r
			END
			
			-- 3. Loginfo Table
			DELETE #logInfo
			SELECT MatchId, ScoreId FROM #logInfo

			-- 4. Unmark table
			SELECT NULL AS UnmarkTransIds
		
			-- 5. Transinfo table
			SELECT @TransInfoJson_Output AS TransInfoJson

		END
		ELSE 
		BEGIN 
			-- 1. Validate table
			SELECT LiveScores
				,1 AS IsInValidTotalTickets
				,IsExistedInOtherRequest
				,ScoreId
			FROM @Validation
		
			-- 2. TransId in request table
			IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
			BEGIN
				SELECT RequestId, r.ScoreId, 
					STUFF((
					SELECT ', ' + CAST(MainTransId AS VARCHAR(MAX)) 
					FROM #TransidInRequest
					WHERE (RequestId = r.RequestId AND ScoreId = r.ScoreId) 
					FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
					,1,2,'') AS TransIds
				FROM #TransidInRequest r
				GROUP BY r.RequestId, r.ScoreId
			END
			ELSE
			BEGIN 
				SELECT RequestId, ScoreId, CAST(TransId AS VARCHAR(MAX)) AS TransIds
				FROM #TransidInRequest
			END
			
			-- 3. Loginfo Table
			DELETE #logInfo
			SELECT MatchId, ScoreId FROM #logInfo

			-- 4. Unmark table
			SELECT NULL AS UnmarkTransIds

			-- 5. TransInfo table
			SELECT @TransInfoJson_Output AS TransInfoJson
		END

		RETURN;
	END

	IF @FilterBy <> 2
	BEGIN
		UPDATE v 
		SET  v.IsInValidTotalTickets = CASE WHEN ISNULL(l.SingleCount,0) = 0 AND ISNULL(l.MainParlayCount,0) = 0 THEN 1 ELSE 0 END
		FROM @Validation v
		OUTER APPLY( 
				SELECT SUM(SingleCount) AS SingleCount
					,SUM(MainParlayCount) AS MainParlayCount
				FROM #logInfo
				WHERE ScoreId = v.ScoreId
				GROUP BY ScoreId
			)l
		
	END
	ELSE IF @FilterBy = 2
	BEGIN 
		UPDATE v SET v.IsInValidTotalTickets = CASE WHEN ISNULL(l.SingleCount,0) = 0 AND ISNULL(l.MainParlayCount,0) = 0 THEN 1 ELSE 0 END
		FROM @Validation v
		OUTER APPLY( 
				SELECT SUM(SingleCount) AS SingleCount
					,SUM(MainParlayCount) AS MainParlayCount
				FROM #logInfo
				WHERE MatchId = v.MatchId
				GROUP BY MatchId
			)l
	END

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

	IF @FilterBy <> 2
	BEGIN
		-- 1. Validate table
		SELECT LiveScores
			,IsInValidTotalTickets
			,IsExistedInOtherRequest
			,ScoreId
		FROM @Validation

		-- 2. TransId in request table
		IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
		BEGIN
			SELECT RequestId
				,r.ScoreId
				,STUFF((
				SELECT ', ' + CAST(MainTransId AS VARCHAR(MAX)) 
				FROM #TransidInRequest
				WHERE (RequestId = r.RequestId AND ScoreId = r.ScoreId) 
				FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
				,1,2,'') AS TransIds
			FROM #TransidInRequest r
			GROUP BY r.RequestId, r.ScoreId
		END
		ELSE
		BEGIN
			SELECT RequestId, ScoreId, CAST(TransId AS VARCHAR(MAX)) AS TransIds
			FROM #TransidInRequest
		END

		-- 3. Loginfo table
		SELECT MatchId
			,LiveScores
			,MIN(VoidFromTime) AS VoidFromTime
			,MAX(VoidToTime) AS VoidToTime
			,SUM(SingleCount) AS SingleCount
			,SUM(CashOutCount) AS CashOutCount
			,SUM(InstantlySettleCount) AS InstantlySettleCount
			,SUM(SettleCount) AS SettleCount
			,SUM(MainParlayCount) AS MainParlayCount
			,ScoreId
		FROM #logInfo l
		GROUP BY MatchId, LiveScores, ScoreId

	END
	ELSE IF @FilterBy = 2
	BEGIN
		-- 1. Validate table
		SELECT MatchId
			,IsInValidTotalTickets
			,IsExistedInOtherRequest
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
								FROM #logInfo rd WITH(NOLOCK)
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
						WHERE l.MatchId = b.matchid AND l.HighLightMinTime = CASE WHEN b.checktime IS NOT NULL THEN b.checktime 
																			  WHEN b.checktime IS NULL THEN b.transdate END 
				) AS h
	END
	
	-- 4. List ticket unmark   (if any)
	SELECT @UnmarkTransIds AS UnmarkTransIds
		  ,@MarkTransIds AS MarkTransIds

	-- 5. Transinfo table
	SET @TransInfoJson_Output = COMPRESS((SELECT t.matchid AS 'mid'
		,t.transid AS 't'
		,t.Subtransid  AS 's_t'
		,b.custid AS  'c'           
		,b.bettype AS 'btype'
		,b.betid AS 'bid'
		,t.transdate AS 'tdate'
		,t.checktime AS 'checkt'
		,b.IsMixParlay AS 'isP'
		,b.SiteDBGroupID AS 'sitedb'
	FROM #TVSTicketBets t
		INNER JOIN #tmpTransInfo b ON t.matchid = b.matchid AND t.transid = b.transid
	WHERE NOT EXISTS (SELECT 1 FROM #TransidInRequest r WHERE r.TransId = t.SubTransid)
	FOR JSON PATH))
	
	SELECT CONVERT(VARCHAR(MAX), @TransInfoJson_Output, 1) AS TransInfoJson

	DROP TABLE #TVSTicketBets
	DROP TABLE #TransidInRequest
	DROP TABLE #logInfo
	DROP TABLE #InstantSettlementBettypes
	DROP TABLE #FilterInfo
	DROP TABLE #logInfoVoidPage
	DROP TABLE #tmpTransInfo
END
GO


