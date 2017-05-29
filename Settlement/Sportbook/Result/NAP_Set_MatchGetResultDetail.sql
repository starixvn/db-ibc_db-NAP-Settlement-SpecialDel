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
			,CASE 
				WHEN m.betstatus LIKE 'Refund FT%' THEN 'Refund FT'
				WHEN m.betstatus LIKE 'Refund HT%' THEN 'Refund HT'
				WHEN m.betstatus LIKE 'Refund%' THEN 'Refund'
				WHEN m.betstatus LIKE 'Abandoned 1H%' THEN 'Abandoned 1H'
				WHEN m.betstatus LIKE 'Abandoned 2H%' THEN 'Abandoned 2H'
				ELSE m.eventstatus
			END AS eventstatus
			,m.betstatus
			,m.GoalRecord
			,ISNULL(mr.IsHTCal, 0) AS IsHTCal
			,ISNULL(mr.calculate, 0) AS calculate
			,ISNULL(mr.isPending, 0) AS isPending
	FROM	dbo.Match m WITH (NOLOCK)
			LEFT JOIN dbo.match_remark mr WITH (NOLOCK) ON m.MatchID = mr.MatchID 
	WHERE	m.MatchID = @MatchID 
	
	SELECT 	@Sporttype = sporttype
	FROM 	dbo.Match WITH (NOLOCK)
	WHERE 	matchId = @MatchId

	SELECT	 MatchId
			,ResourceID 
			,HomeValue 
			,AwayValue 
			,OtherInfo
			,CASE 
				WHEN @Sporttype = 2 AND SettlementStatusID = 0 THEN 4
				ELSE SettlementStatusID
			END AS SettlementStatusID
	FROM	dbo.[ResultDetail] WITH (NOLOCK) 
	WHERE	MatchID = @MatchID 
			AND 1 = CASE
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