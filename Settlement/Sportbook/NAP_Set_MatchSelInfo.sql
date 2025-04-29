/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchSelInfo]
	@matchid 			   INT = 0
	,@matchIds	VARCHAR(MAX) = NULL

AS
/*
    Created by: 20180802@Vicky
    Task: Info of match
    DB: DBPRO/BODB02 
    
    Revisions:            
		- 20180801@Vicky: Incorporate eSports 2.0 [Redmine #95874]
		- 20200210@Sol: Settlement with Ticket Exclusion for Other Sports - Tennis - [Redmine:#129316]
		- 20200703@Kathy: Incorporate New Bet Types of Basketball - Phase 2 [Redmine:#135846]
		- 20210611@Louisa: Beach Volleyball [Redmine:#156541]
		- 20210930@Louisa: Move running ticket to new match for E-Sports [Redmine:#159271]
		- 20211118@Louisa: EventStatusReason for soccer only [Redmine:#164408]
		- 20220126@Kathy: Settlement - Incorporate Saba Basketball PinGoal [Redmine:#167926]
		- 20210107@Louisa: E-Sports Phase 4 [Redmine:#166330]
		- 20220509@Kathy: Change to use STRING_SPLIT [Redmine:#172461]
		- 20230404@Louisa: Get data for JackTime [Redmine:#184764]
		- 20230406@Aries: Un-calculate FT Only [Redmine: #146737]
		- 20230404@Kathy: Merge single and parlay [Redmine:#175202]
		- 20230515@Aries: Apply Settle Determined for Basketball [Redmine:#175202]
		- 20231002@Aries: Apply Auto Payout for Cricket by using TheSports Provider  [Redmine: #195768]
		- 20231002@Louisa: Integrate sporttype 58-Bandy [Redmine: #196041]
		- 20240122@Aries: Provider Result Log [Redmine:#199100]
		- 20240229@Aries: Auto Payout for e-Sports Main ＆ Early Results  [Redmine: #191875]
		- 20240412@Aries: Direct Payout for Virtual Kabaddi [Redmine:#203590]
		- 20270327@Aries: Support the Super Tiebreak match in Tennis  [Redmine: #202531]
		- 20240605@Louisa:Notify if not yet refund [Redmine:#204909] 
		- 20240910@Aries:Return IsTest [Redmine:#204909] 
		- 20250326@Aries: Support AutoPayout2 for Ice Hockey [Redmine:#219397]
		- 20250429@Louisa: Enhance sql plan [Redmine:#225892]
*/ 
BEGIN
	SET NOCOUNT ON

	DECLARE @tmpMatchInfo TABLE (
		 matchId	INT
        ,matchcode	NVARCHAR(100)
		,eventdate	DATETIME
        ,kickofftime DATETIME
        ,playtime	INT
        ,homeid		INT
        ,awayid		INT
        ,leagueId	INT
        ,BestOfMap	TINYINT
		,betstatus	NVARCHAR(100)
		,isHalftimeCal	BIT
		,sporttype	SMALLINT
		,eventstatus NVARCHAR(100)
		,ConfirmFT	INT
		,SettlementStatus	TINYINT
		,EventStatusReason	TINYINT
		,LeagueGroupId	SMALLINT
		,GameType	TINYINT ---for E-sports
		,ParentID	INT
		,GoalRecord VARCHAR(50)
		,AutoSetting TINYINT
		,GameSession TINYINT
		,LeagueType TINYINT
		,OverTimeSession	TINYINT
		,hthomescore		INT
		,htawayscore		INT
		,finalhomescore		INT
		,finalawayscore		INT
		,ChildMatchType		TINYINT
		,SessionTime FLOAT
		,isTest BIT
		,ChildLeagueType INT
		)
	
	IF ISNULL(@matchIds,'') <> ''
	BEGIN
		INSERT INTO @tmpMatchInfo (
			 matchId
			,matchcode
			,eventdate
			,kickofftime
			,homeid
			,awayid
			,leagueId
			,betstatus
			,sporttype
			,eventstatus
			,SettlementStatus
			,EventStatusReason
			,LeagueGroupId
			,GameType
			,ParentID
			,GoalRecord
			,AutoSetting
			,GameSession
			,LeagueType
			,OverTimeSession
			,hthomescore	
			,htawayscore
			,finalhomescore
			,finalawayscore
			,ChildMatchType
			,SessionTime
			,isTest
			,ChildLeagueType
		)
		SELECT  m.matchId
			,m.matchcode
			,m.eventdate
			,m.kickofftime
			,m.homeid
			,m.awayid
			,m.leagueId
			,m.betstatus
			,m.sporttype
			,m.eventstatus
			,m.SettlementStatus
			,m.EventStatusReason
			,l.LeagueGroupID
			,l.OverTimeSession
			,m.ParentID
			,m.goalrecord
			,ISNULL(m.AutoSetting, l.AutoSetting)	
			,l.GameSession
			,ls.LeagueType
			,l.OverTimeSession
			,m.hthomescore	
			,m.htawayscore
			,m.finalhomescore
			,m.finalawayscore
			,m.ChildMatchType
			,l.SessionTime
			,ISNULL(l.isTest,0)
			,ls.ChildLeagueType
		 FROM dbo.[match] m WITH (NOLOCK)
			INNER JOIN dbo.League l WITH(NOLOCK)
				ON m.leagueid = l.leagueid
			LEFT JOIN dbo.LeagueSetting ls WITH(NOLOCK)
				ON l.leagueid = ls.Leagueid
		WHERE EXISTS ( SELECT TOP 1 value FROM STRING_SPLIT(@matchIds, ',') f WHERE CAST(f.value AS INT) = m.matchid  )

	END

	ELSE 
	INSERT INTO @tmpMatchInfo (
		 matchId	
		,matchcode	
		,eventdate
		,kickofftime
		,playtime	
		,homeid		
		,awayid		
		,leagueId	
		,BestOfMap	
		,betstatus	
		,isHalftimeCal
		,sporttype	
		,eventstatus
		,ConfirmFT
		,SettlementStatus
		,EventStatusReason
		,LeagueGroupId
		,GameType
		,ParentID
		,GoalRecord
		,AutoSetting
		,GameSession
		,LeagueType
		,OverTimeSession
		,hthomescore	
		,htawayscore
		,finalhomescore
		,finalawayscore
		,ChildMatchType
		,SessionTime
		,isTest
		,ChildLeagueType
	)   
	SELECT m.matchId
        ,m.matchcode
		,m.eventdate
        ,m.kickofftime
        ,datediff(minute, kickofftime, CURRENT_TIMESTAMP) playtime
        ,m.homeid
        ,m.awayid
        ,m.leagueId
        ,mr.BestOfMap
		,m.betstatus
		,mr.IsHTCal AS isHalftimeCal
		,m.sporttype
		,m.eventstatus
		,mr.ConfirmFT
		,m.SettlementStatus
		,m.EventStatusReason
		,l.LeagueGroupID
		,l.OverTimeSession
		,m.ParentID
		,m.GoalRecord
		,ISNULL(m.AutoSetting, l.AutoSetting)
		,l.GameSession
		,ls.LeagueType
		,l.OverTimeSession
		,m.hthomescore	
		,m.htawayscore
		,m.finalhomescore
		,m.finalawayscore
		,m.ChildMatchType
		,l.SessionTime
		,ISNULL(l.isTest,0)
		,ls.ChildLeagueType
     FROM dbo.[match] m WITH (NOLOCK)
		INNER JOIN dbo.League l WITH(NOLOCK)
				ON m.leagueid = l.leagueid
		LEFT JOIN dbo.LeagueSetting ls WITH(NOLOCK)
			ON l.leagueid = ls.Leagueid
     	INNER JOIN dbo.[match_remark] mr WITH (NOLOCK) ON mr.matchid = m.matchid
     WHERE m.matchid = @matchid


	 SELECT matchId	
		,matchcode	
		,ParentId
		,eventdate
		,kickofftime
		,playtime	
		,homeid		
		,awayid		
		,leagueId	
		,BestOfMap	
		,betstatus	
		,isHalftimeCal
		,sporttype	
		,eventstatus
		,ConfirmFT
		,SettlementStatus
		,EventStatusReason
		,LeagueGroupId
		,GameType
		,ParentID
		,GoalRecord
		,AutoSetting
		,GameSession
		,LeagueType
		,OverTimeSession
		,hthomescore AS HalfTimeHomeScore	
		,htawayscore AS HalfTimeAwayScore
		,FinalHomeScore
		,FinalAwayScore
		,ChildMatchType
		,SessionTime
		,isTest
		,ChildLeagueType
	FROM @tmpMatchInfo

END
GO
