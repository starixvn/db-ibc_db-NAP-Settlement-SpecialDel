/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
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
*/
BEGIN
	SET NOCOUNT ON
    
	DECLARE @ResultTable		TINYINT = 0
			,@BestOfMap			TINYINT = NULL

	DECLARE @tblOddsES TABLE (ResourceID VARCHAR(20), bettype SMALLINT)
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

	IF (@SportType = 43 AND @SettleType = 'EAR')
	BEGIN
		INSERT INTO @tblOddsES (ResourceId, Bettype)
		SELECT o.ResourceId, o.Bettype 
		FROM dbo.OddsES o WITH(NOLOCK)
		WHERE o.Matchid = @matchid
			AND ISNULL(o.IsDeleted,0) = 0

		INSERT INTO @tblResource (ResourceID, RefResourceId, OrdNo)
		SELECT  DISTINCT sp.ResourceID AS ResourceID
				,sp.RefResourceId
				,MAX(sp.OrdNo)
		FROM (
			SELECT 	o.ResourceID, o.bettype
			FROM 	@tblOddsES o
		)o
		INNER JOIN SettlementSpecialBettypeProfile sp WITH (NOLOCK) ON sp.Bettype = o.Bettype and sp.BetID = '8' + o.Resourceid 
		WHERE sp.sporttype = @SportType
			AND sp.Settletype = @SettleType
			AND SUBSTRING(sp.ResourceID, 5, 2) <= @BestOfMap
		GROUP BY sp.ResourceID, sp.RefResourceId
	END
	ELSE
	BEGIN
		INSERT INTO @tblResource (ResourceID, RefResourceId, OrdNo)
		SELECT  DISTINCT sp.ResourceId
				, sp.RefResourceId
				,MAX(sp.OrdNo)
		FROM dbo.SettlementSpecialBettypeProfile sp WITH (NOLOCK)
		WHERE sp.sporttype = @SportType
			AND sp.Settletype = @SettleType
		GROUP BY sp.ResourceId, sp.RefResourceId
	END

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
	  			LEFT JOIN dbo.ResultDetailES rs WITH (NOLOCK)  
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