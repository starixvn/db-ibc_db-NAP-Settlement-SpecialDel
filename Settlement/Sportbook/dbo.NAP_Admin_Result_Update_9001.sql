/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_Admin_Result_Update_9001]
  @action           VARCHAR(100)       = ''
 ,@MatchID          INT
 ,@SelectedRID      VARCHAR(MAX)       = NULL
 ,@creator          INT                = 0 
 ,@Sporttype		SMALLINT
 ,@IsDirectly		BIT				   = 0 --- Apply for Basketball, Tennis, Badminton, E-Sports, Beach Volleyball
 ,@IsAuto			BIT				   = 0

AS 
/*
    Created: 20180803@Vicky
    Task: Update the result
    DB: DBPRO/bodb02 

    Revision
        - 20180803@Vicky: E-Sports 2.0 [Redmine:#95874] 
		- 20190924@Sol: Incorporate BMAIO - insert/update data to resultdetailOS [Redmine:#120324]
        - 20200320@Sol: Settlement with Ticket Exclusion for Other Sports - Tennis - [Redmine:#129316]
		- 20200701@Kathy: Settlement Enhancement for Basketball Phase 2 [Redmine:#135846]
        - 20200701@Kathy: Incorporate New Bet Types of Basketball - Phase 2 [Redmine:#135846]
		- 20210121@Kathy: Cricket AIO [Redmine:#148870]
		- 20210205@Louisa:Cricket AIO [Redmine:#148870]
		- 20210331@Louisa: Enhancement MultiSports page [Redmine:#151545]
		- 20210611@Louisa: Beach Volleyball [Redmine:#156541]
		- 20210729@Louisa: Auto Settle Cricket [Redmine:#154586]
		- 20210811@Louisa: SOP Refund for Tennis, E-Sports [Redmine:#159270]
		- 20210819@Louisa: Show Provider Results for remain sports [Redmine:#160192]
		- 20210906@Louisa: Settle by profile for Volleyball [Redmine:#160478]
		- 20211025@Louisa: SOP Refund for Badminton, Basketball, Cricket [Redmine:#163574]
		- 20220128@Louisa: Update OtherInfo [Redmine:#166335]
		- 20220329@Louisa: Extend data length for dbo.ResultDetailOS.OtherInfo [Redmine:#170406]
		- 20220309@Louisa: Auto settle Volleyball [Redmine:#168346]
		- 20220512@Louisa: Auto settle Badminton [Redmine:#171676]
		- 20221213@Kathy: Upgrade Auto Payout for Badminton & Volleyball [Redmine:#181458]
		
    Param's Explanation: 
    
       + @SelectedRID: <Resources>
					    	<Resource Id="M1" Home="1" Away="3" />
					    	<Resource Id="M2" Home="2" Away="4" />
					   </Resources>

*/
BEGIN
    SET NOCOUNT ON 

	DECLARE @IsApplyRefundSOP BIT

	SELECT @IsApplyRefundSOP =  CASE WHEN @Sporttype IN ( 2, 5, 6, 9, 43, 45,50) THEN 1
									 ELSE 0
									 END

	IF @Sporttype = 50
	BEGIN
		IF EXISTS ( SELECT TOP 1 1 FROM dbo.Match m WITH(NOLOCK) 
					WHERE	m.matchid = @MatchID 
							AND Sporttype = @Sporttype 
							AND ISNULL(ChildMatchType,0) = 200
							AND m.ParentID IS NOT NULl
		)
			RETURN
	END

    DECLARE @tblSelectedRID TABLE (ResourceID VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50), OtherInfo VARCHAR(2000) )
    DECLARE @handle INT, @SettlementStatusID INT, @ResultStatusID INT
	DECLARE @hthomescore INT
			,@htawayscore INT
			,@othomescore INT
			,@otawayscore INT
			,@ResultTable TINYINT = 0
		
    -------------END DECLARE    
    
	SELECT @ResultTable =  r.ResultTable
	FROM   dbo.SettlementResultTableSetting r WITH(NOLOCK)
	WHERE r.Sporttype = @SportType
		/*@ResultTable:
				1: ResultDetail
				2: ResultDetailOS
				3: ResultDetailES
		*/

    --parse XML   
    EXEC sp_xml_preparedocument @handle OUTPUT, @SelectedRID
    INSERT INTO @tblSelectedRID(ResourceID, HomeValue, AwayValue, OtherInfo)
    SELECT DISTINCT  Id, Home, Away, OtherInfo
    FROM OPENXML(@handle,'Resources/Resource',1)
    WITH(
            Id VARCHAR(20)
            ,Home varchar(50)
            ,Away varchar(50)
			,OtherInfo VARCHAR(2000)
        ) tbl
        
    EXEC sp_xml_removedocument @handle
    
	IF @Sporttype = 2
	BEGIN
		UPDATE @tblSelectedRID
		SET	HomeValue = CASE WHEN HomeValue + AwayValue = 0 THEN NULL ELSE HomeValue END
			,AwayValue = CASE WHEN HomeValue + AwayValue = 0 THEN NULL ELSE AwayValue END
		WHERE ResourceID = 'OT'
	END

    IF @action = 'CAL'
    BEGIN
       SET @SettlementStatusID 	=  4
       SET @ResultStatusID 		= CASE WHEN @IsAuto = 1 AND @Sporttype IN ( 6, 9, 50 ) THEN 2 
										ELSE 5
										END
    END 
    ELSE IF @action = 'UNDO'
    BEGIN
	   SET @ResultStatusID      = 4
       SET @SettlementStatusID  = 0  -- Initial
    END 
    ELSE IF @action = 'REFUND'
    BEGIN
	   SET @SettlementStatusID 	= 1
       SET @ResultStatusID 		= CASE WHEN @IsAuto = 1 THEN 2 
										ELSE 5   
										END
       
       UPDATE sr 
       SET HomeValue = '0'
       	   ,AwayValue = '0'
       FROM @tblSelectedRID sr
       		INNER JOIN dbo.f_Set_MajorRound(@Sporttype) sd ON sr.ResourceID = sd.ResourceID
    END 
    ELSE
    BEGIN
        ---set default value
        SET @SettlementStatusID = 4
        SET @ResultStatusID = 5
    END
    
    --Insert and update ResultDetail
    IF @ResultTable = 3
    BEGIN
	    MERGE dbo.ResultDetailES TARGET
	    USING (
	        SELECT  sr.ResourceId, sr.HomeValue, sr.AwayValue
	        FROM    @tblSelectedRID sr
	        ) AS SOURCE ON  TARGET.ResourceId = SOURCE.ResourceId AND TARGET.MatchId = @matchid
	    WHEN MATCHED THEN
	        UPDATE SET HomeValue     = SOURCE.HomeValue
	            ,AwayValue           = SOURCE.AwayValue
	            ,ResultStatusID      = @ResultStatusID
	            ,SettlementStatusID  = @SettlementStatusID
	            ,LastModifyDate      = GETDATE()
	            ,LastModifyBy        = @creator
				,ResultSetting		 = CASE WHEN @IsApplyRefundSOP = 1 AND (@Action LIKE 'UNDO%' OR @Action LIKE 'REFUND%') THEN ISNULL(ResultSetting,0) & (~2) --- Turn off bit[2]
											ELSE ResultSetting END
	
	    WHEN NOT MATCHED BY TARGET AND @action <> 'UNDO' THEN
	        INSERT (MatchId, ResourceId,        HomeValue,        AwayValue,        ResultStatusID,  SettlementStatusID, CreateDate, LastModifyDate, CreateBy, LastModifyBy)               
	        VALUES(@matchid, SOURCE.ResourceId, SOURCE.HomeValue, SOURCE.AwayValue, @ResultStatusID, @SettlementStatusID, GETDATE(), GETDATE(),      @creator, @creator);

		IF @IsDirectly = 1
		UPDATE r
			SET  r.HomeValue = ''
				,r.AwayValue = ''
				,r.SettlementStatusID = 0
				,r.ResultStatusID = 0
		FROM dbo.ResultDetailES r
			INNER JOIN dbo.f_Set_MajorRound(@Sporttype) sd ON r.ResourceID = sd.ResourceID
		WHERE r.MatchID = @MatchID
			AND sd.AllowDirectly = 0
    END
	--Insert and update ResultDetailOS - Badminton, Cricket, Beach Volleyball
    ELSE IF @ResultTable = 2
    BEGIN
	    MERGE dbo.ResultDetailOS TARGET
	    USING (
	        SELECT  sr.ResourceId, sr.HomeValue, sr.AwayValue, sr.OtherInfo
	        FROM    @tblSelectedRID sr
	        ) AS SOURCE ON  TARGET.ResourceId = SOURCE.ResourceId AND TARGET.MatchId = @matchid
	    WHEN MATCHED THEN
	        UPDATE SET HomeValue     = SOURCE.HomeValue
	            ,AwayValue           = SOURCE.AwayValue
	            ,ResultStatusID      = @ResultStatusID
	            ,SettlementStatusID  = @SettlementStatusID
	            ,LastModifyDate      = GETDATE()
	            ,LastModifyBy        = @creator
				,ResultSetting		 = CASE WHEN @IsApplyRefundSOP = 1 AND ( @Action LIKE 'UNDO%' OR @Action LIKE 'REFUND%' ) THEN ISNULL(ResultSetting,0) & (~2) --- Turn off bit[2]
											ELSE ResultSetting END
				,OtherInfo			 = CASE WHEN @Sporttype = 50 THEN CASE WHEN ( @Action LIKE 'UNDO%' OR @Action LIKE 'REFUND%' ) THEN ''
																			ELSE ISNULL(SOURCE.OtherInfo, TARGET.OtherInfo)
																			END
											END
	    WHEN NOT MATCHED BY TARGET AND @action <> 'UNDO' THEN
	        INSERT (MatchId, ResourceId,        HomeValue,        AwayValue,        ResultStatusID,  SettlementStatusID, CreateDate, LastModifyDate, CreateBy, LastModifyBy, OtherInfo)               
	        VALUES(@matchid, SOURCE.ResourceId, SOURCE.HomeValue, SOURCE.AwayValue, @ResultStatusID, @SettlementStatusID, GETDATE(), GETDATE(),      @creator, @creator, SOURCE.OtherInfo);

		IF @IsDirectly = 1
		UPDATE r
			SET  r.HomeValue = ''
				,r.AwayValue = ''
				,r.SettlementStatusID = 0
				,r.ResultStatusID = 0
		FROM dbo.ResultDetailOS r
			INNER JOIN dbo.f_Set_MajorRound(@Sporttype) sd ON r.ResourceID = sd.ResourceID
		WHERE r.MatchID = @MatchID
			AND sd.AllowDirectly = 0
    END 
    ELSE IF @ResultTable = 1 
    BEGIN
	    MERGE dbo.ResultDetail TARGET
	    USING (
	        SELECT  sr.ResourceId, sr.HomeValue, sr.AwayValue
	        FROM    @tblSelectedRID sr
	        ) AS SOURCE ON  TARGET.ResourceId = SOURCE.ResourceId AND TARGET.MatchId = @matchid
	    WHEN MATCHED THEN
	        UPDATE SET HomeValue     = SOURCE.HomeValue
	            ,AwayValue           = SOURCE.AwayValue
	            ,ResultStatusID      = @ResultStatusID
	            ,SettlementStatusID  = @SettlementStatusID
	            ,LastModifyDate      = GETDATE()
	            ,LastModifyBy        = @creator
				,ResultSetting		 = CASE WHEN @IsApplyRefundSOP = 1 AND ( @Action LIKE 'UNDO%' OR @Action LIKE 'REFUND%' ) THEN ISNULL(ResultSetting,0) & (~2) --- Turn off bit[2]
											ELSE ResultSetting END
	
	    WHEN NOT MATCHED BY TARGET AND @action <> 'UNDO' THEN
	        INSERT (MatchId, ResourceId,        HomeValue,        AwayValue,        ResultStatusID,  SettlementStatusID, CreateDate, LastModifyDate, CreateBy, LastModifyBy)               
	        VALUES(@matchid, SOURCE.ResourceId, SOURCE.HomeValue, SOURCE.AwayValue, @ResultStatusID, @SettlementStatusID, GETDATE(), GETDATE(),      @creator, @creator);
		
		IF @IsDirectly = 1
		UPDATE r
			SET  r.HomeValue = ''
				,r.AwayValue = ''
				,r.SettlementStatusID = 0
				,r.ResultStatusID = 0
		FROM dbo.ResultDetail r
			INNER JOIN dbo.f_Set_MajorRound(@Sporttype) sd ON r.ResourceID = sd.ResourceID
		WHERE r.MatchID = @MatchID
			AND sd.AllowDirectly = 0

		IF @Sporttype = 2 AND EXISTS (SELECT TOP 1 1 FROM @tblSelectedRID WHERE ResourceID = '00')
		BEGIN
			SELECT	@hthomescore = ISNULL(SUM(CASE WHEN rd.ResourceId = '01' THEN rd.HomeValue ELSE 0 END), 0)
					,@htawayscore = ISNULL(SUM(CASE WHEN rd.ResourceId = '01' THEN rd.AwayValue ELSE 0 END), 0)
					,@othomescore = ISNULL(SUM(CASE WHEN rd.ResourceId = 'OT' THEN rd.HomeValue ELSE 0 END), 0)
					,@otawayscore = ISNULL(SUM(CASE WHEN rd.ResourceId = 'OT' THEN rd.AwayValue ELSE 0 END), 0)
			FROM	dbo.ResultDetail rd WITH(NOLOCK)
			WHERE	rd.MatchId = @matchid
					AND rd.ResourceId IN ('00', '01', 'OT')

			IF @action = 'REFUND'
			BEGIN
				DELETE
				FROM	dbo.ResultDetail WITH(ROWLOCK, UPDLOCK)
				WHERE	MatchId = @MatchID
						AND ResourceId = 'OT'
			END

			MERGE dbo.ResultDetail TARGET
			USING (
				SELECT  sr.ResourceId, sr.HomeValue, sr.AwayValue
				FROM    @tblSelectedRID sr
				WHERE	sr.ResourceID = '00'
				) AS SOURCE ON  TARGET.ResourceId = '02' AND TARGET.MatchId = @matchid
			WHEN MATCHED THEN
				UPDATE SET HomeValue     = CASE WHEN @action = 'CAL' THEN SOURCE.HomeValue - @hthomescore - @othomescore ELSE 0 END
					,AwayValue           = CASE WHEN @action = 'CAL' THEN SOURCE.AwayValue - @htawayscore - @otawayscore ELSE 0 END
					,ResultStatusID      = @ResultStatusID
					,SettlementStatusID  = @SettlementStatusID
					,LastModifyDate      = GETDATE()
					,LastModifyBy        = @creator
	
			WHEN NOT MATCHED BY TARGET THEN
				INSERT (MatchId, ResourceId, HomeValue, AwayValue, ResultStatusID,  SettlementStatusID, CreateDate, LastModifyDate, CreateBy, LastModifyBy)               
				VALUES(@matchid, '02', CASE WHEN @action = 'CAL' THEN SOURCE.HomeValue - @hthomescore - @othomescore ELSE 0 END
					, CASE WHEN @action = 'CAL' THEN SOURCE.AwayValue - @htawayscore - @otawayscore ELSE 0 END
					, @ResultStatusID, @SettlementStatusID, GETDATE(), GETDATE(), @creator, @creator);
		END
    END 
    
END 
GO