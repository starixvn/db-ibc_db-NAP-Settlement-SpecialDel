/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_LogInfo_ADVMode_Select]
(	
	 @RequestId			  INT = 0
	,@IssueTypeId		  INT = 1
	,@ActionId			  INT = 5
	,@IsShowLogOnly		  BIT = 0
	,@AdvancedModeInfo	  VARCHAR(MAX) = NULL
	,@TransInfoJson		  VARCHAR(MAX) = NULL
)
AS
/*	
	Created by: 20240522@Max
	Task: [TVS] Wrong Market Offered issue type [Redmine: #197051]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20240522@Max: Create new SP [Redmine:#197051]
		- 20240727@Max: Modify betid return [Redmine:#197051]
		- 20240727@Max: Change validation for transdesc [Redmine: #197051]
		- 20240822@Max: [TVS] Integrate new bet type of Baseball AiO - Phase 2 [Redmine: #209441]
		- 20240823@July: WMKO/TE - Add Details of bet list for issue types [Redmine: #208628]
		- 20241122@July: Wrong Market Offered - Enhance the way to add request & Update 'copy' message template [Redmine: #212928]

	Param's explanation:	
		- @AdvancedModeInfo: <root><r MatchId="" FilterFromTransTime="" FilterToTransTime =""/></root>
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @SingleCount			INT = 0
			,@MainParlayCount		INT = 0
			,@UnmarkTransIds		VARCHAR(MAX) =''
			,@MarkTransIds		    VARCHAR(MAX) =''
			,@OldActionId			TINYINT
			,@LogInfoTicketsJson	VARBINARY(MAX) = NULL

	DECLARE	@AdvancedModeInfoXML	XML = NULL
		   ,@MatchId				INT	= 0
		   ,@TransInfoJson_Output	VARBINARY(MAX) = NULL

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
			checktime			  DATETIME,
			accepttype			  TINYINT,
			SubIssueTypeId		  SMALLINT,
			IsCancelCashOut		  BIT,
			CheckTimeCashOut	  DATETIME,
			liveindicator		  BIT,
			GroupDisplay		  INT,
			GroupBettype		  SMALLINT,
			GroupTransdesc        NVARCHAR(1000),
			GroupBetteam		  NVARCHAR(10),
			Groupbetid			  NVARCHAR(50),
			GroupOddsId			  INT,
			Id					  INT,
			betid				  BIGINT,
			SiteDBGroupID		  SMALLINT
	)

	CREATE TABLE #logInfo (
		 Id						INT --Diffrence rangetime
		,MatchId				INT
		,LiveScores				NVARCHAR(300)
		,VoidFromTime			DATETIME
		,VoidToTime				DATETIME
		,SingleCount			INT
		,CashOutCount			INT
		,SettleCount            INT
		,MainParlayCount		INT
		,CancelCashOutCount		INT
	)

	CREATE TABLE #TransidInRequest (Id INT, TransId BIGINT, RequestId INT, MainTransId BIGINT, MatchId INT, CreatedBy INT)
	CREATE TABLE #logInfoVoidPage (Id INT, RequestId INT, MatchId INT, SettleCount INT, CancelCashOutCount INT)

	CREATE TABLE #FilterInfo (
		 Id						INT --Diffrence rangetime
		,MatchId				INT
		,FilterFromTransTime	DATETIME
		,FilterToTransTime		DATETIME
		,SubIssueTypeId			SMALLINT
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
	  ,AcceptModeCashOut  TINYINT
	  ,OddsId INT
	  ,WalletType TINYINT
	  ,RefCode BIGINT
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
	)
	DECLARE @tblScoreMessage AS TABLE (MatchId INT, ScoreNormalTicket VARCHAR(100), ScoreOfMatch VARCHAR(100))

	DECLARE @Validation AS TABLE (
			 Id						 INT
			,MatchId                 INT	
			,IsInValidTotalTickets   BIT DEFAULT(0) 
			,IsExistedInOtherRequest BIT DEFAULT(0) 
			,IsExistsSecondAccept	 BIT DEFAULT(0) 	
			,LogInfoTicketsJson		 NVARCHAR(MAX)
			,IsFinish				 BIT
		)
	DECLARE @tmpUnmarkTransId AS TABLE (TransId BIGINT)
	DECLARE @tmpMarkTransId AS TABLE (TransId BIGINT)
	DECLARE @tmpLogInfoTickets TABLE (Id INT, TransId BIGINT, IsCancelCashOut BIT)

	DECLARE @tmpConsolidatedBettypes TABLE (
        parentid        INT
        ,typeid         INT PRIMARY KEY
    )
    
    INSERT INTO @tmpConsolidatedBettypes (parentid, typeid)
    SELECT f.GroupTypeId AS parentid
		 , f.Bettype AS typeid
    FROM [dbo].[f_SD_GroupDisplayBettype] () f

	SET @AdvancedModeInfoXML = CONVERT(XML, @AdvancedModeInfo)
	INSERT INTO #FilterInfo (Id, MatchId, FilterFromTransTime, FilterToTransTime, SubIssueTypeId)
	SELECT  CASE WHEN t.c.value('@Id','INT') IS NULL THEN 1 ELSE t.c.value('@Id','INT') END AS Id --Default = 1 with case old request
	        ,t.c.value('@MatchId','INT') AS MatchID
		    ,CASE WHEN t.c.value('@FilterFromTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterFromTransTime','DATETIME') END AS FilterFromTransTime
		    ,CASE WHEN t.c.value('@FilterToTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterToTransTime','DATETIME') END AS FilterToTransTime
			,t.c.value('@SubIssueTypeId','SMALLINT') AS SubIssueTypeId
	FROM @AdvancedModeInfoXML.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@AdvancedModeInfoXML = NULL))

	SET @MatchId = (SELECT TOP(1) MatchId FROM #FilterInfo)

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
		   ,AcceptModeCashOut
		   ,OddsId
		   ,WalletType 
	       ,RefCode 
	)
	SELECT mid ,t ,s_t ,ref ,c ,hdp1 ,hdp2 ,lh ,la ,li
		,o ,os ,bfr ,btype ,bteam ,bcheck ,s ,tdate , checkt ,bid
		,tdes ,sid ,s_c ,s_hdp1 ,s_hdp2 ,s_lh ,s_la ,s_li ,s_o ,s_os
		,s_bfr ,s_btype ,s_bteam ,s_bcheck ,s_s ,s_tdate , s_checkt ,s_tdes ,s_sid ,sre
		,mre ,re ,cr ,stake ,ost ,curr ,bdaq ,ex ,bo ,w
		,acstake ,wld ,m ,statuswl ,isP ,sitedb
		,lbat ,sat ,s_lbat ,s_sat ,checktCO ,amCO, f_oid
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
					  ,lbat ,sat ,s_lbat ,s_sat ,CASE WHEN checktCO = '1900-01-01 00:00:00.000' THEN NULL ELSE checktCO END AS checktCO ,amCO, CONVERT(INT, f_oid) AS f_oid
					  ,wt ,refc
				FROM OPENJSON(t.Decompress_TransInfoJson) 
				WITH( mid INT, t BIGINT, s_t BIGINT, ref BIGINT, c INT, hdp1 SMALLMONEY, hdp2 SMALLMONEY, lh SMALLINT, la SMALLINT ,li BIT 
					 ,o SMALLMONEY ,os MONEY ,bfr NVARCHAR(4) ,btype SMALLINT ,bteam NVARCHAR(10) ,bcheck NVARCHAR(50) ,s NVARCHAR(10) ,tdate DATETIME ,checkt DATETIME ,bid BIGINT
					 ,tdes NVARCHAR(1000) ,sid TINYINT ,s_c INT ,s_hdp1 SMALLMONEY ,s_hdp2 SMALLMONEY ,s_lh SMALLINT ,s_la SMALLINT ,s_li BIT ,s_o SMALLMONEY ,s_os MONEY 
					 ,s_bfr NVARCHAR(4) ,s_btype SMALLINT ,s_bteam NVARCHAR(10) ,s_bcheck NVARCHAR(50) ,s_s NVARCHAR(10) ,s_tdate DATETIME ,s_checkt DATETIME ,s_tdes NVARCHAR(1000) ,s_sid  TINYINT ,sre INT
					 ,mre INT ,re INT ,cr INT ,stake MONEY ,ost TINYINT ,curr NVARCHAR(50) ,bdaq BIGINT ,ex VARCHAR(1000) ,bo INT ,w MONEY
					 ,acstake MONEY ,wld SMALLDATETIME ,m SMALLMONEY ,statuswl TINYINT ,isP BIT ,sitedb SMALLINT
					 ,lbat SMALLINT ,sat TINYINT ,s_lbat SMALLINT ,s_sat TINYINT ,checktCO DATETIME ,amCO TINYINT, f_oid NVARCHAR(1000)
					 ,wt TINYINT ,refc BIGINT	
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
	END

	--Init Validation
	INSERT INTO @Validation (Id, MatchId)
	SELECT Id, MatchId
	FROM #FilterInfo

	INSERT INTO #TVSTicketBets(
			transid		
			,SubTransid		
			,refno			
			,custid				
			,transdate		
			,bettype 					
			,Subbettype
			,livehomescore 	
			,liveawayscore 			
			,betdaqid	
			,matchid
			,StatusId
			,SubStatusId
			,checktime
			,accepttype
			,SubIssueTypeId
			,IsCancelCashOut
			,CheckTimeCashOut
			,liveindicator
			,GroupDisplay
			,GroupBettype
			,GroupBetteam
			,GroupTransdesc
			,Groupbetid
			,GroupOddsId
			,Id
			,betid
			,SiteDBGroupID
		)
	SELECT   b.transid
			,b.SubTransID
			,b.refno
			,b.custid
			,b.transdate
			,b.bettype
			,b.bettype AS Subbettype
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
			,CASE WHEN b.transdate BETWEEN d.FilterFromTransTime AND d.FilterToTransTime THEN 0
				  ELSE CASE WHEN b.betdaqid = -2 AND b.CheckTimeCashOut BETWEEN d.FilterFromTransTime AND d.FilterToTransTime AND b.AcceptModeCashOut IS NOT NULL THEN 1
							ELSE 0 END
				  END AS IsCancelCashOut
			,b.CheckTimeCashOut
			,b.liveindicator
			,ISNULL(tb.parentid, b.bettype)
			,b.bettype
			,b.betteam
			,b.Transdesc
			,CONVERT(NVARCHAR(50), b.betid)
			,b.OddsId
			,d.Id
			,b.betid
			,b.SiteDBGroupID
	FROM #tmpTransInfo b
		INNER JOIN #FilterInfo d ON d.MatchId = b.matchid
		LEFT JOIN @tmpConsolidatedBettypes tb ON  tb.typeid = b.bettype
	WHERE 1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
					WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
					ELSE 0 END
		AND b.betfrom <> 'P' AND b.IsMixParlay = 0 
		AND 1 = CASE 
					WHEN d.FilterFromTransTime IS NULL AND d.FilterToTransTime IS NULL THEN 1
					WHEN b.transdate BETWEEN d.FilterFromTransTime AND d.FilterToTransTime THEN 1
					ELSE CASE 
							 WHEN b.betdaqid = -2 AND b.CheckTimeCashOut IS NOT NULL AND b.CheckTimeCashOut BETWEEN d.FilterFromTransTime AND d.FilterToTransTime AND b.AcceptModeCashOut IS NOT NULL THEN 1
						     ELSE 0 END
				END

	UPDATE t
	SET accepttype = CASE WHEN b.AcceptModeCashOut = 0 THEN 3 ELSE b.AcceptModeCashOut END
	FROM #TVSTicketBets t
		INNER JOIN #tmpTransInfo b ON t.transid = b.transid AND t.matchid = b.matchid
	WHERE b.IsMixParlay = 0 AND t.IsCancelCashOut = 1

	-- Fix case: WMO 2 range time: Original range time 1, Canel CO: range time 2
	DECLARE @tmpRemoveDuplCancelCO TABLE (TransId BIGINT)
	INSERT INTO @tmpRemoveDuplCancelCO (TransId)
	SELECT TransId
	FROM #TVSTicketBets 
	GROUP BY transid
	HAVING COUNT(TransId) >=2

	IF EXISTS (SELECT TOP 1 1 FROM @tmpRemoveDuplCancelCO)
	BEGIN
		DELETE t
		FROM #TVSTicketBets t
		WHERE t.IsCancelCashOut = 1 
		 AND t.transid IN ( SELECT transid FROM @tmpRemoveDuplCancelCO)
	END

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
				,Subbettype
				,livehomescore	
				,liveawayscore			
				,IsMixParlay
				,matchid
				,StatusId
				,SubStatusId
				,checktime
				,accepttype
				,SubIssueTypeId
				,IsCancelCashOut
				,CheckTimeCashOut
				,liveindicator
				,GroupDisplay
				,GroupBettype
				,GroupBetteam
				,GroupTransdesc
				,Groupbetid
				,GroupOddsId
				,Id
				,betid
				,SiteDBGroupID
			)
		SELECT   b.transid AS TransId
				,b.SubTransID
				,b.refno
				,b.Subcustid				
				,b.Subtransdate
				,b.bettype
				,b.Subbettype
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
									WHEN b.Subchecktime = DATEADD(SECOND,ISNULL(b.SubLiveBetAcceptTime,0) + ISNULL(b.SubSecAcceptTime,0), b.Subtransdate) THEN 2 --Second Accept
									ELSE 3 --Pending Accept
								END
					END AS accepttype
				,d.SubIssueTypeId
				,0 AS IsCancelCashOut
				,NULL AS CheckTimeCashOut
				,b.liveindicator
				,ISNULL(tb.parentid, b.Subbettype)
				,b.Subbettype
				,b.Subbetteam
				,b.SubTransdesc
				,b.Subbetcheck
				,b.OddsId
				,d.Id
				,b.betid
				,b.SiteDBGroupID
		FROM	#FilterInfo d
				INNER JOIN #tmpTransInfo b ON b.matchid = d.MatchId AND b.IsMixParlay = 1 
				LEFT JOIN @tmpConsolidatedBettypes tb ON tb.typeid = b.Subbettype
		WHERE 1 = CASE WHEN @ActionId <>2 AND b.SubstatusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
					   WHEN @ActionId = 2 AND b.SubstatusID NOT IN (101, 103) THEN 1
					   ELSE 0 END
				AND b.Subbetfrom <> 'P' 
				AND (b.Subtransdate BETWEEN d.FilterFromTransTime AND d.FilterToTransTime
					OR (d.FilterFromTransTime IS NULL AND d.FilterToTransTime IS NULL)
				    )
	
	END 

	/*Get Transid in Request of range Transid*/
	IF @ActionId NOT IN (2)
	BEGIN
		INSERT INTO #TransidInRequest (TransId, RequestId, MainTransId, MatchId, CreatedBy, Id)
		SELECT tmp.transid, r.RequestId, tmp.MainTransId, t.matchid, r.UserId, t.Id
		FROM #TVSTicketBets t
			CROSS APPLY (
						SELECT rs.TransId, rs.TransId AS MainTransId, rs.RequestId
						FROM dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK)
						WHERE rs.TransId = t.transid AND rs.MatchId = @MatchId
						UNION ALL
						SELECT rp.TransId, rp.MainTransId, rp.RequestId
						FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rp WITH (NOLOCK)
						WHERE rp.TransId = t.SubTransid AND rp.MatchId = @MatchId
				)tmp
			INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = tmp.RequestId
		WHERE r.RequestId <> @RequestId 
			AND (r.ActionId NOT IN (2) AND r.IssueTypeId NOT IN (22))

		IF @@ROWCOUNT <> 0
		BEGIN
			UPDATE v SET v.IsExistedInOtherRequest = 1
			FROM @Validation v
				INNER JOIN #TransidInRequest t ON t.MatchId = v.MatchId
			WHERE v.Id = t.Id
		END
		
		--Remove Transid exists in other request
		DELETE FROM #TVSTicketBets 
		WHERE EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = SubTransid)
		
	END

	--Data Section
	INSERT INTO #logInfo (MatchId, VoidFromTime, VoidToTime, SingleCount, MainParlayCount, SettleCount, Id)
	SELECT @MatchId AS MatchId
		,MIN(b.transdate) AS VoidFromTime
		,MAX(b.transdate) AS VoidToTime
		,COUNT(CASE WHEN b.transid = b.SubTransid THEN b.transid ELSE NULL END) AS SingleCount
		,COUNT(CASE WHEN b.transid <> b.SubTransid THEN b.transid ELSE NULL END) AS MainParlayCount
		,COUNT(CASE WHEN b.transid = b.SubTransid AND b.StatusId IN (111, 112, 113) AND ISNULL(b.betdaqid,-1) <> -2 THEN  b.transid ELSE NULL END) AS SettleCount
		,b.Id
	FROM #TVSTicketBets b
	WHERE b.IsCancelCashOut <> 1 -- Not count ticket cancel CO
	GROUP BY CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2)), b.Id
	ORDER BY CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2)), b.Id

	IF EXISTS (SELECT TOP 1 1 FROM #TVSTicketBets WHERE IsCancelCashOut = 1)
	BEGIN
		UPDATE li
		SET CancelCashOutCount = b.CancelCashOutCount
		   ,VoidFromTime = CASE WHEN b.MIN_CheckTimeCashOut < li.VoidFromTime THEN b.MIN_CheckTimeCashOut ELSE li.VoidFromTime END
		   ,VoidToTime = CASE WHEN b.MAX_CheckTimeCashOut >  li.VoidToTime THEN b.MAX_CheckTimeCashOut ELSE li.VoidToTime END
		FROM #logInfo li
			CROSS APPLY(
				SELECT COUNT(b.transid) AS CancelCashOutCount
					  ,MIN(CheckTimeCashOut) AS MIN_CheckTimeCashOut
					  ,MAX(CheckTimeCashOut) AS MAX_CheckTimeCashOut
				FROM #TVSTicketBets b
				WHERE li.MatchId = b.matchid AND b.IsCancelCashOut = 1 AND li.Id = b.Id
				GROUP BY b.matchid, b.Id
			)b
	END

	--Not display Score in message template when voiding non-live tickets only [193108]
	IF NOT EXISTS (SELECT TOP 1 1 FROM #TVSTicketBets WHERE liveindicator = 1)
	BEGIN
		UPDATE l SET l.LiveScores = ''
		FROM #logInfo l
	END

	IF @IsShowLogOnly = 0
	BEGIN
		INSERT INTO @tmpLogInfoTickets (Id, TransId, IsCancelCashOut)
		SELECT Id, SubTransid, IsCancelCashOut
		FROM #TVSTicketBets
	END
	ELSE --Edit request
	BEGIN
		DECLARE @tmpRowNumber table (Id INT, RequestDetailId INT ) --Suport filter time range Id
		INSERT INTO @tmpRowNumber (Id, RequestDetailId)
		SELECT ROW_NUMBER() OVER(ORDER BY Id ASC) AS Id, Id AS RequestDetailId
		FROM  dbo.TicketVoiding_RequestDetail WITH (NOLOCK) 
		WHERE RequestId = @RequestId
		
		INSERT INTO @tmpLogInfoTickets (Id, TransId, IsCancelCashOut)
		SELECT r.Id, TransId, IsCancelCO
		FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK) 
			INNER JOIN @tmpRowNumber r ON s.RequestDetailId = r.RequestDetailId
		WHERE RequestId = @RequestId
		UNION ALL
		SELECT r.Id, TransId, 0
		FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay s WITH (NOLOCK) 
			INNER JOIN @tmpRowNumber r ON s.RequestDetailId = r.RequestDetailId
		WHERE RequestId = @RequestId
			
	END
	
	DECLARE @Id INT
	WHILE (1=1)
	BEGIN
		UPDATE TOP (1) v
		SET v.IsFinish = 1, @Id = v.Id
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
				,ISNULL(tb.parentid, m.Subbettype) AS 'GroupBettypeId' --Return for web filter bettype
				,s.IsCancelCashOut AS 'IsCancelCashOut'
		FROM @tmpLogInfoTickets s
			INNER JOIN #tmpTransInfo m ON s.transid = m.Subtransid
			LEFT JOIN @tmpConsolidatedBettypes tb ON tb.typeid = m.Subbettype
		WHERE s.Id = @Id
		FOR JSON PATH))

		UPDATE v
		SET v.LogInfoTicketsJson = CONVERT(VARCHAR(MAX), @LogInfoTicketsJson, 1)
		FROM @Validation v
		WHERE Id = @Id
	END

	IF @IsShowLogOnly = 1 AND @RequestId <> 0
	BEGIN
		-- 1. Validate table
		SELECT Id
			 , MatchId
			 , IsInValidTotalTickets
			 , IsExistedInOtherRequest
			 , IsExistsSecondAccept
		FROM @Validation

		-- 2. TransId in request table
		SELECT Id, RequestId, MatchId, CAST(TransId AS VARCHAR(MAX)) AS TransIds
		FROM #TransidInRequest

		/*Get log info for Void Page*/
		INSERT INTO #logInfoVoidPage (Id, RequestId, MatchId, CancelCashOutCount, SettleCount)
		SELECT b.Id
			  ,@RequestId
			  ,s.matchid
			  ,COUNT(CASE WHEN s.IsCancelCO = 1 THEN s.transid ELSE NULL END) AS CancelCashOutCount
			  ,COUNT(CASE WHEN ISNULL(b.betdaqid, -1) <> -2 AND b.StatusId IN (111, 112, 113) THEN s.TransId ELSE NULL END) AS SettleCount
		FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
			LEFT JOIN #TVSTicketBets b ON b.transid = s.transid AND s.MatchId = @MatchId AND b.IsMixParlay = 0
		WHERE s.RequestId = @RequestId 
		GROUP BY b.Id, s.matchid 

		--Check score for void message
		IF EXISTS (SELECT TOP(1) 1 FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK) WHERE s.RequestId = @RequestId)
		BEGIN
			INSERT INTO @tblScoreMessage (MatchId, ScoreNormalTicket)
			SELECT s.MatchId, CAST(b.livehomescore AS VARCHAR(10)) + '-' + CAST(b.liveawayscore AS VARCHAR(10))
			FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
				INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = s.bettype
				INNER JOIN #TVSTicketBets b ON b.transid = s.TransId AND b.IsMixParlay = 0 AND b.IsCancelCashOut <> 1
			WHERE s.RequestId = @RequestId
				AND f.GroupName <> '2H'
		END

		IF EXISTS (SELECT TOP(1) 1 FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay s WITH (NOLOCK) WHERE s.RequestId = @RequestId)
		BEGIN
			INSERT INTO @tblScoreMessage (MatchId, ScoreNormalTicket)
			SELECT s.MatchId, CAST(b.Sublivehomescore AS VARCHAR(10)) + '-' + CAST(b.Subliveawayscore AS VARCHAR(10))
			FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay s WITH (NOLOCK)
				INNER JOIN #tmpTransInfo b ON b.Subtransid = s.TransId AND b.IsMixParlay = 1
				INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = b.Subbettype			
			WHERE s.RequestId = @RequestId
				AND f.GroupName <> '2H'
		END

		IF NOT EXISTS (SELECT TOP(1) 1 FROM @tblScoreMessage)
		BEGIN
			INSERT INTO @tblScoreMessage (MatchId, ScoreOfMatch) 
			SELECT rd.MatchId, CAST(m.livehomescore AS VARCHAR(10)) + '-' + CAST(m.liveawayscore AS VARCHAR(10))
			FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
				INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = rd.MatchId
			WHERE rd.RequestId = @RequestId
		END

		-- 3. Loginfo Table
		SELECT rd.Id
		      ,rd.MatchId
			  ,rd.VoidFromTime
			  ,rd.VoidToTime
			  ,rd.SingleCount
			  ,rd.MainParlayCount
			  ,STUFF(s2.ScoreTicket2H,1,1,'') AS ScoreNormalTicket
			  ,STUFF(sm.ScoreOfMatch,1,1,'') AS ScoreOfMatch
			  ,t.CancelCashOutCount
			  ,t.SettleCount
			  ,v.LogInfoTicketsJson
		FROM (
				SELECT ROW_NUMBER() OVER(ORDER BY Id ASC) AS Id, RequestId
					  ,MatchId, VoidFromTime, VoidToTime, SingleCount, MainParlayCount
				FROM dbo.TicketVoiding_RequestDetail  WITH (NOLOCK)
				WHERE RequestId = @RequestId
			)rd
			LEFT JOIN #logInfoVoidPage t ON t.RequestId = rd.RequestId AND t.MatchId = rd.MatchId AND rd.Id = t.Id
			CROSS APPLY(
				SELECT DISTINCT '|' + l.ScoreNormalTicket FROM @tblScoreMessage l WHERE l.MatchId = rd.MatchId FOR XML PATH('')
			)s2(ScoreTicket2H)
			CROSS APPLY(
				SELECT DISTINCT '|' + l.ScoreOfMatch FROM @tblScoreMessage l WHERE l.MatchId = rd.MatchId FOR XML PATH('')
			)sm(ScoreOfMatch)
			INNER JOIN @Validation v ON rd.MatchId = v.MatchId AND v.Id = rd.Id

		-- 4. Unmark table (No need -> return table)
		SELECT TransId AS UnmarkTransIds FROM @tmpUnmarkTransId
		
		-- 5. Transinfo table (No need -> return table)
		SELECT @TransInfoJson_Output AS TransInfoJson

		-- 6. Count detail group by bettype
		SELECT DENSE_RANK() OVER (ORDER BY rd.Id ASC) AS Id
		    ,bt.bettypeid
			,bt.betid
			,bt.TicketsCount
			,t.typenamee AS originalBetTypeName
			,bt.PlayerName
		FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
			CROSS APPLY (
				SELECT bettypeid AS bettypeid, betid AS betid , TicketsCount AS TicketsCount, PlayerName AS PlayerName
				FROM OPENJSON(NULLIF(rd.TransIds,'')) 
				WITH( BetTypeId SMALLINT, BetId NVARCHAR(50),  TicketsCount INT, PlayerName NVARCHAR(MAX))
			)bt
			INNER JOIN dbo.bettype t WITH (NOLOCK) ON t.typeid = bt.bettypeid
		WHERE rd.RequestId = @RequestId
		ORDER BY DENSE_RANK() OVER (ORDER BY rd.Id ASC), t.typenamee

		RETURN;
	END

	--For case no ticket valid
	SELECT @SingleCount = ISNULL(SUM(SingleCount),0)
		,@MainParlayCount = ISNULL(SUM(MainParlayCount),0)
	FROM #logInfo

	IF @SingleCount = 0 AND @MainParlayCount = 0
	BEGIN
		-- 1. Validate table
		SELECT Id
			 , MatchId
			 , 1 AS IsInValidTotalTickets
			 , IsExistedInOtherRequest
		FROM @Validation

		-- 2. TransId in request table
		IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
		BEGIN
			SELECT r.Id, RequestId,
				STUFF((
				SELECT ', ' + CAST(MainTransId AS VARCHAR(MAX)) 
				FROM #TransidInRequest
				WHERE (RequestId = r.RequestId AND MatchId = r.MatchId AND Id = r.Id)
				ORDER BY TransId
				FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
				,1,2,'') AS TransIds
				,MatchId
				,c.username AS CreatedBy
			FROM #TransidInRequest r
				INNER JOIN CustDB.dbo.custInfo c WITH (NOLOCK) ON c.custid = r.CreatedBy
			GROUP BY r.Id, r.RequestId, r.MatchId, c.username
		END
		ELSE
		BEGIN
			SELECT Id, RequestId, MatchId, CAST(TransId AS VARCHAR(MAX)) AS TransIds
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

	UPDATE v SET v.IsInValidTotalTickets = CASE WHEN ISNULL(l.SingleCount,0) = 0 AND ISNULL(l.MainParlayCount,0) = 0 THEN 1 ELSE 0 END
	FROM @Validation v
	OUTER APPLY( 
			SELECT SUM(SingleCount) AS SingleCount
				,SUM(MainParlayCount) AS MainParlayCount
			FROM #logInfo
			WHERE MatchId = v.MatchId AND v.Id = Id
			GROUP BY MatchId, Id
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
	SELECT Id
		, MatchId
		, IsInValidTotalTickets
		, IsExistedInOtherRequest
		, IsExistsSecondAccept
	FROM @Validation

	-- 2. TransId exists in other request table
	IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
	BEGIN
		SELECT r.Id, RequestId,
			STUFF((
			SELECT ', ' + CAST(MainTransId AS VARCHAR(MAX)) 
			FROM #TransidInRequest
			WHERE (RequestId = r.RequestId AND MatchId = r.MatchId AND Id = r.Id)
			ORDER BY TransId
			FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
			,1,2,'') AS TransIds
			,MatchId
			,c.username AS CreatedBy
		FROM #TransidInRequest r
			INNER JOIN CustDB.dbo.custInfo c WITH (NOLOCK) ON c.custid = r.CreatedBy
		GROUP BY r.Id, r.RequestId, r.MatchId, c.username
	END
	ELSE
	BEGIN
		SELECT Id, RequestId, MatchId, CAST(TransId AS VARCHAR(MAX)) AS TransIds
		FROM #TransidInRequest
	END

	-- 3. Loginfo table
	SELECT l.Id
	    ,l.MatchId 
		,MIN(VoidFromTime) AS VoidFromTime
		,MAX(VoidToTime) AS VoidToTime
		,SUM(SingleCount) AS SingleCount
		,SUM(ISNULL(CancelCashOutCount,0)) AS CancelCashOutCount
		,SUM(MainParlayCount) AS MainParlayCount
		,SUM(SettleCount) AS SettleCount
		,v.LogInfoTicketsJson
	FROM #logInfo l
		INNER JOIN @Validation v ON l.MatchId = v.MatchId AND l.Id = v.Id
	GROUP BY l.Id, l.MatchId, v.LogInfoTicketsJson

	-- 4. List ticket unmark/mark (if any)
	SELECT @UnmarkTransIds AS UnmarkTransIds
	      ,@MarkTransIds AS MarkTransIds

	-- 5. Transinfo table
	SET @TransInfoJson_Output = COMPRESS((SELECT t.matchid AS 'mid'
		,t.transid AS 't'
		,t.Subtransid  AS 's_t'
		,t.custid AS  'c'           
		,t.bettype AS 'btype'
		,t.betid AS 'bid'
		,t.IsMixParlay AS 'isP'
		,t.SiteDBGroupID AS 'sitedb'
		,t.IsCancelCashOut AS 'isCCO'
		,li.VoidFromTime AS 'vft'
		,li.VoidToTime AS 'vtt'
		,@MatchId AS 'm_mid'
	FROM #TVSTicketBets t
		CROSS APPLY (
				SELECT MIN(VoidFromTime) AS VoidFromTime
					,MAX(VoidToTime) AS VoidToTime
				FROM #logInfo li 
				WHERE li.MatchId = t.matchid AND t.Id = li.Id
				GROUP BY li.matchid
			)li
	FOR JSON PATH))
	
	SELECT CONVERT(VARCHAR(MAX), @TransInfoJson_Output, 1) AS TransInfoJson

	-- 6. Count detail group by bettype
	SELECT bt.Id
	    ,bt.bettypeid
		,bt.originalBetTypeName
		,bt.bettypecount AS TicketsCount
		,bt.betid
		,bt.PlayerName
		,bt.PlayerAndOdds 
	FROM (
		SELECT b.Id
			,b.GroupDisplay AS bettypeid
			,CASE WHEN ISNULL(b.Groupbetid,'') = '' OR b.GroupDisplay = 501 THEN '0' ELSE b.Groupbetid END AS betid
			,COUNT(b.transid) AS bettypecount
			,bt.typenamee AS originalBetTypeName
			,NULL AS PlayerName
			,NULL AS PlayerAndOdds
		FROM #TVSTicketBets b
			INNER JOIN dbo.bettype bt WITH (NOLOCK) ON bt.typeid = b.GroupDisplay 
		WHERE b.IsCancelCashOut <> 1 -- Not count ticket cancel CO
			AND b.GroupBettype NOT IN (SELECT bettype FROM f_TVS_BettypesUsingTransdesc())
		GROUP BY b.Id, b.GroupDisplay, bt.typenamee, CASE WHEN ISNULL(b.Groupbetid,'') = '' OR b.GroupDisplay = 501 THEN '0' ELSE b.Groupbetid END 
	
		UNION ALL
		SELECT b.Id
			,b.GroupDisplay AS bettypeid
			,'0' AS betid
			,COUNT(b.transid) AS bettypecount
			,bt.typenamee AS originalBetTypeName
			,NULL AS PlayerName
			,b.GroupBetteam +'$'+ CONVERT(NVARCHAR(1000),b.GroupOddsId) AS PlayerAndOdds
		FROM #TVSTicketBets b
			INNER JOIN dbo.bettype bt WITH (NOLOCK) ON bt.typeid = b.GroupDisplay 
		WHERE b.IsCancelCashOut <> 1 -- Not count ticket cancel CO
			AND b.GroupBettype IN (SELECT bettype FROM f_TVS_BettypesUsingTransdesc() WHERE TypeId = 1)
		GROUP BY b.Id, b.GroupDisplay, bt.typenamee, b.GroupBetteam +'$'+ CONVERT(NVARCHAR(1000),b.GroupOddsId)

		UNION ALL
		SELECT t1.Id
		    ,t1.bettypeid
			,'0' AS betid
			,t1.bettypecount
			,t1.originalBetTypeName
			,t.teamname AS PlayerName
			,NULL AS PlayerAndOdds
		FROM
		(
			SELECT b.Id
			    ,b.GroupDisplay AS bettypeid
				,COUNT(b.transid) AS bettypecount
				,bt.typenamee AS originalBetTypeName
				,CONVERT(BIGINT, b.GroupTransdesc) AS PlayerId
			FROM #TVSTicketBets b
				INNER JOIN dbo.bettype bt WITH (NOLOCK) ON bt.typeid = b.GroupDisplay 
			WHERE b.IsCancelCashOut <> 1 -- Not count ticket cancel CO
				AND b.GroupBettype IN (SELECT bettype FROM f_TVS_BettypesUsingTransdesc() WHERE TypeId = 0)
			GROUP BY b.Id, b.GroupDisplay, bt.typenamee,CONVERT(BIGINT, b.GroupTransdesc) 
		)t1
		LEFT JOIN dbo.Team t WITH (NOLOCK) ON t.teamid = t1.PlayerId
	)bt
	ORDER BY bt.Id
	        ,bt.originalBetTypeName
			,bt.bettypeid 

	DROP TABLE #TVSTicketBets
	DROP TABLE #TransidInRequest
	DROP TABLE #logInfo
	DROP TABLE #logInfoVoidPage
	DROP TABLE #FilterInfo
	DROP TABLE #tmpTransInfo
END
GO

