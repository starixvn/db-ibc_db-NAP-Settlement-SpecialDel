/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Validation_PrePush] 
	 @Matchid				INT
	,@CheckType				TINYINT			= 0
    ,@SelectedResource		VARCHAR(MAX)	= NULL
    ,@Action				VARCHAR(100)	= 'CAL_EAR'
    ,@ErrCode               INT             = 0     OUTPUT
    ,@ErrMsg                NVARCHAR(200)   = ''    OUTPUT
    
AS
/*   
	Creator: Helen
    Date: 20191231
    Task: SP for validation
    DB: DBPRO/BODB02

    Revisions:        
        - 20191231@Helen: Basketball | Accidentally Settled Running Match caused by Keyscore - [Redmine:126287]
		- 20200110@Max: Prevent User From Calculating a Running Match [Redmine: #127031]
		- 20200710@Kathy: Incorporate New Bet Types of Basketball - Phase 2 [Redmine:#135846]
		- 20210205@Louisa: Cricket AIO [Redmine:#148870]
		- 20210311@Louisa: Check runnind Odds [Redmine:#151173]
		- 20210413@Louisa: Enhancement [Redmine:#148241]
		- 20210524@Louisa: SOP for Badminton, Basketball [Redmine:#155361,#155360]
		- 20210611@Louisa: Beach Volleyball [Redmine:#156541]
		- 20210906@Louisa: Settle by profile for Volleyball [Redmine:#160478]
		- 20211108@Louisa: In-house Replicator: Deleted Action [Redmine:#164393]
		- 20220315@Kathy: Change to use STRING_SPLIT [Redmine:#166454]
		- 20220512@Louisa: Change message content [Redmine:#171676]
		- 20220629@Louisa: Volleyball AIO - use dbo.ddsOS instead of dbo.Odds [Redmineid:#173862]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
		- 20231002@Aries: Apply Auto Payout for Cricket by using TheSports Provider [Redmine:#195768]
		- 20240502@204698: Direct Payout- Kabadi/Icehockey- missing check live odds are closed [Redmine:#204698]
     
    Param's Explanation:

		@CheckType: 0 : Check for single match
					1 : Check for multiple match
					
		@SelectedResource
				'<Resources>
					<Resource MatchId="701026796">
						<ResourceId Id="0101" />
						<ResourceId Id="0102" />
						<ResourceId Id="0103" />
						<ResourceId Id="0104" />
						<ResourceId Id="0105" />
						<ResourceId Id="00" />
					</Resource>
					<Resource MatchId="701026797">
						<ResourceId Id="00" />
					</Resource>
					<Resource MatchId="701026798">
						<ResourceId Id="00" />
					</Resource>
					<Resource MatchId="701027909">
						<ResourceId Id="00" />
					</Resource>
					<Resource MatchId="701027910">
						<ResourceId Id="00" />
					</Resource>
					<Resource MatchId="701027911">
						<ResourceId Id="00" />
					</Resource>
				</Resources>'	
		
    Matchid for testing: 70031309     
*/
BEGIN
    SET NOCOUNT ON

    DECLARE	@sporttype SMALLINT
		, @XmlData XML
		, @oddsTable TINYINT = 0
		, @ChildMatchList	VARCHAR(200) = ''
	
	DECLARE @tmpMatchRunningOdds TABLE ( Matchid INT )

	SELECT	@sporttype   = m.sporttype
	FROM	dbo.match m WITH (NOLOCK)
	WHERE	m.matchid = @MatchId

	SELECT @oddsTable = CASE WHEN @sporttype IN ( 2, 5, 4,47 )		THEN 1 --Odds
							 WHEN @sporttype IN ( 9, 45, 50, 6 )	THEN 2 --OddsOS
							 WHEN @sporttype = 43					THEN 3 --OddsES
							 ELSE 0 END -- not checking

	IF	(	@oddsTable = 0	OR ISNULL(@SelectedResource,'') = '' )
	RETURN

	IF OBJECT_ID('tempdb..#SelectedMatchResource') IS NOT NULL
		DROP TABLE #SelectedMatchResource

	IF OBJECT_ID('tempdb..#Bettypes') IS NOT NULL
		DROP TABLE #Bettypes

	CREATE TABLE #SelectedMatchResource ( Matchid INT, ResourceId VARCHAR(20) )
	CREATE NONCLUSTERED INDEX IX_SelectedMatchResource ON #SelectedMatchResource (ResourceId)

	CREATE TABLE #Bettypes ( Bettype SMALLINT, BetID BIGINT )


	SET @XmlData =  CONVERT(XML, @SelectedResource)

	;WITH TmpData AS
	(
		SELECT T.C.value('@MatchId', 'INT') AS Matchid
				,X.C.value('@Id', 'VARCHAR(20)') AS ResourceId
		FROM @xmlData.nodes('/Resources/Resource') AS T(C)
			CROSS APPLY	C.nodes('ResourceId') AS X(C)
	)
	INSERT INTO #SelectedMatchResource ( Matchid, ResourceId )
	SELECT	Matchid, ResourceId
	FROM TmpData
	OPTION ( OPTIMIZE FOR ( @XmlData = NULL ) )	

	----------------- Checking running Odds
	INSERT INTO #Bettypes ( Bettype , BetID )
	SELECT   BetType, BetID
	FROM dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK)
        INNER JOIN #SelectedMatchResource AS r ON  sp.RefResourceID = r.ResourceId 
	WHERE sp.sporttype = @sporttype		
    UNION 
	SELECT   BetType, BetID
	FROM dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK)
        INNER  JOIN #SelectedMatchResource AS r ON  sp.ResourceId = r.ResourceId 
	WHERE sp.sporttype = @sporttype		

	IF @CheckType = 0
	BEGIN
		IF @oddsTable = 1 OR @sporttype = 6 --when Volleyball AIO release, odds info will save into OddsOS instead of Odds
		BEGIN
		SET @ErrCode = (SELECT TOP (1) 1001018
							FROM dbo.odds o WITH (NOLOCK)
								INNER JOIN #Bettypes	r
									ON o.bettype = r.Bettype
							WHERE o.matchid = @Matchid
								AND o.liveindicator = 1
								AND o.oddsstatus <> 'closed'
								AND ( r.BetID = 0 OR CHARINDEX (o.Resourceid, BetID ) > 0 )
								AND ISNULL(o.IsDeleted,0) = 0
							)
		END

		IF @oddsTable = 2 
		BEGIN
		SET @ErrCode = (SELECT TOP (1) 1001018
							FROM dbo.oddsOS o WITH (NOLOCK)
								INNER JOIN #Bettypes	r
									ON o.bettype = r.Bettype
							WHERE o.matchid = @Matchid
								AND o.liveindicator = 1
								AND o.oddsstatus <> 'closed'
								AND ( r.BetID = 0 OR CHARINDEX (o.Resourceid, BetID ) > 0 )
								AND ISNULL(o.IsDeleted,0) = 0
							)
		END

		ELSE IF @oddsTable = 3
		BEGIN
		SET @ErrCode = (SELECT TOP (1) 1001018
							FROM dbo.oddsES o WITH (NOLOCK)
								INNER JOIN #Bettypes	r
									ON o.bettype = r.Bettype
							WHERE o.matchid = @Matchid
								AND o.liveindicator = 1
								AND o.oddsstatus <> 'closed'
								AND ( r.BetID = 0 OR CHARINDEX (o.Resourceid, BetID ) > 0 )
								AND ISNULL(o.IsDeleted,0) = 0
							)
		END

		IF 	@ErrCode > 0
			SELECT @ErrMsg = N'ERROR! Cannot proceed due to unclosed odds. Please make sure you select correct match/interval/result to calculate.'

	END
	
	ELSE IF @CheckType = 1 AND @sporttype = 6
	BEGIN
		INSERT INTO @tmpMatchRunningOdds ( Matchid )
				SELECT DISTINCT o.matchid
				FROM dbo.odds o WITH (NOLOCK)
				INNER JOIN #Bettypes b
					ON o.bettype = b.Bettype
				CROSS APPLY 
				(
					SELECT TOP 1 matchid
					FROM #SelectedMatchResource mr
						WHERE o.matchid = mr.Matchid
						AND ( b.BetID = 0 OR CHARINDEX (o.Resourceid, BetID ) > 0 )
						AND o.liveindicator = 1
						AND o.oddsstatus <> 'closed'
						AND ISNULL(o.IsDeleted,0) = 0
				) r

		INSERT INTO @tmpMatchRunningOdds ( Matchid )
				SELECT DISTINCT o.matchid
				FROM dbo.oddsOS o WITH (NOLOCK)
				INNER JOIN #Bettypes b
					ON o.bettype = b.Bettype
				CROSS APPLY 
				(
					SELECT TOP 1 matchid
					FROM #SelectedMatchResource mr
						WHERE o.matchid = mr.Matchid
						AND ( b.BetID = 0 OR CHARINDEX (o.Resourceid, BetID ) > 0 )
						AND o.liveindicator = 1
						AND o.oddsstatus <> 'closed'
						AND ISNULL(o.IsDeleted,0) = 0
				) r

				IF EXISTS (SELECT TOP 1 1 FROM @tmpMatchRunningOdds WHERE Matchid = @Matchid)
					SELECT  @ErrCode = 1001018
							,@ErrMsg = N'ERROR! Cannot proceed due to unclosed odds. Please make sure you select correct match/interval/result to calculate.'

				ELSE IF EXISTS (SELECT TOP 1 1 FROM @tmpMatchRunningOdds WHERE Matchid <> @Matchid )
				BEGIN
					SELECT @ChildMatchList = @ChildMatchList + '<br/>' + CAST(matchid AS VARCHAR(20) ) FROM @tmpMatchRunningOdds ORDER BY Matchid
					SELECT  @ErrCode = 1001057
							,@ErrMsg = 'WARNING! Cannot continue due to following matches have unclosed odds:'
									+ @ChildMatchList
				END
				
	END

END

GO