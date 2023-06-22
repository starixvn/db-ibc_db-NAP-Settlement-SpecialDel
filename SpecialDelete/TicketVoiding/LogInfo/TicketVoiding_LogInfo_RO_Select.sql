/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_LogInfo_RO_Select]
(	
	 @RequestId			  INT = 0
	,@ActionId			  INT = 5
	,@IsShowLogOnly		  BIT = 0
	,@IssueTypeId		  INT = 19
	,@ReducedOverInfo	  VARCHAR(MAX) = NULL
	,@TransInfoJson		  VARCHAR(MAX) = NULL
)
AS
/*	
	Created: 20230608@Max  
    Task : [TVS] Support void Cricket when reducing over [Redmine: #185833]
    DB: DBTXN/bodb02 
      
    Revisions:      
        - 20230608@Max: Create SP - [Redmine: #185833]

	Param's explanation:	
		- @ReducedOverInfo: 
		<root>
			<r MatchId="" SubIssueTypeId="" BetTypes="1" WicketOver ="" PlayerIds="" Runs="" Live="" NonLive=""/>
			<r MatchId="" SubIssueTypeId="" BetTypes="1,2" WicketOver ="" PlayerIds="" Runs="" Live="" NonLive=""/>
		</root>
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE  @SingleCount			  INT = 0
			,@MainParlayCount		  INT = 0
			,@MarkTransIds		      VARCHAR(MAX) =''
			,@UnmarkTransIds		  VARCHAR(MAX) = ''
			,@OldActionId			  TINYINT
			,@TransInfoJson_Output	  VARBINARY(MAX) = NULL

	DECLARE	 @ReducedOverInfoXML		  XML = NULL
		    ,@VoidFromTime			  DATETIME = NULL
		    ,@VoidToTime			  DATETIME = NULL
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
			betid				  BIGINT,
			SiteDBGroupID		  SMALLINT
	)

	CREATE TABLE #logInfo (
		 MatchId				INT
		,LiveScores				NVARCHAR(300)
		,VoidFromTime			DATETIME
		,VoidToTime				DATETIME
		,SingleCount			INT
		,InstantlySettleCount	INT
		,SettleCount            INT
		,MainParlayCount		INT
	)

	CREATE TABLE #TransidInRequest (TransId BIGINT, RequestId INT, MainTransId BIGINT, MatchId INT)
	CREATE TABLE #FilterInfo (
		 MatchId				INT
	)
	CREATE TABLE #logInfoVoidPage (RequestId INT, MatchId INT, InstantlySettleCount INT, SettleCount INT)
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
      ,betfrom NVARCHAR(4)
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
	  ,Subbetfrom NVARCHAR(4)
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
	  ,CheckTimeCashOut DATETIME
	)

	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)
	DECLARE @tmpUnmarkTransId AS TABLE (TransId BIGINT)
	DECLARE @tmpMarkTransId AS TABLE (TransId BIGINT)
	DECLARE @tblScoreMessage AS TABLE (MatchId INT, ScoreNormalTicket VARCHAR(100), ScoreOfMatch VARCHAR(100))

	DECLARE @Validation AS TABLE (
			 IsInValidTotalTickets   BIT DEFAULT(0)
			,IsExistedInOtherRequest BIT DEFAULT(0)
			,MatchId                 INT
		)
	SET @ReducedOverInfoXML = CONVERT(XML, @ReducedOverInfo)
		
	INSERT INTO #FilterInfo(MatchId)
	SELECT	T.C.value('./@MatchId', 'INT')
	FROM @ReducedOverInfoXML.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@ReducedOverInfoXML = NULL ))

	SELECT TOP (1) @MatchId = MatchId 
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
		,CheckTimeCashOut
	)
    SELECT mid ,t ,s_t ,ref ,c ,hdp1 ,hdp2 ,lh ,la ,li
		,o ,os ,bfr ,btype ,bteam ,bcheck ,s ,tdate ,checkt ,bid
		,tdes ,sid ,s_c ,s_hdp1 ,s_hdp2 ,s_lh ,s_la ,s_li ,s_o ,s_os
		,s_bfr ,s_btype ,s_bteam ,s_bcheck ,s_s ,s_tdate ,s_checkt ,s_tdes ,s_sid ,sre
		,mre ,re ,cr ,stake ,ost ,curr ,bdaq ,ex ,bo ,w
		,acstake ,wld ,m ,statuswl ,isP ,sitedb
		,lbat ,sat ,s_lbat ,s_sat ,checktCO 
	FROM STRING_SPLIT(@TransInfoJson, ',') f
		CROSS APPLY (SELECT CAST(DECOMPRESS(CONVERT(VARBINARY(MAX), f.value, 1)) AS NVARCHAR(MAX)) AS Decompress_TransInfoJson) t
		CROSS APPLY (
				SELECT mid ,t ,s_t ,ref ,c ,hdp1 ,hdp2 ,lh ,la ,li
					  ,o ,os ,bfr ,btype ,bteam ,bcheck ,s ,tdate ,CASE WHEN checkt = '1900-01-01 00:00:00.000' THEN NULL ELSE checkt END AS checkt ,bid
					  ,tdes ,sid ,s_c ,s_hdp1 ,s_hdp2 ,s_lh ,s_la ,s_li ,s_o ,s_os
					  ,s_bfr ,s_btype ,s_bteam ,s_bcheck ,s_s ,s_tdate ,CASE WHEN s_checkt = '1900-01-01 00:00:00.000' THEN NULL ELSE s_checkt END AS s_checkt ,s_tdes ,s_sid ,sre
					  ,mre ,re ,cr ,stake ,ost ,curr ,bdaq ,ex ,bo ,w
					  ,acstake ,CASE WHEN wld = '1900-01-01 00:00:00.000' THEN NULL ELSE wld END AS wld ,m ,statuswl ,isP ,sitedb
					  ,lbat ,sat ,s_lbat ,s_sat ,CASE WHEN checktCO = '1900-01-01 00:00:00.000' THEN NULL ELSE checktCO END AS checktCO
				FROM OPENJSON(t.Decompress_TransInfoJson) 
				WITH( mid INT, t BIGINT, s_t BIGINT, ref BIGINT, c INT, hdp1 SMALLMONEY, hdp2 SMALLMONEY, lh SMALLINT, la SMALLINT ,li BIT 
					 ,o SMALLMONEY ,os MONEY ,bfr NVARCHAR(3) ,btype SMALLINT ,bteam NVARCHAR(10) ,bcheck NVARCHAR(50) ,s NVARCHAR(10) ,tdate DATETIME ,checkt DATETIME ,bid BIGINT
					 ,tdes NVARCHAR(1000) ,sid TINYINT ,s_c INT ,s_hdp1 SMALLMONEY ,s_hdp2 SMALLMONEY ,s_lh SMALLINT ,s_la SMALLINT ,s_li BIT ,s_o SMALLMONEY ,s_os MONEY 
					 ,s_bfr NVARCHAR(3) ,s_btype SMALLINT ,s_bteam NVARCHAR(10) ,s_bcheck NVARCHAR(50) ,s_s NVARCHAR(10) ,s_tdate DATETIME ,s_checkt DATETIME ,s_tdes NVARCHAR(1000) ,s_sid  TINYINT ,sre INT
					 ,mre INT ,re INT ,cr INT ,stake MONEY ,ost TINYINT ,curr NVARCHAR(50) ,bdaq BIGINT ,ex VARCHAR(1000) ,bo INT ,w MONEY
					 ,acstake MONEY ,wld SMALLDATETIME ,m SMALLMONEY ,statuswl TINYINT ,isP BIT ,sitedb SMALLINT
					 ,lbat SMALLINT ,sat TINYINT ,s_lbat SMALLINT ,s_sat TINYINT ,checktCO DATETIME 
				)
		) tbl
	WHERE f.value <> ''

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
	INSERT INTO @Validation (MatchId)
	SELECT DISTINCT MatchId
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
			,betid
			,SiteDBGroupID
			,LiveIndicator
			,matchid
			,StatusId
			,SubStatusId
			,checktime
			
		)
	SELECT DISTINCT  b.transid
			,b.transid AS SubTransID
			,b.refno
			,b.custid
			,b.transdate
			,b.bettype
			,b.livehomescore
			,b.liveawayscore
			,b.betdaqid
			,b.betid
			,b.SiteDBGroupID
			,b.liveindicator
			,@MatchId
			,b.statusID
			,b.SubstatusID
			,b.checktime
	FROM #tmpTransInfo b
		INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
		INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = b.bettype
		INNER JOIN #FilterInfo d ON d.MatchId = b.matchid
	WHERE	b.matchid = @matchid AND b.IsMixParlay = 0 
			AND 1= CASE WHEN @ActionId <> 2 AND b.statusID NOT IN (101, 102, 103) THEN 1
						WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
						ELSE 0 END
			AND b.betfrom <> 'P'

	---get sub ticket of a mix parlay	
	IF EXISTS ( SELECT TOP 1 1 FROM #tmpTransInfo WHERE IsMixParlay = 1)
	BEGIN		
		INSERT INTO #TVSTicketBets(
				transid		
				,SubTransid		
				,refno			
				,custid						
				,transdate		
				,bettype					
				,betid
				,SiteDBGroupID
				,livehomescore	
				,liveawayscore		
				,IsMixParlay
				,LiveIndicator
				,matchid
				,StatusId
				,SubStatusId
				,checktime
			)
		SELECT b.transid 
				,b.SubTransID
				,b.refno
				,b.Subcustid				
				,b.Subtransdate
				,b.Subbettype
				,b.betid
				,b.SiteDBGroupID
				,b.Sublivehomescore
				,b.Subliveawayscore
				,b.IsMixParlay
				,b.Subliveindicator
				,@MatchId
				,b.statusID
				,b.SubstatusID
				,b.Subchecktime
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
				INNER JOIN #TransidInRequest t ON t.MatchId = v.MatchId
		END
		
		--Remove Transid exists in other request
		DELETE FROM #TVSTicketBets 
		WHERE EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = SubTransid)
		
	END

	--Data Section
	INSERT INTO #logInfo (MatchId, LiveScores, VoidFromTime, VoidToTime, SingleCount, InstantlySettleCount, SettleCount, MainParlayCount)
	SELECT @MatchId AS MatchId
		,CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2)) AS LiveScores
		,MIN(b.transdate) AS VoidFromTime
		,MAX(b.transdate) AS VoidToTime
		,COUNT(CASE WHEN b.transid = b.SubTransid THEN b.transid ELSE NULL END) AS SingleCount
		,COUNT(CASE WHEN b.transid = b.SubTransid AND b.StatusId IN (111, 112, 113) AND i.bettype IS NOT NULL AND ISNULL(b.betdaqid,-1) <> -2 THEN  b.transid ELSE NULL END) AS InstantlySettleCount
		,COUNT(CASE WHEN b.transid = b.SubTransid AND b.StatusId IN (111, 112, 113) AND i.bettype IS NULL AND ISNULL(b.betdaqid,-1) <> -2 THEN  b.transid ELSE NULL END) AS SettleCount --Exclude InstantlySettleCount,CO
		,COUNT(CASE WHEN b.transid <> b.SubTransid THEN b.transid ELSE NULL END) AS MainParlayCount
	FROM #TVSTicketBets b
		LEFT JOIN #InstantSettlementBettypes i ON i.bettype = b.bettype AND i.matchid = b.matchid
	GROUP BY CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2))

	IF @IsShowLogOnly = 1 AND @RequestId <> 0
	BEGIN
		/*Get log info for Void Page*/
		INSERT INTO #logInfoVoidPage (RequestId, MatchId, InstantlySettleCount, SettleCount)
		SELECT @RequestId
			  ,s.matchid
			  ,COUNT(CASE WHEN i.bettype IS NOT NULL AND ISNULL(b.betdaqid, -1) <> -2 AND b.StatusId IN (111, 112, 113) THEN s.TransId ELSE NULL END) AS InstantlySettleCount
			  ,COUNT(CASE WHEN i.bettype IS NULL AND ISNULL(b.betdaqid, -1) <> -2 AND b.StatusId IN (111, 112, 113) THEN s.TransId ELSE NULL END) AS SettleCount
		FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
			LEFT JOIN #TVSTicketBets b ON s.MatchId = b.matchid AND s.TransId = b.transid AND b.IsMixParlay = 0
			LEFT JOIN #InstantSettlementBettypes i ON i.bettype = b.bettype AND i.matchid = s.MatchId
		WHERE s.RequestId = @RequestId 
		GROUP BY s.matchid

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

		-- 3.Loginfo table
		SELECT DISTINCT rd.MatchId
			,SUBSTRING(rd.IssueDetail, CHARINDEX('Live:',rd.IssueDetail) + 5, CHARINDEX(';Act:',rd.IssueDetail) - 6) AS LiveScores
			,rd.VoidFromTime
			,rd.VoidToTime
			,rd.SingleCount
			,tmp.InstantlySettleCount
			,tmp.SettleCount
			,rd.MainParlayCount
			,STUFF(s2.ScoreTicket2H,1,1,'') AS ScoreNormalTicket
			,STUFF(sm.ScoreOfMatch,1,1,'') AS ScoreOfMatch
		FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
			LEFT JOIN #logInfoVoidPage tmp ON rd.RequestId = tmp.RequestId AND rd.MatchId = tmp.MatchId
			CROSS APPLY(
				SELECT DISTINCT '|' + l.ScoreNormalTicket
				FROM @tblScoreMessage l
				WHERE l.MatchId = rd.MatchId
				FOR XML PATH('')
			)s2(ScoreTicket2H)
			CROSS APPLY(
				SELECT DISTINCT '|' + l.ScoreOfMatch
				FROM @tblScoreMessage l
				WHERE l.MatchId = rd.MatchId
				FOR XML PATH('')
			)sm(ScoreOfMatch)
		WHERE rd.RequestId = @RequestId 
			
		-- 4. Unmark table (No need -> return table)
		SELECT TransId AS UnmarkTransIds FROM @tmpUnmarkTransId
		
		-- 5. Transinfo table (No need -> return table)
		SELECT @TransInfoJson_Output AS TransInfoJson

		RETURN;
	END

	--For case no ticket valid
	SELECT @SingleCount = ISNULL(SUM(SingleCount),0)
		  ,@MainParlayCount = ISNULL(SUM(MainParlayCount),0)
	FROM #logInfo
	IF @SingleCount = 0 AND @MainParlayCount = 0
	BEGIN
		-- 1. Validate table
		SELECT MatchId
			,1 AS IsInValidTotalTickets
			,IsExistedInOtherRequest
		FROM @Validation
		
		-- 2. TransId in request table
		IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
		BEGIN
			SELECT RequestId, 
				STUFF((
				SELECT ', ' + CAST(MainTransId AS VARCHAR(MAX)) 
				FROM #TransidInRequest
				WHERE (RequestId = r.RequestId) 
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
		
		-- 3. Loginfo table (No need -> return table)
		SELECT MatchId FROM #logInfo WHERE Matchid IS NULL

		-- 4. Unmark table (No need -> return table)
		SELECT TransId AS UnmarkTransIds FROM @tmpUnmarkTransId
		
		-- 5. Transinfo table (No need -> return table)
		SELECT @TransInfoJson_Output AS TransInfoJson
		
		RETURN;
	END

	UPDATE v 
	SET  v.IsInValidTotalTickets = CASE WHEN ISNULL(l.SingleCount,0) = 0 AND ISNULL(l.MainParlayCount,0) = 0 THEN 1 ELSE 0 END
	FROM @Validation v
	OUTER APPLY( 
			SELECT SUM(SingleCount) AS SingleCount
				,SUM(MainParlayCount) AS MainParlayCount
			FROM #logInfo
		)l

	IF @RequestId = 0 AND @ActionId <> 2
	BEGIN
		--Mark ticket when add request
		INSERT INTO @tmpMarkTransId (TransId)
		SELECT tp.SubTransid
		FROM #TVSTicketBets tp
		WHERE tp.SubStatusId IN (0,1)
	END
	ELSE IF @IsShowLogOnly = 0 AND @RequestId <> 0 
	BEGIN
		SELECT @OldActionId = ISNULL(ActionId,0) FROM dbo.TicketVoiding_Request WITH(NOLOCK) WHERE RequestId = @RequestId

		IF @ActionId <> 2 AND @OldActionId <> 2
		BEGIN
			--Edit request filter on UI -> unmark ticket 
			INSERT INTO @tmpUnmarkTransId (TransId)
			SELECT um.TransId
			FROM (
					SELECT s.TransId
					FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH(NOLOCK)
					WHERE s.RequestId = @RequestId
					UNION ALL
					SELECT p.TransId
					FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay p WITH(NOLOCK)
					WHERE p.RequestId = @RequestId
				)um
				LEFT JOIN #TVSTicketBets tp ON um.TransId = tp.SubTransid 
			WHERE tp.TransId IS NULL 

			--Add mark ticket when edit request (mark all again -> support case unmark by function SD)
			INSERT INTO @tmpMarkTransId (TransId)
			SELECT tp.SubTransid
			FROM #TVSTicketBets tp
			WHERE tp.SubStatusId IN (0,1)
		END
		ELSE IF @ActionId <> 2 AND @OldActionId = 2
		BEGIN
			--Mark ticket when add request
			INSERT INTO @tmpMarkTransId (TransId)
			SELECT tp.SubTransid
			FROM #TVSTicketBets tp
			WHERE tp.SubStatusId IN (0,1)
		END
		ELSE IF @ActionId = 2 AND @ActionId <> @OldActionId -- Take note
		BEGIN
			--Unmark ticket 
			INSERT INTO @tmpUnmarkTransId (TransId)
			SELECT s.TransId
			FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH(NOLOCK)
			WHERE s.RequestId = @RequestId
			UNION ALL
			SELECT p.TransId
			FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay p WITH(NOLOCK)
			WHERE p.RequestId = @RequestId
		END

	END
	SELECT @UnmarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
											FROM @tmpUnmarkTransId
											FOR XML PATH('')), 1,1,'')
											,'')

	SELECT @MarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
										FROM @tmpMarkTransId
										FOR XML PATH('')), 1,1,'')
										,'')

	/*****************Return table **************************/

	-- 1. Validate table
	SELECT MatchId
		,IsInValidTotalTickets
		,IsExistedInOtherRequest
	FROM @Validation

	-- 2. TransId in request table
	IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
	BEGIN
		SELECT RequestId
			,STUFF((
			SELECT ', ' + CAST(MainTransId AS VARCHAR(MAX)) 
			FROM #TransidInRequest
			WHERE (RequestId = r.RequestId) 
			FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
			,1,2,'') AS TransIds
			,r.MatchId
		FROM #TransidInRequest r
		GROUP BY r.RequestId, r.MatchId
	END
	ELSE
	BEGIN
		SELECT RequestId, Matchid, CAST(TransId AS VARCHAR(MAX)) AS TransIds
		FROM #TransidInRequest
	END

	-- 3. Loginfo table
	SELECT MatchId
		,STUFF(w.scores,1,1,'') AS LiveScores
		,MIN(VoidFromTime) AS VoidFromTime
		,MAX(VoidToTime) AS VoidToTime
		,SUM(SingleCount) AS SingleCount
		,SUM(InstantlySettleCount) AS InstantlySettleCount
		,SUM(SettleCount) AS SettleCount
		,SUM(MainParlayCount) AS MainParlayCount
	FROM #logInfo l
		CROSS APPLY(
					SELECT '|' + LiveScores
					FROM #logInfo rd
					where l.MatchId = rd.MatchId
					FOR XML PATH('')
					)w (scores) 
	GROUP BY MatchId, w.scores

	-- 4. List ticket unmark   (if any)
	SELECT @UnmarkTransIds AS UnmarkTransIds
		  ,@MarkTransIds AS MarkTransIds

	-- 5. Transinfo table
	SET @TransInfoJson_Output = COMPRESS((SELECT t.matchid AS 'mid'
		,transid AS 't'
		,Subtransid  AS 's_t'
		,custid AS  'c'           
		,bettype AS 'btype'
		,betid AS 'bid'
		,li.VoidFromTime AS 'vft'
		,li.VoidToTime AS 'vtt'
		,IsMixParlay AS 'isP'
		,SiteDBGroupID AS 'sitedb'
	FROM #TVSTicketBets t
		INNER JOIN #logInfo li ON t.matchid = li.MatchId
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


