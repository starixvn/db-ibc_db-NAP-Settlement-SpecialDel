/*<info serverAlias="DBTP-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: 20250325@Hughie
	Task: Enhance data history when updating events and results  [Redmine:#221187]
	DB: DBTP/bodb02
*/
/*----------------------------------------------------------------------------------------
								1. Match3rd_Tracking
----------------------------------------------------------------------------------------*/

CREATE TRIGGER [dbo].[Match3rd_Upd] ON [dbo].[Match3rd] 
AFTER UPDATE
AS
	SET NOCOUNT ON

	INSERT INTO dbo.Match3rd_Tracking (	
		Match3rdId
		,League3rdId
		,HomeId
		,AwayId
		,EventDate
		,SportType
		,VendorMatchId
		,MatchNo
		,EventStatus
		,CreateTime
		,UpdateTime
		,StartTime
		,MarketEndTime
		,BetStatus
		,EndTime
		,livehomescore
		,liveawayscore
		,hthomescore
		,htawayscore
		,finalhomescore
		,finalawayscore
		,matchcode
		,UpdateTimeHistory		
	)
	SELECT d.Match3rdId
			, d.League3rdId AS League3rdId
			, d.HomeId		AS HomeId
			, d.AwayId		AS AwayId
			, d.EventDate	AS EventDate
			, d.SportType	AS SportType
			, d.VendorMatchId AS VendorMatchId
			, d.MatchNo		AS MatchNo
			, d.EventStatus AS EventStatus
			, d.CreateTime	AS CreateTime
			, d.UpdateTime	AS UpdateTime
			, d.StartTime	AS StartTime
			, d.MarketEndTime AS MarketEndTime
			, d.BetStatus	AS BetStatus
			, d.EndTime		AS EndTime
			, d.livehomescore AS livehomescore
			, d.liveawayscore AS liveawayscore
			, d.hthomescore	AS hthomescore
			, d.htawayscore	AS htawayscore
			, d.finalhomescore AS finalhomescore
			, d.finalawayscore AS finalawayscore
			, d.matchcode AS matchcode
			, GETDATE() AS UpdateTimeHistory
	FROM INSERTED i
		INNER JOIN  DELETED d ON i.Match3rdId = d.Match3rdId

GO

/*----------------------------------------------------------------------------------------
								2. VSOutright_Tracking
----------------------------------------------------------------------------------------*/
CREATE TRIGGER [dbo].[VSOutright_Upd] ON [dbo].VSOutright 
AFTER UPDATE
AS
	SET NOCOUNT ON

	INSERT INTO dbo.VSOutright_Tracking (	
		Orid
		,EventID
		,RacerNum
		,IsFavor
		,EventDate
		,KickoffTime
		,RacerID
		,HumanID
		,WinOdds
		,PlaceOdds
		,Lane
		,MaxBet
		,DisplayMode
		,Placing
		,Colours
		,Creator
		,ChangeTime
		,EventStatus
		,UpdateTime		
	)
	SELECT d.Orid AS Orid
			, d.EventID		AS EventID
			, d.RacerNum	AS RacerNum
			, d.IsFavor		AS IsFavor
			, d.EventDate	AS EventDate
			, d.KickoffTime	AS KickoffTime
			, d.RacerID		AS RacerID
			, d.HumanID		AS HumanID
			, d.WinOdds		AS WinOdds
			, d.PlaceOdds	AS PlaceOdds
			, d.Lane		AS Lane
			, d.MaxBet		AS MaxBet
			, d.DisplayMode	AS DisplayMode
			, d.Placing		AS Placing
			, d.Colours		AS Colours
			, d.Creator		AS Creator
			, d.ChangeTime	AS ChangeTime
			, d.EventStatus	AS EventStatus
			, GETDATE() AS UpdateTime
	FROM INSERTED i
		INNER JOIN  DELETED d ON i.Orid = d.Orid

GO

/*----------------------------------------------------------------------------------------
								3. VSRaceInfo_Tracking
----------------------------------------------------------------------------------------*/
CREATE TRIGGER [dbo].[VSRaceInfo_Upd] ON [dbo].VSRaceInfo 
AFTER UPDATE
AS
	SET NOCOUNT ON

	INSERT INTO dbo.VSRaceInfo_Tracking (	
		EventTime
		,LeagueID
		,PayOut
		,EachWay
		,CourseName
		,TrackType
		,Distance
		,Racers
		,ForeCastPayout
		,TriCastPayout
		,CreateDate
		,Calculate
		,SportType
		,ChangeTime
		,BetStatus
		,EventStatus
		,VendorMatchId
		,EventID
		,UpdateTime	
	)
	SELECT d.EventTime			AS EventTime
			, d.LeagueID		AS LeagueID
			, d.PayOut			AS PayOut
			, d.EachWay			AS EachWay
			, d.CourseName		AS CourseName
			, d.TrackType		AS TrackType
			, d.Distance		AS Distance
			, d.Racers			AS Racers
			, d.ForeCastPayout	AS ForeCastPayout
			, d.TriCastPayout	AS TriCastPayout
			, d.CreateDate		AS CreateDate
			, d.Calculate		AS Calculate
			, d.SportType		AS SportType
			, d.ChangeTime		AS ChangeTime
			, d.BetStatus		AS BetStatus
			, d.EventStatus		AS EventStatus
			, d.VendorMatchId	AS VendorMatchId
			, d.EventID
			, GETDATE() AS UpdateTime
	FROM INSERTED i
		INNER JOIN  DELETED d ON i.EventID = d.EventID

GO