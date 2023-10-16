/*<info serverAlias="DBTXN-bodb02" executers="Dot_Member,bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Admin_Settlement_BetRadar] 
     @AdminId           INT
    ,@MatchId           INT
    ,@Fth               SMALLINT        = NULL
    ,@Fta               SMALLINT        = NULL
    ,@Hth               SMALLINT        = NULL
    ,@Hta               SMALLINT        = NULL
    ,@Action            VARCHAR(10)     = 'CAL'
    ,@IP                VARCHAR(50)     = ''
    ,@IsAuto            BIT             = 1
    ,@ResourceResult    VARCHAR(MAX)    = ''
    ,@ErrCode           INT             = 0     OUTPUT
    ,@ErrMsg            NVARCHAR(200)   = ''    OUTPUT
AS
/*  
	Created: 20231016@Aries  
	Task: Auto Send Announcement When Refund VS [Redmine:#195333]
	DB: DBTXN/BODB02  

	Revisions:  
		- 20231016@Aries: Created [Redmine:#195333]
		
	Param explanation:  
  
*/
BEGIN
    SET NOCOUNT ON  

    DECLARE @IsCalParlay        BIT
           ,@xml                XML
           ,@IsCentral          BIT  = 0
           ,@ActionId           INT     
           ,@sportType          INT

    DECLARE @Resources_193 TABLE (ResourceID VARCHAR(100))
    DECLARE @tmpResult TABLE (ResourceId VARCHAR(20), HomeValue VARCHAR(20), AwayValue VARCHAR(20))

    EXEC dbo.NAP_Set_ServerInfo
        @IsCentral = @IsCentral OUTPUT
        
    SELECT @ActionID = CASE @Action WHEN 'CAL'      THEN 187
                                    WHEN 'REFUND'   THEN 188
                       END         
    SELECT TOP 1 @sportType = sportType
    FROM  dbo.match m WITH(NOLOCK) 
    WHERE m.matchid = @MatchId    
    
    IF @sportType = 193
    BEGIN
        SET @xml = CONVERT(XML,@ResourceResult)
        
        INSERT INTO @Resources_193 
        VALUES ('280920'),('280940'),('280960')
        
        INSERT INTO @tmpResult (ResourceId, HomeValue, AwayValue)
        SELECT  DISTINCT
                T.C.value('@ResourceId', 'VARCHAR(20)') AS ResourceId
                ,T.C.value('@Custom1', 'VARCHAR(20)') AS HomeValue
                ,T.C.value('@Custom2', 'VARCHAR(20)') AS AwayValue
        FROM    @xml.nodes('/Results/Resource') AS T(C)
        OPTION ( OPTIMIZE FOR ( @xml = NULL ) ) 
            
        SET @Fth = (SELECT HomeValue FROM @tmpResult WHERE ResourceId = '00')
        SET @Fta = (SELECT AwayValue FROM @tmpResult WHERE ResourceId = '00')
        SET @Hth = (SELECT HomeValue FROM @tmpResult WHERE ResourceId = '01')
        SET @Hta = (SELECT AwayValue FROM @tmpResult WHERE ResourceId = '01')
    END

    --CHECK for offering parlay or NOT
    SELECT  @IsCalParlay = MAX(CASE 
                                    WHEN @IsCentral = 1 THEN 1 -- alway insert parlay queue at central
                                    WHEN @IsCentral = 0 AND bm.SiteDBGroupId <> 0 THEN 1
                                    ELSE 0
                                END)
    FROM    dbo.bettransm bm WITH(ROWLOCK)
    WHERE   matchid = @matchid
        AND EXISTS (
                    SELECT  1 
                    FROM    dbo.f_Set_VS_BetRadar_GetBettypes() AS f
                    WHERE   f.bettype   = bm.bettype
                            AND f.sportType = @sportType
                )
        AND bm.statusID NOT IN (1, 101)
           
    EXEC [dbo].[NAP_Admin_Settlement_VS_BetRadar] 
                @matchid        = @MatchId
               ,@AdminId        = @AdminId
               ,@fth            = @fth
               ,@fta            = @fta
               ,@hth            = @hth
               ,@hta            = @hta
               ,@Action         = @Action
               ,@IP             = @IP
               ,@IsCalParlay    = 0
               ,@IsAuto         = @IsAuto
               ,@ResourceResult = @ResourceResult
               ,@KeyId          = 0 
               ,@ErrCode        = @ErrCode OUTPUT
               ,@ErrMsg         = @ErrMsg OUTPUT

    IF (@ErrCode <> 0) 
	BEGIN
        RETURN
    END

    IF @IsCalParlay = 1
    BEGIN
        EXEC [NAP_Admin_Settlement_VS_BetRadar_MP] 
					 @AdminId = @AdminId
					,@matchid = @matchid
					,@action  = @action
					,@IP      = @IP
					,@ErrCode = @ErrCode    OUTPUT
					,@ErrMsg  = @ErrMsg     OUTPUT
    END
        
END

