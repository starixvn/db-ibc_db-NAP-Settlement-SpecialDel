/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_LogInfo_HDP_Select]
(	
	 @RequestId			  INT = 0
	,@ActionId			  INT = 5
	,@IsShowLogOnly		  BIT = 0
	,@IssueTypeId		  INT = 4
	,@WrongHDPInfo		  VARCHAR(MAX) = NULL
	,@TransInfoJson		  VARCHAR(MAX) = NULL
)
AS
/*	
	Created by: 20220510@Max
	Task: Refactor code issue type Wrong HDP & Wrong 1st HDP [Redmine: #172281]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20220510@Max: Create new SP [Redmine: #172281]
		- 20220808@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20221124@July: [TVS] Increase data size when sending data between web and DB [Redmine: #180863]
		- 20221125@July: TVS - Wrong HDP affects to PH bet types [Redmine: #172486]
		- 20230103@Max: Change JSON input [Redmine: #180625]
		- 20230420@July: [TVS] Update the data length of 'betfrom' column [Redmine: #187035]
		- 20230403@July: TVS - Change code poolhouse affect [Redmine: #172975]
		- 20230419@Max: [TVS] New issue type Wrong Odds [Redmine: #179934]
		- 20231004@Max: [TVS] Not display Score in message template when voiding non-live tickets only [Redmine: #193108]
		- 20231017@Max: [TVS] Update rule get tickets when offering wrong handicap [Redmine: #195445]	
		- 20231023@Max: Extend datatype [Redmine: #192202]
		- 20240102@July: [TVS] Recover Ticket - validation/loginfo of other Issuetype void (exclude issuetype recover) [Redmine: #196020]
		- 20240722@July: [TVS] Add Details function for traders of LG/Early teams [Redmine: #206715]
		- 20240912@July: [TVS] Support Sportsbook for Wrong HDP, 1st HDP, OU, 1st OU, & Wrong Odds issue types [Redmine: #210152]
		- 20241216@Lani: [TVS] Add 'GroupName' columns returned [Redmine: #213960]
		- 20250102@Lani: [TVS] Add new filter (FilterBetTypeId, FilterBetIdX, FilterBetIdY) [Redmine: #215545]

	Param's explanation:
		+ @WrongHDPInfo, @Wrong1stHDPInfo:
			<root><r MatchId="0" FilterFromTransTime="1" FilterToTransTime ="" HomeFavorite ="" AwayFavorite ="" HdpValue ="" SubIssueTypeId="" PoolHouseCheckedBetTypes ="1,2,3,4" IsMainMatch="true" IsLinkGroup1X2 ="" IsLinkGroupAIO = "" LiveIndicator =""/></root>
	         (*) PoolHouseCheckedBetTypes   : ALL - (all bettype của ticket)
											 '1,2,3' - (bettype selected)
											 -1 - (no bettype affected)
											 '' - (uncheck all bettype PH)

*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @SingleCount			  INT = 0
			,@MainParlayCount		  INT = 0
			,@WrongHDPInfoXML		  XML = NULL
			,@MarkTransIds		      VARCHAR(MAX) =''
			,@UnmarkTransIds		  VARCHAR(MAX) =''
	 		,@OldActionId			  TINYINT
			,@PHBettypes			  VARCHAR(MAX) =''
			,@MainMatchId			  INT
			,@PoolHouseCheckedBetTypes VARCHAR(MAX) = ''
			,@TransInfoJson_Output	VARBINARY(MAX) = NULL
			,@MatchId				   INT
			,@LogInfoTicketsJson	  VARBINARY(MAX) = NULL

	CREATE TABLE #TVSTicketBets (
			transid               BIGINT,
			SubTransid            BIGINT,
			refno                 BIGINT,
			custid                INT,
			transdate             DATETIME,
			bettype               SMALLINT,
			Subbettype			  SMALLINT,
			livehomescore         SMALLINT,
			liveawayscore         SMALLINT,
			betdaqid              BIGINT,
			IsMixParlay           BIT DEFAULT(0),
			matchid               INT,
			StatusId			  TINYINT,
			SubStatusId			  TINYINT,
			SubIssueTypeId		  SMALLINT,
			GroupName			  VARCHAR(50),
			LiveIndicator		  BIT,
			SettledType			  TINYINT,
			FilterBetIdX		  NVARCHAR(50),
			FilterBetIdY		  NVARCHAR(50)
	)

	CREATE TABLE #logInfo (
		 MatchId						INT
		,LiveScores						NVARCHAR(300)
		,VoidFromTime					DATETIME
		,VoidToTime						DATETIME
		,SingleCount					INT
		,CashOutCount					INT
		,SettleCount					INT
		,InstantlySettleCount			INT
		,MainParlayCount 				INT
		,PoolHouseSingleCount			INT
		,PoolHouseCashOutCount			INT
		,PoolHouseSettleCount 			INT
		,PoolHouseInstantlySettleCount	INT
		,PoolHouseMainParlayCount 		INT
	)

	CREATE TABLE #TransidInRequest (TransId BIGINT, RequestId INT, MainTransId BIGINT, MatchId INT)
	CREATE TABLE #FilterInfo (
		 MatchId				INT
		,FilterFromTransTime	DATETIME
		,FilterToTransTime		DATETIME
		,SubIssueTypeId			SMALLINT
		,HomeFavorite			VARCHAR(1000)
		,AwayFavorite			VARCHAR(1000)
		,HdpValue				VARCHAR(1000)
		,PoolHouseCheckedBetTypes VARCHAR(MAX)
		,IsMainMatch			VARCHAR(10)
		,IsLinkGroup1X2			BIT DEFAULT(0) --Soccer: call API get link log | Other sports: No.default = 0
		,IsLinkGroupAIO			BIT DEFAULT(0) --Soccer: call API get link log | Other sports: No.default = 0
		,LiveIndicator			BIT DEFAULT(0)
		,FilterBetTypeId		SMALLINT
		,FilterBetIdX			NVARCHAR(50) -- Get X of bettype
		,FilterBetIdY			NVARCHAR(50) -- Get Y of bettype
	)
	CREATE TABLE #logInfoVoidPage (
		RequestId						INT
		,MatchId						INT
		,CashOutCount					INT
		,SettleCount					INT
		,InstantlySettleCount			INT
		,PoolHouseSingleCount			INT
		,PoolHouseCashOutCount			INT
		,PoolHouseSettleCount			INT
		,PoolHouseInstantlySettleCount	INT
		,PoolHouseMainParlayCount 		INT
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
	  ,homeid INT
      ,awayid INT
	  ,leagueid INT
	  ,isNeutral BIT
	  ,matchcode NVARCHAR(50)
	  ,sporttype SMALLINT
	  ,eventstatus NVARCHAR(50)
	  ,SettlementStatus TINYINT
	  ,username NVARCHAR(50)
	  ,IsDeposit BIT
	  ,WalletType TINYINT
	  ,RefCode BIGINT
	  ,SettledType TINYINT -- 1: Instant Settlement, 2: Normal Settlement
	)
	DECLARE @tblScoreMessage AS TABLE (MatchId INT, ScoreNormalTicket VARCHAR(100), ScoreOfMatch VARCHAR(100))
	DECLARE @Validation AS TABLE (
			 IsInValidTotalTickets   BIT DEFAULT(0) 
			,IsExistedInOtherRequest BIT DEFAULT(0) 
			,MatchId                 INT
			,IsPoolHouseAffected	 BIT DEFAULT(0)
			,LogInfoTicketsJson		 VARCHAR(MAX)
		    ,IsFinish BIT
		)
	DECLARE @tmpUnmarkTransId AS TABLE (TransId BIGINT)
	DECLARE @tmpMarkTransId AS TABLE (TransId BIGINT)
	DECLARE @tmpLogInfoTickets TABLE (TransId BIGINT)

	SET @WrongHDPInfoXML = CONVERT(XML, @WrongHDPInfo)
	INSERT INTO #FilterInfo( 
			MatchID				
			,FilterFromTransTime	
			,FilterToTransTime			
			,HomeFavorite
			,AwayFavorite
			,HdpValue
			,SubIssueTypeId
			,PoolHouseCheckedBetTypes
			,IsMainMatch
			,IsLinkGroup1X2
			,IsLinkGroupAIO
			,LiveIndicator
			,FilterBetTypeId
			,FilterBetIdX
			,FilterBetIdY
		)
	SELECT t.c.value('@MatchId','INT') AS MatchID
			,CASE WHEN t.c.value('@FilterFromTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterFromTransTime','DATETIME') END AS FilterFromTransTime
			,CASE WHEN t.c.value('@FilterToTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterToTransTime','DATETIME') END AS FilterToTransTime
			,CASE WHEN ISNULL(t.c.value('@HomeFavorite','VARCHAR(1000)'),'') ='' THEN NULL ELSE t.c.value('@HomeFavorite','VARCHAR(1000)')  END AS HomeFavorite
			,CASE WHEN ISNULL(t.c.value('@AwayFavorite','VARCHAR(1000)'),'') = '' THEN NULL ELSE t.c.value('@AwayFavorite','VARCHAR(1000)')  END AS AwayFavorite
			,CASE WHEN ISNULL(t.c.value('@HdpValue','VARCHAR(1000)'),'') = '' THEN NULL ELSE t.c.value('@HdpValue','VARCHAR(1000)')  END AS HdpValue
			,t.c.value('@SubIssueTypeId','SMALLINT') AS SubIssueTypeId
			,t.c.value('@PoolHouseCheckedBetTypes','VARCHAR(MAX)') AS PoolHouseCheckedBetTypes
			,t.c.value('@IsMainMatch','VARCHAR(10)') AS IsMainMatch
			,t.c.value('@IsLinkGroup1X2','BIT') AS IsLinkGroup1X2
			,t.c.value('@IsLinkGroupAIO','BIT') AS IsLinkGroupAIO
			,t.c.value('@LiveIndicator','BIT') AS LiveIndicator
			,t.c.value('@FilterBetTypeId','SMALLINT') AS FilterBetTypeId
			,t.c.value('@FilterBetIdX','NVARCHAR(50)') AS FilterBetIdX
			,t.c.value('@FilterBetIdY','NVARCHAR(50)') AS FilterBetIdY
	FROM @WrongHDPInfoXML.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@WrongHDPInfoXML = NULL))

	BEGIN -- Instant Settlement declaration
		
		CREATE TABLE #InstantSettlementBettypes (matchid INT, bettype SMALLINT, betid BIGINT)	
		
		DECLARE @eventstatus_completed NVARCHAR(50) = 'completed'
		CREATE TABLE #CTE_match (matchid INT, sporttype SMALLINT)
		CREATE TABLE #CTE_isCal (matchid INT, IsHTCal BIT, ResourceId VARCHAR(20))

		INSERT INTO #CTE_match (matchid, sporttype)
		SELECT DISTINCT t.matchid, m.sporttype
		FROM #FilterInfo t
			INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = t.matchid and m.eventstatus <> @eventstatus_completed
			
		IF EXISTS (SELECT TOP 1 1 FROM #CTE_match WHERE sporttype = 1) --Soccer	 
		BEGIN 
			INSERT INTO #CTE_isCal (matchid, IsHTCal)
			SELECT m.matchid, ISNULL(mr.IsHTCal, 0) AS IsHTCal
			FROM #CTE_match m
				LEFT JOIN dbo.match_remark mr WITH (NOLOCK) ON mr.matchid = m.matchid
			WHERE m.sporttype = 1

			--> Build bettype list supported for instant settlement based on settlement status of match
			INSERT INTO #InstantSettlementBettypes (matchid, bettype)
			SELECT c.matchid,  f.bettype
			FROM #CTE_isCal c
				CROSS APPLY (
						SELECT bettype
						FROM dbo.f_TVS_GetInstantBettypes() 
						WHERE 1 = CASE WHEN c.IsHTCal = 0 AND InstantType IN (1, 3) THEN 1
									   WHEN c.IsHTCal > 0 AND InstantType IN (2, 3) THEN 1
									ELSE 0 END
				)f	 	
		END
		IF EXISTS (SELECT TOP 1 1 FROM #CTE_match WHERE sporttype = 2) --Basketball
		BEGIN
			INSERT INTO #CTE_isCal (matchid, ResourceId)
			SELECT m.matchid, rd.ResourceId
			FROM #CTE_match m
				LEFT JOIN DBPRO.bodb02.dbo.ResultDetail rd WITH (NOLOCK) 
					ON rd.matchid = m.matchid
					AND ResultStatusID IN (2,5) AND (ResourceId LIKE 'Q[1-4]' OR ResourceId IN ('01','OT')) 
			WHERE m.sporttype = 2

			INSERT INTO #InstantSettlementBettypes (matchid, bettype, betid)
			SELECT DISTINCT c.matchid, f.bettype, f.betid
			FROM #CTE_isCal c
				CROSS APPLY (
						SELECT bettype, betid
						FROM dbo.f_TVS_GetInstantBettypes()
						WHERE InstantType IS NULL
						AND 1 = CASE WHEN c.ResourceId IS NULL THEN 1 --NOT executed on this match.
									 WHEN c.ResourceId IS NOT NULL AND ResourceId NOT IN (SELECT ResourceId FROM #CTE_isCal) THEN 1
									 ELSE 0 END
				)f	 	
		END
		DROP TABLE #CTE_match
		DROP TABLE #CTE_isCal
	END	

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
		   ,WalletType 
	       ,RefCode 
	)
	SELECT mid ,t ,s_t ,ref ,c ,hdp1 ,hdp2 ,lh ,la ,li
		,o ,os ,bfr ,btype ,bteam ,bcheck ,s ,tdate ,checkt ,bid
		,tdes ,sid ,s_c ,s_hdp1 ,s_hdp2 ,s_lh ,s_la ,s_li ,s_o ,s_os
		,s_bfr ,s_btype ,s_bteam ,s_bcheck ,s_s ,s_tdate ,s_checkt ,s_tdes ,s_sid ,sre
		,mre ,re ,cr ,stake ,ost ,curr ,bdaq ,ex ,bo ,w
		,acstake ,wld ,m ,statuswl ,isP ,sitedb
		,wt ,refc
	FROM STRING_SPLIT(@TransInfoJson, ',') f
		CROSS APPLY (SELECT CAST(DECOMPRESS(CONVERT(VARBINARY(MAX), f.value, 1)) AS NVARCHAR(MAX)) AS Decompress_TransInfoJson) t
		CROSS APPLY (
				SELECT mid ,t ,s_t ,ref ,c ,hdp1 ,hdp2 ,lh ,la ,li
					  ,o ,os ,bfr ,btype ,bteam ,bcheck ,s ,tdate ,CASE WHEN checkt = '1900-01-01 00:00:00.000' THEN NULL ELSE checkt END AS checkt ,bid
					  ,tdes ,sid ,s_c ,s_hdp1 ,s_hdp2 ,s_lh ,s_la ,s_li ,s_o ,s_os
					  ,s_bfr ,s_btype ,s_bteam ,s_bcheck ,s_s ,s_tdate ,CASE WHEN s_checkt = '1900-01-01 00:00:00.000' THEN NULL ELSE s_checkt END AS s_checkt ,s_tdes ,s_sid ,sre
					  ,mre ,re ,cr ,stake ,ost ,curr ,bdaq ,ex ,bo ,w
					  ,acstake ,CASE WHEN wld = '1900-01-01 00:00:00.000' THEN NULL ELSE wld END AS wld ,m ,statuswl ,isP ,sitedb
					  ,wt ,refc
				FROM OPENJSON(t.Decompress_TransInfoJson) 
				WITH( mid INT, t BIGINT, s_t BIGINT, ref BIGINT, c INT, hdp1 SMALLMONEY, hdp2 SMALLMONEY, lh SMALLINT, la SMALLINT ,li BIT 
					 ,o SMALLMONEY ,os MONEY ,bfr NVARCHAR(4) ,btype SMALLINT ,bteam NVARCHAR(10) ,bcheck NVARCHAR(50) ,s NVARCHAR(10) ,tdate DATETIME ,checkt DATETIME ,bid BIGINT
					 ,tdes NVARCHAR(1000) ,sid TINYINT ,s_c INT ,s_hdp1 SMALLMONEY ,s_hdp2 SMALLMONEY ,s_lh SMALLINT ,s_la SMALLINT ,s_li BIT ,s_o SMALLMONEY ,s_os MONEY 
					 ,s_bfr NVARCHAR(4) ,s_btype SMALLINT ,s_bteam NVARCHAR(10) ,s_bcheck NVARCHAR(50) ,s_s NVARCHAR(10) ,s_tdate DATETIME ,s_checkt DATETIME ,s_tdes NVARCHAR(1000) ,s_sid  TINYINT ,sre INT
					 ,mre INT ,re INT ,cr INT ,stake MONEY ,ost TINYINT ,curr NVARCHAR(50) ,bdaq BIGINT ,ex VARCHAR(1000) ,bo INT ,w MONEY
					 ,acstake MONEY ,wld SMALLDATETIME ,m SMALLMONEY ,statuswl TINYINT ,isP BIT ,sitedb SMALLINT
					 ,wt TINYINT ,refc BIGINT
				)
		) tbl
	WHERE f.value <> ''

	---UPDATE column show loginfo details
	BEGIN
		UPDATE b
		SET matchcode 	= m.matchcode
			,homeid 	= m.homeid
			,awayid 	= m.awayid
			,leagueid 	= m.leagueid
			,sporttype 	= m.sporttype
			,IsNeutral 	= ISNULL(m.IsNeutral, CONVERT(BIT, 0))
			,eventstatus = ISNULL(m.eventstatus,'')
			,SettlementStatus = ISNULL(m.SettlementStatus, 0)
			,username = ci.username
		FROM #tmpTransInfo b
			INNER JOIN dbo.match m WITH (NOLOCK) ON	b.matchid = m.matchid
			INNER JOIN CustDB.dbo.custInfo ci WITH(NOLOCK) ON b.custid = ci.custid
	
		-- update Isdeposit
		UPDATE b 
			SET IsDeposit = 1
		FROM #tmpTransInfo b
		WHERE EXISTS (SELECT d.custid FROM CustDB.dbo.Dep_CustSuper d WITH(NOLOCK) WHERE d.custid = b.srecommend)
	
		-- update get instant/settle
		UPDATE b
		SET  b.SettledType = CASE 
								WHEN ISNULL(b.eventstatus, '') <> @eventstatus_completed
									THEN CASE
											WHEN b.sporttype = 1 AND EXISTS (
												SELECT TOP 1 1
												FROM #InstantSettlementBettypes AS i
												WHERE b.Subbettype = i.bettype
												) THEN 1
											WHEN b.sporttype = 2 AND EXISTS (
												SELECT TOP 1 1
												FROM #InstantSettlementBettypes AS i
												WHERE b.Subbettype = i.bettype AND (b.betid = i.betid OR b.betid IS NULL)
												) THEN 1
											ELSE 2
										END
								ELSE 2
							END
		FROM #tmpTransInfo b 
		WHERE ISNULL(b.betdaqid,0) <> -2 AND b.SubStatusId IN (111, 112, 113) 
	
	END

	--Init Validation
	INSERT INTO @Validation (MatchId, IsPoolHouseAffected)
	SELECT MatchId, CASE WHEN d.IsLinkGroup1X2 = 0 AND d.IsLinkGroupAIO = 0 THEN 0 ELSE 1 END
	FROM #FilterInfo d

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
			,Subbettype
			,SubStatusId
			,SubIssueTypeId
			,GroupName
			,LiveIndicator
			,SettledType
			,FilterBetIdX
			,FilterBetIdY
		)
	SELECT  DISTINCT b.transid
			,b.transid AS SubTransID
			,b.refno
			,b.custid
			,b.transdate
			,b.bettype
			,b.livehomescore
			,b.liveawayscore
			,b.betdaqid
			,b.matchid
			,b.statusID
			,b.Subbettype
			,b.SubstatusID
			,d.SubIssueTypeId
			,CASE WHEN b.bettype = d.FilterBetTypeId THEN 'HDP'
				  WHEN d.IsMainMatch = 'true' AND f.BetType IS NOT NULL AND f.GroupMatch = 0 THEN 'PH' --1X2
				  WHEN d.IsMainMatch = 'true' AND f.BetType IS NOT NULL AND f.GroupMatch <> 0 THEN 'PH' --AIO
			END AS GroupName
			,b.liveindicator
			,b.SettledType
			,CASE WHEN b.IsMixParlay = 0 THEN b.betid ELSE b.Subbetcheck END AS FilterBetIdX
			,CASE WHEN b.IsMixParlay = 0 THEN RIGHT(b.betid,2) ELSE RIGHT(b.Subbetcheck,2) END AS FilterBetIdY
	FROM	#tmpTransInfo b 
		INNER JOIN #FilterInfo d ON d.MatchId = b.matchid
		OUTER APPLY (
			SELECT DISTINCT CONVERT(SMALLMONEY, value) AS HomeFavorite
			FROM STRING_SPLIT(d.HomeFavorite, '&')
			WHERE value <> ''				
		)xHDPHome
		OUTER APPLY (
			SELECT DISTINCT CONVERT(SMALLMONEY, value) AS AwayFavorite
			FROM STRING_SPLIT(d.AwayFavorite, '&')
			WHERE value <> ''				
		)xHDPAway
		OUTER APPLY (
			SELECT DISTINCT CONVERT(SMALLMONEY, value) AS HdpValue
			FROM STRING_SPLIT(d.HdpValue, '&')
			WHERE value <> ''				
		)xHDPvalue
		LEFT JOIN dbo.f_TVS_CheckingIssueTypePHBettypes() f ON f.IssueTypeId = @IssueTypeId AND b.bettype = f.BetType
	WHERE b.betfrom <> 'P'  
		AND b.transdate BETWEEN d.FilterFromTransTime AND d.FilterToTransTime
		AND b.liveindicator = d.LiveIndicator AND b.IsMixParlay = 0
		AND 1 = CASE WHEN @ActionId <> 2 AND b.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
					 WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
					 ELSE 0 END
		AND 1 = CASE WHEN b.bettype = d.FilterBetTypeId
							AND d.SubIssueTypeId IN (8) 
							AND 1 = CASE WHEN xHDPHome.HomeFavorite <> 0 AND b.hdp1 = xHDPHome.HomeFavorite THEN 1
										WHEN xHDPHome.HomeFavorite = 0 AND b.hdp1 = 0 AND b.hdp2 = 0 THEN 1 --case input hdp value filter = 0
									ELSE 0 END
							AND d.HomeFavorite IS NOT NULL THEN 1
					 WHEN b.bettype = d.FilterBetTypeId
							AND d.SubIssueTypeId IN (8) 
							AND 1 = CASE WHEN xHDPAway.AwayFavorite <> 0 AND b.hdp2 = xHDPAway.AwayFavorite THEN 1
										WHEN xHDPAway.AwayFavorite = 0 AND b.hdp2 = 0 AND b.hdp1 = 0 THEN 1 --case input hdp value filter = 0
									ELSE 0 END
							AND d.AwayFavorite IS NOT NULL THEN 1
					 WHEN b.bettype = d.FilterBetTypeId
							AND d.SubIssueTypeId IN (22) 
							AND 1 = CASE WHEN xHDPvalue.HdpValue <> 0 AND b.hdp2 = xHDPvalue.HdpValue THEN 1
										WHEN xHDPvalue.HdpValue = 0 AND b.hdp2 = 0 AND b.hdp1 = 0 THEN 1 --case input hdp value filter = 0
									ELSE 0 END
							AND d.HdpValue IS NOT NULL THEN 1 --Away Virtual Head Reversed
					 WHEN b.bettype = d.FilterBetTypeId 
							AND d.SubIssueTypeId IN (23) 
							AND 1 = CASE WHEN xHDPvalue.HdpValue <> 0 AND b.hdp1 = xHDPvalue.HdpValue THEN 1
										WHEN xHDPvalue.HdpValue = 0 AND b.hdp1 = 0 AND b.hdp2 = 0 THEN 1 --case input hdp value filter = 0
									ELSE 0 END
							AND d.HdpValue IS NOT NULL THEN 1 --Home Virtual Head Reversed
					 WHEN b.sporttype = 1 AND d.IsMainMatch = 'true' AND f.BetType IS NOT NULL AND f.GroupMatch = 0 AND d.IsLinkGroup1X2 = 1 THEN 1 --Only support soccer
					 WHEN b.sporttype = 1 AND d.IsMainMatch = 'true' AND f.BetType IS NOT NULL AND f.GroupMatch <> 0 AND d.IsLinkGroupAIO = 1 THEN 1 --Only support soccer
				ELSE 0 END
	
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
				,livehomescore	
				,liveawayscore			
				,IsMixParlay
				,matchid
				,StatusId
				,Subbettype
				,SubStatusId
				,SubIssueTypeId
				,GroupName
				,LiveIndicator
				,SettledType
				,FilterBetIdX
				,FilterBetIdY
			)
		SELECT  DISTINCT b.transid
				,b.Subtransid 
				,b.refno
				,b.custid				
				,b.Subtransdate
				,b.bettype
				,b.Sublivehomescore
				,b.Subliveawayscore
				,b.IsMixParlay
				,b.matchid
				,b.statusID
				,b.Subbettype
				,b.SubstatusID
				,d.SubIssueTypeId
				,CASE WHEN b.sporttype = 1 THEN 'PH' ELSE 'HDP' END AS GroupName
				,b.liveindicator
				,b.SettledType
				,CASE WHEN b.IsMixParlay = 0 THEN b.betid ELSE b.Subbetcheck END AS FilterBetIdX
				,CASE WHEN b.IsMixParlay = 0 THEN RIGHT(b.betid,2) ELSE RIGHT(b.Subbetcheck,2) END AS FilterBetIdY
		FROM	#FilterInfo d
				INNER JOIN #tmpTransInfo b ON d.MatchId = b.matchid AND b.IsMixParlay = 1
				OUTER APPLY (
					SELECT DISTINCT CONVERT(SMALLMONEY, value) AS HomeFavorite
					FROM STRING_SPLIT(d.HomeFavorite, '&')
					WHERE value <> ''				
				)xHDPHome
				OUTER APPLY (
					SELECT DISTINCT CONVERT(SMALLMONEY, value) AS AwayFavorite
					FROM STRING_SPLIT(d.AwayFavorite, '&')
					WHERE value <> ''				
				)xHDPAway
				OUTER APPLY (
					SELECT DISTINCT CONVERT(SMALLMONEY, value) AS HdpValue
					FROM STRING_SPLIT(d.HdpValue, '&')
					WHERE value <> ''				
				)xHDPvalue
				LEFT JOIN dbo.f_TVS_CheckingIssueTypePHBettypes() f ON f.IssueTypeId = @IssueTypeId AND b.Subbettype = f.BetType
		WHERE 1 = CASE WHEN @ActionId <> 2 AND b.SubstatusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
						WHEN @ActionId = 2 AND b.SubstatusID NOT IN (101, 103) THEN 1
						ELSE 0 END
				AND b.Subbetfrom <> 'P'
				AND b.Subliveindicator = d.LiveIndicator
				AND b.Subtransdate BETWEEN d.FilterFromTransTime AND d.FilterToTransTime
				AND 1 = CASE WHEN b.sporttype = 1 AND d.IsMainMatch = 'true' THEN 1
				             WHEN b.sporttype <> 1 THEN 1 
							 ELSE 0 END
				AND 1 = CASE WHEN b.Subbettype = d.FilterBetTypeId 
								AND d.SubIssueTypeId IN (8) 
								AND 1 = CASE WHEN xHDPHome.HomeFavorite <> 0 AND b.Subhdp1 = xHDPHome.HomeFavorite THEN 1
											WHEN xHDPHome.HomeFavorite = 0 AND b.Subhdp1 = 0 AND b.Subhdp2 = 0 THEN 1 --case input hdp value filter = 0
										ELSE 0 END
								AND d.HomeFavorite IS NOT NULL THEN 1
							 WHEN b.Subbettype = d.FilterBetTypeId 
								AND d.SubIssueTypeId IN (8) 
								AND 1 = CASE WHEN xHDPAway.AwayFavorite <> 0 AND b.Subhdp2 = xHDPAway.AwayFavorite THEN 1
											WHEN xHDPAway.AwayFavorite = 0 AND b.Subhdp2 = 0 AND b.Subhdp1 = 0 THEN 1 --case input hdp value filter = 0
										ELSE 0 END
								AND d.AwayFavorite IS NOT NULL THEN 1
							 WHEN b.Subbettype = d.FilterBetTypeId 
								AND d.SubIssueTypeId IN (22) 
								AND 1 = CASE WHEN xHDPvalue.HdpValue <> 0 AND b.Subhdp2 = xHDPvalue.HdpValue THEN 1
											WHEN xHDPvalue.HdpValue = 0 AND b.Subhdp2 = 0 AND b.Subhdp1 = 0 THEN 1 --case input hdp value filter = 0
										ELSE 0 END
								AND d.HdpValue IS NOT NULL THEN 1 --Away Virtual Head Reversed
							 WHEN b.Subbettype = d.FilterBetTypeId 
								AND d.SubIssueTypeId IN (23) 
								AND 1 = CASE WHEN xHDPvalue.HdpValue <> 0 AND b.Subhdp1 = xHDPvalue.HdpValue THEN 1
											WHEN xHDPvalue.HdpValue = 0 AND b.Subhdp1 = 0 AND b.Subhdp2 = 0 THEN 1 --case input hdp value filter = 0
										ELSE 0 END
								AND d.HdpValue IS NOT NULL THEN 1 --Home Virtual Head Reversed
							 WHEN b.sporttype = 1 AND f.BetType IS NOT NULL AND f.GroupMatch = 0 AND d.IsLinkGroup1X2 = 1 THEN 1 --Only support soccer
							 WHEN b.sporttype = 1 AND f.BetType IS NOT NULL AND f.GroupMatch <> 0 AND d.IsLinkGroupAIO = 1 THEN 1 --Only support soccer
						ELSE 0 END
	END  

	/* Remove invalid data */
	DELETE tb
	FROM #TVSTicketBets AS tb
	INNER JOIN #FilterInfo AS f ON f.MatchId = tb.matchid AND tb.Subbettype = f.FilterBetTypeId
	WHERE 1 = CASE WHEN 
					(f.FilterBetIdX = '' OR tb.FilterBetIdX LIKE f.FilterBetIdX + '%')
					AND (f.FilterBetIdY = '' OR tb.FilterBetIdY = f.FilterBetIdY OR (f.FilterBetIdY LIKE '>%' AND tb.FilterBetIdY > RIGHT(f.FilterBetIdY,2))) THEN 0
					ELSE 1
				END

	/*Get Transid in Request of range Transid*/
	IF @ActionId NOT IN (2)
	BEGIN
		INSERT INTO #TransidInRequest (TransId, RequestId, MainTransId, MatchId)
		SELECT tmp.transid, r.RequestId, tmp.MainTransId, t.matchid
		FROM #TVSTicketBets t
			CROSS APPLY (
						SELECT rs.TransId, rs.TransId AS MainTransId, RequestId
						FROM dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK)
						WHERE rs.TransId = t.transid AND rs.MatchId = t.MatchId
						UNION ALL
						SELECT rp.TransId, rp.MainTransId , RequestId
						FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rp WITH (NOLOCK)
						WHERE rp.TransId = t.SubTransid AND rp.MatchId = t.matchid
				)tmp
			INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = tmp.RequestId
		WHERE r.RequestId <> @RequestId 
			AND (r.ActionId NOT IN (2) AND r.IssueTypeId NOT IN (22))
			
		IF @@ROWCOUNT <> 0
		BEGIN
			UPDATE v SET v.IsExistedInOtherRequest = 1
			FROM @Validation v
			WHERE EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest t WHERE t.MatchId = v.MatchId)
		END

		--Remove Transid exists in other request
		DELETE FROM #TVSTicketBets 
		WHERE EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = SubTransid)
		
	END

	SELECT @MainMatchId = CASE WHEN PoolHouseCheckedBetTypes = 'ALL' THEN MatchId ELSE NULL END
		   ,@PoolHouseCheckedBetTypes = PoolHouseCheckedBetTypes
	FROM #FilterInfo 
	WHERE IsMainMatch = 'true' 

	IF @MainMatchId IS NOT NULL
	BEGIN
		SET @PHBettypes = STUFF((SELECT DISTINCT ',' + CAST(Subbettype AS VARCHAR(10))
									  FROM #TVSTicketBets AS b
									  INNER JOIN #FilterInfo AS f ON b.matchid = f.MatchId
									  WHERE b.matchid = @MainMatchId
									  AND 1 = CASE WHEN IsMixParlay = 0 AND Subbettype <> f.FilterBetTypeId THEN 1
												   WHEN IsMixParlay = 1 THEN 1
												   ELSE 0 END
									  FOR XML PATH ('')
								),1,1,'')
		UPDATE #FilterInfo
		SET PoolHouseCheckedBetTypes = @PHBettypes
		WHERE MatchID = @MainMatchId
	END

	/*Remove Transid poolhouse bettype un-check*/
	DELETE b
	FROM #TVSTicketBets b
		INNER JOIN #FilterInfo d ON b.matchid = d.MatchId
		OUTER APPLY (
				SELECT value AS bettype
				FROM STRING_SPLIT(d.PoolHouseCheckedBetTypes, ',')
				WHERE b.Subbettype = CAST (value AS SMALLINT)		
			)xPH
	WHERE d.IsMainMatch = 'true' AND GroupName = 'PH'
	   AND 1 = CASE WHEN ISNULL(@PoolHouseCheckedBetTypes,'') <> '' AND xPH.bettype IS NULL THEN 1
					WHEN ISNULL(@PoolHouseCheckedBetTypes,'') = '' THEN 1
					ELSE 0 END
		
	IF @@ROWCOUNT <> 0
	BEGIN
		UPDATE v SET v.IsPoolHouseAffected = 1
		FROM @Validation v
			INNER JOIN #FilterInfo d ON v.matchid = d.MatchId
		WHERE d.IsMainMatch = 'true'
	END

	--Data Section
	INSERT INTO #logInfo (MatchId, LiveScores, VoidFromTime, VoidToTime, SingleCount, CashOutCount, SettleCount, InstantlySettleCount, MainParlayCount, PoolHouseSingleCount, PoolHouseCashOutCount, PoolHouseSettleCount, PoolHouseInstantlySettleCount, PoolHouseMainParlayCount)
	SELECT b.matchid AS MatchId
		,CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2)) AS LiveScores
		,MIN(b.transdate) AS VoidFromTime
		,MAX(b.transdate) AS VoidToTime
		,COUNT(CASE WHEN b.GroupName = 'HDP' AND b.transid = b.SubTransid  THEN b.transid ELSE NULL END) AS SingleCount
		,COUNT(CASE WHEN b.GroupName = 'HDP' AND b.transid = b.SubTransid AND b.StatusId IN (111, 112, 113) AND ISNULL(b.betdaqid,-1) = -2 THEN b.transid ELSE NULL END) AS CashOutCount
		,COUNT(CASE WHEN b.GroupName = 'HDP' AND b.transid = b.SubTransid AND b.SettledType = 2 THEN b.transid ELSE NULL END) AS SettleCount
		,COUNT(CASE WHEN b.GroupName = 'HDP' AND b.transid = b.SubTransid AND b.SettledType = 1 THEN b.transid ELSE NULL END) AS InstantlySettleCount
		,COUNT(CASE WHEN b.GroupName = 'HDP' AND b.transid <> b.SubTransid AND b.IsMixParlay = 1 THEN b.transid ELSE NULL END) AS MainParlayCount
		,COUNT(CASE WHEN b.GroupName = 'PH' AND b.transid = b.SubTransid THEN b.transid ELSE NULL END) AS PoolHouseSingleCount
		,COUNT(CASE WHEN b.GroupName = 'PH' AND b.transid = b.SubTransid AND b.StatusId IN (111, 112, 113) AND ISNULL(b.betdaqid,-1) = -2 THEN b.transid ELSE NULL END) AS PoolHouseCashOutCount
		,COUNT(CASE WHEN b.GroupName = 'PH' AND b.transid = b.SubTransid AND b.SettledType = 2 THEN b.transid ELSE NULL END) AS PoolHouseSettleCount
		,COUNT(CASE WHEN b.GroupName = 'PH' AND b.transid = b.SubTransid AND b.SettledType = 1 THEN b.transid ELSE NULL END) AS PoolHouseInstantlySettleCount
		,COUNT(CASE WHEN b.GroupName = 'PH' AND b.transid <> b.SubTransid AND b.IsMixParlay = 1 THEN b.transid ELSE NULL END) AS PoolHouseMainParlayCount
	FROM #TVSTicketBets b
	GROUP BY CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2)), b.matchid
	ORDER BY CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2)) ASC

	UPDATE v SET v.IsInValidTotalTickets = CASE WHEN ISNULL(l.SingleCount,0) = 0 AND ISNULL(l.MainParlayCount,0) = 0 THEN 1 ELSE 0 END
		,v.IsPoolHouseAffected = CASE WHEN v.IsPoolHouseAffected = 1 THEN v.IsPoolHouseAffected ELSE l.IsPoolHouseAffected END
	FROM @Validation v
		OUTER APPLY( 
			SELECT ISNULL(SUM(SingleCount),0) + ISNULL(SUM(PoolHouseSingleCount),0) AS SingleCount
				  ,ISNULL(SUM(MainParlayCount),0) + ISNULL(SUM(PoolHouseMainParlayCount),0) AS MainParlayCount
				  ,MAX(CASE WHEN PoolHouseMainParlayCount <> 0 THEN 1 ELSE 0 END) AS IsPoolHouseAffected
			FROM #logInfo
			WHERE MatchId = v.MatchId
			GROUP BY MatchId
		)l 

	--Not display Score in message template when voiding non-live tickets only [193108]
	IF NOT EXISTS (SELECT TOP 1 1 FROM #TVSTicketBets WHERE liveindicator = 1)
	BEGIN
		UPDATE l SET l.LiveScores = ''
		FROM #logInfo l
	END

	IF @IsShowLogOnly = 0
	BEGIN
		INSERT INTO @tmpLogInfoTickets (TransId)
		SELECT SubTransid
		FROM #TVSTicketBets WHERE GroupName = 'HDP'
	END
	ELSE --Edit request
	BEGIN
		INSERT INTO @tmpLogInfoTickets (TransId)
		SELECT TransId
		FROM dbo.TicketVoiding_RequestDetailTicket_Single AS s WITH (NOLOCK) 
		INNER JOIN #FilterInfo AS f ON s.MatchId = f.MatchId
		WHERE RequestId = @RequestId
			AND 1 = CASE WHEN IssueTypeId = 4 AND bettype = f.FilterBetTypeId THEN 1
						 ELSE 0 END
		UNION ALL
		SELECT s.TransId
		FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay s WITH (NOLOCK) 
			CROSS APPLY (
				SELECT TOP 1 sporttype
				FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) 
				WHERE s.MatchId = rd.MatchId
					AND rd.RequestId = @RequestId
			)rd
		WHERE s.RequestId = @RequestId
			AND rd.Sporttype <> 1 --Other sports
	END

	WHILE (1=1)
	BEGIN
		UPDATE TOP (1) v
		SET v.IsFinish = 1, @MatchId = v.MatchId
		FROM @Validation v
		WHERE IsFinish IS NULL 

		IF @@ROWCOUNT = 0 BREAK;

		SET @LogInfoTicketsJson = COMPRESS((SELECT m.transid AS 'transid'
			   ,m.refno AS 'refno'		
			   ,m.SubTransId AS 'SubTransId'	
			   ,m.username AS 'username'		
			   ,m.transdate AS 'transdate'	
			   ,m.Stake AS 'Stake'	
			   ,m.odds AS 'odds'	
			   ,m.SubOdds AS 'SubOdds'
			   ,m.oddsspread AS 'oddsspread'	
			   ,m.OddsType AS 'OddsType'
			   ,m.bettype AS 'bettype'
			   ,m.SubBettype AS 'SubBettype'
			   ,m.STATUS AS 'STATUS'
			   ,m.SubStatus AS 'SubStatus'
			   ,m.currencyname AS 'currencyname'
			   ,m.betteam AS 'betteam'
			   ,m.SubBetTeam AS 'SubBetTeam'
			   ,m.Subhdp1 AS 'Subhdp1'
			   ,m.Subhdp2 AS 'Subhdp2'
			   ,m.hdp1 AS 'hdp1'
			   ,m.hdp2 AS 'hdp2'
			   ,m.livehomescore AS 'livehomescore'
			   ,m.liveawayscore AS 'liveawayscore'
			   ,m.betid AS 'betid'
			   ,m.betcheck AS 'betcheck'
			   ,m.Subchecktime AS 'Subchecktime'
			   ,m.IsMixParlay AS 'IsMixParlay'
			   ,m.Transdesc AS 'Transdesc'
			   ,m.betdaqid AS 'betdaqid'
			   ,m.WalletType AS 'WalletType'
			   ,m.RefCode AS 'RefCode'
			   ,CAST(m.winlost AS VARCHAR) AS 'winlost'
			   ,m.LiveIndicator AS 'IsLiveIndicator' 
			   ,m.actual_stake AS 'ActualStake'
			   ,m.ExtraInfo AS 'ExtraInfo'
			   ,m.winlostdate AS 'winlostdate'
			   ,m.IsDeposit AS 'IsDeposit'
			   ,m.matchid AS 'matchid'
			   ,m.homeid AS 'homeid'
			   ,m.awayid AS 'awayid'
			   ,m.leagueid AS 'leagueid'
			   ,m.IsNeutral AS 'IsNeutral'
			   ,m.matchcode AS 'matchcode'
			   ,m.SettlementStatus AS 'SettlementStatus'
			   ,m.sporttype AS 'sporttype'
			   ,CASE 
					WHEN m.IsMixParlay = 1 THEN 'Parlay'
					ELSE bt.typenamee 
				END AS 'GroupName'
		FROM @tmpLogInfoTickets s
			INNER JOIN #tmpTransInfo m ON s.transid = m.Subtransid
			INNER JOIN bettype AS bt WITH (NOLOCK) ON bt.typeid = m.Subbettype
		WHERE m.matchid = @MatchId
		FOR JSON PATH))

		UPDATE v
		SET v.LogInfoTicketsJson = CONVERT(VARCHAR(MAX), @LogInfoTicketsJson, 1)
		FROM @Validation v
		WHERE MatchId = @MatchId

	END

	IF @IsShowLogOnly = 1 AND @RequestId <> 0
	BEGIN
		/*Support case uncheck bettype PH -> still show PH count = 0 & case voided*/
		UPDATE v
		SET v.IsPoolHouseAffected = CASE WHEN v.IsPoolHouseAffected = 1 THEN v.IsPoolHouseAffected ELSE 1 END
		FROM @Validation v
		INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) ON v.MatchId = rd.MatchId
		WHERE rd.RequestId = @RequestId AND rd.Sporttype = 1
			AND rd.TransIds LIKE '%IsMainMatch="true"%' AND rd.TransIds NOT LIKE '%PoolHouseCheckedBetTypes="-1"%'

		-- 1. Validate table
		SELECT MatchId
			, IsInValidTotalTickets
			, IsExistedInOtherRequest
			, IsPoolHouseAffected 
		FROM @Validation

		-- 2. TransId in request table
		SELECT RequestId, MatchId, 
			   STUFF((SELECT ', ' + CAST(MainTransId AS VARCHAR(MAX)) 
				FROM #TransidInRequest
				WHERE (RequestId = r.RequestId AND MatchId = r.MatchId)
				ORDER BY TransId
				FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)') ,1,2,'') AS TransIds
		FROM #TransidInRequest r
		GROUP BY r.RequestId, r.MatchId

		/*Get log info for Void Page*/
		INSERT INTO #logInfoVoidPage (RequestId, MatchId, CashOutCount, SettleCount, InstantlySettleCount, PoolHouseCashOutCount, PoolHouseSettleCount, PoolHouseInstantlySettleCount)
		SELECT @RequestId
				,b.matchid
				, COUNT(CASE WHEN b.bettype = f.FilterBetTypeId AND b.betdaqid = -2 THEN s.TransId ELSE NULL END) AS CashOutCount
				, COUNT(CASE WHEN b.bettype = f.FilterBetTypeId AND b.SettledType = 2 THEN s.TransId ELSE NULL END) AS SettleCount
				, COUNT(CASE WHEN b.bettype = f.FilterBetTypeId AND b.SettledType = 1 THEN s.TransId ELSE NULL END) AS InstantlySettleCount
				, COUNT(CASE WHEN b.bettype <> f.FilterBetTypeId AND b.betdaqid = -2 AND b.sporttype = 1 THEN s.TransId ELSE NULL END) AS PoolHouseCashOutCount
				, COUNT(CASE WHEN b.bettype <> f.FilterBetTypeId AND b.SettledType = 2 AND b.sporttype = 1 THEN s.TransId ELSE NULL END) AS PoolHouseSettleCount
				, COUNT(CASE WHEN b.bettype <> f.FilterBetTypeId AND b.SettledType = 1 AND b.sporttype = 1 THEN s.TransId ELSE NULL END) AS PoolHouseInstantlySettleCount
		FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
			INNER JOIN #tmpTransInfo b ON b.transid = s.transid AND b.matchid = s.MatchId AND b.IsMixParlay = 0
			INNER JOIN #FilterInfo f ON b.matchid = f.MatchId
		WHERE s.RequestId = @RequestId AND b.StatusId IN (111, 112, 113)
		GROUP BY b.matchid

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

		-- 3. Loginfo table
		SELECT rd.MatchId
			,SUBSTRING(rd.IssueDetail, CHARINDEX('Live:',rd.IssueDetail) + 5, CHARINDEX(';Act:',rd.IssueDetail) - 6) AS LiveScores
			,rd.VoidFromTime
			,rd.VoidToTime
			,SUBSTRING(rd.IssueDetail, CHARINDEX('SingleCount:',rd.IssueDetail) + LEN('SingleCount:'), CHARINDEX(';PoolHouseSingleCount:',rd.IssueDetail) - (CHARINDEX('SingleCount:',rd.IssueDetail) + LEN('SingleCount:'))) AS SingleCount
			,t.CashOutCount
			,t.SettleCount
			,t.InstantlySettleCount
			,CASE WHEN rd.Sporttype <> 1 THEN rd.MainParlayCount ELSE 0 END AS MainParlayCount --Other sports
			,SUBSTRING(rd.IssueDetail,CHARINDEX('PoolHouseSingleCount:',rd.IssueDetail) + LEN('PoolHouseSingleCount:'), CHARINDEX(';PoolHouseMainParlayCount:',rd.IssueDetail) - ( CHARINDEX('PoolHouseSingleCount:',rd.IssueDetail)+ LEN('PoolHouseSingleCount:'))) AS PoolHouseSingleCount
			,t.PoolHouseCashOutCount
			,t.PoolHouseSettleCount 
			,t.PoolHouseInstantlySettleCount
			,CASE WHEN rd.Sporttype = 1 THEN rd.MainParlayCount ELSE 0 END AS PoolHouseMainParlayCount --Soccer
			,STUFF(s2.ScoreTicket2H,1,1,'') AS ScoreNormalTicket
			,STUFF(sm.ScoreOfMatch,1,1,'') AS ScoreOfMatch
			,v.LogInfoTicketsJson
		FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
			LEFT JOIN #logInfoVoidPage t ON t.RequestId = rd.RequestId AND t.MatchId = rd.MatchId
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
			INNER JOIN @Validation v ON rd.MatchId = v.MatchId
		WHERE rd.RequestId = @RequestId

		-- 4. Unmark table (No need -> return table)
		SELECT TransId AS UnmarkTransIds FROM @tmpUnmarkTransId
		
		-- 5. Transinfo table (No need -> return table)
		SELECT @TransInfoJson_Output AS TransInfoJson

		RETURN;
	END

	--For case no ticket valid
	SELECT @SingleCount = ISNULL(SUM(SingleCount),0) + ISNULL(SUM(PoolHouseSingleCount),0)
		  ,@MainParlayCount = ISNULL(SUM(MainParlayCount),0) + ISNULL(SUM(PoolHouseMainParlayCount),0)
	FROM #logInfo
	IF @SingleCount = 0 AND @MainParlayCount = 0
	BEGIN
		-- 1. Validate table
		SELECT MatchId
			 , 1 AS IsInValidTotalTickets
			 , IsExistedInOtherRequest
			 , IsPoolHouseAffected
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
			
		-- 3. Loginfo table (No need -> return table)
		SELECT MatchId FROM #logInfo WHERE Matchid IS NULL

		-- 4. Unmark table (No need -> return table)
		SELECT TransId AS UnmarkTransIds FROM @tmpUnmarkTransId
		
		-- 5. Transinfo table (No need -> return table)
		SELECT @TransInfoJson_Output AS TransInfoJson

		RETURN;
	END

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
		,IsPoolHouseAffected
	FROM @Validation

	-- 2. TransId exists in other request table
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
		SELECT RequestId, MatchId, CAST(TransId AS VARCHAR(MAX)) AS TransIds
		FROM #TransidInRequest
	END

	-- 3. Loginfo table
	SELECT l.MatchId
		,STUFF(w.scores,1,1,'') AS LiveScores
		,MIN(VoidFromTime) AS VoidFromTime
		,MAX(VoidToTime) AS VoidToTime
		,SUM(SingleCount) AS SingleCount
		,SUM(CashOutCount) AS CashOutCount
		,SUM(SettleCount) AS SettleCount
		,SUM(InstantlySettleCount) AS InstantlySettleCount
		,SUM(MainParlayCount) AS MainParlayCount
		,SUM(PoolHouseSingleCount) AS PoolHouseSingleCount
		,SUM(PoolHouseCashOutCount) AS PoolHouseCashOutCount
		,SUM(PoolHouseSettleCount) AS PoolHouseSettleCount
		,SUM(PoolHouseInstantlySettleCount) AS PoolHouseInstantlySettleCount
		,SUM(PoolHouseMainParlayCount) AS PoolHouseMainParlayCount
		,v.LogInfoTicketsJson
	FROM #logInfo l
		CROSS APPLY(
					SELECT '|' + LiveScores
					FROM #logInfo rd
					where l.MatchId = rd.MatchId
					FOR XML PATH('')
					)w (scores) 
		INNER JOIN @Validation v ON l.MatchId = v.MatchId
	GROUP BY l.MatchId, w.scores, v.LogInfoTicketsJson

	-- 4. List ticket unmark/mark (if any)
	SELECT @UnmarkTransIds AS UnmarkTransIds
	      ,@MarkTransIds AS MarkTransIds

	-- 5. Transinfo table
	SET @TransInfoJson_Output = COMPRESS((SELECT t.matchid AS 'mid'
		,t.transid AS 't'
		,t.Subtransid  AS 's_t'
		,b.custid AS  'c'           
		,b.bettype AS 'btype'
		,b.betid AS 'bid'
		,b.Subbettype AS 's_btype'
		,b.IsMixParlay AS 'isP'
		,b.SiteDBGroupID AS 'sitedb'
	FROM #TVSTicketBets t
		INNER JOIN #tmpTransInfo b ON t.matchid = b.matchid AND t.transid = b.transid
	FOR JSON PATH))
	
	SELECT CONVERT(VARCHAR(MAX), @TransInfoJson_Output, 1) AS TransInfoJson

	DROP TABLE #TVSTicketBets
	DROP TABLE #TransidInRequest
	DROP TABLE #logInfo
	DROP TABLE #FilterInfo
	DROP TABLE #logInfoVoidPage
	DROP TABLE #tmpTransInfo
	DROP TABLE #InstantSettlementBettypes
END
GO
 


