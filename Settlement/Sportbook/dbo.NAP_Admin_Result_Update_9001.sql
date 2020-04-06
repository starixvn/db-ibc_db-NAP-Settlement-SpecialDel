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


AS 
/*
    Created: 20180803@Vicky
    Task: Update the result
    DB: DBPRO/bodb02 

    Revision
        - 20180803@Vicky: E-Sports 2.0 [Redmine:#95874] 
		- 20190924@Sol: Incorporate BMAIO - insert/update data to resultdetailOS [Redmine:#120324]
        - 20200320@Sol: Settlement with Ticket Exclusion for Other Sports - Tennis - [Redmine:#129316]
        
    Param's Explanation: 
    
       + @SelectedRID: <Resources>
					    	<Resource Id="M1" Home="1" Away="3" />
					    	<Resource Id="M2" Home="2" Away="4" />
					   </Resources>

*/
BEGIN
    SET NOCOUNT ON 

    DECLARE @tblSelectedRID TABLE (ResourceID VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50))
    DECLARE @handle INT, @SettlementStatusID INT, @ResultStatusID INT
    -------------END DECLARE    
    
    --parse XML   
    EXEC sp_xml_preparedocument @handle OUTPUT, @SelectedRID
    INSERT INTO @tblSelectedRID(ResourceID, HomeValue, AwayValue)
    SELECT DISTINCT  Id, Home, Away
    FROM OPENXML(@handle,'Resources/Resource',1)
    WITH(
            Id VARCHAR(20)
            ,Home varchar(50)
            ,Away varchar(50)
        ) tbl
        
    EXEC sp_xml_removedocument @handle
    
    IF @action = 'CAL'
    BEGIN
       SET @SettlementStatusID 	= 4
       SET @ResultStatusID 		= 5
    END 
    ELSE IF @action = 'UNDO'
    BEGIN
	   SET @ResultStatusID      = 0     -- Initial 
       SET @SettlementStatusID  = 0     -- Initial
    END 
    ELSE IF @action = 'REFUND'
    BEGIN
	   SET @SettlementStatusID 	= 1
       SET @ResultStatusID 		= 5   
       
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
    IF @Sporttype = 43
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
	
	    WHEN NOT MATCHED BY TARGET THEN
	        INSERT (MatchId, ResourceId,        HomeValue,        AwayValue,        ResultStatusID,  SettlementStatusID, CreateDate, LastModifyDate, CreateBy, LastModifyBy)               
	        VALUES(@matchid, SOURCE.ResourceId, SOURCE.HomeValue, SOURCE.AwayValue, @ResultStatusID, @SettlementStatusID, GETDATE(), GETDATE(),      @creator, @creator);
    END
	--Insert and update ResultDetailOS - Badminton
    ELSE IF @Sporttype = 9
    BEGIN
	    MERGE dbo.ResultDetailOS TARGET
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
	    WHEN NOT MATCHED BY TARGET THEN
	        INSERT (MatchId, ResourceId,        HomeValue,        AwayValue,        ResultStatusID,  SettlementStatusID, CreateDate, LastModifyDate, CreateBy, LastModifyBy)               
	        VALUES(@matchid, SOURCE.ResourceId, SOURCE.HomeValue, SOURCE.AwayValue, @ResultStatusID, @SettlementStatusID, GETDATE(), GETDATE(),      @creator, @creator);
    END 
    ELSE 
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
	
	    WHEN NOT MATCHED BY TARGET THEN
	        INSERT (MatchId, ResourceId,        HomeValue,        AwayValue,        ResultStatusID,  SettlementStatusID, CreateDate, LastModifyDate, CreateBy, LastModifyBy)               
	        VALUES(@matchid, SOURCE.ResourceId, SOURCE.HomeValue, SOURCE.AwayValue, @ResultStatusID, @SettlementStatusID, GETDATE(), GETDATE(),      @creator, @creator);
    END 
    
END 
GO
