/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_LogInfo_WOName_Select]
(	
	 @RequestId			  INT = 0
	,@IssueTypeId		  INT = 1
	,@ActionId			  INT = 5
	,@IsShowLogOnly		  BIT = 0
	,@WrongOfferedNameInfo VARCHAR(MAX) = NULL
	,@TransInfoJson		  VARCHAR(MAX) = NULL
)
AS
/*	
	Created by: 20240925@July
	Task: [TVS] New Issue Type "Wrong Offered Name" [Redmine: #187408]
	DB: DBCTG-bodb02
	
	Revisions: 
		- 20240925@July: Create new SP [Redmine:#179934]

	Param's explanation:	
		- @WrongOfferedNameInfo: <root><r MatchId="" @CurrencyIds="" LicenseeNames="" /></root>
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE  @WrongOfferedNameXML	  XML = NULL	
			,@MarkTransIds		      VARCHAR(MAX) =''
			,@UnmarkTransIds		  VARCHAR(MAX) =''
			,@OldActionId			  TINYINT
			,@TransInfoJson_Output	  VARBINARY(MAX) = NULL
		    ,@MatchId				  INT
			,@CurrencyIds			  VARCHAR(MAX)
			,@LicenseeNames			  VARCHAR(MAX)
			,@LogInfoTicketsJson	  VARBINARY(MAX) = NULL

	-- Constant
	DECLARE @MBCGroup_Name	VARCHAR(50) = 'MBC Group'
		   ,@789y_Name		VARCHAR(50) = '789y'
		   ,@777_Name		VARCHAR(50) = '777'

	CREATE TABLE #FilterInfo (
		 MatchId				INT
		,CurrencyIds			VARCHAR(MAX)
		,LicenseeNames			VARCHAR(MAX)
	)

	SET @WrongOfferedNameXML = CONVERT(XML, @WrongOfferedNameInfo)
	INSERT INTO #FilterInfo (MatchId, CurrencyIds ,LicenseeNames)
	SELECT  t.c.value('@MatchId','INT')
		  , t.c.value('@CurrencyIds','VARCHAR(MAX)')
		  , t.c.value('@LicenseeNames','VARCHAR(MAX)')
	FROM @WrongOfferedNameXML.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@WrongOfferedNameXML = NULL)) 

	SELECT @MatchId = MatchId
		  ,@CurrencyIds = CurrencyIds
		  ,@LicenseeNames = LicenseeNames
	FROM #FilterInfo

	DECLARE @tmpCurrencyIds AS TABLE (CurrencyId INT)
	DECLARE @tmpLogInfoTickets TABLE (TransId BIGINT)
	DECLARE @tmpLicenseeNames TABLE(LicenseeName VARCHAR(100), GroupName VARCHAR(100))	
	DECLARE @tmpUIRepresentativeLicenseeGroupNames TABLE (GroupName VARCHAR(100))	
	
	INSERT INTO @tmpCurrencyIds(CurrencyId)
	SELECT value AS CurrencyId
	FROM STRING_SPLIT(@CurrencyIds, ',') 
	WHERE value <> ''		 		

	INSERT INTO @tmpLicenseeNames(LicenseeName, GroupName)
	SELECT ss.value AS LicenseeName, ss.value AS GroupName
	FROM STRING_SPLIT(@LicenseeNames, ',') ss
	WHERE value <> ''

	-- Replace all UI representative groups (MBCGroup and 789y) by their real credit licensees
	DELETE FROM @tmpLicenseeNames 
	OUTPUT DELETED.GroupName 
			INTO @tmpUIRepresentativeLicenseeGroupNames(GroupName)
	WHERE LicenseeName IN (@MBCGroup_Name, @789y_Name, @777_Name)
	
	IF @@ROWCOUNT > 0
	BEGIN
		;WITH CTE_CreditSite AS
		(
			SELECT [site], ISNULL(SiteLabel,'') AS SiteLabel
			FROM CustDB.dbo.Site WITH(NOLOCK) 
			WHERE isLicensee = 0		  
			  AND isActive = 1
		)
		INSERT INTO @tmpLicenseeNames(LicenseeName, GroupName)
		SELECT cte.[site] AS LicenseeName, t.GroupName
		FROM @tmpUIRepresentativeLicenseeGroupNames AS t
			 CROSS APPLY (
							SELECT cte.[site]
							FROM CTE_CreditSite cte
							WHERE 1 = CASE
										  WHEN t.GroupName = @MBCGroup_Name AND cte.SiteLabel NOT IN (@789y_Name, @777_Name) THEN 1
										  WHEN t.GroupName = @789y_Name AND cte.SiteLabel = @789y_Name THEN 1
										  WHEN t.GroupName = @777_Name AND cte.SiteLabel = @777_Name THEN 1
										  ELSE 0 
									  END
						 ) AS cte
	END					 		

	CREATE TABLE #TVSTicketBets (
			 transid             BIGINT
			,SubTransid          BIGINT
			,refno               BIGINT
			,custid              INT
			,transdate           DATETIME
			,bettype             SMALLINT
			,Subbettype          SMALLINT
			,livehomescore       SMALLINT
			,liveawayscore       SMALLINT
			,IsMixParlay         BIT DEFAULT(0)
			,matchid             INT
			,LiveIndicator		 BIT DEFAULT(0)
			,StatusId			 TINYINT
			,SubStatusId		 TINYINT
			,SiteDBGroupID		 SMALLINT
			,betid				 BIGINT
			,betdaqid			 BIGINT
			,SettledType		 TINYINT -- 1: Instant Settlement, 2: Normal Settlement, 3: SABA Time Machine Settlement
	)

	DECLARE @Validation AS TABLE (
			 MatchId                 INT
			,IsInValidTotalTickets   BIT DEFAULT(0) 
			,IsExistedInOtherRequest BIT DEFAULT(0) 
			,IsHasSettledTicket		 BIT DEFAULT(0) 
			,IsHasInstantlySettledTicket BIT DEFAULT(0) 
			,LogInfoTicketsJson		 VARCHAR(MAX)
		)
	DECLARE @tmpUnmarkTransId AS TABLE (TransId BIGINT)
	DECLARE @tmpMarkTransId AS TABLE (TransId BIGINT)

	CREATE TABLE #TransidInRequest (TransId BIGINT, RequestId INT, MainTransId BIGINT, MatchId INT)
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
	  ,WalletType TINYINT
	  ,RefCode BIGINT
	  ,currency TINYINT
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
	  ,GroupName VARCHAR(100)
	)

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
		   ,currency
	)
	SELECT mid ,t ,s_t ,ref ,c ,hdp1 ,hdp2 ,lh ,la ,li
		,o ,os ,bfr ,btype ,bteam ,bcheck ,s ,tdate ,checkt ,bid
		,tdes ,sid ,s_c ,s_hdp1 ,s_hdp2 ,s_lh ,s_la ,s_li ,s_o ,s_os
		,s_bfr ,s_btype ,s_bteam ,s_bcheck ,s_s ,s_tdate ,s_checkt ,s_tdes ,s_sid ,sre
		,mre ,re ,cr ,stake ,ost ,curr ,bdaq ,ex ,bo ,w
		,acstake ,wld ,m ,statuswl ,isP ,sitedb
		,wt ,refc ,ccy
	FROM STRING_SPLIT(@TransInfoJson, ',') f
		CROSS APPLY (SELECT CAST(DECOMPRESS(CONVERT(VARBINARY(MAX), f.value, 1)) AS NVARCHAR(MAX)) AS Decompress_TransInfoJson) t
		CROSS APPLY (
				SELECT mid ,t ,s_t ,ref ,c ,hdp1 ,hdp2 ,lh ,la ,li
					  ,o ,os ,bfr ,btype ,bteam ,bcheck ,s ,tdate ,CASE WHEN checkt = '1900-01-01 00:00:00.000' THEN NULL ELSE checkt END AS checkt ,bid
					  ,tdes ,sid ,s_c ,s_hdp1 ,s_hdp2 ,s_lh ,s_la ,s_li ,s_o ,s_os
					  ,s_bfr ,s_btype ,s_bteam ,s_bcheck ,s_s ,s_tdate ,CASE WHEN s_checkt = '1900-01-01 00:00:00.000' THEN NULL ELSE s_checkt END AS s_checkt ,s_tdes ,s_sid ,sre
					  ,mre ,re ,cr ,stake ,ost ,curr ,bdaq ,ex ,bo ,w
					  ,acstake ,CASE WHEN wld = '1900-01-01 00:00:00.000' THEN NULL ELSE wld END AS wld ,m ,statuswl ,isP ,sitedb
					  ,wt ,refc ,ccy
				FROM OPENJSON(t.Decompress_TransInfoJson) 
				WITH( mid INT, t BIGINT, s_t BIGINT, ref BIGINT, c INT, hdp1 SMALLMONEY, hdp2 SMALLMONEY, lh SMALLINT, la SMALLINT ,li BIT 
					 ,o SMALLMONEY ,os MONEY ,bfr NVARCHAR(4) ,btype SMALLINT ,bteam NVARCHAR(10) ,bcheck NVARCHAR(50) ,s NVARCHAR(10) ,tdate DATETIME ,checkt DATETIME ,bid BIGINT
					 ,tdes NVARCHAR(1000) ,sid TINYINT ,s_c INT ,s_hdp1 SMALLMONEY ,s_hdp2 SMALLMONEY ,s_lh SMALLINT ,s_la SMALLINT ,s_li BIT ,s_o SMALLMONEY ,s_os MONEY 
					 ,s_bfr NVARCHAR(4) ,s_btype SMALLINT ,s_bteam NVARCHAR(10) ,s_bcheck NVARCHAR(50) ,s_s NVARCHAR(10) ,s_tdate DATETIME ,s_checkt DATETIME ,s_tdes NVARCHAR(1000) ,s_sid  TINYINT ,sre INT
					 ,mre INT ,re INT ,cr INT ,stake MONEY ,ost TINYINT ,curr NVARCHAR(50) ,bdaq BIGINT ,ex VARCHAR(1000) ,bo INT ,w MONEY
					 ,acstake MONEY ,wld SMALLDATETIME ,m SMALLMONEY ,statuswl TINYINT ,isP BIT ,sitedb SMALLINT
					 ,wt TINYINT ,refc BIGINT ,ccy TINYINT
				)
		) tbl
	WHERE f.value <> ''
	
	---UPDATE column show loginfo details
	BEGIN
		UPDATE s
		SET matchcode 	= m.matchcode
			,homeid 	= m.homeid
			,awayid 	= m.awayid
			,leagueid 	= m.leagueid
			,sporttype 	= m.sporttype
			,IsNeutral 	= ISNULL(m.IsNeutral, CONVERT(BIT, 0))
			,eventstatus = ISNULL(m.eventstatus,'')
			,SettlementStatus = ISNULL(m.SettlementStatus, 0)
			,username = ci.username
		FROM #tmpTransInfo s
			INNER JOIN dbo.match m WITH (NOLOCK) ON	s.matchid = m.matchid
			INNER JOIN CustDB.dbo.custInfo ci WITH(NOLOCK) ON s.custid = ci.custid
	
		-- update Isdeposit
		UPDATE s 
			SET IsDeposit = 1
		FROM	#tmpTransInfo s
		WHERE EXISTS (SELECT d.custid FROM CustDB.dbo.Dep_CustSuper d WITH(NOLOCK) WHERE d.custid = s.srecommend)
	
		-- update GroupName
		UPDATE s 
			SET GroupName = tl.GroupName
		FROM	#tmpTransInfo s
			INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK)
						 ON s.recommend = c.custid
			INNER JOIN @tmpLicenseeNames tl
						 ON tl.LicenseeName = c.site 

		DELETE FROM #tmpTransInfo WHERE GroupName IS NULL
	
	END

	BEGIN -- Instant Settlement declaration
		
		CREATE TABLE #InstantSettlementBettypes (matchid INT, bettype SMALLINT, betid BIGINT)	
		DECLARE @SupportInstantSettleSABABettype TABLE (bettype SMALLINT);

		INSERT INTO @SupportInstantSettleSABABettype (bettype)
		VALUES (228) --SABA OU Time Machine
			 , (229) --SABA HDP Time Machine

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
			,LiveIndicator
			,matchid
			,StatusId
			,SubStatusId
			,Subbettype
			,SiteDBGroupID
			,betid
			,betdaqid
		)
	SELECT   b.transid
			,b.Subtransid
			,b.refno
			,b.custid
			,b.transdate
			,b.bettype
			,b.livehomescore
			,b.liveawayscore
			,b.liveindicator
			,b.matchid
			,b.statusID
			,b.SubstatusID
			,b.Subbettype
			,b.SiteDBGroupID
			,b.betid
			,b.betdaqid
	FROM #tmpTransInfo b
		INNER JOIN #FilterInfo f ON b.matchid = f.MatchId
		INNER JOIN @tmpCurrencyIds curr ON b.currency = curr.CurrencyId 
	WHERE	b.IsMixParlay = 0
			AND 1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1
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
				,livehomescore	
				,liveawayscore		
				,IsMixParlay
				,LiveIndicator
				,matchid
				,StatusId
				,SubStatusId
				,Subbettype
				,SiteDBGroupID
				,betid
				,betdaqid
			)
		SELECT   b.transid
				,b.Subtransid
				,b.refno
				,b.Subcustid				
				,b.Subtransdate
				,b.bettype
				,b.Sublivehomescore
				,b.Subliveawayscore
				,b.IsMixParlay
				,b.Subliveindicator
				,b.matchid
				,b.statusID
				,b.SubstatusID
				,b.Subbettype
				,SiteDBGroupID
				,betid
				,betdaqid
		FROM #tmpTransInfo b	
			INNER JOIN #FilterInfo f ON b.matchid = f.MatchId
			INNER JOIN @tmpCurrencyIds curr ON b.currency = curr.CurrencyId 
		WHERE	b.IsMixParlay = 1 
				AND 1= CASE WHEN @ActionId <>2 AND b.SubstatusID NOT IN (101, 102, 103) THEN 1
							WHEN @ActionId = 2 AND b.SubstatusID NOT IN (101, 103) THEN 1
							ELSE 0 END
				AND b.Subbetfrom <> 'P'
				AND b.statusID NOT IN (101, 102, 103)
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

	UPDATE b
	SET  b.SettledType = CASE 
							WHEN ISNULL(m.eventstatus, '') <> @eventstatus_completed
								THEN CASE
										WHEN m.sporttype = 1 AND EXISTS (
											SELECT TOP 1 1
											FROM #InstantSettlementBettypes AS i
											WHERE b.Subbettype = i.bettype
											) THEN 1
										WHEN m.sporttype = 2 AND EXISTS (
											SELECT TOP 1 1
											FROM #InstantSettlementBettypes AS i
											WHERE b.Subbettype = i.bettype AND (b.betid = i.betid OR b.betid IS NULL)
											) THEN 1
										WHEN ib.bettype IS NOT NULL THEN 3
										ELSE 2
									END
							WHEN ib.bettype IS NOT NULL THEN 3
							ELSE 2
						END
	FROM #TVSTicketBets b 
		INNER JOIN dbo.match m WITH (NOLOCK) ON b.matchid = m.matchid
		LEFT JOIN @SupportInstantSettleSABABettype ib ON b.Subbettype = ib.bettype
	WHERE ISNULL(b.betdaqid,0) <> -2
		  AND b.SubStatusId IN (111, 112, 113) 

	UPDATE v 
	SET v.IsInValidTotalTickets = CASE WHEN ISNULL(l.SingleCount,0) = 0 AND ISNULL(l.MainParlayCount,0) = 0 THEN 1 ELSE 0 END
	   ,v.IsHasSettledTicket = l.IsHasSettledTicket
	   ,v.IsHasInstantlySettledTicket = l.IsHasInstantlySettledTicket
	FROM @Validation v
	OUTER APPLY( 
			SELECT COUNT(CASE WHEN IsMixParlay = 0 THEN transid ELSE NULL END) AS SingleCount
				 , COUNT(CASE WHEN IsMixParlay = 1 THEN transid ELSE NULL END) AS MainParlayCount
				 , MAX(CASE WHEN SettledType = 2 THEN 1 ELSE 0 END) AS IsHasSettledTicket
				 , MAX(CASE WHEN SettledType IN (1,3) THEN 1 ELSE 0 END) AS IsHasInstantlySettledTicket
			FROM #TVSTicketBets
			WHERE MatchId = v.MatchId
			GROUP BY MatchId
		)l
	
	IF @IsShowLogOnly = 0
	BEGIN
		INSERT INTO @tmpLogInfoTickets (TransId)
		SELECT SubTransid
		FROM #TVSTicketBets
	END
	ELSE --Edit request
	BEGIN
		INSERT INTO @tmpLogInfoTickets (TransId)
		SELECT TransId
		FROM dbo.TicketVoiding_RequestDetailTicket_Single WITH (NOLOCK) 
		WHERE RequestId = @RequestId
		UNION ALL
		SELECT TransId
		FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay WITH (NOLOCK) 
		WHERE RequestId = @RequestId
			
	END

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
			,m.GroupName AS 'GroupName'
	FROM @tmpLogInfoTickets s
		INNER JOIN #tmpTransInfo m ON s.transid = m.Subtransid
	FOR JSON PATH))

	UPDATE v
	SET v.LogInfoTicketsJson = CONVERT(VARCHAR(MAX), @LogInfoTicketsJson, 1)
	FROM @Validation v

	IF @IsShowLogOnly = 1 AND @RequestId <> 0
	BEGIN
		-- 1. Validate table
		SELECT MatchId
		     , IsInValidTotalTickets
		     , IsExistedInOtherRequest
		     , IsHasSettledTicket
		     , IsHasInstantlySettledTicket
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
			SELECT RequestId, MatchId, CAST(TransId AS VARCHAR(MAX)) AS TransIds 
			FROM #TransidInRequest
		END

		-- 3. Loginfo table (No need -> return table)
		SELECT NULL AS MatchId, LogInfoTicketsJson
		FROM @Validation

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
		, IsInValidTotalTickets
		, IsExistedInOtherRequest
	    , IsHasSettledTicket
		, IsHasInstantlySettledTicket
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

	-- 3. Loginto table (no-need but must return)
	SELECT NULL AS MatchId, LogInfoTicketsJson
	FROM @Validation

	-- 4. List ticket unmark/mark   (if any)
	SELECT @UnmarkTransIds AS UnmarkTransIds
	      ,@MarkTransIds AS MarkTransIds

	-- 5. Transinfo table
	SET @TransInfoJson_Output = COMPRESS((SELECT t.matchid AS 'mid'
		,t.transid AS 't'
		,t.Subtransid  AS 's_t'
		,b.custid AS  'c'           
		,b.bettype AS 'btype'
		,b.betid AS 'bid'
		,b.IsMixParlay AS 'isP'
		,b.SiteDBGroupID AS 'sitedb'
	FROM #TVSTicketBets t
		INNER JOIN #tmpTransInfo b ON t.matchid = b.matchid AND t.transid = b.transid
	FOR JSON PATH))

	SELECT CONVERT(VARCHAR(MAX), @TransInfoJson_Output, 1) AS TransInfoJson

	DROP TABLE #FilterInfo
	DROP TABLE #TVSTicketBets
	DROP TABLE #TransidInRequest
	DROP TABLE #tmpTransInfo
	DROP TABLE #InstantSettlementBettypes
	DROP TABLE #CTE_match
	DROP TABLE #CTE_isCal
END
GO

