/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_FantasyMatchOSSel]
	 @matchid INT
AS
/* 
	Created by: 20230807@Aries
    Task: Auto Link Result for Fantasy Basketball Matches [Redmine:#189191]
    DB: DBPRO/bodb02
	
	Revisions:
		- 20230807@Aries:  Created [Redmine:#189191]
		- 202308028@Aries:  Enhance Auto Fill Result for Fantasy Basketball Matches [Redmine:#193101]

*/
BEGIN
	SET NOCOUNT ON

	DECLARE  @fantasy	VARCHAR(2000)
			,@fantasyh	VARCHAR(2000)
			,@fantasya	VARCHAR(2000)
	
	DECLARE @tmpRelatedMatchIds  TABLE ( MatchId INT )
	DECLARE @tmpRelatedMatchInfo TABLE 
	( 
		  matchid				INT
		, matchcode				NVARCHAR(100)
		, kickofftime			DATETIME
		, eventstatus			NVARCHAR(100)
		, betstatus				NVARCHAR(100)
		, SettlementStatus		TINYINT
		, homeid				INT
		, awayid				INT
		, ResourceId			VARCHAR(20)
		, HomeValue				VARCHAR(50)
		, AwayValue				VARCHAR(50)
		, ResultStatusID		TINYINT
		, SettlementStatusID	TINYINT
		, IsDeleted				BIT
	)

	SELECT   @fantasy = pv.fantasy
			,@fantasyh = pv.fantasyh
			,@fantasya = pv.fantasya
	FROM 
	(		SELECT mp.MatchId, mp.[key], mp.Value
			FROM dbo.Match_Property mp WITH(NOLOCK)
			WHERE  mp.matchid = @matchid
	) f
	PIVOT 
	( 
		MAX( f.Value) 
		FOR f.[key] IN ([fantasy],[fantasyh],[fantasya] )
	) pv
	
	INSERT INTO @tmpRelatedMatchIds ( MatchId )
	SELECT f.value FROM STRING_SPLIT ( @fantasy, ',' ) f

	INSERT INTO @tmpRelatedMatchInfo
	(
		  matchid		 
		, matchcode
		, kickofftime	 
		, eventstatus	 
		, betstatus		 
		, SettlementStatus
		, homeid		 
		, awayid	
		, ResourceId
		, HomeValue	 
		, AwayValue	 
		, ResultStatusID		
		, SettlementStatusID	
		, IsDeleted
	)
	SELECT m.matchid
		, m.matchcode
		, m.kickofftime
		, m.eventstatus
		, m.betstatus
		, m.SettlementStatus
		, m.homeid
		, m.awayid
		, rd.ResourceId
		, rd.HomeValue
		, rd.AwayValue
		, rd.ResultStatusID		
		, rd.SettlementStatusID	
		, m.IsDeleted
	FROM dbo.match m WITH(NOLOCK)
		INNER JOIN @tmpRelatedMatchIds AS tmp ON m.matchid = tmp.MatchId
		LEFT JOIN dbo.ResultDetail AS rd WITH(NOLOCK) ON rd.matchid = tmp.MatchId			
	WHERE 1 = CASE WHEN m.sporttype = 2 AND (rd.ResourceId IN ('Q1','Q2','Q3','Q4','OT','00','01') OR rd.ResourceId  IS NULL) THEN 1
				   ELSE 0
			  END
	
	SELECT @fantasyh AS fantasyHomeTeam, @fantasya AS fantasyAwayTeam

	SELECT	  matchid		 
			, matchcode
			, kickofftime	 
			, eventstatus	 
			, betstatus		 
			, SettlementStatus
			, homeid		 
			, awayid	
			, ResourceId
			, HomeValue	 
			, AwayValue	 
			, ResultStatusID		
			, SettlementStatusID	
			, IsDeleted
	FROM @tmpRelatedMatchInfo

END
GO
