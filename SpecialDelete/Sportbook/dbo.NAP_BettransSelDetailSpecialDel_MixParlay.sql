/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BettransSelDetailSpecialDel_MixParlay]  
	@Refno BIGINT
AS  
/*  
	Created by: Kathy
	Date: 20131009
	Task: Get tickets of mix parlay by Refno 
	DB:  DBTXN/BODB02
	Original:   
   
	Revisions:   
		- 20141125@Kathy: Add betcheck column [Redmine:#26489]
		- 20150119@Kathy: Changes for phase 1.2 of PH All in One: add transdesc column [Redmine:#50932]	
		- 20160420@Kathy: Combo parlay - add stake column [Redmine:#55272]
		- 20160915@Kent: Combine logic of [NAP_BettransSpecialDelBetID_Sel_ParlayDetail] [Redmine:#63202]  					  
		- 20160930@Kathy: Get detail tickets of Sportbook only [Redmine:#64703]
		- 20170530@Kent: Integrate Betradar Virtual Sports [Redmine:#77177]
		- 20201105@Charles:  LSports Integration Football & Baseball [Redmine: #144544]
		- 20210315@July: Integrate Cricket AIO - [Redmine: #150075]
		- 20220816@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20240304@July: [TVS] Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]

	Param's Explanation:
			

*/  
BEGIN
	SET NOCOUNT ON	
	DECLARE @SiteDBGroupID SMALLINT = 0 
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	DECLARE @BetListMP TABLE (
		TransID			BIGINT
		,Bettype		INT
		,HomeID			INT
		,AwayID			INT
		,hdp1			SMALLMONEY
		,hdp2			SMALLMONEY
		,Odds			SMALLMONEY
		,Betteam		NVARCHAR(20)
		,statusid		INT
		,Livehomescore	SMALLINT
		,Liveawayscore	SMALLINT
		,Liveindicator	BIT
		,LeagueID		INT
		,Sporttype		SMALLINT
		,isNeutral		BIT
		,matchid		INT
		,matchcode		NVARCHAR(50)
		,Stake			MONEY
		,betcheck		NVARCHAR(50)
		,transdesc		NVARCHAR(1000)
		,showtime		NVARCHAR(50)
		,transdate		DATETIME		
		)			
		
	INSERT INTO @BetListMP	
		(
			TransID
			,Bettype
			,HomeID
			,AwayID
			,hdp1
			,hdp2
			,Odds
			,Betteam
			,statusid
			,Livehomescore
			,Liveawayscore
			,Liveindicator
			,LeagueID
			,Sporttype
			,isNeutral
			,matchid
			,matchcode
			,Stake
			,betcheck
			,transdesc
			,showtime
			,transdate			
		)				
	SELECT
			b.transid		
			,b.bettype
			,m.homeid
			,m.awayid
			,b.hdp1
			,b.hdp2 
			,b.odds
			,b.betteam
			,b.statusid
			,b.livehomescore
			,b.liveawayscore 
			,b.liveindicator 
			,m.leagueid
			,m.sporttype
			,m.isNeutral as IsNeutral
			,m.matchid
			,m.matchcode	
			,b.stake AS Stake		
			,b.betcheck
			,b.transdesc
			,ISNULL(CONVERT(NVARCHAR(20), m.kickofftime, 113), '') AS showtime
			,b.transdate					
	FROM	dbo.BettransM AS b WITH(NOLOCK)		
		INNER JOIN match AS m WITH(NOLOCK)
			ON	b.matchid=m.matchid
				AND refno=@refno										
	WHERE	(m.sporttype BETWEEN 1 AND 99
			OR m.sporttype BETWEEN 190 AND 199
			OR m.sporttype = 188 --VS4
			)
			AND b.SiteDBGroupID = @SiteDBGroupID
	ORDER BY CASE WHEN m.sporttype = 50 AND m.ChildMatchType = 200 AND m.ParentID IS NOT NULL THEN 1 ELSE 2 END
		
	IF EXISTS (
			SELECT	TOP 1 1
			FROM	bettransm14 WITH (NOLOCK)
			WHERE	refno = @refno AND SiteDBGroupID = @SiteDBGroupID
			)
	BEGIN
		INSERT INTO @BetListMP	
			(
				TransID
				,Bettype
				,HomeID
				,AwayID
				,hdp1
				,hdp2
				,Odds
				,Betteam
				,statusid
				,Livehomescore
				,Liveawayscore
				,Liveindicator
				,LeagueID
				,Sporttype
				,isNeutral
				,matchid
				,matchcode
				,Stake
				,betcheck
				,transdesc
				,showtime
				,transdate				
			)				
		SELECT
				b.transid		
				,b.bettype
				,m.homeid
				,m.awayid
				,b.hdp1 
				,b.hdp2 
				,b.odds
				,b.betteam
				,b.statusid
				,b.livehomescore
				,b.liveawayscore 
				,b.liveindicator 
				,m.leagueid
				,m.sporttype
				,m.isNeutral as IsNeutral
				,m.matchid
				,m.matchcode	
				,b.stake AS Stake		
				,b.betcheck
				,b.transdesc
				,ISNULL(CONVERT(NVARCHAR(20), m.kickofftime, 113), '') AS showtime
				,b.transdate						
		FROM	dbo.BettransM14 AS b WITH(NOLOCK)		
			INNER JOIN match14 AS m WITH(NOLOCK)
				ON	b.matchid=m.matchid
					AND refno=@refno								
		WHERE	(m.sporttype BETWEEN 1 AND 99
				OR m.sporttype BETWEEN 190 AND 199
				OR m.sporttype = 188 --VS4
				)
			AND b.SiteDBGroupID = @SiteDBGroupID
		ORDER BY CASE WHEN m.sporttype = 50 AND m.ChildMatchType = 200 AND m.ParentID IS NOT NULL THEN 1 ELSE 2 END
	END	

	SELECT TransID
		  ,Bettype
		  ,HomeID
		  ,AwayID
		  ,hdp1
		  ,hdp2
		  ,Odds
		  ,Betteam
		  ,statusid
		  ,Livehomescore
		  ,Liveawayscore
		  ,Liveindicator
		  ,LeagueID
		  ,Sporttype
		  ,isNeutral
		  ,matchid
		  ,matchcode
		  ,Stake
		  ,betcheck
		  ,transdesc
		  ,showtime
		  ,transdate		
	FROM @BetListMP	
	
END
GO