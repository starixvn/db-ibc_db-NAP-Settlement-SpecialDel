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
		- 20210311@Louisa: Check runnind Odds [Redmine:#151173]
		- 20210413@Louisa: Enhancement [Redmine:#148241]

     
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
	
	IF ( ISNULL(@SelectedResource,'') = ''	)
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

	ELSE IF ( @sporttype IN ( 5, 9, 43, 50 )	)
	BEGIN
		DECLARE @queryMatch NVARCHAR(MAX) = ''

		IF @sporttype = 9 AND @SelectedResource LIKE '%00%'
			SELECT @SelectedResource = @SelectedResource + ',70400' ---Special resource FT

		CREATE TABLE #Resources ( Bettype SMALLINT, BetID BIGINT )

		SET	@queryMatch = N'INSERT INTO #Resources ( Bettype , BetID )
							SELECT   BetType
									, BetID
							FROM	OPENQUERY(DBTXN, '' SELECT  sp.BetType
 										, sp.BetID
							FROM bodb02.dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK)
									INNER JOIN (SELECT val FROM bodb02.dbo.f_SplitString(''''' + @SelectedResource + ''''' , '''','''')) tm
															ON sp.ResourceID = tm.val OR ISNULL(sp.RefResourceId,'''''''') = tm.val
							WHERE sp.sporttype ='   + CAST( @sporttype AS VARCHAR(4) ) + '
							OPTION (MAXRECURSION 0)
							'')'

		EXECUTE	sys.sp_executesql @queryMatch

		IF( @sporttype = 43)
		BEGIN
		SET @ErrCode = (SELECT TOP (1) 1001018
							FROM dbo.oddsES o WITH (NOLOCK)
								INNER JOIN #Resources	r
									ON o.bettype = r.Bettype
							WHERE o.matchid = @Matchid
								AND o.liveindicator = 1
								AND o.oddsstatus <> 'closed'
								AND ( r.BetID = 0 OR CHARINDEX (o.Resourceid, BetID ) > 0 )
							)
		END

		ELSE IF( @sporttype = 5)
		BEGIN
		SET @ErrCode = (SELECT TOP (1) 1001018
							FROM dbo.odds o WITH (NOLOCK)
								INNER JOIN #Resources	r
									ON o.bettype = r.Bettype
							WHERE o.matchid = @Matchid
								AND o.liveindicator = 1
								AND o.oddsstatus <> 'closed'
								AND ( r.BetID = 0 OR CHARINDEX (o.Resourceid, BetID ) > 0 )
							)
		END

		ELSE IF( @sporttype IN (9,50) )
		BEGIN
		SET @ErrCode = (SELECT TOP (1) 1001018
							FROM dbo.oddsOS o WITH (NOLOCK)
								INNER JOIN #Resources	r
									ON o.bettype = r.Bettype
							WHERE o.matchid = @Matchid
								AND o.liveindicator = 1
								AND o.oddsstatus <> 'closed'
								AND ( r.BetID = 0 OR CHARINDEX (o.Resourceid, BetID ) > 0 )
							)
		END

	END


	
	IF @ErrCode > 0
	BEGIN
		SET @ErrMsg = N'ERROR! Cannot calculate due to unclosed odds. Please make sure you select correct match/interval/result to calculate.'
	END
END

GO