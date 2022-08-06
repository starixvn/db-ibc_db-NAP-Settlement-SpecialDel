/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_LastTime_Select]
(	
	@MatchId				INT
	,@FilterFromTransTime	DATETIME = NULL
	,@ActionId				INT = 5
	,@FilterBy				TINYINT = 0
	,@TransInfo		        XML = NULL
)
AS
/*	
	Created by: Max
	Date 20210616
	Task: [TVS] Wrong Score Enhancement 1 [Redmine: #140953]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20210616@Max: Create new SP [Redmine: #156349]
		- 20220208@Max: [TVS] Wrong Score Enhancement 3 [Redmine: #164561]
		- 20220808@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]

	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @LastTime  DATETIME

	CREATE TABLE #tmpTransInfo(
	   matchid INT
	  ,transid BIGINT PRIMARY KEY
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
		,t.c.value('@checkt','DATETIME') AS checktime
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
		,t.c.value('@s_checkt','DATETIME') AS Subchecktime
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
		,t.c.value('@wld', 'SMALLDATETIME') AS winlostdate
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

	SELECT @LastTime = (
					SELECT MAX(LastTime)
					FROM
					(
						SELECT MAX(CASE WHEN @FilterBy IN (1,4) THEN b.transdate 
										WHEN @FilterBy = 2 THEN ISNULL(b.checktime, b.transdate) END) AS LastTime
						FROM #tmpTransInfo b
							INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = b.bettype
						WHERE b.matchid = @MatchId AND b.IsMixParlay = 0
							AND 1 = CASE WHEN @FilterBy = 1 AND b.transdate > @FilterFromTransTime THEN 1
										WHEN @FilterBy = 2 AND ISNULL(b.checktime, b.transdate) > @FilterFromTransTime THEN 1
										WHEN @FilterBy = 4 AND ((b.checktime > @FilterFromTransTime) OR (b.transdate > @FilterFromTransTime)) THEN 1
									ELSE 0 END 
							AND 1 = CASE WHEN @ActionId <> 2 AND b.statusID NOT IN (101, 102, 103) THEN 1
									WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
								ELSE 0 END
							AND b.betfrom <> 'P'
							AND 1 = CASE WHEN b.livehomescore = 0 AND b.liveawayscore = 0 AND b.liveindicator = 0 AND f.GroupName <> '2H' THEN 0 ELSE 1 END

						UNION ALL
						SELECT MAX(CASE WHEN @FilterBy IN (1,4) THEN bm.Subtransdate 
										WHEN @FilterBy = 2 THEN ISNULL(bm.Subchecktime, bm.Subtransdate) END) AS LastTime
						FROM #tmpTransInfo bm
							INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = bm.bettype
						WHERE bm.matchid = @MatchId AND bm.IsMixParlay = 1
							AND 1 = CASE WHEN @FilterBy = 1 AND bm.transdate > @FilterFromTransTime THEN 1
										WHEN @FilterBy = 2 AND ISNULL(bm.checktime, bm.transdate) > @FilterFromTransTime THEN 1
										WHEN @FilterBy = 4 AND ((bm.checktime > @FilterFromTransTime) OR (bm.transdate > @FilterFromTransTime)) THEN 1
									ELSE 0 END 
							AND 1 = CASE WHEN @ActionId <> 2 AND bm.SubstatusID NOT IN (101, 102, 103) THEN 1
									WHEN @ActionId = 2 AND bm.SubstatusID NOT IN (101, 103) THEN 1
								ELSE 0 END
							AND bm.Subbetfrom <> 'P'
							AND bm.statusID NOT IN (102, 103)
							AND 1 = CASE WHEN bm.Sublivehomescore = 0 AND bm.Subliveawayscore = 0 AND bm.Subliveindicator = 0 AND f.GroupName <> '2H' THEN 0 ELSE 1 END
					)b
				)

	SELECT ISNULL(@LastTime, @FilterFromTransTime) AS LastTime

	DROP TABLE #tmpTransInfo
END
GO