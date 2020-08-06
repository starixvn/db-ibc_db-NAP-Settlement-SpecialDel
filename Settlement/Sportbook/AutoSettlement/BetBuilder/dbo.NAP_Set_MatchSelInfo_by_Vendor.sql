/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchSelInfo_by_Vendor] 
	@matchid 			INT

AS
/*
	Created by: 20200806@July
	Task: Incorporate BetBuilder 
	DB: DBTXN.BODB02
	
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
		CROSS APPLY dbo.f_Set_MajorRound_xpre (m.sporttype) f
	WHERE m.matchid = @matchid AND m.sporttype IN (1,2)

	SELECT	 r.MatchID
			,r.ResourceId
			,r.HomeValue
			,r.AwayValue
			,r.ResultStatusID
			,r.SettlementStatusID
			,m.matchCode
			,m.leagueID
			,m.kickOffTime
			,m.finalHomeScore
			,m.finalAwayScore
			,m.homeID
			,m.awayID
			,m.htHomeScore AS halfTimeHomeScore
			,m.htAwayScore AS halfTimeAwayScore
	FROM	DBPRO.bodb02.dbo.ResultDetail r WITH(NOLOCK)
	INNER JOIN dbo.match m WITH(NOLOCK) ON r.MatchId=m.matchid
	INNER JOIN @tmpResourceIds temp ON temp.ResourceId = r.ResourceId
	WHERE r.MatchId =@matchid
		
END

