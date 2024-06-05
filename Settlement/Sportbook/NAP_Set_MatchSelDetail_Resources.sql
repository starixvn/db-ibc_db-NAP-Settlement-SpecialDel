/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchSelDetail_Resources]
	@matchid 		INT
	,@SportType     INT
	,@SettleType	CHAR(3) = 'MNL'		
AS
/*
    Created by: 20220719@Louisa
    Task: Scale Out BetTrans [Redmine:#175251]
    DB: DBPRO/BODB02 
    
    Revisions: 
		- 20220719@Louisa: Initial [Redmine:#175251]
		- 20230920@Aries: Remove remote query [Redmine:#194359]
		- 20240604@Aries: Support calculate interval child-matches for Table Tennis (SOP) [Redmine:#202100] 
*/
BEGIN
	SET NOCOUNT ON
    
	DECLARE @ResultTable		TINYINT = 0
			,@BestOfMap			TINYINT = NULL

	DECLARE @tblResource TABLE (ResourceID VARCHAR(20), RefResourceId VARCHAR(20), SettleType CHAR(3), OrdNo SMALLINT)

	DECLARE @tblResult TABLE 
	(		ResourceID VARCHAR(20)
			,HomeValue VARCHAR(50)
			,AwayValue VARCHAR(50)
			,ResultStatusID TINYINT
			,SettlementStatusID  TINYINT
			,ResultSetting TINYINT
			,OrdNo SMALLINT
			,SettleType CHAR(3)
	)
	
	SELECT @ResultTable =  r.ResultTable
	FROM   dbo.SettlementResultTableSetting r WITH(NOLOCK)
	WHERE r.Sporttype = @SportType

	 --Use @BestOfMap for E-sport only
	SELECT @BestOfMap = BestOfMap
	FROM [dbo].[match_remark] WITH (NOLOCK) 
	WHERE matchid = @matchid  

	INSERT INTO @tblResource (ResourceID, RefResourceId, OrdNo)
	SELECT  DISTINCT sp.ResourceId
			, sp.RefResourceId
			,MAX(sp.OrdNo)
	FROM dbo.SettlementSpecialBettypeProfile sp WITH (NOLOCK)
	WHERE sp.sporttype = @SportType
		AND sp.Settletype = @SettleType
	GROUP BY sp.ResourceId, sp.RefResourceId
	

	---INSERT for Major round if not exists
	INSERT INTO @tblResource (ResourceID, SettleType, OrdNo)
	SELECT mr.ResourceID, 'MNL', mr.OrdNo
	FROM dbo.f_Set_MajorRound(@Sporttype) mr
		LEFT JOIN @tblResource r ON r.ResourceID = mr.ResourceID
	WHERE r.ResourceID IS NULL
	
    ---return

    IF @ResultTable = 3 --E-Sports only
    BEGIN
		IF @BestOfMap IS NOT NULL
		BEGIN
			DELETE t
			FROM @tblResource t
			INNER JOIN dbo.f_Set_MajorRound(@Sporttype) mr ON mr.ResourceID = t.ResourceID
			WHERE mr.OrdNo > @BestOfMap AND mr.ResourceID <> '00'
		END

		SELECT ResourceId, HomeValue, AwayValue, ResultStatusId, SettlementStatusId, ResultSetting, OrdNo
		FROM (
			SELECT  ISNULL(tbl.RefResourceId, tbl.ResourceID ) AS ResourceId
	    			,rs.HomeValue
					,rs.AwayValue
					,ISNULL(rs.ResultStatusId,0)	 AS ResultStatusId
					,ISNULL(rs.SettlementStatusId,0) AS SettlementStatusId
					,ISNULL(rs.ResultSetting, 0) AS ResultSetting
					,tbl.OrdNo
					,tbl.SettleType
	  		FROM @tblResource tbl
	  			INNER JOIN dbo.ResultDetailES rs WITH (NOLOCK)  
					ON tbl.ResourceID = rs.ResourceID
		  			AND rs.matchid = @matchid
		) tbl
		 ORDER BY CASE tbl.SettleType WHEN 'MNL' THEN 0 ELSE 1 END , tbl.OrdNo
	END
	
	ELSE IF @ResultTable = 2 ---dbo.ResultDetailOS
	BEGIN
		SELECT ResourceId, HomeValue, AwayValue, ResultStatusId, SettlementStatusId, ResultSetting, OrdNo
		FROM (
				SELECT  ISNULL(tbl.RefResourceId, tbl.ResourceID ) AS ResourceId
	    			,rs.HomeValue
					,rs.AwayValue
					,ISNULL(rs.ResultStatusId,0)	 AS ResultStatusId
					,ISNULL(rs.SettlementStatusId,0) AS SettlementStatusId
					,ISNULL(rs.ResultSetting,0) AS ResultSetting
					,tbl.OrdNo
					,tbl.SettleType
	  		FROM  @tblResource tbl
				INNER JOIN dbo.ResultDetailOS rs WITH (NOLOCK)
				ON tbl.ResourceID = rs.ResourceID
		  			AND rs.matchid = @matchid
		) tbl
		 ORDER BY CASE tbl.SettleType WHEN 'MNL' THEN 0 ELSE 1 END , tbl.OrdNo
	END
	
	ELSE
	BEGIN
		SELECT ResourceId, HomeValue, AwayValue, ResultStatusId, SettlementStatusId, ResultSetting, OrdNo
		FROM (
			SELECT  DISTINCT ISNULL(tbl.RefResourceId, tbl.ResourceID ) AS ResourceId
	    			,rs.HomeValue
					,rs.AwayValue
					,ISNULL(rs.ResultStatusId,0)	 AS ResultStatusId
					,ISNULL(rs.SettlementStatusId,0) AS SettlementStatusId
					,ISNULL(rs.ResultSetting,0) AS ResultSetting
					,OrdNo
					,tbl.SettleType
	  		FROM @tblResource tbl
				INNER JOIN dbo.ResultDetail rs WITH (NOLOCK)
				ON tbl.ResourceID = rs.ResourceID
		  			AND rs.matchid = @matchid
			) tbl
		 ORDER BY CASE tbl.SettleType WHEN 'MNL' THEN 0 ELSE 1 END , tbl.OrdNo
	END

END
GO