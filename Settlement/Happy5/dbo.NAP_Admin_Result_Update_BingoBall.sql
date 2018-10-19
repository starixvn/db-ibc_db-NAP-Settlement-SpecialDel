/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Result_Update_BingoBall]
	@MatchID			INT
	,@Sporttype			SMALLINT
	,@Resources			VARCHAR(MAX) 
	,@ErrCode 			INT 			= 0 OUTPUT
	,@ErrMsg 			NVARCHAR(200) 	= '' OUTPUT

AS 
/*
	Created: 20181018@Vicky
	Task: Update BingoBall
	DB: DBPRO/bodb02 

	Revision
		- 20181016@Vicky: Incorporate Happy 5  [Redmine:#102844]

	Param's Explanation: 

		+ @Resources:   <Resources>
					    	<Resource Id="1" Result="1"/>
					    	<Resource Id="2" Result="2"/>
					    	<Resource Id="3" Result="3"/>
					    	<Resource Id="4" Result="4"/>
					    	<Resource Id="5" Result="5"/>
					    </Resources>

*/
BEGIN
    SET NOCOUNT ON 

    DECLARE @tblSelectedRID TABLE (ResourceID TINYINT, Result TINYINT)
    DECLARE @handle INT
    ---------------------------------------------------------------------------- 
    IF @MatchID IS NULL OR @Sporttype IS NULL OR @Resources IS NULL OR @Resources = ''
    BEGIN
	    SELECT @ErrCode = 1000002
	    	  ,@ErrMsg = 'Data is not valid'
	   	RETURN
    END 
    
    ----------------------------------------------------------------------------
    --parse XML   
    EXEC sp_xml_preparedocument @handle OUTPUT, @Resources
    INSERT INTO @tblSelectedRID(ResourceID, Result)
    SELECT DISTINCT  Id, Result
    FROM OPENXML(@handle,'Resources/Resource',1)
    WITH(
            Id TINYINT
            ,Result TINYINT
        ) tbl
    EXEC sp_xml_removedocument @handle
    
    ------------------------VALIDATE--------------------------------------------
    IF @Sporttype = 164
    BEGIN
	    SELECT @ErrCode = 1000002
	    		,@ErrMsg = 'Ball number must be from 1 to 20'
	    FROM @tblSelectedRID
	    WHERE Result < 1 OR Result > 20
	    	
	    SELECT @ErrCode = 1000002
	    		,@ErrMsg = 'Data is not valid'
	    FROM @tblSelectedRID
	    HAVING COUNT(*) <> 5
	    
	    SELECT @ErrCode = 1000002
	    		,@ErrMsg = 'Duplicate ball numbers'
	    FROM @tblSelectedRID
	    GROUP BY Result
	    HAVING COUNT(Result) > 1
    END 

    IF @ErrCode <> 0
    	RETURN
    	
    ----------------------------------------------------------------------------
    --Insert and update BingoBall
    MERGE dbo.BingoBall TARGET
    USING (
        SELECT  sr.ResourceId, sr.Result
        FROM    @tblSelectedRID sr
        ) AS SOURCE ON  TARGET.Seq = SOURCE.ResourceId AND TARGET.MatchId = @matchid
    WHEN MATCHED THEN
        UPDATE SET Number     			 = SOURCE.Result
            	   ,UpdateTime           = GETDATE()

    WHEN NOT MATCHED BY TARGET THEN
        INSERT (MatchId,  Seq,        		 Number,        UpdateTime, 	   SportType,  isTest)
        VALUES (@matchid, SOURCE.ResourceId, SOURCE.Result, CURRENT_TIMESTAMP, @Sporttype, 0);
    
    
END 
GO
