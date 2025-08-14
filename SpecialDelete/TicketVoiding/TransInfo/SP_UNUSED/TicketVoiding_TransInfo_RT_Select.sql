/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_TransInfo_RT_Select] 
(
	@RecoverTicketInfo  VARCHAR(MAX) = NULL
)
AS
/*	
	Created by: 20240102@July
	Task: [TVS] Recover Ticket issue type [Redmine: #196020]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20240102@July: Create new SP [Redmine:#196020]
		- 20240718@Max: [TVS] Integrate Virtual Sports 5 (Virtually Sports) [Redmine: #207545]
		- 20240822@Max: [TVS] Integrate new bet type of Baseball AiO - Phase 2 [Redmine: #209441]
		
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON	

	DECLARE @TransInfoJson	VARBINARY(MAX)
		   ,@SiteDBGroupID	SMALLINT

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	DECLARE  @RecoverTicketInfoXML  XML = NULL
			,@TransIds				VARCHAR(MAX) = NULL
			,@ProductIds			VARCHAR(50) = NULL
			,@FilterBy				TINYINT = NULL -- (NULL: sing & mix parlay, 3: subparlay)

	CREATE TABLE #TransInfo (
		matchid			INT
		,transid		BIGINT
		,custid			INT        
		,transdate		DATETIME
		,checktime		DATETIME
		,hdp1			SMALLMONEY
		,hdp2			SMALLMONEY
		,livehomescore	SMALLINT
		,liveawayscore	SMALLINT
		,liveindicator	BIT
		,betteam		NVARCHAR(10)
		,creator		INT
		,refno			BIGINT
		,betid			BIGINT
		,bettype		SMALLINT
		,betdaqid		BIGINT
		,betfrom		NVARCHAR(4)
		,statusID		TINYINT
		,WalletType		TINYINT
		,RefCode		BIGINT
		,recommend		INT
		,mrecommend		INT
		,srecommend		INT
		,statuswinlost	TINYINT
		,IsMixParlay	BIT
		,IsMoved14		BIT
		,odds			MONEY
		,oddsspread		MONEY
		,oddstype		TINYINT
		,betcheck		NVARCHAR(50)
		,stake			MONEY
		,CurrencyName	NVARCHAR(50)
		,Transdesc		NVARCHAR(1000)
		,ExtraInfo		VARCHAR(1000)
		,BonusID		INT
		,winlost        MONEY
		,actual_stake	MONEY
		,Status			NVARCHAR(10)
		,modds			SMALLMONEY
		,SiteDBGroupID	SMALLINT
		,winlostdate	SMALLDATETIME
	)	

	CREATE TABLE #transIdTemp (transid BIGINT PRIMARY KEY)

	SET @RecoverTicketInfoXML = CONVERT(XML, @RecoverTicketInfo)
	SELECT @TransIds = t.c.value('@TransIds','NVARCHAR(MAX)') 
		  ,@ProductIds = t.c.value('@ProductIds','VARCHAR(50)')
		  ,@FilterBy = CASE WHEN t.c.value('@FilterBy','TINYINT') = 0 THEN NULL ELSE t.c.value('@FilterBy','TINYINT') END
	FROM @RecoverTicketInfoXML.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@RecoverTicketInfoXML = NULL))

	INSERT INTO #transIdTemp (transid)
	SELECT DISTINCT value
	FROM STRING_SPLIT(@TransIds, ',')
	WHERE value <> ''

	INSERT INTO #TransInfo(
			matchid 
			,transid
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
			,recommend 
			,mrecommend 
			,srecommend 
			,statuswinlost 
			,IsMixParlay 
			,IsMoved14 
			,odds 
			,oddsspread 
			,oddstype 
			,betcheck 
			,stake 
			,CurrencyName 
			,Transdesc 
			,ExtraInfo 
			,BonusID 
			,winlost        
			,actual_stake 
			,Status
			,modds 
			,SiteDBGroupID
			,winlostdate
	)
	SELECT	z.matchid
			,z.transid
			,z.custid
			,z.transdate
			,z.checktime
			,z.hdp1
			,z.hdp2
			,z.livehomescore
			,z.liveawayscore
			,z.liveindicator
			,z.betteam
			,z.creator
			,z.refno	
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
			,0 AS IsMixParlay 
			,0 AS IsMoved14 
			,z.odds
			,b.oddsspread
			,b.oddstype
			,z.betcheck
			,z.stake
			,b.CurrencyName
			,b.transdesc
			,b.ExtraInfo
			,b.BonusID
			,z.winlost - b.actual_stake
			,b.actual_stake
			,z.STATUS	
			,b.modds
			,b.SiteDBGroupID
			,b.winlostdate
	FROM dbo.zzzbettrans z WITH (NOLOCK)
		INNER JOIN dbo.bettrans b WITH (NOLOCK) 
				ON b.transid = z.transid
					AND b.custid = z.custid
					AND b.matchid = z.matchid
					AND b.bettype = z.bettype 
	WHERE z.transid IN (SELECT s.transid FROM #transIdTemp s)
		AND b.betfrom <> 'p'
		AND z.SiteDBGroupID = @SiteDBGroupID AND b.SiteDBGroupID = z.SiteDBGroupID
		AND ISNULL(z.comstatus,'') <> 'CO'

	--Update Main MatchID for child match cricket (Sporttype = 50)
	UPDATE d
	SET d.matchid = m.ParentID
	FROM #TransInfo d
		INNER JOIN dbo.match m WITH (NOLOCK) ON	d.matchid = m.matchid AND m.sporttype IN (50,8) AND m.ChildMatchType = 200
	WHERE d.bettype NOT IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))

	IF EXISTS (SELECT TOP(1) 1 
				FROM #transIdTemp t
					INNER JOIN dbo.bettrans14 b14 WITH (NOLOCK) ON b14.transid = t.transid
			)
	BEGIN
		INSERT INTO #TransInfo(
				matchid 
				,transid
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
				,recommend 
				,mrecommend 
				,srecommend 
				,statuswinlost 
				,IsMixParlay 
				,IsMoved14 
				,odds 
				,oddsspread 
				,oddstype 
				,betcheck 
				,stake 
				,CurrencyName 
				,Transdesc 
				,ExtraInfo 
				,BonusID 
				,winlost        
				,actual_stake 
				,Status
				,modds 
				,SiteDBGroupID
				,winlostdate
		)
		SELECT	z.matchid
				,z.transid
				,z.custid
				,z.transdate
				,z.checktime
				,z.hdp1
				,z.hdp2
				,z.livehomescore
				,z.liveawayscore
				,z.liveindicator
				,z.betteam
				,z.creator
				,z.refno	
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
				,0 AS IsMixParlay 
				,1 AS IsMoved14 
				,z.odds
				,b.oddsspread
				,b.oddstype
				,z.betcheck
				,z.stake
				,b.CurrencyName
				,b.transdesc
				,b.ExtraInfo
				,b.BonusID
				,z.winlost - b.actual_stake
				,b.actual_stake
				,z.STATUS	
				,b.modds
				,b.SiteDBGroupID
				,b.winlostdate
		FROM dbo.zzzbettrans z WITH (NOLOCK)
			INNER JOIN dbo.bettrans14 b WITH (NOLOCK) 
					ON b.transid = z.transid
						AND b.custid = z.custid
						AND b.matchid = z.matchid
						AND b.bettype = z.bettype 
		WHERE z.transid IN (SELECT s.transid FROM #transIdTemp s)
			AND b.betfrom <> 'p'
			AND z.SiteDBGroupID = @SiteDBGroupID AND b.SiteDBGroupID = z.SiteDBGroupID
			AND ISNULL(z.comstatus,'') <> 'CO'
			AND 1 = CASE WHEN b.bettype NOT IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1)) AND b.statuswinlost IS NULL THEN 0 ELSE 1 END --not support recover ticket single do not have statuswinlost in range 14

		--exclude main parlay with refno not exists in BetParlayResults & all combine not completed
		DELETE t
		FROM #TransInfo t
			OUTER APPLY (
					SELECT TOP 1 1 refno
					FROM dbo.BetParlayResult b WITH (NOLOCK)
					WHERE b.RefNo = t.refno
				)rs
		WHERE rs.refno IS NULL
			AND t.IsMoved14 = 1
			AND t.matchid IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))

		DELETE t
		FROM #TransInfo t
			CROSS APPLY (
					SELECT TOP 1 1 refno
					FROM dbo.BetParlayResult b WITH (NOLOCK)
					WHERE b.RefNo = t.refno
						AND b.statusid = 0
				)rs
		WHERE t.IsMoved14 = 1
			AND t.matchid IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))

		--Update Main MatchID for child match cricket (Sporttype = 50)
		UPDATE d
		SET d.matchid = m.ParentID
		FROM #TransInfo d
			INNER JOIN dbo.match14 m WITH (NOLOCK) ON d.matchid = m.matchid AND m.sporttype IN (50,8) AND m.ChildMatchType = 200
		WHERE d.bettype NOT IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))

	END
						
	--RETURN DATA
	SET @TransInfoJson = COMPRESS((SELECT matchid AS 'mid'
		,transid AS 't'
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
		,recommend AS 're'
		,mrecommend AS 'mre'
		,srecommend AS 'sre'
		,statuswinlost AS 'statuswl'
		,IsMixParlay AS 'isP'
		,IsMoved14 AS 'isM'
		,odds AS 'o'
		,oddsspread AS 'os'
		,oddstype AS 'ost'
		,betcheck AS 'bcheck'
		,stake AS 'stake'
		,CurrencyName AS 'curr'
		,Transdesc AS 'tdes'
		,ExtraInfo AS 'ex'
		,BonusID AS 'bo'
		,winlost    AS 'w'    
		,actual_stake AS 'acstake'
		,Status AS 's' 
		,modds AS 'm'
		,SiteDBGroupID AS 'sitedb'
		,winlostdate AS 'wld'
	FROM #TransInfo
	FOR JSON PATH))

	SELECT CONVERT(VARCHAR(MAX), @TransInfoJson, 1) AS TransInfoJson
	
	DROP TABLE #transIdTemp
	DROP TABLE #TransInfo
END

GO

