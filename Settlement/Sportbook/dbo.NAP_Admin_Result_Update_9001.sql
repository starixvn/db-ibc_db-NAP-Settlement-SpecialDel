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
 ,@DeterminedType	TINYINT			   = 0

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
		- 20230315@Aries: Support Direct Payout for Child Tennis Matches [Redmine:#182330]
		- 20230328@Aries: Support Auto Payout for Main Tennis Matches [Redmine: #182329]
		- 20230515@Aries: Apply Settle Determined for Basketball [Redmine:#184124]
		- 20230817@Aries: Basketball - Enhance Generating Result 2H [Redmine:#192864]
		- 20230727@Aries: Basketball AIO  [Redmine:#191381]
		
    Param's Explanation: 
    
       + @SelectedRID: <Resources>
					    	<Resource Id="M1" Home="1" Away="3" />
					    	<Resource Id="M2" Home="2" Away="4" />
					   </Resources>

*/
BEGIN
    SET NOCOUNT ON 

	DECLARE @IsApplyRefundSOP	BIT
		   ,@AutoSetting		TINYINT
		   ,@HasAutoPayout		BIT = 0
		   ,@SDTResourceID		VARCHAR(20)

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

			,@q1homescore	INT
			,@q1awayscore	INT
			,@q2homescore	INT
			,@q2awayscore	INT
			,@q3homescore	INT
			,@q3awayscore	INT
			,@q4homescore	INT
			,@q4awayscore	INT

			,@hasQ1			TINYINT = 0
			,@hasQ2			TINYINT = 0
			,@hasQ3			TINYINT = 0
			,@hasQ4			TINYINT = 0
			,@hasHT			TINYINT = 0
			,@hasOT			TINYINT = 0
			,@has2H			TINYINT = 1
			
		
    -------------END DECLARE    
    
	SELECT @ResultTable =  r.ResultTable
		  ,@AutoSetting	=  ISNULL(r.Setting,0)
	FROM   dbo.SettlementResultTableSetting r WITH(NOLOCK)
	WHERE r.Sporttype = @SportType
		/*@ResultTable:
				1: ResultDetail
				2: ResultDetailOS
				3: ResultDetailES
		*/
	SET @HasAutoPayout = IIF(@AutoSetting & 2 > 0,1,0)
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

	IF @Sporttype = 2 AND @DeterminedType = 0
	BEGIN
		UPDATE @tblSelectedRID
		SET	HomeValue = CASE WHEN HomeValue + AwayValue = 0 THEN NULL ELSE HomeValue END
			,AwayValue = CASE WHEN HomeValue + AwayValue = 0 THEN NULL ELSE AwayValue END
		WHERE ResourceID = 'OT'
	END

    IF @action = 'CAL'
    BEGIN
       SET @SettlementStatusID 	=  4
       SET @ResultStatusID 		=  CASE WHEN @IsAuto = 1 AND @HasAutoPayout = 1 THEN 2 
										ELSE 5
										END
    END 
    ELSE IF @action = 'UNDO'
    BEGIN
	   SET @ResultStatusID      = 4
       SET @SettlementStatusID  = 0  -- Initial
    END 
    ELSE IF @action = 'REFUND' AND @DeterminedType = 0
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
	ELSE IF @action = 'REFUND' AND @DeterminedType > 0
    BEGIN
		SET @SettlementStatusID  = 1
		SET @ResultStatusID  = 5

		SELECT @SDTResourceID = sr.ResourceID
		FROM @tblSelectedRID AS sr
       		INNER JOIN dbo.f_Set_MajorRound(@Sporttype) AS sd ON sr.ResourceID = sd.ResourceID
		WHERE sr.HomeValue != '' 
			AND sr.AwayValue != ''
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
				,ResultSetting		 = CASE WHEN @IsApplyRefundSOP = 1 AND ( @Action LIKE 'UNDO%' OR @Action LIKE 'REFUND%' ) THEN ISNULL(ResultSetting,0) & (~6) --- Turn off bit[2] bit[3]
											ELSE ResultSetting END
	
	    WHEN NOT MATCHED BY TARGET AND @action <> 'UNDO' THEN
	        INSERT (MatchId, ResourceId,        HomeValue,        AwayValue,        ResultStatusID,  SettlementStatusID, CreateDate, LastModifyDate, CreateBy, LastModifyBy)               
	        VALUES(@matchid, SOURCE.ResourceId, SOURCE.HomeValue, SOURCE.AwayValue, @ResultStatusID, @SettlementStatusID, GETDATE(), GETDATE(),      @creator, @creator);
		
		IF @IsDirectly = 1
		BEGIN
			UPDATE r
				SET  r.HomeValue = ''
					,r.AwayValue = ''
					,r.SettlementStatusID = 0
					,r.ResultStatusID = 0
			FROM dbo.ResultDetail r
				INNER JOIN dbo.f_Set_MajorRound(@Sporttype) sd ON r.ResourceID = sd.ResourceID
			WHERE r.MatchID = @MatchID
				AND sd.AllowDirectly = 0
		END

		IF @action = 'UNDO' AND @Sporttype = 2
		BEGIN
			DELETE 
			FROM dbo.ProviderExternalResultDetail 
			WHERE MatchId = @MatchId 
				AND SourceId = 99
		END

		IF @Sporttype = 2 AND EXISTS (SELECT TOP 1 1 FROM @tblSelectedRID WHERE ResourceID = '00')
		BEGIN
			SELECT	@hthomescore = ISNULL(SUM(CASE WHEN rd.ResourceId = '01' THEN rd.HomeValue ELSE 0 END), 0)
					,@htawayscore = ISNULL(SUM(CASE WHEN rd.ResourceId = '01' THEN rd.AwayValue ELSE 0 END), 0)
					,@othomescore = ISNULL(SUM(CASE WHEN rd.ResourceId = 'OT' THEN rd.HomeValue ELSE 0 END), 0)
					,@otawayscore = ISNULL(SUM(CASE WHEN rd.ResourceId = 'OT' THEN rd.AwayValue ELSE 0 END), 0)

					,@q1homescore = ISNULL(SUM(CASE WHEN rd.ResourceId = 'Q1' THEN rd.HomeValue ELSE 0 END), 0)
					,@q1awayscore = ISNULL(SUM(CASE WHEN rd.ResourceId = 'Q1' THEN rd.AwayValue ELSE 0 END), 0)
					,@q2homescore = ISNULL(SUM(CASE WHEN rd.ResourceId = 'Q2' THEN rd.HomeValue ELSE 0 END), 0)
					,@q2awayscore = ISNULL(SUM(CASE WHEN rd.ResourceId = 'Q2' THEN rd.AwayValue ELSE 0 END), 0)
					,@q3homescore = ISNULL(SUM(CASE WHEN rd.ResourceId = 'Q3' THEN rd.HomeValue ELSE 0 END), 0)
					,@q3awayscore = ISNULL(SUM(CASE WHEN rd.ResourceId = 'Q3' THEN rd.AwayValue ELSE 0 END), 0)
					,@q4homescore = ISNULL(SUM(CASE WHEN rd.ResourceId = 'Q4' THEN rd.HomeValue ELSE 0 END), 0)
					,@q4awayscore = ISNULL(SUM(CASE WHEN rd.ResourceId = 'Q4' THEN rd.AwayValue ELSE 0 END), 0)

					,@hasQ1       = ISNULL(SUM(CASE WHEN rd.ResourceId = 'Q1' AND ISNULL(rd.HomeValue,'') != '' THEN 1 ELSE 0 END), 0)
					,@hasQ2       = ISNULL(SUM(CASE WHEN rd.ResourceId = 'Q2' AND ISNULL(rd.HomeValue,'') != '' THEN 1 ELSE 0 END), 0)
					,@hasQ3       = ISNULL(SUM(CASE WHEN rd.ResourceId = 'Q3' AND ISNULL(rd.HomeValue,'') != '' THEN 1 ELSE 0 END), 0)
					,@hasQ4       = ISNULL(SUM(CASE WHEN rd.ResourceId = 'Q4' AND ISNULL(rd.HomeValue,'') != '' THEN 1 ELSE 0 END), 0)
					,@hasHT       = ISNULL(SUM(CASE WHEN rd.ResourceId = '01' AND ISNULL(rd.HomeValue,'') != '' THEN 1 ELSE 0 END), 0)
					,@hasOT       = ISNULL(SUM(CASE WHEN rd.ResourceId = 'OT' AND ISNULL(rd.HomeValue,'') != '' THEN 1 ELSE 0 END), 0)
			FROM	dbo.ResultDetail rd WITH(NOLOCK)
			WHERE	rd.MatchId = @matchid
					AND rd.ResourceId IN ('Q1','Q2','Q3','Q4','00', '01', 'OT')
					AND rd.ResultStatusID IN (2,5)

			IF  @Action = 'CAL' AND @hasHT = 0
			BEGIN
				SET @has2H = 0
			END

			IF @action = 'REFUND'
			BEGIN
				DELETE
				FROM	dbo.ResultDetail WITH(ROWLOCK, UPDLOCK)
				WHERE	MatchId = @MatchID
					AND ResourceId = 'OT'
					AND (ISNULL(HomeValue,'') = '' OR @DeterminedType = 0)
			END

			IF @action = 'REFUND' AND @DeterminedType > 0
			BEGIN
				UPDATE dbo.ResultDetail
				SET  HomeValue = @q1homescore + @q2homescore
					,AwayValue = @q1awayscore + @q2awayscore
				WHERE MatchId = @MatchID 
					AND ResourceId = '01'
					AND @SDTResourceID IN ('Q1','Q2')
					AND ISNULL(HomeValue,'') = ''

				UPDATE dbo.ResultDetail
				SET  HomeValue = @q1homescore + @q2homescore + @q3homescore + @q4homescore + @othomescore
					,AwayValue = @q1awayscore + @q2awayscore + @q3awayscore + @q4awayscore + @otawayscore
				WHERE MatchId = @MatchID 
					AND ResourceId = '00'
					AND @SDTResourceID IN ('HT','Q3','Q4','OT')
					AND ISNULL(HomeValue,'') = ''

				UPDATE @tblSelectedRID
				SET HomeValue = @q1homescore + @q2homescore + @q3homescore + @q4homescore + @othomescore
				   ,AwayValue = @q1awayscore + @q2awayscore + @q3awayscore + @q4awayscore + @otawayscore
				WHERE ResourceId = '00'
					AND @SDTResourceID IN ('Q3','Q4','OT')
					AND ISNULL(HomeValue,'') = ''

				IF @hasQ1 = 0 AND @hasQ2 = 0 AND @hasHT = 0
				BEGIN
					SET @has2H = 0
					UPDATE dbo.ResultDetail
					SET	 SettlementStatusID = 0
						,ResultStatusID = 4
						,HomeValue = NULL
						,AwayValue = NULL
					WHERE MatchId = @matchid
						AND ResourceID = '02' 
				END
			END

			MERGE dbo.ResultDetail TARGET
			USING (
				SELECT  sr.ResourceId, sr.HomeValue, sr.AwayValue
				FROM    @tblSelectedRID sr
				WHERE	sr.ResourceID = '00'
					AND @has2H = 1
				) AS SOURCE ON  TARGET.ResourceId = '02' AND TARGET.MatchId = @matchid
			WHEN MATCHED THEN
				UPDATE SET HomeValue     = CASE WHEN @action = 'CAL' THEN SOURCE.HomeValue - @hthomescore
												WHEN @action = 'REFUND' AND @DeterminedType > 0 THEN IIF(SOURCE.HomeValue = '',NULL,SOURCE.HomeValue - @hthomescore )
												ELSE NULL 
										   END
					,AwayValue           = CASE WHEN @action = 'CAL'  THEN SOURCE.AwayValue - @htawayscore
												WHEN @action = 'REFUND' AND @DeterminedType > 0 THEN IIF(SOURCE.AwayValue = '',NULL,SOURCE.AwayValue - @htawayscore)
												ELSE NULL 
											END
					,ResultStatusID      = @ResultStatusID
					,SettlementStatusID  = @SettlementStatusID
					,LastModifyDate      = GETDATE()
					,LastModifyBy        = @creator
	
			WHEN NOT MATCHED BY TARGET THEN
				INSERT (MatchId, ResourceId, HomeValue, AwayValue, ResultStatusID,  SettlementStatusID, CreateDate, LastModifyDate, CreateBy, LastModifyBy)               
				VALUES(@matchid, '02'
					, CASE WHEN @action = 'CAL' THEN SOURCE.HomeValue - @hthomescore
						   WHEN @action = 'REFUND' AND @DeterminedType > 0 THEN IIF(SOURCE.HomeValue = '',NULL,SOURCE.HomeValue - @hthomescore)
						   ELSE NULL 
					  END
					, CASE  WHEN @action = 'CAL'  THEN SOURCE.AwayValue - @htawayscore
							WHEN @action = 'REFUND' AND @DeterminedType > 0 THEN IIF(SOURCE.AwayValue = '',NULL,SOURCE.AwayValue - @htawayscore)
							ELSE NULL 
					  END
					, @ResultStatusID, @SettlementStatusID, GETDATE(), GETDATE(), @creator, @creator);

			IF @action = 'REFUND' AND @DeterminedType > 0
			BEGIN
				UPDATE r
				SET  r.SettlementStatusID = 7
				FROM dbo.ResultDetail AS r
				WHERE r.MatchId = @matchid
					AND 1  = CASE WHEN r.ResourceId = @SDTResourceID THEN 1
								  WHEN r.ResourceId IN ('00') THEN 1
								  WHEN @SDTResourceID IN ('Q1','Q2') AND r.ResourceId IN ('01') THEN 1
								  WHEN @SDTResourceID IN ('Q3','Q4','OT','00') AND r.ResourceId IN ('02') AND @has2H = 1 THEN 1
								  ELSE 0
							 END
			END
		END
    END 
    
END 
GO