/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_LogInfo_WOName_Select]
(	
	 @RequestId			  INT = 0
	,@IssueTypeId		  INT = 1
	,@ActionId			  INT = 5
	,@IsShowLogOnly		  BIT = 0
	,@WrongOfferedNameInfo VARCHAR(MAX) = NULL
)
AS
/*	
	Created by: 20240925@July
	Task: [TVS] New Issue Type "Wrong Offered Name" [Redmine: #187408]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
	
	Revisions: 
		- 20240925@July: Create new SP [Redmine:#179934]
		- 20241126@Lani: Change join type on 'recommend' and 'custid' columns [Redmine: #213451]
		- 20250311@July: [TVS] Enhance the Out-of-Memory [Redmine: #217771]

	Param's explanation:	
		- @WrongOfferedNameInfo: <root><r MatchId="" @CurrencyIds="" LicenseeNames="" /></root>
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE  @WrongOfferedNameXML	  XML = NULL	
			,@MarkTransIds		      VARCHAR(MAX) =''
			,@UnmarkTransIds		  VARCHAR(MAX) =''
			,@OldActionId			  TINYINT
			,@TransInfoJson			  VARBINARY(MAX) = NULL
		    ,@MatchId				  INT
			,@CurrencyIds			  VARCHAR(MAX)
			,@LicenseeNames			  VARCHAR(MAX)
			,@LogInfoTicketsJson	  VARBINARY(MAX) = NULL
		    ,@SiteDBGroupID			  SMALLINT

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()
	DECLARE @Validation AS TABLE (
		 MatchId                 INT
		,IsInValidTotalTickets   BIT DEFAULT(0) 
		,IsExistedInOtherRequest BIT DEFAULT(0) 
		,IsHasSettledTicket		 BIT DEFAULT(0) 
		,IsHasInstantlySettledTicket BIT DEFAULT(0) 
		,LogInfoTicketsJson		 VARCHAR(MAX)
	)

	DECLARE @tmpCurrencyIds AS TABLE (CurrencyId INT)
	DECLARE @tmpLogInfoTickets TABLE (TransId BIGINT)
	DECLARE @tmpLicenseeNames TABLE(LicenseeName VARCHAR(100), GroupName VARCHAR(100))	
	DECLARE @tmpUIRepresentativeLicenseeGroupNames TABLE (GroupName VARCHAR(100))	
	DECLARE @tmpUnmarkTransId AS TABLE (TransId BIGINT)
	DECLARE @tmpMarkTransId AS TABLE (TransId BIGINT)
	DECLARE @tmpMatchId TABLE (MatchId INT)

	CREATE TABLE #TransidInRequest (TransId BIGINT, RequestId INT, MainTransId BIGINT, MatchId INT)
	CREATE TABLE #TVSTicketBets(
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
	  ,SettledType		 TINYINT -- 1: Instant Settlement, 2: Normal Settlement, 3: SABA Time Machine Settlement
	  ,ID INT IDENTITY (1,1) PRIMARY KEY
	)
	
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

	--Init Validation
	INSERT INTO @Validation (MatchId)
	SELECT MatchId
	FROM #FilterInfo

	SELECT @MatchId = MatchId
		  ,@CurrencyIds = CurrencyIds
		  ,@LicenseeNames = LicenseeNames
	FROM #FilterInfo

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

	--Cricket/Baseball - Get child match
	INSERT INTO @tmpMatchId (MatchId)
	SELECT MatchId
	FROM dbo.match m WITH(NOLOCK)
	WHERE 1 = CASE WHEN m.matchid = @MatchId THEN 1
				   WHEN m.sporttype IN (50,8) AND m.ChildMatchType = 200 AND m.ParentID = @MatchId THEN 1
			       ELSE 0 END

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
		DROP TABLE #CTE_match
		DROP TABLE #CTE_isCal
	END	

	--Search single tickets
	INSERT INTO #TVSTicketBets(
			matchid 
			,transid
			,Subtransid 
			,custid                
			,transdate 
			,checktime 
			,hdp1 
			,hdp2 
			,livehomescore 
			,liveawayscore 
			,liveindicator 
			,betteam 
			,creator 
			,refno 
			,betid 
			,bettype 
			,betdaqid 
			,betfrom 
			,statusID 
			,WalletType 
			,RefCode 
			,Subcustid         
			,Sublivehomescore 
			,Subliveawayscore 
			,Subhdp1 
			,Subhdp2 
			,Subbetfrom 
			,Subbettype 
			,SubstatusID 
			,Subtransdate 
			,Subchecktime 
			,Subliveindicator 
			,recommend 
			,mrecommend 
			,srecommend 
			,statuswinlost 
			,IsMixParlay 
			,odds 
			,Subodds 
			,oddsspread 
			,oddstype 
			,betcheck 
			,Subbetcheck 
			,stake 
			,currency
			,CurrencyName 
			,Transdesc 
			,ExtraInfo 
			,BonusID 
			,winlost        
			,actual_stake 
			,Status
			,SubStatus 
			,Subbetteam  
			,Suboddsspread 
			,SubTransdesc  
			,modds 
			,SiteDBGroupID
		)
	SELECT @MatchId AS matchid
		,b.TransId
		,b.transid AS SubTransID
		,b.custid
		,b.transdate
		,b.checktime
		,b.hdp1
		,b.hdp2
		,b.livehomescore
		,b.liveawayscore
		,b.liveindicator
		,b.betteam
		,b.creator
		,b.refno
		,b.betid
		,b.bettype
		,b.betdaqid 
		,b.betfrom 
		,b.statusID 
		,b.WalletType 
		,b.RefCode 
		,b.custid Subcustid         
		,b.livehomescore AS Sublivehomescore 
		,b.liveawayscore AS Subliveawayscore 
		,b.hdp1 AS Subhdp1 
		,b.hdp2 AS Subhdp2 
		,b.betfrom AS Subbetfrom 
		,b.bettype AS Subbettype 
		,b.statusID AS SubstatusID 
		,b.transdate AS Subtransdate 
		,b.checktime AS Subchecktime 
		,b.liveindicator AS Subliveindicator 
		,b.recommend 
		,b.mrecommend 
		,b.srecommend 
		,b.statuswinlost 
		,0 AS IsMixParlay 
		,b.odds 
		,b.odds AS Subodds 
		,b.oddsspread
		,b.oddstype 
		,b.betcheck 
		,b.betcheck AS Subbetcheck 
		,b.stake 
		,b.currency
		,b.CurrencyName 
		,b.Transdesc 
		,b.ExtraInfo 
		,b.BonusID 
		,b.winlost        
		,b.actual_stake 
		,b.Status
		,b.status AS SubStatus 
		,b.betteam AS Subbetteam  
		,b.oddsspread AS Suboddsspread 
		,b.transdesc SubTransdesc  
		,b.modds 
		,b.SiteDBGroupID
	FROM dbo.bettrans b WITH (NOLOCK)
		INNER JOIN @tmpMatchId d ON d.MatchId = b.matchid
		INNER JOIN @tmpCurrencyIds c ON b.currency = c.CurrencyId
	WHERE 1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1
				   WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
				   ELSE 0 END
		AND b.betfrom <> 'P'
		AND b.SiteDBGroupID = @SiteDBGroupID
	
	--Search sub-parlay
	IF EXISTS (
					SELECT TOP(1) 1
					FROM dbo.bettransm AS bm WITH (NOLOCK)
						INNER JOIN @tmpMatchId d oN d.MatchId = bm.matchid
					WHERE 1 = CASE WHEN @ActionId <>2 AND bm.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
				  			       WHEN @ActionId = 2 AND bm.statusID NOT IN (101, 103) THEN 1
				   				   ELSE 0 END
						AND bm.betfrom <> 'P' AND bm.SiteDBGroupID = @SiteDBGroupID
					)
	BEGIN		
		INSERT INTO #TVSTicketBets(
				matchid 
				,transid
				,Subtransid 
				,custid                
				,transdate 
				,checktime 
				,hdp1 
				,hdp2 
				,livehomescore 
				,liveawayscore 
				,liveindicator 
				,betteam 
				,creator 
				,refno 
				,betid 
				,bettype 
				,betdaqid 
				,betfrom 
				,statusID 
				,WalletType 
				,RefCode 
				,Subcustid         
				,Sublivehomescore 
				,Subliveawayscore 
				,Subhdp1 
				,Subhdp2 
				,Subbetfrom 
				,Subbettype 
				,SubstatusID 
				,Subtransdate 
				,Subchecktime 
				,Subliveindicator 
				,recommend 
				,mrecommend 
				,srecommend 
				,statuswinlost 
				,IsMixParlay 
				,odds 
				,Subodds 
				,oddsspread 
				,oddstype 
				,betcheck 
				,Subbetcheck 
				,stake 
				,currency
				,CurrencyName 
				,Transdesc 
				,ExtraInfo 
				,BonusID 
				,winlost        
				,actual_stake 
				,Status
				,SubStatus 
				,Subbetteam  
				,Suboddsspread 
				,SubTransdesc  
				,modds 
				,SiteDBGroupID
			)
		SELECT @MatchId AS matchid
			,b.TransId
			,sub.transid AS SubTransID
			,b.custid
			,b.transdate
			,b.checktime
			,b.hdp1
			,b.hdp2
			,b.livehomescore
			,b.liveawayscore
			,b.liveindicator
			,b.betteam
			,b.creator
			,b.refno
			,b.betid
			,b.bettype
			,b.betdaqid 
			,b.betfrom 
			,b.statusID 
			,b.WalletType 
			,b.RefCode 
			,b.custid Subcustid         
			,sub.livehomescore AS Sublivehomescore 
			,sub.liveawayscore AS Subliveawayscore 
			,sub.hdp1 AS Subhdp1 
			,sub.hdp2 AS Subhdp2 
			,sub.betfrom AS Subbetfrom 
			,sub.bettype AS Subbettype 
			,sub.statusID AS SubstatusID 
			,sub.transdate AS Subtransdate 
			,sub.checktime AS Subchecktime 
			,sub.liveindicator AS Subliveindicator 
			,b.recommend 
			,b.mrecommend 
			,b.srecommend 
			,b.statuswinlost 
			,1 AS IsMixParlay 
			,b.odds 
			,Sub.odds AS Subodds 
			,b.oddsspread
			,b.oddstype 
			,b.betcheck 
			,sub.betcheck AS Subbetcheck 
			,b.stake 
			,b.currency
			,b.CurrencyName 
			,b.Transdesc 
			,b.ExtraInfo 
			,b.BonusID 
			,b.winlost        
			,b.actual_stake 
			,b.Status
			,sub.status AS SubStatus 
			,sub.betteam AS Subbetteam  
			,sub.oddsspread AS Suboddsspread 
			,sub.transdesc SubTransdesc  
			,b.modds
			,sub.SiteDBGroupID
		FROM @tmpMatchId d
			INNER JOIN dbo.bettransm sub WITH (NOLOCK) ON d.MatchId = sub.matchid
			INNER HASH JOIN dbo.bettrans AS b WITH (NOLOCK) ON b.refno = sub.refno
			INNER JOIN @tmpCurrencyIds c ON b.currency = c.CurrencyId
	WHERE 1 = CASE WHEN @ActionId <>2 AND sub.statusID NOT IN (101, 102, 103) THEN 1
				   WHEN @ActionId = 2 AND sub.statusID NOT IN (101, 103) THEN 1
				   ELSE 0 END
			AND sub.betfrom <> 'P'
			AND b.matchid = 29 AND b.bettype = 29
			AND b.SiteDBGroupID = @SiteDBGroupID AND sub.SiteDBGroupID = @SiteDBGroupID
	END 
	
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
		FROM #TVSTicketBets s
			INNER JOIN dbo.match m WITH (NOLOCK) ON	s.matchid = m.matchid
			INNER JOIN CustDB.dbo.custInfo ci WITH(NOLOCK) ON s.custid = ci.custid
	
		-- update Isdeposit
		UPDATE s 
			SET IsDeposit = 1
		FROM	#TVSTicketBets s
		WHERE EXISTS (SELECT d.custid FROM CustDB.dbo.Dep_CustSuper d WITH(NOLOCK) WHERE d.custid = s.srecommend)
	
		-- update GroupName
		UPDATE s 
			SET GroupName = tl.GroupName
		FROM	#TVSTicketBets s
			INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK)
						 ON s.custid = c.custid
			INNER JOIN @tmpLicenseeNames tl
						 ON tl.LicenseeName = c.site 

		DELETE FROM #TVSTicketBets WHERE GroupName IS NULL
	
		-- update get instant/settle
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
	END

	/*Get Transid in Request of range Transid*/
	DECLARE @TransInfoJson_Request		VARBINARY(MAX)
	DECLARE @StartRow INT 
			, @StopRow INT 
			, @MaxRow INT  -- Keep the total row of your data
			, @Threshold INT  -- the number of each batch

	SET @MaxRow = (SELECT MAX(ID) FROM #TVSTicketBets)
	SET @Threshold = 20000

	IF @Threshold >= @MaxRow
		SET @Threshold = @MaxRow

	-- SET for first batch
	SELECT @StartRow = 1, @StopRow = @Threshold
	IF @ActionId <> 2
	BEGIN
		WHILE (@MaxRow IS NOT NULL)
		BEGIN
		
				SET @TransInfoJson_Request = COMPRESS((SELECT matchid AS 'mid'
						,transid AS 't'
						,SubTransid AS 's_t'
				FROM #TVSTicketBets R
				WHERE ID BETWEEN @StartRow AND @StopRow
					FOR JSON PATH))

				INSERT INTO #TransidInRequest (TransId, RequestId, MainTransId, MatchId)
				EXEC DBCTG.bodb02.dbo.TicketVoiding_CheckExistingRequest
					@TransInfoJson = @TransInfoJson_Request
					,@RequestId = @RequestId
					,@Mode = 1

				IF @StopRow = @MaxRow BREAK

				SET @StartRow = @StopRow + 1
				SET @StopRow = @StopRow + @Threshold
				IF @StopRow >= @MaxRow
					SET @StopRow = @MaxRow

		END
		
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
	
	
	CREATE TABLE #CTE_RequestDetail (RequestId INT, MatchId INT, Sporttype SMALLINT, TransIds VARCHAR(MAX), IssueDetail NVARCHAR(MAX), VoidFromTime DATETIME, VoidToTime DATETIME, MainParlayCount INT, ActionId TINYINT)
	CREATE TABLE #CTE_Ticket_Single (RequestId INT, MatchId INT, TransId BIGINT, Bettype SMALLINT)
	CREATE TABLE #CTE_Ticket_SubParlay (RequestId INT, MatchId INT, TransId BIGINT)

	DECLARE @cnt_s INT , @cnt_p INT	

	INSERT INTO #CTE_RequestDetail (RequestId, MatchId, Sporttype, TransIds, IssueDetail, VoidFromTime, VoidToTime, MainParlayCount, ActionId)
	SELECT rd.RequestId, MatchId, Sporttype, TransIds, IssueDetail, VoidFromTime, VoidToTime, MainParlayCount, ActionId
	FROM DBCTG.bodb02.dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
		INNER JOIN DBCTG.bodb02.dbo.TicketVoiding_Request r WITH(NOLOCK) ON rd.RequestId = r.RequestId
	WHERE rd.RequestId = @RequestId

	INSERT INTO #CTE_Ticket_Single (RequestId, MatchId, TransId, Bettype)
	SELECT RequestId, MatchId, TransId, Bettype
	FROM DBCTG.bodb02.dbo.TicketVoiding_RequestDetailTicket_Single WITH(NOLOCK)
	WHERE RequestId = @RequestId
	SET @cnt_s = @@ROWCOUNT

	INSERT INTO #CTE_Ticket_SubParlay (RequestId, MatchId, TransId)
	SELECT RequestId, MatchId, TransId
	FROM DBCTG.bodb02.dbo.TicketVoiding_RequestDetailTicket_SubParlay WITH(NOLOCK)
	WHERE RequestId = @RequestId
	SET @cnt_p = @@ROWCOUNT

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
		FROM #CTE_Ticket_Single WITH (NOLOCK) 
		UNION ALL
		SELECT TransId
		FROM #CTE_Ticket_SubParlay WITH (NOLOCK) 
			
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
		INNER JOIN #TVSTicketBets m ON s.transid = m.Subtransid
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

		-- 3. Loginfo table 
		SELECT MatchId, LogInfoTicketsJson
		FROM @Validation

		-- 4. Unmark/Transinfo table (No need -> return table)
		SELECT TransId AS UnmarkTransIds, @TransInfoJson AS TransInfoJson FROM @tmpUnmarkTransId

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
		SET @OldActionId = (SELECT TOP 1 ISNULL(ActionId,0) FROM #CTE_RequestDetail WITH(NOLOCK))

		IF @ActionId <> 2 AND @OldActionId <> 2
		BEGIN
			--Edit request filter on UI -> unmark ticket 
			INSERT INTO @tmpUnmarkTransId (TransId)
			SELECT um.TransId
			FROM ( 
					SELECT TransId FROM #CTE_Ticket_Single s
					UNION ALL 
					SELECT TransId FROM #CTE_Ticket_SubParlay p
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
			SELECT TransId FROM #CTE_Ticket_Single s
			UNION ALL 
			SELECT TransId FROM #CTE_Ticket_SubParlay p
		END

	END

	SELECT @UnmarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(mt.TransId AS VARCHAR(50)) 
											FROM @tmpUnmarkTransId mt
											WHERE EXISTS (SELECT TOP 1 1 FROM dbo.MarkedTransaction m WITH (NOLOCK) WHERE mt.TransId = m.TransId)
											FOR XML PATH('')), 1,1,'')
											,'')

	SELECT @MarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(mt.TransId AS VARCHAR(50)) 
										FROM @tmpMarkTransId mt
										WHERE NOT EXISTS (SELECT TOP 1 1 FROM dbo.MarkedTransaction m WITH (NOLOCK) WHERE mt.TransId = m.TransId)
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

	-- 3. Loginto table 
	SELECT MatchId, LogInfoTicketsJson
	FROM @Validation

	SET @TransInfoJson = COMPRESS((SELECT b.matchid AS 'mid'
		,b.transid AS 't'
		,b.Subtransid  AS 's_t'
		,b.custid AS  'c'           
		,b.bettype AS 'btype'
		,b.betid AS 'bid'
		,b.IsMixParlay AS 'isP'
		,b.SiteDBGroupID AS 'sitedb'
	FROM #TVSTicketBets b
	FOR JSON PATH))

	-- 4. List ticket unmark/mark & Transinfo table (if any)
	SELECT @UnmarkTransIds AS UnmarkTransIds
		  ,@MarkTransIds AS MarkTransIds
		  ,CONVERT(VARCHAR(MAX), @TransInfoJson, 1) AS TransInfoJson

	DROP TABLE #FilterInfo
	DROP TABLE #TVSTicketBets
	DROP TABLE #TransidInRequest
	DROP TABLE #InstantSettlementBettypes
	DROP TABLE #CTE_Ticket_Single
	DROP TABLE #CTE_Ticket_SubParlay
	DROP TABLE #CTE_RequestDetail
END
GO

