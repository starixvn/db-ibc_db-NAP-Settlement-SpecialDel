/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Set_MatchSelDetail_Resources_ReCal]
(
	@matchid		INT 
	,@SportType		INT = 0
	,@SettleType	VARCHAR(10) = 'MNL'
)
AS
/*
    Created by: 20201211@Max
    Task: Support to Re-calculate Settled Tickets
    DB: DBTXN/BODB02 
    
    Revisions:            
		- 20201211@Max: Support to Re-calculate Settled Tickets [Redmine: #145669]
		
*/
BEGIN
	SET NOCOUNT ON
	IF @SportType =0
        SELECT @SportType = SportType FROM dbo.match WHERE matchID = @matchid
    ---return
    IF @Sporttype = 43
    BEGIN
	    SELECT rs.ResourceID
	    		,rs.HomeValue
				,rs.AwayValue
				,rs.ResultStatusId
	           ,rs.ResultStatusID
				,rs.SettlementStatusID 
	  	FROM DBPRO.bodb02.dbo.ResultDetailES rs WITH (NOLOCK)  
		WHERE rs.matchid = @matchid
	END
	
	---Badminton AIO - get data from dbo.ResultDetailOS
	ELSE IF @SportType = 9
	BEGIN
		SELECT rs.ResourceID
	    		,rs.HomeValue
				,rs.AwayValue
	           ,rs.ResultStatusID
				,rs.SettlementStatusID
	  	FROM DBPRO.bodb02.dbo.ResultDetailOS rs WITH (NOLOCK) 
		WHERE rs.matchid = @matchid
	END
	ELSE
	BEGIN
		SELECT rs.ResourceId AS ResourceID
	    		,rs.HomeValue
				,rs.AwayValue
				,rs.ResultStatusID
				,rs.SettlementStatusID
	  	FROM  DBPRO.bodb02.dbo.ResultDetail rs WITH (NOLOCK) 
		WHERE rs.matchid = @matchid
	END

END
GO