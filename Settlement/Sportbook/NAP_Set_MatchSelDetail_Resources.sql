/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchSelDetail_Resources]
	@matchid 		INT
	,@SportType     INT = 0
	--,@SettleType	VARCHAR(10) = 'MNL'
	,@Resources		VARCHAR(MAX) = ''		
AS
/*
    Created by: 20220719@Louisa
    Task: Scale Out BetTrans [Redmine:#175251]
    DB: DBPRO/BODB02 
    
    Revisions: 
		- 20220719@Louisa: Initial [Redmine:#175251]
*/
BEGIN
	SET NOCOUNT ON
    
	DECLARE @ResultTable		TINYINT = 0	
    DECLARE @tblResource TABLE (ResourceID VARCHAR(20) )

    IF @SportType = 0
	BEGIN
        SELECT @SportType = SportType FROM Match WITH(NOLOCK) WHERE matchID = @matchid
	END 

	SELECT @ResultTable =  r.ResultTable
	FROM   dbo.SettlementResultTableSetting r WITH(NOLOCK)
	WHERE r.Sporttype = @SportType

	INSERT INTO @tblResource (ResourceID )
	SELECT f.[value] from STRING_SPLIT(@MatchIds, ',') f

    ---return
    IF @ResultTable = 3 --E-Sports only
    BEGIN
	    SELECT tbl.ResourceID
	    		,rs.HomeValue
				,rs.AwayValue
				,rs.ResultStatusId
				,rs.SettlementStatusId
				,ISNULL(rs.ResultSetting, 0) AS ResultSetting
	  	FROM @tblResource tbl
	  		LEFT JOIN dbo.ResultDetailES rs WITH (NOLOCK)  
				ON tbl.ResourceID = rs.ResourceID
		  		AND rs.matchid = @matchid
	END
	
	ELSE IF @ResultTable = 2 ---dbo.ResultDetailOS
	BEGIN
		SELECT tbl.ResourceID
	    		,rs.HomeValue
				,rs.AwayValue
				,rs.ResultStatusId
				,rs.SettlementStatusId
				,ISNULL(rs.ResultSetting,0) AS ResultSetting,tbl.OrdNo
	  	FROM @tblResource tbl
		  		LEFT JOIN dbo.ResultDetailOS rs WITH (NOLOCK) 
		  			ON tbl.ResourceID = rs.ResourceID
		  			AND rs.matchid = @matchid
	END
	
	ELSE
	BEGIN
		SELECT tbl.ResourceID
	    		,rs.HomeValue
				,rs.AwayValue
				,rs.ResultStatusId
				,rs.SettlementStatusId
				,rs.ResultSetting
	  	FROM @tblResource tbl
			LEFT JOIN dbo.ResultDetail rs WITH (NOLOCK) 
		  		ON tbl.ResourceID = rs.ResourceID
		  		AND rs.matchid = @matchid
	END

END
GO