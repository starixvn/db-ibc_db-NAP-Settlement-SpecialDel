/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Nap_SpecialDelete_AllMarkedTicketsDetail_Select]
	@MatchId		INT,
	@UserId			INT,
	@CreatedDate	DATETIME
AS
/*
    Created by: Alan
	Date: 20190325
	Task: Mark Ticket for Settlement Exclusion
	DB: DBTXN/BODB02

	Revisions:
		- 20190325@Alan: - Mark Ticket for Settlement Exclusion [108826]
		- 20190426@Jacob: Mark Tickets - Enhancement [112480]
		- 20190812@Charles: Add new column IsMarked [118437]
		- 20191101@Charles: Remove column IsMarked [122187]
		- 20201604@Charles: Implement parlay tickets for Mark ticket [131670]
		- 20201105@Charles: Fix show liveindicator for subparlay [143091]
		- 20210707@Max: [TVS] Tuning SP mark/unmark tickets [Redmine: #157930]
		- 20211214@July: Remove code CashOut [Redmine: #165097]
		- 20220829@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20230220@Max: [TVS] Change of TVS regarding to Scale out DBTrans for Credit - Split 789y Site [Redmine: #182803]

	Explanation's Param:
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @SiteDBGroupID		SMALLINT = 0
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	CREATE TABLE #Tickets
             (GroupID         BIGINT,
              transid         BIGINT,
              custid          INT,
              username        VARCHAR(50),
              oddsspread      MONEY,
              odds            SMALLMONEY,
              OddsType        INT,
              transdate       DATETIME,
              bettype         SMALLINT,
              betteam         NVARCHAR(10),
              betcheck        NVARCHAR(50),
              hdp1            SMALLMONEY,
              hdp2            SMALLMONEY,
              IsLiveIndicator BIT,
              livehomescore   SMALLINT,
              liveawayscore   SMALLINT,
              Stake           MONEY,
              CurrencyName    VARCHAR(10),
              status          NVARCHAR(10),
              srecommend      INT,
              recommend       INT,
              SecAcceptFlag   BIT,
              betid           BIGINT,
              betdaqid        BIGINT,
              TransDesc       NVARCHAR(1000),
              refno           BIGINT,
              ExtraInfo       VARCHAR(1000),
			  matchid         INT,
              WalletType      TINYINT,
              RefCode         BIGINT,
              BonusID         INT,
              MainTransId     BIGINT,
              WinLost         MONEY,
			  IsMixParlay     BIT DEFAULT(0),
			  SubTransId      BIGINT,
              SubStatus       NVARCHAR(10),
              SubBetCheck     NVARCHAR(50),
              SubBetTeam      NVARCHAR(10),
              SubBetType      SMALLINT DEFAULT(0),
              SubHdp1         SMALLMONEY,
              SubHdp2         SMALLMONEY,
              SubOdds         SMALLMONEY
             );
	-- get single tickets
	INSERT INTO #Tickets (
			GroupID
			,bettype
			,transid
			,betid
			,refno
			,hdp1
			,hdp2
			,odds
			,oddsspread	
			,OddsType
			,STATUS	
			,stake
			,transdate
			,betteam
			,betcheck
			,IsLiveIndicator
			,custid	
			,livehomescore
			,liveawayscore
			,matchid
			,winlost
			,TransDesc
			,betdaqid
			,username
			,srecommend
			,recommend
			,ExtraInfo
			,CurrencyName
			,WalletType
			,RefCode
			,BonusID
		)
		SELECT
			b.transid AS GroupId
			,b.bettype
			,b.transid
			,isnull(b.BetID, 0) AS BetID
			,b.refno
			,b.hdp1
			,b.hdp2
			,b.odds
			,b.oddsspread
			,b.OddsType
			,CASE WHEN b.STATUS = 'running'
					AND IsNull(b.SecAcceptFlag, 0) = 1
					AND IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.STATUS END AS STATUS
			,b.stake
			,b.transdate
			,b.betteam
			,b.betcheck
			,b.liveindicator
			,b.custid
			,b.livehomescore
			,b.liveawayscore
			,b.matchid
			,(b.winlost - b.actual_stake) winlost
			,b.transdesc
			,b.betdaqid
			,b.username
			,b.srecommend
			,b.recommend
			,b.ExtraInfo
			,b.CurrencyName
			,b.WalletType
			,b.RefCode
			,b.BonusID
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON m.TransId = b.transid
		WHERE b.statusID IN (0, 1) -- running, waiting
		AND b.MatchId = @MatchId 
		AND m.UserId = @UserId
		AND m.CreatedDate = @CreatedDate
		AND b.SiteDBGroupID = @SiteDBGroupID

	-- get subparlay tickets
	INSERT INTO #Tickets (
			GroupID
			,bettype
			,transid
			,betid
			,refno
			,hdp1
			,hdp2
			,odds
			,oddsspread	
			,OddsType
			,STATUS	
			,stake
			,transdate
			,betteam
			,betcheck
			,IsLiveIndicator
			,custid	
			,livehomescore
			,liveawayscore
			,matchid
			,winlost
			,TransDesc
			,betdaqid
			,username
			,srecommend
			,recommend
			,ExtraInfo
			,CurrencyName
			,IsMixParlay
			,SubTransId
			,SubStatus
			,SubBetCheck
			,SubBetTeam
			,SubBetType
			,SubHdp1
			,SubHdp2
			,SubOdds
		)
		SELECT
			b.transid AS GroupId
			,b.bettype
			,b.transid
			,isnull(b.BetID, 0) AS BetID
			,bm.refno
			,b.hdp1
			,b.hdp2
			,b.odds
			,bm.oddsspread
			,b.OddsType
			,CASE WHEN b.STATUS = 'running'
					AND IsNull(b.SecAcceptFlag, 0) = 1
					AND IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.STATUS END AS STATUS
			,b.stake
			,bm.transdate
			,b.betteam
			,b.betcheck
			,bm.liveindicator
			,bm.custid
			,bm.livehomescore
			,bm.liveawayscore
			,bm.matchid
			,(b.winlost - b.actual_stake) winlost
			,bm.transdesc
			,b.betdaqid
			,b.username
			,b.srecommend
			,b.recommend
			,b.ExtraInfo
			,b.CurrencyName
			,1 AS IsMixParlay
			,bm.transid AS SubTransId
			,bm.status AS SubStatus
			,bm.betcheck AS SubBetCheck
			,bm.betteam AS SubBetTeam
			,bm.bettype AS SubBetType
			,bm.hdp1 AS SubHdp1
			,bm.hdp2 AS SubHdp2
			,bm.odds As SubOdds
		FROM dbo.bettransm AS bm WITH (NOLOCK)
			INNER HASH JOIN dbo.bettrans AS b with (NOLOCK) ON b.matchid = 29 AND b.bettype = 29 AND bm.refno = b.refno
			INNER JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON m.TransId = b.transid AND m.MatchId = @MatchId
		WHERE bm.statusID IN (0, 1) -- running, waiting
		AND bm.matchid = @MatchId
		AND m.UserId = @UserId
		AND m.CreatedDate = @CreatedDate
		AND bm.SiteDBGroupID = @SiteDBGroupID AND b.SiteDBGroupID = bm.SiteDBGroupID
	
	UPDATE sub
	SET MainTransId = main.transid
	FROM #Tickets main
			INNER JOIN #Tickets sub
					ON main.RefCode = sub.RefCode	
					AND main.transid <> sub.transid					
					AND main.custid = sub.custid
					AND main.matchid = sub.matchid
					AND main.bettype = sub.bettype											
	WHERE main.WalletType = 1		

	-- Group Name By Licensee
	BEGIN
		DECLARE @MBCGroup_Name VARCHAR(50) = 'MBC Group'
			  , @789y_Name	   VARCHAR(50) = '789y'
			  , @y987_Name	   VARCHAR(50) = 'y987'
			  , @cn88_Name		VARCHAR(50) = 'CN88'
		CREATE TABLE #t_LicenseeNames(LicenseeName VARCHAR(100), GroupName VARCHAR(100))
		CREATE CLUSTERED INDEX t_IDX_LicenseeNames_LicenseeName ON #t_LicenseeNames(LicenseeName)
		CREATE TABLE #t_UIRepresentativeLicenseeGroupNames(GroupName VARCHAR(100))

		INSERT INTO #t_LicenseeNames(LicenseeName, GroupName)
		SELECT	s.site AS LicenseeName,  s.site AS GroupName 
		FROM	DBCUST.CUSTDB.dbo.site s WITH(NOLOCK)
		WHERE	s.isLicensee = 1 AND s.isActive =1 AND s.siteID NOT IN (29,35)

		INSERT INTO #t_UIRepresentativeLicenseeGroupNames(GroupName)
		VALUES (@MBCGroup_Name), (@789y_Name), (@cn88_Name)

		;WITH CTE_CreditSit AS
		(
			SELECT [site], ISNULL(SiteLabel,'') AS SiteLabel
			FROM DBCUST.CUSTDB.dbo.Site WITH(NOLOCK) 
			WHERE isLicensee = 0 AND isActive = 1
		)
		INSERT INTO #t_LicenseeNames(LicenseeName, GroupName)
		SELECT cte.[site] AS LicenseeName, t.GroupName
		FROM #t_UIRepresentativeLicenseeGroupNames AS t
			 CROSS APPLY (
							SELECT cte.[site]
							FROM CTE_CreditSit cte
							WHERE CASE
								WHEN t.GroupName = @MBCGroup_Name AND cte.[site] NOT IN (@789y_Name, @y987_Name, @cn88_Name) AND cte.SiteLabel <> @789y_Name THEN 1
								WHEN t.GroupName = @789y_Name AND cte.SiteLabel = @789y_Name THEN 1
								WHEN t.GroupName = @cn88_Name AND cte.[site] IN (@cn88_Name) THEN 1 ELSE 0  
								END = 1
						 ) AS cte
	END

	SELECT 
		b.Stake,
		b.BetCheck,
		b.BetId,
		b.BetTeam,
		b.BetType,
		b.CurrencyName,
		b.Hdp1,
		b.Hdp2,
		b.IsLiveIndicator,
		b.LiveAwayScore,
		b.LiveHomeScore,
		b.Odds,
		b.oddsspread,
		b.OddsType,
		b.RefNo,
		b.Status,
		b.TransDate,
		b.TransDesc,
		b.TransId,
		b.UserName,
		b.WinLost,
		CASE 
		  WHEN b.recommend IN (52466, 5707545) THEN '8RM/BARM' 
		  WHEN b.custid IN(1077687,2331,115770,15523642,15042477,16041068,16041058) THEN 'Betfair' 
		  ELSE tl.GroupName
		END GroupName,
		b.betdaqid,
		b.ExtraInfo,
		b.WalletType,
		b.MainTransId,
		b.RefCode,
		m.homeid,
		m.awayid,
		m.leagueid,
		m.IsNeutral,
		m.sporttype,
		m.SettlementStatus,
		c.site AS LicenseeName,
		CASE WHEN tl.GroupName IN(@cn88_Name, @789y_Name, @MBCGroup_Name) THEN 0 ELSE 1 END AS IsDeposit,
		b.IsMixParlay,
		b.SubTransid,
		b.SubStatus,
		b.SubBetcheck,
		b.SubBetteam,
		b.SubBettype,
		b.SubHdp1,
		b.SubHdp2,
		b.SubOdds,
		@SiteDBGroupID AS SiteDBGroupID
	FROM #Tickets b
		INNER JOIN CUSTDB.dbo.Customer c WITH (NOLOCK) ON b.recommend = c.custid
		INNER JOIN #t_LicenseeNames tl WITH (NOLOCK) ON tl.LicenseeName = c.site 
		LEFT JOIN match m WITH (NOLOCK) ON b.matchid = m.matchid
		CROSS APPLY (SELECT CASE
						WHEN EXISTS (SELECT d.custid 
										FROM CustDB.dbo.Dep_CustSuper d WITH(NOLOCK) 
										WHERE d.custid = b.srecommend)
								THEN 1
						ELSE 0
					END AS IsDeposit) AS T1
	ORDER BY CASE
				WHEN b.recommend IN (52466, 5707545) THEN 1
				WHEN b.custid IN(1077687,2331,115770,15523642,15042477,16041068,16041058) THEN 2
				WHEN tl.GroupName = @cn88_Name THEN 3
				WHEN tl.GroupName = @789y_Name THEN 4
				WHEN tl.GroupName = @MBCGroup_Name THEN 5
				ELSE 6
		     END ASC
		   , tl.GroupName ASC
		   , ISNULL(b.MainTransId, b.transid) ASC
		   , CASE WHEN b.BonusID IS NOT NULL
				THEN CASE WHEN b.MainTransId IS NULL THEN 1
				ELSE 2 END ELSE b.transid END

				
	DROP TABLE #Tickets
	DROP TABLE #t_LicenseeNames
	DROP TABLE #t_UIRepresentativeLicenseeGroupNames

	SET NOCOUNT OFF
END
GO
