/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_FantasyMatchSel]
	 @matchid INT
AS
/* 
	Created by: 20210920@Louisa
    Task: 20210920@Louisa: Linked result for Fantasy match [Redmine:#161268]
    DB: DBPRO/bodb02
	
	Revisions:
		- 20210920@Louisa:  Linked result for Fantasy match [Redmine:#161268]
		- 20211108@Louisa: In-house Replicator: Updated Action [Redmine:#164393]
		- 20220509@Kathy: Change to use STRING_SPLIT [Redmine:#172461]
		- 20221122@Louisa: Add Fantasy league 125351 [Redmine:#180306]
*/
BEGIN
	SET NOCOUNT ON

	DECLARE  @fantasy	VARCHAR(100)
			,@fantasyh	VARCHAR(100)
			,@fantasya	VARCHAR(100)
	
	DECLARE @tmpRelatedMatchIds  TABLE ( MatchId INT )
	DECLARE @tmpRelatedMatchInfo TABLE 
	( 
		  matchid		 INT
		, matchcode		 NVARCHAR(100)
		, kickofftime	 DATETIME
		, eventstatus	 NVARCHAR(100)
		, betstatus		 NVARCHAR(100)
		, SettlementStatus	TINYINT
		, homeid		 INT
		, awayid		 INT
		, hthomescore	 INT
		, htawayscore	 INT
		, finalhomescore INT
		, finalawayscore INT
		, IsDeleted		 BIT
	)

	SELECT   @fantasy = pv.fantasy
			, @fantasyh = pv.fantasyh
			, @fantasya = pv.fantasya
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
	

	IF EXISTS (SELECT TOP 1 1 FROM dbo.match m WITH(NOLOCK) WHERE m.matchid = @matchid AND m.leagueid IN ( 16371,65550, 89611,125351 )) --- Fantasy League
	BEGIN
		INSERT INTO @tmpRelatedMatchIds ( MatchId )
		SELECT f.value FROM STRING_SPLIT ( @fantasy, ',' ) f

		INSERT INTO @tmpRelatedMatchInfo
		(
			  matchid		 
			, matchcode
			, kickofftime	 
			, eventstatus	 
			, betstatus		 
			, SettlementStatuS
			, homeid		 
			, awayid		 
			, hthomescore	 
			, htawayscore	 
			, finalhomescore 
			, finalawayscore
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
			, m.hthomescore
			, m.htawayscore
			, m.finalhomescore
			, m.finalawayscore
			, m.IsDeleted
		FROM dbo.match m WITH(NOLOCK)
			INNER JOIN @tmpRelatedMatchIds tmp
				ON m.matchid = tmp.MatchId
		WHERE m.sporttype = 1
	END

	---- Return data

	SELECT @fantasyh AS fantasyHomeTeam, @fantasya AS fantasyAwayTeam

	SELECT   matchid		 
			, matchcode
			, kickofftime		 
			, eventstatus	 
			, betstatus		 
			, SettlementStatus
			, homeid		 
			, awayid		 
			, hthomescore	 
			, htawayscore	 
			, finalhomescore 
			, finalawayscore 
			, IsDeleted
	FROM @tmpRelatedMatchInfo

END
GO
