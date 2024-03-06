/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Result_Update_1s]
  @Command                      VARCHAR(100) 
 ,@MatchID                      INT
 ,@SelectedResources			VARCHAR(MAX)= NULL
 ,@fth                          SMALLINT    = NULL
 ,@fta                          SMALLINT    = NULL
 ,@hth                          SMALLINT    = NULL
 ,@hta                          SMALLINT    = NULL
 ,@Action                       VARCHAR(10) = 'CAL'
 ,@IsAuto                       BIT         = 0 
 ,@creator                      INT         = 0 
 ,@SDTRecord                    TINYINT     = 0
 ,@ResourceResult               VARCHAR(MAX) = NULL
AS 
/*
    Created by: Jamie
    Date: 20140204
    Task: Update the result of Tennis 
    DB: DBPRO/bodb02 

    Revision
        - 20150604@Jamie: Apply for Soccer ONLY 
        - 20150618@Jamie: Offer the option Exclude Corner tickets [Feature #38099]
        - 20150928@Johnson: update result of corner without single corner ticket [Redmine: #44415]
        - 20160705@Kathy: PH-AIO phase 2 (67 bettypes ) [Redmine:#53154]
        - 20161118@Bobby: #67551 - Update changes for refunding SDT - ABANDONED match
        - 20170815@Kathy: Using table ResultDetail to store FGLG result instead of betstatus [Redmine:#81308]
        - 20180720@Vicky: Refund FT without Settle Determined [Redmine:#92859]
		- 20190313@Kathy: Change command for refund HT, FT, ALL to avoid wrong replacing SP deployment [Redmine:#109007]
		- 20190411@Kathy: Change command for calculate FGLG to avoid wrong replacing SP deployment [Redmine:#106823]
		- 20190425@Sol: Auto Payout Phase 3 [Redmine:#116073]
		- 20190620@Kathy: Remove corner, auto betradar bettypes [Redmine:#109584]
		- 20190725@Sol: Incorporate PHAIO 4b - Implement [ResourceID] = '09' to Settle PH4B Bet Types [Redmine:#115232]
        - 20191213@Helen: Support Instant Calculation for Corner Bet Types - Update result for manual process [Redmine:115377]
		- 20191112@Sol: Incorporate PHAIO 5 [Redmine:#121681]
		- 20200522@Kathy: update settlementstatusid = 2 if refund HT [Redmine:#134192]
		- 20211215@Kathy: Soccer - Include calculate parlay into calculate single tickets process [Redmine:#166072]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
        - 20230406@Aries: Un-calculate FT Only [Redmine: #146737]
        - 20240510@Aries: Enhance SOP-Refund for Soccer's Early results [Redmine:#201462]

    Param's Explanation: 
        + @Results: 'H,1,X,NL,...'  NL: Blank result of Bettype 216 
        + @ResourceResult
                    <Results>
                        <Resource Id="" HomeValue="" SettlementStatusId="" ResultStatusId=""/>
                    </Results>

		+ @SelectedResources: <Resources>
						    	<Resource Id="" Home="" Away="" />
						    	<Resource Id="" Home="" Away="" />
						      </Resources>
*/
BEGIN
    SET NOCOUNT ON 
     
    DECLARE @sporttype          INT
        ,@OtherInfo             VARCHAR(50)
        ,@GoalSequence          VARCHAR(50)
        ,@betstatus             NVARCHAR(50) 
        ,@SettlementStatusID    TINYINT 
        ,@ResultStatusID        TINYINT
        ,@xmlResourceResult     XML
		,@xmlSelectedResources  XML
		,@IsMatchPenalty		BIT
        
    DECLARE @tmpResultDetail TABLE(
            ResourceID              VARCHAR(20)
            ,HomeValue              VARCHAR(50)
            ,AwayValue              VARCHAR(50)
            ,ResultStatusId         TINYINT
            ,SettlementStatusId     TINYINT
            ,SourceType             BIT DEFAULT(0) -- 0: DB, 1: Web
			,IsDetermined			BIT DEFAULT(0)
    )
    
    SELECT  @sporttype  = Sporttype 
            ,@GoalSequence  = GoalRecord
            ,@betstatus = betstatus
			,@IsMatchPenalty = CASE WHEN ChildMatchType = 202 THEN 1 ELSE 0 END
    FROM    dbo.Match WITH (NOLOCK)
    WHERE   MatchID = @MatchID
    
    IF @sporttype <> 1 RETURN -- Apply for Soccer ONLY

    -- 14, 127, GoalRecord bettypes
    IF @ResourceResult IS NOT NULL
    BEGIN
        SET @xmlResourceResult = CAST(@ResourceResult AS XML)

        ;WITH cteResourceResult
        AS
        (
            SELECT  T.C.value('@Id', 'VARCHAR(50)') AS ResourceId
                    ,T.C.value('@HomeValue', 'VARCHAR(50)') AS HomeValue
                    ,T.C.value('@AwayValue', 'VARCHAR(50)') AS AwayValue
                    ,T.C.value('@SettlementStatusId', 'TINYINT') AS SettlementStatusId
                    ,T.C.value('@ResultStatusId', 'TINYINT') AS ResultStatusId
            FROM    @xmlResourceResult.nodes('/Results/Resource') AS T(C)
        )
        INSERT INTO @tmpResultDetail(ResourceID, HomeValue, AwayValue, SettlementStatusId, ResultStatusId, SourceType)
        SELECT   ResourceId, HomeValue, AwayValue, SettlementStatusId, ResultStatusId, 1
        FROM    cteResourceResult
        WHERE   ResourceID IS NOT NULL
        OPTION ( OPTIMIZE FOR ( @xmlResourceResult = NULL ) )   
    END 
    
	IF @SelectedResources IS NOT NULL
	BEGIN
		SET @xmlSelectedResources = CAST(@SelectedResources AS XML)

        ;WITH cteSelectedResources
        AS
        (
            SELECT  T.C.value('@Id', 'VARCHAR(50)') AS ResourceId
                    ,T.C.value('@Home', 'VARCHAR(50)') AS HomeValue
					,T.C.value('@Away', 'VARCHAR(50)') AS AwayValue
					,T.C.value('@IsDetermined', 'BIT') AS IsDetermined
            FROM    @xmlSelectedResources.nodes('/Resources/Resource') AS T(C)
        )
        INSERT INTO @tmpResultDetail(ResourceID, HomeValue, AwayValue,IsDetermined)
        SELECT   ResourceId, HomeValue, AwayValue,IsDetermined
        FROM    cteSelectedResources 
	END

    IF @Command ='NAP_Admin_Settlement_Auto_1s-CAL'
    BEGIN
        IF @IsAuto = 1 
        BEGIN
            UPDATE  ResultDetail WITH (UPDLOCK,ROWLOCK)
            SET      ResultStatusID     = 2     -- Auto Settlement 
                    ,SettlementStatusID = 4     -- Completed
                    ,LastModifyBy       = @Creator 
                    ,LastModifyDate     = GETDATE() 
            WHERE   MatchID = @MatchID
                    AND ResourceID IN (SELECT ResourceID FROM @tmpResultDetail)
        END
        ELSE IF @IsAuto = 0 
        BEGIN 
            MERGE   ResultDetail AS TARGET
            USING(
                SELECT   @MatchID AS MatchID
                        ,r.ResourceID 
                        ,r.HomeValue
						,r.AwayValue
                FROM    @tmpResultDetail r 
            ) AS SOURCE 
				ON	TARGET.MatchID = SOURCE.MatchID 
					AND TARGET.ResourceID = SOURCE.ResourceID
            WHEN    MATCHED THEN                 
                    UPDATE SET
                        TARGET.HomeValue            = SOURCE.HomeValue
						,TARGET.AwayValue			= SOURCE.AwayValue
                        ,TARGET.ResultStatusID      = 5     -- Manual Settlement 
                        ,TARGET.SettlementStatusID  = 4     -- Completed
                        ,TARGET.LastModifyBy        = @Creator 
                        ,TARGET.LastModifyDate      = GETDATE() 
            WHEN    NOT MATCHED BY TARGET THEN 
                    INSERT(
                         MatchID
                        ,ResourceID
                        ,HomeValue
						,AwayValue
                        ,ResultStatusID
                        ,SettlementStatusID
                        ,CreateBy
                        ,CreateDate
                        ,LastModifyBy
                        ,LastModifyDate
                    )
                    VALUES(
                         SOURCE.MatchID
                        ,SOURCE.ResourceID
                        ,SOURCE.HomeValue
						,SOURCE.AwayValue
                        ,5 -- Manual Settlement 
                        ,4 -- Completed
                        ,@Creator
                        ,GETDATE()
                        ,@Creator
                        ,GETDATE()
                    );      
        END

    END 
    /* END - @Command = 'NAP_Admin_Settlement_Auto_1s-CAL' */
    ELSE IF @Command ='NAP_Admin_Settlement_Auto_1s-UNDO'
    BEGIN
        UPDATE  ResultDetail WITH (UPDLOCK,ROWLOCK)
        SET      HomeValue          = NULL 
                ,AwayValue          = NULL 
                ,OtherInfo          = NULL 
                ,ResultStatusID     = 0     -- Initial 
                ,SettlementStatusID = 0     -- Initial
                ,ResultSetting      = ISNULL(ResultSetting,0) & (~6) 
                ,LastModifyBy       = @Creator 
                ,LastModifyDate     = GETDATE() 
        WHERE   MatchID = @MatchID
                AND ResourceID IN (SELECT ResourceID FROM @tmpResultDetail)

        DELETE 
		FROM dbo.ProviderExternalResultDetail 
		WHERE MatchId = @MatchId 
			AND SourceId = 99
            AND ResourceID IN (SELECT ResourceID FROM @tmpResultDetail)
    END
    /* END - @Command = 'NAP_Admin_Settlement_Auto_1s-UNDO' */
    ELSE IF @Command ='NAP_Admin_Settlement_Auto_1s-REFUND'
    BEGIN
        MERGE   ResultDetail AS TARGET
        USING   @tmpResultDetail AS SOURCE ON TARGET.MatchID = @MatchID AND TARGET.ResourceID = SOURCE.ResourceID 
        WHEN MATCHED THEN 
                UPDATE SET
                     TARGET.ResultStatusID      = 5
                    ,TARGET.SettlementStatusID  = CASE WHEN SOURCE.IsDetermined = 1 THEN 7 ELSE 1 END
                    ,TARGET.ResultSetting       = ISNULL(TARGET.ResultSetting,0) & (~6) 
					,TARGET.HomeValue           = CASE WHEN @IsMatchPenalty = 0 THEN TARGET.HomeValue
														ELSE 
															CASE WHEN (SOURCE.IsDetermined = 1 OR SOURCE.ResourceID LIKE '38[12]0[12345]') THEN SOURCE.HomeValue 
																ELSE NULL 
															END
													END
                    ,TARGET.AwayValue           = CASE WHEN @IsMatchPenalty = 0 THEN TARGET.AwayValue
														ELSE 
															CASE WHEN (SOURCE.IsDetermined = 1 OR SOURCE.ResourceID LIKE '38[12]0[12345]') THEN SOURCE.AwayValue 
																ELSE NULL 
															END
													END
                    ,TARGET.LastModifyBy        = @Creator
                    ,TARGET.LastModifyDate      = GETDATE()
        WHEN NOT MATCHED BY TARGET THEN 
                INSERT(
                         MatchID
                        ,ResourceID
                        ,HomeValue
                        ,AwayValue
                        ,OtherInfo 
                        ,ResultStatusID
                        ,SettlementStatusID
                        ,ResultSetting   
                        ,CreateBy
                        ,CreateDate
                        ,LastModifyBy
                        ,LastModifyDate
                    )
                    VALUES(
                         @MatchID
                        ,SOURCE.ResourceID
                        ,CASE WHEN (SOURCE.IsDetermined = 1 OR SOURCE.ResourceID LIKE '38[12]0[12345]') THEN SOURCE.HomeValue ELSE NULL END
                        ,CASE WHEN (SOURCE.IsDetermined = 1 OR SOURCE.ResourceID LIKE '38[12]0[12345]') THEN SOURCE.AwayValue ELSE NULL END
                        ,NULL 
                        ,5 -- Manual Settlement 
                        ,CASE WHEN SOURCE.IsDetermined = 1 THEN 7 ELSE 1 END -- Refund
                        ,0
                        ,@Creator
                        ,GETDATE()
                        ,@Creator
                        ,GETDATE()
                    );      

        DELETE 
		FROM dbo.ProviderExternalResultDetail 
		WHERE MatchId = @MatchId 
			AND SourceId = 99
            AND ResourceID IN (SELECT ResourceID FROM @tmpResultDetail)
    END 
    /* END - @Command = 'NAP_Admin_Settlement_Auto_1s-REFUND' */
    ELSE IF @Command = 'NAP_Admin_Settlement_1-CAL'
    BEGIN
        -- HalfTime
        INSERT INTO @tmpResultDetail(ResourceID,HomeValue,AwayValue)
        SELECT '01', CAST(@hth AS VARCHAR(50)), CAST(@hta AS VARCHAR(50))
       
        -- FullTime 
        UNION ALL 
        SELECT'00', CAST(@fth AS VARCHAR(50)), CAST(@fta AS VARCHAR(50)) WHERE @fth IS NOT NULL AND @fta IS NOT NULL 
       
        UPDATE @tmpResultDetail
            SET SettlementStatusID = 4 -- Completed
                ,ResultStatusID = 5 -- Manual Settlement
        WHERE   SourceType = 0
        
        MERGE   ResultDetail AS TARGET
        USING   @tmpResultDetail AS SOURCE ON (TARGET.MatchID = @MatchID AND TARGET.ResourceID = SOURCE.ResourceID)
        WHEN    MATCHED THEN                 
                UPDATE SET
                    TARGET.HomeValue            = SOURCE.HomeValue
                    ,TARGET.AwayValue           = SOURCE.AwayValue  
                    ,TARGET.OtherInfo           = NULL
                    ,TARGET.ResultStatusID      = CASE 
                                                    WHEN TARGET.ResourceId = '01' AND @betstatus LIKE '%Refund HT%' THEN TARGET.ResultStatusID 
                                                    ELSE SOURCE.ResultStatusID END
                    ,TARGET.SettlementStatusID  =  CASE 
                                                    WHEN TARGET.ResourceId = '01' AND @betstatus LIKE '%Refund HT%' THEN TARGET.SettlementStatusID 
                                                    ELSE SOURCE.SettlementStatusID END
                    ,TARGET.LastModifyBy        = @Creator 
                    ,TARGET.LastModifyDate      = GETDATE() 
        WHEN    NOT MATCHED BY TARGET THEN 
                INSERT(
                     MatchID
                    ,ResourceID
                    ,HomeValue
                    ,AwayValue
                    ,OtherInfo 
                    ,ResultStatusID
                    ,SettlementStatusID
                    ,CreateBy
                    ,CreateDate
                    ,LastModifyBy
                    ,LastModifyDate
                )
                VALUES(
                     @MatchID
                    ,SOURCE.ResourceID
                    ,SOURCE.HomeValue
                    ,SOURCE.AwayValue 
                    ,NULL 
                    ,SOURCE.ResultStatusID
                    ,SOURCE.SettlementStatusID
                    ,@Creator
                    ,GETDATE()
                    ,@Creator
                    ,GETDATE()
                );   

    END
    /* END - @Command = 'NAP_Admin_Settlement_1-CAL' */
    ELSE IF @Command = 'NAP_Admin_Settlement_1-UNDO'
    BEGIN
        UPDATE ResultDetail WITH (UPDLOCK,ROWLOCK)
        SET     HomeValue           = CASE WHEN ResourceID IN ('08','09') THEN '' ELSE NULL END 
                ,AwayValue          = NULL
                ,ResultStatusID     = 0     -- Initial 
                ,SettlementStatusID = 0     -- Initial
                ,LastModifyBy       = @Creator 
                ,LastModifyDate     = GETDATE() 
        WHERE   MatchID = @MatchID
                AND ResourceID IN ('00','01','08','09','14F','14L','127F','127L')

    END
    /* END - @Command = 'NAP_Admin_Settlement_1-UNDO' */
    ELSE IF @Command = 'NAP_Admin_Settlement_Refund-All'
    BEGIN
        SELECT   @fth           = finalhomescore
                ,@fta           = finalawayscore
                ,@hth           = hthomescore
                ,@hta           = htawayscore 
                ,@GoalSequence  = GoalRecord
        FROM    Match WITH (NOLOCK)
        WHERE   MatchID = @MatchID

        INSERT INTO @tmpResultDetail(ResourceID,HomeValue,AwayValue)

        SELECT'00', CAST(@fth AS VARCHAR(50)), CAST(@fta AS VARCHAR(50)) 

        IF @Action IN ('CAL-HT', 'CAL', 'REFUND', 'REFUND-HT')
	    BEGIN
		    INSERT INTO @tmpResultDetail(ResourceID,HomeValue,AwayValue)
		    
	        SELECT '01', CAST(@hth AS VARCHAR(50)), CAST(@hta AS VARCHAR(50))
        END
        
        UPDATE @tmpResultDetail
            SET SettlementStatusID = CASE WHEN ResourceID = '01' AND @Action IN('CAL-HT', 'REFUND-HT') THEN 2 ELSE 1 END -- Refund
                ,ResultStatusID = 5 -- Manual Settlement
        WHERE   SourceType = 0
        
        MERGE   ResultDetail AS TARGET
        USING   @tmpResultDetail AS SOURCE ON (TARGET.MatchID = @MatchID AND TARGET.ResourceID = SOURCE.ResourceID)
        WHEN    MATCHED THEN                 
                UPDATE SET
                    TARGET.HomeValue            = SOURCE.HomeValue
                    ,TARGET.AwayValue           = SOURCE.AwayValue  
                    ,TARGET.OtherInfo           = NULL
                    ,TARGET.ResultStatusID      = SOURCE.ResultStatusID
                    ,TARGET.SettlementStatusID  = SOURCE.SettlementStatusID
                    ,TARGET.LastModifyBy        = @Creator 
                    ,TARGET.LastModifyDate      = GETDATE() 
        WHEN    NOT MATCHED BY TARGET THEN 
                INSERT(
                     MatchID
                    ,ResourceID
                    ,HomeValue
                    ,AwayValue
                    ,OtherInfo 
                    ,ResultStatusID
                    ,SettlementStatusID
                    ,CreateBy
                    ,CreateDate
                    ,LastModifyBy
                    ,LastModifyDate
                )
                VALUES(
                     @MatchID
                    ,SOURCE.ResourceID
                    ,SOURCE.HomeValue
                    ,SOURCE.AwayValue 
                    ,NULL 
                    ,SOURCE.ResultStatusID -- Manual Settlement 
                    ,SOURCE.SettlementStatusID -- Refund
                    ,@Creator
                    ,GETDATE()
                    ,@Creator
                    ,GETDATE()
                );   
    END 
    /* END - @Command = 'NAP_Admin_Settlement_Refund-All' */
    
    ELSE IF @Command ='NAP_Admin_Settlement_Refund-All-ABANDONED'
    BEGIN
        
        INSERT INTO @tmpResultDetail(ResourceID,HomeValue,AwayValue)
        SELECT '00', NULL, NULL
        UNION ALL
        SELECT '01', CAST(@hth AS VARCHAR(50)), CAST(@hta AS VARCHAR(50))         
                    
        UPDATE @tmpResultDetail
            SET SettlementStatusID = 5 -- ABANDONED 1H
                ,ResultStatusID = 5 -- Manual Settlement    
        WHERE SourceType = 0            
                            
        MERGE   dbo.ResultDetail AS TARGET
        USING   @tmpResultDetail AS SOURCE ON (TARGET.MatchID = @MatchID AND TARGET.ResourceID = SOURCE.ResourceID)
        WHEN    MATCHED THEN                 
                UPDATE SET
                    TARGET.HomeValue            = CASE WHEN SOURCE.HomeValue  = 'NA' THEN TARGET.HomeValue ELSE SOURCE.HomeValue END
                    ,TARGET.AwayValue           = CASE WHEN SOURCE.AwayValue  = 'NA' THEN TARGET.AwayValue ELSE SOURCE.AwayValue END
                    ,TARGET.OtherInfo           = CASE WHEN SOURCE.ResourceID  = '01' THEN TARGET.OtherInfo ELSE NULL END
                    ,TARGET.ResultStatusID      = SOURCE.ResultStatusID     
                    ,TARGET.SettlementStatusID  = SOURCE.SettlementStatusID     
                    ,TARGET.LastModifyBy        = @Creator 
                    ,TARGET.LastModifyDate      = GETDATE() 
        WHEN    NOT MATCHED BY TARGET THEN 
                INSERT(
                     MatchID
                    ,ResourceID
                    ,HomeValue
                    ,AwayValue
                    ,OtherInfo 
                    ,ResultStatusID
                    ,SettlementStatusID
                    ,CreateBy
                    ,CreateDate
                    ,LastModifyBy
                    ,LastModifyDate
                )
                VALUES(
                     @MatchID
                    ,SOURCE.ResourceID
                    ,CASE WHEN SOURCE.HomeValue = 'NA' THEN NULL ELSE SOURCE.HomeValue END
                    ,CASE WHEN SOURCE.AwayValue = 'NA' THEN NULL ELSE SOURCE.AwayValue END
                    ,NULL 
                    ,SOURCE.ResultStatusID      
                    ,SOURCE.SettlementStatusID
                    ,@Creator
                    ,GETDATE()
                    ,@Creator
                    ,GETDATE()
                );          
        
        -- UPDATE OtherInfo
        SELECT @OtherInfo = ISNULL(OtherInfo,'')
        FROM dbo.ResultDetail WITH(NOLOCK)
        WHERE matchid       = @matchid 
            AND ResourceID  = '01' --HT
        
        SET @OtherInfo = CASE 
                            WHEN CHARINDEX('SDT:',@OtherInfo) > 0 THEN REPLACE(@OtherInfo,SUBSTRING(@OtherInfo,CHARINDEX('SDT:',@OtherInfo) + 4, 1),CAST(ISNULL(@SDTRecord,0) AS VARCHAR(50))) 
                            ELSE @OtherInfo + 'SDT:' + CAST(ISNULL(@SDTRecord,0) AS VARCHAR(50)) + ';'  
                        END
        
        UPDATE dbo.ResultDetail WITH(ROWLOCK,UPDLOCK)
        SET OtherInfo       =  @OtherInfo
        WHERE matchid       = @matchid 
            AND ResourceID  = '01' -- ABANDONED 1H
            
    END
    /* END - @Command = 'NAP_Admin_Settlement_Refund_All-ABANDONED' */
    ELSE IF @Command ='NAP_Admin_Settlement_Refund-FT'
    BEGIN
        SELECT   @fth           = finalhomescore
                ,@fta           = finalawayscore
                ,@betstatus     = betstatus
        FROM    Match WITH (NOLOCK)
        WHERE   MatchID = @MatchID

        INSERT INTO @tmpResultDetail(ResourceID,HomeValue,AwayValue)

        SELECT'00', CAST(@fth AS VARCHAR(50)), CAST(@fta AS VARCHAR(50)) 
        
        UPDATE @tmpResultDetail
            SET SettlementStatusID = CASE WHEN CHARINDEX('Refund;', @betstatus) > 0 THEN 1 
                                           WHEN CHARINDEX('Refund FT;',@betstatus) > 0 THEN 3 
                                           ELSE 3 
                                       END --Refund FT 
                ,ResultStatusID = 5 -- Manual Settlement    
        WHERE SourceType = 0        

        MERGE   ResultDetail AS TARGET
        USING   @tmpResultDetail AS SOURCE ON (TARGET.MatchID = @MatchID AND TARGET.ResourceID = SOURCE.ResourceID)
        WHEN    MATCHED THEN                 
                UPDATE SET
                    TARGET.HomeValue            = SOURCE.HomeValue
                    ,TARGET.AwayValue           = SOURCE.AwayValue  
                    ,TARGET.OtherInfo           = NULL
                    ,TARGET.ResultStatusID      = SOURCE.ResultStatusID
                    ,TARGET.SettlementStatusID  = SOURCE.SettlementStatusID -- Refund/RefundFT
                    ,TARGET.LastModifyBy        = @Creator 
                    ,TARGET.LastModifyDate      = GETDATE() 
        WHEN    NOT MATCHED BY TARGET THEN 
                INSERT(
                     MatchID
                    ,ResourceID
                    ,HomeValue
                    ,AwayValue
                    ,OtherInfo 
                    ,ResultStatusID
                    ,SettlementStatusID
                    ,CreateBy
                    ,CreateDate
                    ,LastModifyBy
                    ,LastModifyDate
                )
                VALUES(
                     @MatchID
                    ,SOURCE.ResourceID
                    ,SOURCE.HomeValue
                    ,SOURCE.AwayValue 
                    ,NULL 
                    ,SOURCE.ResultStatusID
                    ,SOURCE.SettlementStatusID -- Refund/RefundFT
                    ,@Creator
                    ,GETDATE()
                    ,@Creator
                    ,GETDATE()
                );   
    END 
    /* END - @Command = ''NAP_Admin_Settlement_Refund-FT' */
    ELSE IF @Command ='NAP_Admin_Settlement_RefundFT-ABANDONED'
    BEGIN
                
        INSERT INTO @tmpResultDetail(ResourceID,HomeValue,AwayValue)
        --SELECT '00', 'NA', 'NA'
        SELECT'00', CAST(@fth AS VARCHAR(50)), CAST(@fta AS VARCHAR(50)) 
       
        UPDATE @tmpResultDetail
            SET SettlementStatusID = 6 -- ABANDONED 2H                              
                ,ResultStatusID = 5 -- Manual Settlement 
        WHERE   SourceType = 0
                
        MERGE   dbo.ResultDetail AS TARGET
        USING   @tmpResultDetail AS SOURCE ON (TARGET.MatchID = @MatchID AND TARGET.ResourceID = SOURCE.ResourceID)
        WHEN    MATCHED THEN                 
                UPDATE SET
                    TARGET.HomeValue            = CASE WHEN SOURCE.HomeValue  = 'NA' THEN TARGET.HomeValue ELSE SOURCE.HomeValue END
                    ,TARGET.AwayValue           = CASE WHEN SOURCE.AwayValue  = 'NA' THEN TARGET.AwayValue ELSE SOURCE.AwayValue END
                    ,TARGET.OtherInfo           = CASE WHEN SOURCE.ResourceID  = '00' THEN TARGET.OtherInfo ELSE NULL END
                    ,TARGET.ResultStatusID      = SOURCE.ResultStatusID     
                    ,TARGET.SettlementStatusID  = SOURCE.SettlementStatusID     
                    ,TARGET.LastModifyBy        = @Creator 
                    ,TARGET.LastModifyDate      = GETDATE() 
        WHEN    NOT MATCHED BY TARGET THEN 
                INSERT(
                     MatchID
                    ,ResourceID
                    ,HomeValue
                    ,AwayValue
                    ,OtherInfo 
                    ,ResultStatusID
                    ,SettlementStatusID
                    ,CreateBy
                    ,CreateDate
                    ,LastModifyBy
                    ,LastModifyDate
                )
                VALUES(
                     @MatchID
                    ,SOURCE.ResourceID
                    ,CASE WHEN SOURCE.HomeValue = 'NA' THEN NULL ELSE SOURCE.HomeValue END
                    ,CASE WHEN SOURCE.AwayValue = 'NA' THEN NULL ELSE SOURCE.AwayValue END
                    ,NULL 
                    ,SOURCE.ResultStatusID      
                    ,SOURCE.SettlementStatusID      
                    ,@Creator
                    ,GETDATE()
                    ,@Creator
                    ,GETDATE()
                );  
        
        --UPDATE OtherInfo
        SELECT @OtherInfo = ISNULL(OtherInfo,'')
        FROM dbo.ResultDetail WITH(NOLOCK)
        WHERE matchid       = @matchid 
            AND ResourceID  = '00' --FT
        
        SET @OtherInfo = CASE 
                            WHEN CHARINDEX('SDT:',@OtherInfo) > 0 THEN REPLACE(@OtherInfo,SUBSTRING(@OtherInfo,CHARINDEX('SDT:',@OtherInfo) + 4, 1),CAST(ISNULL(@SDTRecord,0) AS VARCHAR(50))) 
                            ELSE @OtherInfo + 'SDT:' + CAST(ISNULL(@SDTRecord,0) AS VARCHAR(50)) + ';'  
                        END
        
        UPDATE dbo.ResultDetail WITH(ROWLOCK,UPDLOCK)
        SET OtherInfo       = @OtherInfo
        WHERE matchid       = @matchid 
            AND ResourceID  = '00' -- ABANDONED 2H
            
    END
    /* END - @Command = 'NAP_Admin_Settlement_RefundFT-ABANDONED' */
    ELSE IF @Command ='NAP_Admin_Settlement_Refund-HT'
    BEGIN
        SELECT   @hth           = hthomescore
                ,@hta           = htawayscore
                ,@betstatus     = betstatus
        FROM    Match WITH (NOLOCK)
        WHERE   MatchID = @MatchID

        INSERT INTO @tmpResultDetail(ResourceID,HomeValue,AwayValue)
        SELECT'01', CAST(@hth AS VARCHAR(50)), CAST(@hta AS VARCHAR(50)) 
        
        UPDATE @tmpResultDetail
            SET SettlementStatusID = 2 --Refund HT                          
                ,ResultStatusID = 5 -- Manual Settlement 
        WHERE   SourceType = 0
        
        MERGE   ResultDetail AS TARGET
        USING   @tmpResultDetail AS SOURCE ON (TARGET.MatchID = @MatchID AND TARGET.ResourceID = SOURCE.ResourceID)
        WHEN    MATCHED THEN                 
                UPDATE SET
                    TARGET.HomeValue            = SOURCE.HomeValue
                    ,TARGET.AwayValue           = SOURCE.AwayValue  
                    ,TARGET.OtherInfo           = NULL
                    ,TARGET.ResultStatusID      = SOURCE.ResultStatusID     
                    ,TARGET.SettlementStatusID  = SOURCE.SettlementStatusID -- Refund/RefundHT
                    ,TARGET.LastModifyBy        = @Creator 
                    ,TARGET.LastModifyDate      = GETDATE() 
        WHEN    NOT MATCHED BY TARGET THEN 
                INSERT(
                     MatchID
                    ,ResourceID
                    ,HomeValue
                    ,AwayValue
                    ,OtherInfo 
                    ,ResultStatusID
                    ,SettlementStatusID
                    ,CreateBy
                    ,CreateDate
                    ,LastModifyBy
                    ,LastModifyDate
                )
                VALUES(
                     @MatchID
                    ,SOURCE.ResourceID
                    ,SOURCE.HomeValue
                    ,SOURCE.AwayValue 
                    ,NULL 
                    ,SOURCE.ResultStatusID
                    ,SOURCE.SettlementStatusID -- Refund/RefundHT
                    ,@Creator
                    ,GETDATE()
                    ,@Creator
                    ,GETDATE()
                );   
    END 
    /* END - @Command = 'NAP_Admin_Settlement_Refund-HT' */

    ELSE IF @Command = 'CalByResourceId'
    BEGIN
        IF @ResourceResult IS NULL
            RETURN
            
        SELECT  @SettlementStatusID = 4
                ,@ResultStatusID = 5
                
        MERGE   ResultDetail AS TARGET
        USING   @tmpResultDetail AS SOURCE ON (TARGET.MatchID = @MatchID AND TARGET.ResourceID = SOURCE.ResourceID)
        WHEN    MATCHED THEN                 
                UPDATE SET
                    TARGET.HomeValue            = SOURCE.HomeValue
                    ,TARGET.AwayValue           = SOURCE.AwayValue  
                    ,TARGET.OtherInfo           = NULL
                    ,TARGET.ResultStatusID      = @ResultStatusID       
                    ,TARGET.SettlementStatusID  = @SettlementStatusID
                    ,TARGET.LastModifyBy        = @Creator 
                    ,TARGET.LastModifyDate      = GETDATE() 
        WHEN    NOT MATCHED BY TARGET THEN 
                INSERT(
                     MatchID
                    ,ResourceID
                    ,HomeValue
                    ,AwayValue
                    ,OtherInfo 
                    ,ResultStatusID
                    ,SettlementStatusID
                    ,CreateBy
                    ,CreateDate
                    ,LastModifyBy
                    ,LastModifyDate
                )
                VALUES(
                     @MatchID
                    ,SOURCE.ResourceID
                    ,SOURCE.HomeValue
                    ,SOURCE.AwayValue 
                    ,NULL 
                    ,@ResultStatusID
                    ,@SettlementStatusID
                    ,@Creator
                    ,GETDATE()
                    ,@Creator
                    ,GETDATE()
                );   
    END
    ELSE IF @Command = 'UndoByResouceId'
    BEGIN
        UPDATE  r  WITH (UPDLOCK,ROWLOCK)
        SET     HomeValue           = NULL
                ,AwayValue          = NULL
                ,ResultStatusID     = 0
                ,SettlementStatusID = 0
                ,LastModifyBy       = @Creator 
                ,LastModifyDate     = GETDATE() 
        FROM    dbo.ResultDetail r
            INNER JOIN @tmpResultDetail t 
                ON  r.ResourceID = t.ResourceID
        WHERE   r.MatchID = @MatchID
    END
	ELSE IF @Command = 'NAP_Admin_Settlement_1-Corner-UNDO'
    BEGIN
        UPDATE ResultDetail WITH (UPDLOCK,ROWLOCK)
			SET     HomeValue           = CASE WHEN ResourceID IN ('08','09') THEN '' ELSE NULL END 
					,AwayValue          = NULL
					,ResultStatusID     = 0     -- Initial 
					,SettlementStatusID = 0     -- Initial
					,LastModifyBy       = @Creator 
					,LastModifyDate     = GETDATE() 
        FROM    dbo.ResultDetail r
        WHERE   r.MatchID = @MatchID AND (r.ResourceID IN ('00','01','08','09','488','489','490') OR r.ResourceID LIKE '486%' OR r.ResourceID LIKE '487%')
    END
    ELSE IF @Command = 'NAP_Admin_Settlement_1-Corner-UNDO-FT'
    BEGIN
        UPDATE ResultDetail WITH (UPDLOCK,ROWLOCK)
			SET     HomeValue           = NULL  
					,AwayValue          = NULL
					,ResultStatusID     = 0     -- Initial 
					,SettlementStatusID = 0     -- Initial
					,LastModifyBy       = @Creator 
					,LastModifyDate     = GETDATE() 
        FROM    dbo.ResultDetail r
        WHERE   r.MatchID = @MatchID AND (r.ResourceID IN ('00','08','488','490') OR r.ResourceID LIKE '486%')
    END
END
GO
