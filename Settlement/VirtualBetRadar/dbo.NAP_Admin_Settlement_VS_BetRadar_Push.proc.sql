/*<info serverAlias="DBTXN-bodb02" executers="Dot_Member,bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Admin_Settlement_VS_BetRadar_Push] 
    @AdminId            INT
    ,@MatchId           INT
    ,@Fth               SMALLINT        = NULL
    ,@Fta               SMALLINT        = NULL
    ,@Hth               SMALLINT        = NULL
    ,@Hta               SMALLINT        = NULL
    ,@Action            VARCHAR(10)     = 'CAL'
    ,@IP                VARCHAR(50)     = ''
    ,@IsAuto            BIT             = 1
    ,@ResourceResult    VARCHAR(MAX)    = ''
	,@notifyFlag		TINYINT			= 0
    ,@ErrCode           INT             = 0     OUTPUT
    ,@ErrMsg            NVARCHAR(200)   = ''    OUTPUT
AS
/*  
    Creator: 20170106@Bobby
    Task: 77720 - Implement BetRadar VS League & Nation
    DB: DBTXN/BODB02
    
    Revisions:
        - 20160606@Bobby: Initialize
        - 20180214@Helen: Integrate VSBR 2 - Basketball - [Redmine:90154]
        - 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
		- 20220928@Kathy: Update Send Mail Notification Rule for VS BetRadar [Redmine:#178262]

    Param's Explanation:
        - @Hth: Total score which home team scored in Half Time(HT)
        - @Hta: Total score which away team scored in Half Time(HT)
        - @Fth: Total score which home team scored in Full Time(FT)
        - @Fta: Total score which away team scored in Full Time(FT)
        - @Action: [CAL,REFUND]
        
        @ResourceResult='<Results>
                            <Resource ResourceId="00" Custom1="100" Custom2="106" />
                            <Resource ResourceId="01" Custom1="60" Custom2="41" />
                            <Resource ResourceId="280920" Custom1="H" Custom2="" />
                            <Resource ResourceId="280940" Custom1="A" Custom2="" />
                            <Resource ResourceId="280960" Custom1="N" Custom2="" />
                    </Results>'
 
*/
BEGIN
    SET NOCOUNT ON  

    DECLARE @procName       SYSNAME
        , @sqlCommand       NVARCHAR(MAX)
        , @matchcode        VARCHAR(50)
        , @leagueid         INT
        , @IsCalParlay      BIT
        , @IsExistParlayAllSite BIT = 0

        , @Remark           VARCHAR(200)
        , @KeyId            INT
        , @recipients       VARCHAR(250) 
      
        , @hasParlay        BIT = 0     
        , @xml              XML
        , @IsCentral        BIT  = 0

    EXEC dbo.NAP_Set_ServerInfo
        @IsCentral = @IsCentral OUTPUT
        
    DECLARE @Resources_193 TABLE (ResourceID VARCHAR(100))
    DECLARE @tmpResult TABLE (ResourceId VARCHAR(20), HomeValue VARCHAR(20), AwayValue VARCHAR(20))
    
    DECLARE @ActionId           INT     
            ,@sportType         INT
    
    SELECT @ActionID            = CASE @Action
                                    WHEN 'CAL'      THEN 187
                                    WHEN 'REFUND'   THEN 188
                                END         
    SELECT TOP 1 
            @sportType      = sportType
            , @matchcode    = matchcode
            , @leagueid     = leagueid
    FROM    dbo.match m WITH(NOLOCK) 
    WHERE   m.matchid = @MatchId    
    
    -- Reset home score and away score follow by @ResourceResult
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
            ,@IsExistParlayAllSite = COUNT(1)
    FROM    dbo.bettransm bm WITH(ROWLOCK)
    WHERE   matchid = @matchid
        AND EXISTS (
                    SELECT  1 
                    FROM    dbo.f_Set_VS_BetRadar_GetBettypes() AS f
                    WHERE   f.bettype   = bm.bettype
                            AND f.sportType = @sportType
                )
        AND bm.statusID NOT IN (1, 101)
        --AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
           
    --CHECK for including parlay or NOT
    IF(@notifyFlag & 8 > 0 AND @IsExistParlayAllSite = 0)
    BEGIN
		SET @notifyFlag = @notifyFlag ^ 8                 
    END
    
    SELECT  @ErrCode        = 0
            ,@ErrMsg        = ''
            ,@procName      = OBJECT_NAME(@@procid)
            ,@sqlCommand    = 'EXEC [dbo].[NAP_Admin_Settlement_VS_BetRadar] @matchid = ' + CONVERT(NVARCHAR(50), @MatchId) 
                                                          + ', @AdminId = ' + CONVERT(NVARCHAR(50), @AdminId) 
                                                          + CASE WHEN @fth IS NULL THEN '' ELSE ', @fth = ' + CONVERT(NVARCHAR(50), @fth) END 
                                                          + CASE WHEN @fta IS NULL THEN '' ELSE ', @fta = ' + CONVERT(NVARCHAR(50), @fta) END 
                                                          + CASE WHEN @hth IS NULL THEN '' ELSE ', @hth = ' + CONVERT(NVARCHAR(50), @hth) END 
                                                          + CASE WHEN @hta IS NULL THEN '' ELSE ', @hta = ' + CONVERT(NVARCHAR(50), @hta) END 
                                                          + ', @Action = ''' + CONVERT(NVARCHAR(50), @Action) + '''' 
                                                          + ', @IP = ''' + CONVERT(NVARCHAR(50), @IP) + '''' 
                                                          + ', @IsCalParlay = ' + CONVERT(NVARCHAR(5), ISNULL(@IsCalParlay,0)) 
                                                          + ', @IsAuto = ' + CONVERT(NVARCHAR(5), ISNULL(@IsAuto,0)) 
                                                          + CASE WHEN @ResourceResult IS NULL THEN '' ELSE ', @ResourceResult = ''' + CONVERT(NVARCHAR(MAX), @ResourceResult) + '''' END 
                                                          + ', @KeyId = @KeyId' 
                                                          + ', @ErrCode = @ErrCode OUTPUT' 
                                                          + ', @ErrMsg = @ErrMsg OUTPUT'
        
    IF (@procName LIKE '%_xtest' OR @procName LIKE '%_xpre' OR @procName LIKE '%_UAT_') -- UAT1 -->UAT9
    BEGIN
        BEGIN TRY
            SET @KeyId = 0 --- execute without queueing
            EXEC sys.sp_executesql @sqlCommand
                ,N'@KeyId INT, @ErrMsg VARCHAR(400) OUTPUT, @ErrCode INT OUTPUT'
                ,@KeyId         = @KeyId
                ,@ErrMsg        = @ErrMsg OUTPUT
                ,@ErrCode       = @ErrCode OUTPUT
                
            IF (@IsCalParlay = 1 AND @ErrCode = 0)
            BEGIN
                EXEC [NAP_Admin_Settlement_VS_BetRadar_MP] 
                    @AdminId = @AdminId
                    ,@matchid = @matchid
                    ,@action  = @action
                    ,@IP      = @IP
                    ,@ErrCode = @ErrCode OUTPUT
                    ,@ErrMsg  = @ErrMsg   OUTPUT
            END

            IF(@notifyFlag > 0) -- only central
            BEGIN
                --SEND notify
                EXEC [dbo].[NAP_Admin_SendNotify_VS_Betradar]
                    @matchid        = @matchid
                    ,@notifyAction  = @ActionId
                    ,@ErrCode       = @ErrCode OUTPUT
                    ,@ErrMsg        = @ErrMsg   OUTPUT
            END
        END TRY
        BEGIN CATCH
            SELECT  @ErrMsg   = @ErrMsg + ISNULL(ERROR_MESSAGE(), '')
                    ,@ErrCode = @@error
            RETURN
        END CATCH
    END
    ELSE
    BEGIN
        --UPDATE for queueing execution
        SET @sqlCommand += ', @IsQueued = 1'
        BEGIN TRY
            INSERT INTO dbo.Single_Calculate_Queue_VS (
                    matchid
                    ,matchcode
                    ,IsCalculating
                    ,LeagueID
                    ,SportType
                    ,AdminId
                    ,IP
                    ,Action
                    ,sqlCommand
                    ,execTime
                    ,ActionId
                    ,NotifyFlag
                )
            SELECT  @MatchId
                    ,@matchcode
                    ,0
                    ,@leagueid
                    ,@sporttype
                    ,@AdminId
                    ,@IP
                    ,@Action
                    ,@sqlCommand
                    ,NULL
                    ,@ActionId
                    ,@notifyFlag
        END TRY
        BEGIN CATCH 
            SELECT @ErrCode = ERROR_NUMBER()
                , @ErrMsg   = ERROR_MESSAGE()               
        END CATCH
        
    END
END

