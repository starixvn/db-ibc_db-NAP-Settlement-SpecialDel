/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchSelDetail_Resources_ReCal]
(
	@matchid		INT 
	,@SportType		INT = 0
)
AS
/*
    Created by: 20201211@Max
    Task: Support to Re-calculate Settled Tickets
    DB: DBPRO/BODB02 
    
    Revisions:            
		- 20201211@Max: Support to Re-calculate Settled Tickets [Redmine: #145669]
		- 20210122@Louisa: Cricket AIO [Redmine:#148870]
		- 20210611@Louisa: Beach Volleyball [Redmine:#156541]
		- 20210819@Louisa: Show Provider Results for remain sports [Redmine:#160192] 
		- 20240718@Kathy: Implement AiO for Baseball [Redmine:#206154]
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @ResultTable TINYINT = 0

	IF @SportType = 0
        SELECT @SportType = SportType FROM dbo.match WITH (NOLOCK) WHERE matchID = @matchid

	SELECT @ResultTable = r.ResultTable 
	FROM dbo.SettlementResultTableSetting r WITH(NOLOCK) 
	WHERE r.Sporttype = @SportType
	
	IF @SportType = 8
		SET @ResultTable = 2

    ---return
    IF @ResultTable = 3
    BEGIN
	    SELECT rs.ResourceID
	    		,rs.HomeValue
				,rs.AwayValue
				,rs.ResultStatusId
	           ,rs.ResultStatusID
				,rs.SettlementStatusID 
	  	FROM dbo.ResultDetailES rs WITH (NOLOCK)  
		WHERE rs.matchid = @matchid
	END
	
	---Badminton AIO, Beach Volleyball, Cricket AIO - get data from dbo.ResultDetailOS
	ELSE IF @ResultTable = 2
	BEGIN
		SELECT rs.ResourceID
	    		,rs.HomeValue
				,rs.AwayValue
	           ,rs.ResultStatusID
				,rs.SettlementStatusID
	  	FROM dbo.ResultDetailOS rs WITH (NOLOCK) 
		WHERE rs.matchid = @matchid
	END
	ELSE IF @ResultTable = 1
	BEGIN
		SELECT rs.ResourceId AS ResourceID
	    		,rs.HomeValue
				,rs.AwayValue
				,rs.ResultStatusID
				,rs.SettlementStatusID
	  	FROM  dbo.ResultDetail rs WITH (NOLOCK) 
		WHERE rs.matchid = @matchid
	END

END
GO