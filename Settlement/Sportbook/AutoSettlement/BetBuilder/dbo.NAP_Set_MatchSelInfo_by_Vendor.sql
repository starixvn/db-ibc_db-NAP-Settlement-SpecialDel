/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchSelInfo_by_Vendor] 
	@matchid 			INT

AS
/*
	Created by: 20200806@July
	Task: Info of match for BBD
	DB: DBPRO.BODB02
	
	Revisions:
		- 20200806@July : Info of match for BBD   [Redmine:#138475]
		
	Param's Explanation:	
	
				
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @tmpResourceIds	 TABLE ( ResourceId VARCHAR(20))

	INSERT INTO @tmpResourceIds (ResourceId)
	SELECT DISTINCT f.ResourceID
	FROM dbo.match m WITH (NOLOCK) 
		CROSS APPLY dbo.f_Set_MajorRound (m.sporttype) f
	WHERE m.matchid = @matchid AND m.sporttype IN (1,2)

	SELECT	 m.matchID
			,m.matchCode
			,m.leagueID
			,m.kickOffTime
			,m.SettlementStatus 
			,m.betStatus
			,m.eventStatus
			--,m.finalHomeScore
			--,m.finalAwayScore
			,m.homeID
			,m.awayID
			--,m.htHomeScore AS halfTimeHomeScore
			--,m.htAwayScore AS halfTimeAwayScore
			,m.sporttype
	FROM	dbo.match m WITH(NOLOCK)
	WHERE m.MatchId = @matchid 

	SELECT	 temp.ResourceId AS ResourceId
			,r.HomeValue
			,r.AwayValue
			,r.ResultStatusId
			,r.SettlementStatusId
			,CASE temp.ResourceId	WHEN 'Q1' THEN 1
									WHEN 'Q2' THEN 2
									WHEN 'Q3' THEN 3
									WHEN 'Q4' THEN 4
									WHEN 'OT' THEN 5
									WHEN '01' THEN 6
									WHEN '00' THEN 7					
			END AS OrderNo
	FROM	dbo.ResultDetail r WITH(NOLOCK)
		FULL JOIN @tmpResourceIds temp ON temp.ResourceId = r.ResourceId AND r.MatchId =@matchid
	WHERE temp.ResourceId IS NOT NULL
	ORDER BY OrderNo 
	
END

GO

