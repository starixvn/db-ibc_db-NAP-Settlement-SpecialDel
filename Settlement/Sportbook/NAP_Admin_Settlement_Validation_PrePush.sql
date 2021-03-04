/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Validation_PrePush] 
	 @Matchid				INT
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

     
    Param's Explanation:
		* sample @SelectedResource for manual:	'801,802,1H,803,804,FT'
		* sample @SelectedResource for early:	'604,6130215,6130115,6130110'
		* sample @SelectedResource for Cricket: '94101001,94101002'
		
    Matchid for testing: 70031309     
*/
BEGIN
    SET NOCOUNT ON

    DECLARE	@sporttype INT
			
    SELECT	@sporttype   = m.sporttype
    FROM	dbo.match m WITH (NOLOCK)
    WHERE	m.matchid = @MatchId
		AND 1 = CASE WHEN ISNULL(m.ChildMatchType,0) = 200 AND m.ParentID IS NOT NULL AND m.sporttype = 50 THEN 0 ELSE 1 END
	
	IF ( 
		@sporttype NOT IN (2, 50) -- check for basketball, Cricket
		AND ISNULL(@SelectedResource,'') <> ''
		)
	RETURN

	IF @sporttype = 2
	BEGIN
		IF @Action = 'CAL_EAR'
		BEGIN
			SET @ErrCode = (SELECT TOP (1) 1001018
							FROM dbo.odds o WITH (NOLOCK)
							WHERE o.matchid = @Matchid 
								AND 1 = CASE 
											WHEN CHARINDEX (CONVERT(VARCHAR(10), o.bettype) + ISNULL(o.Resourceid,''),@SelectedResource) > 0
												AND o.bettype IN(604, 606, 607, 613) THEN 1 -- Early bettype
											ELSE 0
										END	
								AND o.liveindicator = 1
								AND o.oddsstatus <> 'closed'
							)	
		END
		ELSE  
		BEGIN
			SET @ErrCode = (SELECT TOP (1) 1001018
							FROM dbo.odds o WITH (NOLOCK)
								INNER JOIN dbo.f_Set_GetGroupBettypes () f ON o.bettype = f.BetType
							WHERE o.matchid = @Matchid 
								AND 1 = CASE 
											WHEN GroupId = 10 AND CHARINDEX (o.Resourceid,@SelectedResource ) > 0 THEN 1 -- special -> Calculate Quarter X
											WHEN CHARINDEX ('1H',@SelectedResource) > 0 AND f.GroupName = '1H' THEN 1 -- HT
											WHEN CHARINDEX ('FT',@SelectedResource) > 0 AND f.GroupName IN ('FT', '2H') THEN 1 -- FT
											ELSE 0
										END	
								AND f.IsAuto = 0
								AND o.liveindicator = 1
								AND o.oddsstatus <> 'closed'
							)	
		END
	END

	ELSE IF @sporttype = 50
	BEGIN
		DECLARE @queryMatch NVARCHAR(MAX) = ''
				,@execSql NVARCHAR(MAX) = ''

		CREATE TABLE #CheckOdds ( Bettype SMALLINT,  ResourceId VARCHAR(20), BetID SMALLINT )
		
		

		SET @queryMatch =
		'SELECT  sp.BetType
				, sp.BetID
		FROM SettlementSpecialBettypeProfile sp WITH(NOLOCK)
			INNER JOIN (SELECT val FROM bodb02.dbo.f_SplitString(@SelectedResource , '','')) tm
									ON sp.ResourceID = tm.val
						OPTION (MAXRECURSION 0)'

		SET @execSql = 'DBTXN.bodb02.dbo.sp_executesql @queryMatch, N''@SelectedResource VARCHAR(MAX)'' , @SelectedResource'

		INSERT INTO #CheckOdds ( Bettype , BetID )
		EXECUTE	sys.sp_executesql @execSql, N'@queryMatch NVARCHAR(MAX), @SelectedResource VARCHAR(MAX)', @queryMatch, @SelectedResource

		SET @ErrCode = (SELECT TOP (1) 1001018
							FROM dbo.oddsOS o WITH (NOLOCK)
								INNER JOIN #CheckOdds	c
									ON o.bettype = c.Bettype
							WHERE o.matchid = @Matchid
								AND o.oddsstatus <> 'closed'
								AND ( c.BetID = 0 OR CHARINDEX (o.Resourceid, BetID ) > 0 )
							)
	END

	IF @ErrCode > 0
	BEGIN
		SET @ErrMsg = N'ERROR! Cannot calculate due to unclosed odds. Please make sure you select correct match/interval/result to calculate.'
	END		

END
GO