/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchGetResultDetail]
	@MatchID	INT 
AS
/*
	Created by: Jamie  
	Date: 2014-1114
	Task: Match results - Get info match in detail   
	DB: DBPRO/BODB02  

	Revisions:  	
		- 20150406@Jamie: Settlement Betradar phase 2 [Redmine: #27212]
		- 20170209@Bobby: Add filtering Abandoned status [Redmine: #71284]
		- 20170525@Kathy: Show all results of Basketball  [Redmine:#77046]
		- 20170920@Kathy: Allow user to view result of matches stored in match14 [Redmine:#83261]
		- 20181002@Kathy: Add New Status "Result Pending" and "Under Settlement" [Redmine:#102028]
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @Sporttype SMALLINT
	
	SELECT	 m.MatchID
			,m.matchcode
			,m.sporttype
			,m.leagueid
			,m.homeid
			,m.awayid
			,m.kickofftime
			,m.hthomescore
			,m.htawayscore
			,m.finalhomescore
			,m.finalawayscore
			,m.eventstatus
			,m.betstatus
			,m.GoalRecord
			,ISNULL(mr.IsHTCal, 0) AS IsHTCal
			,ISNULL(mr.calculate, 0) AS calculate
			,ISNULL(m.SettlementStatus, 0) AS SettlementStatus
	FROM(
		SELECT	m.matchid, m.matchcode, m.sporttype, m.leagueid, m.homeid, m.awayid, m.kickofftime
				,m.hthomescore, m.htawayscore, m.finalhomescore, m.finalawayscore
				,m.eventstatus, m.betstatus, m.GoalRecord, m.SettlementStatus
		FROM	dbo.Match m WITH (NOLOCK)
		WHERE	m.matchid = @MatchId
		UNION ALL
		SELECT	m.matchid, m.matchcode, m.sporttype, m.leagueid, m.homeid, m.awayid, m.kickofftime
				,m.hthomescore, m.htawayscore, m.finalhomescore, m.finalawayscore
				,m.eventstatus, m.betstatus, m.GoalRecord, 0 AS SettlementStatus
		FROM	dbo.match14 m WITH(NOLOCK)
		WHERE	m.matchid = @MatchId
	) m
		LEFT JOIN dbo.match_remark mr WITH (NOLOCK) ON m.MatchID = mr.MatchID  
	
	SELECT 	@Sporttype = sporttype
	FROM 	dbo.Match WITH (NOLOCK)
	WHERE 	matchId = @MatchId
	
	IF @@rowcount = 0
	BEGIN
		SELECT	@Sporttype = sporttype
		FROM	dbo.match14 WITH(NOLOCK)
		WHERE	matchid = @MatchId
	END

	SELECT	 MatchId
			,ResourceID 
			,HomeValue 
			,AwayValue 
			,OtherInfo
			,CASE 
				WHEN @Sporttype = 2 AND SettlementStatusID = 0 THEN 4
				ELSE SettlementStatusID
			END AS SettlementStatusID
	FROM(
		SELECT	MatchId, ResourceId, HomeValue, AwayValue, OtherInfo, SettlementStatusID, ResultStatusID
		FROM	dbo.[ResultDetail] WITH (NOLOCK) 
		WHERE	MatchID = @MatchID 
		UNION ALL
		SELECT	MatchId, ResourceId, HomeValue, AwayValue, OtherInfo, SettlementStatusID, ResultStatusID
		FROM	dbo.[ResultDetail14] WITH (NOLOCK) 
		WHERE	MatchID = @MatchID 
	) r
	WHERE	1 = CASE
					WHEN @Sporttype = 2 THEN CASE 
												WHEN LEN(ResourceId) = 2 THEN 1
												WHEN SettlementStatusID > 0 THEN 1
												WHEN HomeValue IS NOT NULL OR AwayValue IS NOT NULL THEN 1
												ELSE 0
											END
					ELSE CASE WHEN ResultStatusID > 0 THEN 1 ELSE 0 END
				END				
	ORDER BY ResourceID 
END
GO