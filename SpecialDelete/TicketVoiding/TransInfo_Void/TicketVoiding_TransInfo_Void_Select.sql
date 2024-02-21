/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_TransInfo_Void_Select] 
(
	@SingleTransIds			VARCHAR(MAX) = NULL
	,@ParlayTransIds		VARCHAR(MAX) = NULL
	,@CancelCashoutTransIds VARCHAR(MAX) = NULL
	,@MatchId				INT = NULL
)
AS
/*	
	Created by: 20221124@Max
	Task: [TVS] Increase data size when sending data between web and DB [Redmine: #180863]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20221124@Max: Create new SP [Redmine: #180863]
		- 20230103@Max: Change JSON input [Redmine: #180625]
		- 20230220@July: Cancel Cash-Out if action CO in danger time range [Redmine: #176998]
		- 20230310@Max: [TVS] Support void Cricket tickets on TVS Abnormal Bet [Redmine: #168081]
		- 20230405@July: [TVS] Enhance auto cancel cash out for TVS [Redmine: #186417]
		- 20230426@July: [TVS] Support void Cricket tickets on TVS Early Kick Off/Wrong Kick Off Time [Redmine: #187051]
		- 20231016@Max: [TVS] Add related event for voiding Early Kick Off issue type [Redmine: #188957]
		- 20240219@Max: TVS - Voiding request but missing a parlay ticket [Redmine: #200987]

	Param's explanation:	
		- @SingleTransIds: '12343091763609600,12343108943478784'
		
*/
BEGIN
	SET NOCOUNT ON	

	DECLARE @TransInfoJson VARBINARY(MAX)
		   ,@SiteDBGroupID SMALLINT

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	CREATE TABLE #TransInfo (
		matchid INT
		,transid BIGINT
		,Subtransid BIGINT
		,custid        INT        
		,transdate DATETIME
		,checktime DATETIME
		,hdp1 SMALLMONEY
		,hdp2 SMALLMONEY
		,livehomescore SMALLINT
		,liveawayscore SMALLINT
		,liveindicator BIT
		,betteam NVARCHAR(10)
		,creator INT
		,refno BIGINT
		,betid BIGINT
		,bettype SMALLINT
		,betdaqid BIGINT
		,betfrom NVARCHAR(4)
		,statusID TINYINT
		,WalletType TINYINT
		,RefCode BIGINT
		,Subcustid INT        
		,Sublivehomescore SMALLINT
		,Subliveawayscore SMALLINT
		,Subhdp1 SMALLMONEY
		,Subhdp2 SMALLMONEY
		,Subbetfrom NVARCHAR(4)
		,Subbettype SMALLINT
		,SubstatusID TINYINT
		,Subtransdate DATETIME
		,Subchecktime DATETIME
		,Subliveindicator BIT
		,recommend INT
		,mrecommend INT
		,srecommend INT
		,statuswinlost TINYINT
		,IsMixParlay BIT
		,odds MONEY
		,Subodds MONEY
		,oddsspread MONEY
		,oddstype TINYINT
		,betcheck NVARCHAR(50)
		,Subbetcheck NVARCHAR(50)
		,stake MONEY
		,CurrencyName NVARCHAR(50)
		,Transdesc NVARCHAR(1000)
		,ExtraInfo VARCHAR(1000)
		,BonusID INT
		,winlost        MONEY
		,actual_stake MONEY
		,Status NVARCHAR(10)
		,SubStatus NVARCHAR(10)
		,Subbetteam  NVARCHAR(10)
		,Suboddsspread MONEY
		,SubTransdesc  NVARCHAR(1000)
		,modds SMALLMONEY
		,SiteDBGroupID SMALLINT
		,oddsid INT
		,winlostdate SMALLDATETIME
		,IsCancelCashOut 	BIT
		,CheckTimeCashOut DATETIME
	)

	CREATE TABLE #transIdTemp (transid BIGINT PRIMARY KEY, TicketType TINYINT) --1: single(exclude cancel CO), 2: parlay, 3: cancel CO

	INSERT INTO #transIdTemp (transid, TicketType)
	SELECT DISTINCT value, 1
	FROM STRING_SPLIT(@SingleTransIds, ',')
	WHERE value <> ''

	UNION ALL --parlay
	SELECT DISTINCT value, 2
	FROM STRING_SPLIT(@ParlayTransIds, ',')
	WHERE value <> ''

	UNION ALL --cancelCO
	SELECT DISTINCT value, 3
	FROM STRING_SPLIT(@CancelCashoutTransIds, ',')
	WHERE value <> ''

	IF @CancelCashoutTransIds IS NOT NULL
	BEGIN
		--Fix case Cancel Cashout -> Cashout again. Expect: NO show betlist
		DELETE t
		FROM #transIdTemp t
			INNER JOIN dbo.zzzbettrans z WITH (NOLOCK) ON t.transid = z.transid AND z.comstatus ='CO'
		WHERE TicketType = 3
	END

	--Search single tickets
	INSERT INTO #TransInfo(
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
			,oddsid
			,winlostdate
			,IsCancelCashOut
			,CheckTimeCashOut
		)
	SELECT b.matchid
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
		,b.oddsid
		,b.winlostdate
	    ,CASE WHEN d.TicketType = 3 AND b.betdaqid = -2 THEN 1 ELSE 0 END IsCancelCashOut
		,CASE WHEN d.TicketType = 3 AND b.betdaqid = -2 THEN co.CheckTime ELSE NULL END CheckTimeCashOut
	FROM #transIdTemp d 
		INNER JOIN  dbo.bettrans b WITH (NOLOCK) ON d.transid = b.TransId
		LEFT JOIN dbo.CashOutSelling co WITH(NOLOCK) ON b.TransId = co.TransID
	WHERE b.statusID NOT IN (101, 102, 103)
		AND b.SiteDBGroupID = @SiteDBGroupID
		AND d.TicketType <> 2
	
	--Search sub-parlay
	IF EXISTS (
					SELECT TOP(1) 1
					FROM dbo.bettransm AS bm WITH (NOLOCK)
						INNER JOIN #transIdTemp d oN d.transid = bm.TransId
					WHERE bm.statusID NOT IN (101, 102, 103)
						AND d.TicketType = 2
					)
	BEGIN		
		INSERT INTO #TransInfo(
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
				,oddsid
				,winlostdate
			)
		SELECT sub.matchid
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
			,sub.oddsid
			,sub.winlostdate
		FROM #transIdTemp d
			INNER LOOP JOIN dbo.bettransm sub WITH (NOLOCK) ON d.transid = sub.TransId
			INNER HASH JOIN bettrans AS b WITH (NOLOCK) ON b.refno = sub.refno
		WHERE sub.statusID NOT IN (101, 102, 103) -- reject, void, refund
			AND sub.SiteDBGroupID = @SiteDBGroupID
			AND d.TicketType = 2
		
		--Re-scan data for case miss by page split
		IF EXISTS (
					SELECT TOP(1) 1
					FROM #transIdTemp d
						INNER JOIN dbo.bettransm AS bm WITH (NOLOCK) ON d.transid = bm.TransId
					WHERE bm.statusID NOT IN (101, 102, 103)
						AND d.TicketType = 2
						AND NOT EXISTS (SELECT TOP 1 1 FROM #TransInfo t WHERE t.transid = d.transid)
						AND bm.SiteDBGroupID = @SiteDBGroupID
				)
		BEGIN
			DECLARE @tmp_MissingTransId AS TABLE (TransId BIGINT PRIMARY KEY)

			INSERT INTO @tmp_MissingTransId (TransId)
			SELECT d.transid
			FROM #transIdTemp d
				INNER JOIN dbo.bettransm AS bm WITH (NOLOCK) ON d.transid = bm.TransId
			WHERE bm.statusID NOT IN (101, 102, 103)
				AND d.TicketType = 2
				AND NOT EXISTS (SELECT TOP 1 1 FROM #TransInfo t WHERE t.transid = d.transid)
				AND bm.SiteDBGroupID = @SiteDBGroupID

			INSERT INTO #TransInfo(
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
					,oddsid
					,winlostdate
				)
			SELECT sub.matchid
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
				,sub.oddsid
				,sub.winlostdate
			FROM @tmp_MissingTransId d
				INNER JOIN dbo.bettransm sub WITH (NOLOCK) ON d.transid = sub.TransId
				CROSS APPLY (
						SELECT TOP 1 b.TransId
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
							,b.recommend 
							,b.mrecommend 
							,b.srecommend 
							,b.statuswinlost 
							,b.odds 
							,b.oddsspread
							,b.oddstype 
							,b.betcheck 
							,b.stake 
							,b.CurrencyName 
							,b.Transdesc 
							,b.ExtraInfo 
							,b.BonusID 
							,b.winlost        
							,b.actual_stake 
							,b.Status
							,b.modds
						FROM dbo.bettrans b WITH (NOLOCK)
						WHERE b.matchid = 29
							AND b.bettype = 29 
							AND b.refno = sub.refno 
					)b
		END		
	END
	
	--Update Main MatchID for child match cricket (Sporttype = 50)
	UPDATE d
	SET d.matchid = m.ParentID
	FROM #TransInfo d
		INNER JOIN dbo.match m WITH(NOLOCK) ON d.matchid = m.matchid AND m.sporttype = 50 AND m.ChildMatchType = 200

	--Remove Invalid data
	DELETE t
	FROM #TransInfo t
	WHERE @MatchId IS NOT NULL AND t.matchid <> @MatchId

	--RETURN DATA
	SET @TransInfoJson = COMPRESS((SELECT matchid AS 'mid'
		,transid AS 't'
		,Subtransid AS 's_t'
		,custid    AS  'c'           
		,transdate AS 'tdate'
		,checktime AS 'checkt'
		,hdp1 AS 'hdp1'
		,hdp2 AS 'hdp2'
		,livehomescore AS 'lh'
		,liveawayscore AS 'la'
		,liveindicator AS 'li'
		,betteam AS 'bteam'
		,creator AS 'cr'
		,refno AS 'ref'
		,betid AS 'bid'
		,bettype AS 'btype'
		,betdaqid AS 'bdaq'
		,betfrom AS 'bfr'
		,statusID AS 'sid'
		,WalletType AS 'wt'
		,RefCode AS 'refc'
		,Subcustid    AS     's_c' 
		,Sublivehomescore AS 's_lh'
		,Subliveawayscore AS 's_la'
		,Subhdp1 AS 's_hdp1'
		,Subhdp2 AS 's_hdp2'
		,Subbetfrom AS 's_bfr'
		,Subbettype AS 's_btype'
		,SubstatusID AS 's_sid'
		,Subtransdate AS 's_tdate'
		,Subchecktime AS 's_checkt'
		,Subliveindicator AS 's_li'
		,recommend AS 're'
		,mrecommend AS 'mre'
		,srecommend AS 'sre'
		,statuswinlost AS 'statuswl'
		,IsMixParlay AS 'isP'
		,odds AS 'o'
		,Subodds AS 's_o'
		,oddsspread AS 'os'
		,oddstype AS 'ost'
		,betcheck AS 'bcheck'
		,Subbetcheck AS 's_bcheck'
		,stake AS 'stake'
		,CurrencyName AS 'curr'
		,Transdesc AS 'tdes'
		,ExtraInfo AS 'ex'
		,BonusID AS 'bo'
		,winlost    AS 'w'    
		,actual_stake AS 'acstake'
		,Status AS 's' 
		,SubStatus AS 's_s'
		,Subbetteam  AS 's_bteam'
		,Suboddsspread AS 's_os'
		,SubTransdesc  AS 's_tdes'
		,modds AS 'm'
		,SiteDBGroupID AS 'sitedb'
		,oddsid AS 'oid'
		,winlostdate AS 'wld'
		,ISNULL(IsCancelCashOut,0) AS 'isCCO'
		,CheckTimeCashOut AS 'checktCO'
	FROM #TransInfo
	FOR JSON PATH))

	SELECT CONVERT(VARCHAR(MAX), @TransInfoJson, 1) AS TransInfoJson
	
	DROP TABLE #TransInfo
	DROP TABLE #transIdTemp
END

GO

