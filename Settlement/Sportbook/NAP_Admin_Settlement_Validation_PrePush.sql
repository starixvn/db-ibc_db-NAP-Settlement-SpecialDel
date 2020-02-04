/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Validation_PrePush] 
    @Matchid				INT
    ,@SelectedResource		VARCHAR(MAX)		= NULL
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
     
    Param's Explanation:
		* sample @SelectedResource for manual:	'801,802,1H,803,804,FT'
		* sample @SelectedResource for early:	'604,6130215,6130115,6130110'
		
    Matchid for testing: 70031309     
*/
BEGIN
    SET NOCOUNT ON

    DECLARE	@sporttype INT
			
    SELECT	@sporttype   = m.sporttype
    FROM	dbo.match m WITH (NOLOCK)
    WHERE	m.matchid = @MatchId
	
	IF ( 
		@sporttype IN (2) -- check for basketball first
		AND ISNULL(@SelectedResource,'') <> ''
		) 
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
											WHEN CHARINDEX ('FT',@SelectedResource) > 0 AND f.GroupName = 'FT' THEN 1 -- FT
											ELSE 0
										END	
								AND f.IsAuto = 0
								AND o.liveindicator = 1
								AND o.oddsstatus <> 'closed'
							)	
		END
		IF @ErrCode > 0
		BEGIN
			SET @ErrMsg = N'ERROR! Cannot calculate due to unclosed odds. Please make sure you select correct match/interval/result to calculate.'
		END		
	END
END
GO

