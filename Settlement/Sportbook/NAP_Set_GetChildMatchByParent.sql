/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_GetChildMatchByParent (
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
		@Mode	: CAL, CAL-EAR, UNDO, UNDO-EAR, REFUND, REFUND-EAR: Any Action on Single Ticket
				  CAL-MP: Any Action on Parlay Ticket
				  
		@SelectedResources: 
				<Resources>
					<Resource Id="H1" Home="1" />
					<Resource Id="A1" Home="2" />
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
		INNER JOIN dbo.f_SplitString(@MatchIds, ',') tmp ON CAST (tmp.val AS INT ) = m.ParentID
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
	
	DECLARE @tmpReturnTable TABLE (MatchId INT)

	IF @Mode = 'CAL-MP'
	BEGIN
		INSERT INTO @tmpReturnTable (MatchId)
		SELECT m.Matchid
		FROM @tmpChildMatch m
			INNER JOIN dbo.Bettransm bm WITH(NOLOCK) ON m.matchid = bm.matchid
		WHERE EXISTS (SELECT TOP 1 1 FROM dbo.SettlementSpecialBettypeProfile  sp WITH(NOLOCK)
					  INNER JOIN @tmpResources r ON sp.ResourceID = r.ResourceID
					  WHERE sp.SportType = 50
					  AND sp.BetType = bm.bettype
					  AND (sp.BetID = bm.betcheck OR sp.BetId =0)
					  )
			OR @SelectedResources = ''
		GROUP BY m.matchid

	END

	ELSE IF @Mode LIKE 'CAL%' OR @Mode LIKE 'REFUND%'
	BEGIN
		INSERT INTO @tmpReturnTable (MatchId)
		SELECT m.matchid FROM @tmpChildMatch m
			INNER JOIN dbo.Bettrans b WITH(NOLOCK) ON m.matchid = b.matchid
		WHERE EXISTS (SELECT TOP 1 1 FROM dbo.SettlementSpecialBettypeProfile  sp  WITH(NOLOCK)
						INNER JOIN @tmpResources r ON sp.ResourceID = r.ResourceID
					  WHERE sp.SportType = 50
						AND sp.BetType = b.bettype
						AND (sp.BetID = b.BetId OR sp.BetId =0)
					  )
			OR @SelectedResources = ''
		GROUP BY m.matchid
	END

	ELSE IF @Mode LIKE 'UNDO%'
	BEGIN
		INSERT INTO @tmpReturnTable (MatchId)
	    SELECT m.Matchid
		FROM @tmpChildMatch m
			INNER JOIN dbo.Bettransm bm WITH(NOLOCK) ON m.matchid = bm.matchid
		WHERE EXISTS (SELECT TOP 1 1 FROM dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK) 
						INNER JOIN @tmpResources r ON sp.ResourceID = r.ResourceID
					  WHERE sp.SportType = 50
						AND sp.BetType = bm.bettype
						AND (sp.BetID = bm.BetCheck OR sp.BetId =0)
						)
			OR @SelectedResources = ''
		
		UNION
		SELECT m.matchid FROM @tmpChildMatch m
			INNER JOIN dbo.Bettrans b WITH(NOLOCK) ON m.matchid = b.matchid
		WHERE EXISTS (SELECT TOP 1 1 FROM dbo.SettlementSpecialBettypeProfile  sp WITH(NOLOCK)
						INNER JOIN @tmpResources r ON sp.ResourceID = r.ResourceID
					  WHERE sp.SportType = 50
						AND sp.BetType = b.bettype
						AND (sp.BetID = b.BetId OR sp.BetId =0)
						)
			OR @SelectedResources = ''
		GROUP BY m.matchid
	END

	SELECT MatchId FROM @tmpReturnTable
	
END

GO