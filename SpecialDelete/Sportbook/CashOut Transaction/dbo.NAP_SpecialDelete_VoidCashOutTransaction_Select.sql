/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_VoidCashOutTransaction_Select]
(
	@MatchId			INT				= 0
	,@Duration      	XML          	= NULL
	,@FilterBy			TINYINT 		= 0
)
AS
/*
    Created by: Kent
	Date: 20170323
	Original: 
	Task: Select Cash-out transaction for delete
	DB: DBTXN/BODB02

	Revisions:	
		- 20170403@Kent: Integrate Cash-out [Redmine:#72059]			
		- 20170417@Kent: Tune performance [Redmine:#72059]
		- 20190920@Charles: Add filter transdate when search by MatchId [120586]		
		- 20200930@Zane: TVS - Allow filter by Accept Time on Void Cash Out [Redmine:#142482]
		- 20210712@July: TVS - Modify the way to get move bet date [Redmine: #154974]
		- 20211213@Max: [TVS] Integrate new Cash Out model [Redmine: #165097]
		- 20220303@Max: [TVS] Update Virtual Setting when Cancel CO and some enhancements [Redmine: #169237]
		- 20220315@Max: Remove SABA of league name for China View sites [Redmine: #168651]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220727@Max: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]

	Explanation's Param:
		@Option: 0 - by MatchId
				 1 - by BetId(s) - removed
		@FilterBy:	0 - by Trans time
				 	1 - by Accepted time
*/
BEGIN	
	SET NOCOUNT ON
	
	CREATE TABLE #SpecialDeleteBets (	
		BetId				BIGINT,
		TransId				BIGINT,
		BetType				SMALLINT,
		BetTeam				NVARCHAR(10),
		Stake				MONEY,
		Odds				SMALLMONEY,
		OddsType			INT,
		WinLost				MONEY,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		Status				NVARCHAR(10),
		IsLiveIndicator		BIT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,		
		RefNo				BIGINT,				
		BetCheck			NVARCHAR(50),
		TransDesc			NVARCHAR(1000),
		UserName			VARCHAR(30),		
		TransDate			DATETIME,		
		ExtraInfo			VARCHAR(1000),
		BetdaqId			BIGINT,
		custid				INT,
		recommend			INT,
		betfrom				NVARCHAR(3),		
		HomeId				INT,
		AwayId				INT,
		LeagueId			INT,
		SportTypeId			SMALLINT,
		IsNeutral			BIT,
		MatchCode			NVARCHAR(50),
		EventDate			DATETIME,
		statuswinlost		TINYINT,
		ActualStake			MONEY,
		MatchId				INT,
		SiteDBGroupID		SMALLINT				
	)
	
	DECLARE @SiteDBGroupID	SMALLINT
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	CREATE TABLE #Durations (FromTransDate DATETIME, ToTransDate DATETIME)
	
    -- Only parse xml @Durations if @Duration is not null and is not empty
    IF ISNULL(DATALENGTH(@Duration), 5) <> 5
    BEGIN 
        INSERT INTO #Durations
               (FromTransDate,
                ToTransDate
               )
               SELECT x.value('@From', 'DATETIME') AS FromTransDate,
                      x.value('@To', 'DATETIME') AS ToTransDate
               FROM @Duration.nodes('TransDates/TransDate') XmlData(x) OPTION(OPTIMIZE FOR(@Duration = NULL));
    END;

	INSERT INTO #SpecialDeleteBets(
			BetId,
			TransId,
			BetType,
			BetTeam,
			Stake,
			Odds,
			OddsType,
			WinLost,
			Hdp1,
			Hdp2,
			Status,
			IsLiveIndicator,
			LiveHomeScore,
			LiveAwayScore,						
			RefNo,						
			BetCheck,
			TransDesc,
			UserName,						
			TransDate,						
			ExtraInfo,
			BetdaqId,
			custid,
			recommend,
			betfrom,						
			HomeId,
			AwayId,
			LeagueId,
			SportTypeId,
			IsNeutral,
			MatchCode,
			EventDate,
			statuswinlost,
			ActualStake,
			MatchId,
			SiteDBGroupID
		)
	SELECT 
			sub.BetId,
			sub.TransId,
			sub.BetType,
			sub.BetTeam,
			sub.Stake,
			sub.Odds,
			sub.OddsType,
			sub.WinLost - sub.Actual_Stake AS WinLost,
			sub.Hdp1,
			sub.Hdp2,
			sub.Status,
			sub.liveindicator AS IsLiveIndicator,
			sub.LiveHomeScore,
			sub.LiveAwayScore,				
			sub.RefNo,				
			sub.BetCheck,
			sub.TransDesc,
			sub.UserName,				
			sub.TransDate,				
			sub.ExtraInfo,
			sub.BetdaqId,
			sub.custid,
			sub.recommend,
			sub.betfrom,				
			m.HomeId,
			m.AwayId,
			m.LeagueId,
			m.sporttype AS SportTypeId,
			ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
			m.MatchCode,
			m.EventDate,
			sub.statuswinlost,
			sub.actual_stake AS ActualStake,
			@MatchId,
			sub.SiteDBGroupID
	FROM	dbo.bettrans sub WITH(NOLOCK)	
		INNER JOIN dbo.match m WITH(NOLOCK) ON m.matchid = sub.matchid
		INNER JOIN dbo.CashOutSelling c WITH (NOLOCK) ON c.TransID = sub.transid
	WHERE	sub.matchid = @MatchId 	
			AND sub.betdaqid = -2
			AND sub.statusID IN (103, 111, 112, 113)
			AND EXISTS (SELECT TOP (1) 1 FROM #Durations d
				WHERE 1 = CASE WHEN @FilterBy = 1 AND c.checktime BETWEEN d.FromTransDate AND d.ToTransDate THEN 1
							WHEN @FilterBy = 0 AND sub.transdate BETWEEN d.FromTransDate AND d.ToTransDate THEN 1
							ELSE 0 
							END)
			AND sub.SiteDBGroupID = @SiteDBGroupID
	
	SELECT	d.BetId,
			d.TransId,
			d.BetType,
			d.BetTeam,
			d.Stake,
			d.Odds,
			d.OddsType,
			d.WinLost,
			d.Hdp1,
			d.Hdp2,
			d.Status,
			d.IsLiveIndicator,
			d.LiveHomeScore,
			d.LiveAwayScore,			
			d.RefNo,						
			d.BetCheck,
			d.TransDesc,
			d.UserName,			
			d.TransDate,
			c.site AS GroupName,
			d.ExtraInfo,
			d.BetdaqId,			
			d.HomeId,
			d.AwayId,
			d.LeagueId,
			d.SportTypeId,
			d.IsNeutral,
			d.MatchCode,
			d.statuswinlost,
			d.ActualStake,
			d.MatchId,
			d.SiteDBGroupID
	FROM #SpecialDeleteBets d		 
		 INNER JOIN CUSTDB.dbo.Customer c WITH (NOLOCK)
				 ON d.recommend = c.custid		 	
	ORDER BY c.site ASC, d.TransId ASC							 						 
	
	DROP TABLE #SpecialDeleteBets
	DROP TABLE #Durations

	SET NOCOUNT OFF
END
GO
