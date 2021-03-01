/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_GetChildMatchByParent(
	@MatchIds	VARCHAR(MAX)
	,@Mode		VARCHAR(20) ='CAL'
	,@SelectedResources VARCHAR(MAX) = ''
)
AS
/*
	Creator	: 20210205@Louisa
	Task	: Cricket AIO [Redmine:#148870]						
	DB		: DBTXN/bodb02

	Revisions:
		20210205@Louisa: initial Function

	Param's Explanation:
		@MatchId: Parent's Matchid
		@Mode	: CAL
				  CAL-MP
		@SelectedResources: 
				<Resources>
					<Resource Id="M1" Home="1" Away="3" />
					<Resource Id="M2" Home="2" Away="4" />
				</Resources>

*/
BEGIN
	
	SET NOCOUNT ON
	
	DECLARE @Sporttype  TINYINT
			,@handle	INT
	DECLARE @tmpChildMatch TABLE ( MatchId INT)
	DECLARE @tmpResources TABLE(ResourceID VARCHAR(20))
	
	SELECT @Sporttype = 50

	INSERT INTO @tmpChildMatch( MatchId)
	SELECT m.MatchId
	FROM dbo.match m WITH(NOLOCK)
		INNER JOIN dbo.f_SplitString(@MatchIds, ',') tmp ON m.ParentID = tmp.val
	WHERE ISNULL( m.ChildMatchType, 0) = 200
		AND m.sporttype = @Sporttype
		AND m.eventstatus = 'completed'
	OPTION (MAXRECURSION 0)

	IF @@ROWCOUNT > 0 AND @SelectedResources <> ''
	BEGIN
		EXEC sp_xml_preparedocument @handle OUTPUT, @SelectedResources
		INSERT INTO @tmpResources(ResourceID)
		SELECT Id	FROM OPENXML(@handle,'Resources/Resource',1) WITH( Id	VARCHAR(20)	) AS tbl
		EXEC sp_xml_removedocument @handle
	END

	IF @Mode ='CAL-MP'
	BEGIN
		SELECT m.Matchid
		FROM @tmpChildMatch m
			INNER JOIN dbo.Bettransm bm ON m.matchid = bm.matchid
		WHERE EXISTS (SELECT TOP 1 1 FROM dbo.SettlementSpecialBettypeProfile  sp 
					  INNER JOIN @tmpResources r ON sp.ResourceID = r.ResourceID
					  WHERE sp.SportType = 50
					  AND sp.BetType = bm.bettype)
			OR @SelectedResources = ''
		GROUP BY m.matchid

	END

	IF @Mode ='CAL'
	BEGIN
		SELECT m.matchid FROM @tmpChildMatch m
			INNER JOIN dbo.Bettrans b ON m.matchid = b.matchid
		WHERE EXISTS (SELECT TOP 1 1 FROM dbo.SettlementSpecialBettypeProfile  sp 
					  INNER JOIN @tmpResources r ON sp.ResourceID = r.ResourceID
					  WHERE sp.SportType = 50
					  AND sp.BetType = b.bettype)
			OR @SelectedResources = ''
		GROUP BY m.matchid
	END


END

GO