/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Set_GetResultInfo
	@MatchID INT
	,@ResourceIDs VARCHAR(MAX)
AS
/*
    Created by: 20240605@Louisa
    Date: 20240605
    Task: Notify if not yet refund [Redmine:#204909] 
    
    Revisions:
        - 20240605@Louisa: Initial [Redmine:#204909]   

	Param's explaination:
		@ResourceIDs: '00,01'
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @Sporttype		TINYINT
			,@ResultTable	TINYINT
	
	DECLARE @tmp_ResourceID	TABLE ( ResourceID VARCHAR(20) )

	DECLARE @tmp_ResultDetail TABLE (	MatchId	INT
										,ResourceId	VARCHAR(20)
										,HomeValue	VARCHAR(40)
										,AwayValue	VARCHAR(40)
										,ResultStatusID	TINYINT
										,SettlementStatusID	TINYINT
										,ResultSetting	TINYINT
									)
	
	INSERT INTO @tmp_ResourceID ( ResourceID )
	SELECT	DISTINCT f.[value]
	FROM	STRING_SPLIT(@ResourceIDs, ',') f

	SELECT @Sporttype = m.sporttype 
	FROM dbo.match m WITH(NOLOCK) WHERE m.matchid = @MatchID

	SELECT @ResultTable = s.ResultTable
	FROM dbo.SettlementResultTableSetting s WITH(NOLOCK)
	WHERE Sporttype = @Sporttype

	---this future does not do for @ResultTable = 0
	IF @ResultTable = 1
	BEGIN
		INSERT INTO @tmp_ResultDetail ( MatchId, ResourceId, HomeValue, AwayValue, ResultStatusID, SettlementStatusID, ResultSetting)
		SELECT r.MatchId
				,r.ResourceId
				,r.HomeValue
				,r.AwayValue
				,r.ResultStatusID
				,r.SettlementStatusID
				,r.ResultSetting
		FROM dbo.ResultDetail r WITH(NOLOCK)
			INNER JOIN @tmp_ResourceID tmp ON r.ResourceId = tmp.ResourceID
		WHERE r.MatchId = @MatchID
	END
	IF @ResultTable = 2
	BEGIN
		INSERT INTO @tmp_ResultDetail ( MatchId, ResourceId, HomeValue, AwayValue, ResultStatusID, SettlementStatusID, ResultSetting)
		SELECT r.MatchId
				,r.ResourceId
				,r.HomeValue
				,r.AwayValue
				,r.ResultStatusID
				,r.SettlementStatusID
				,r.ResultSetting
		FROM dbo.ResultDetailOS r WITH(NOLOCK)
			INNER JOIN @tmp_ResourceID tmp ON r.ResourceId = tmp.ResourceID
		WHERE r.MatchId = @MatchID
	END
	IF @ResultTable = 3
	BEGIN
		INSERT INTO @tmp_ResultDetail ( MatchId, ResourceId, HomeValue, AwayValue, ResultStatusID, SettlementStatusID, ResultSetting)
		SELECT r.MatchId
				,r.ResourceId
				,r.HomeValue
				,r.AwayValue
				,r.ResultStatusID
				,r.SettlementStatusID
				,r.ResultSetting
		FROM dbo.ResultDetailES r WITH(NOLOCK)
			INNER JOIN @tmp_ResourceID tmp ON r.ResourceId = tmp.ResourceID
		WHERE r.MatchId = @MatchID
	END

	SELECT MatchId, ResourceId, HomeValue, AwayValue, ResultStatusID, SettlementStatusID, ResultSetting
	FROM @tmp_ResultDetail
END
GO