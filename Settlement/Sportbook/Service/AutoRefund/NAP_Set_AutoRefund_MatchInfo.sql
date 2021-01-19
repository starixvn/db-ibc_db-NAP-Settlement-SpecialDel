/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Set_AutoRefund_MatchInfo
	@MatchId INT
	, @TypeId TINYINT
AS
/*
	Creator: 20201216@Louisa		
	Task: Auto refund ET & PEN match [Redmine:#145597]
	DB: DBTXN/bodb02
	Revisions:
		- 20201216@Louisa: Get ET & PEN match for Auto Refund Service [Redmine:#145597]
	
	Param's explaination: 
	- @TypeId:   1 - Auto refund single
				10 - Auto refund parlay
*/
BEGIN
	SET NOCOUNT ON

	DECLARE   @ParentId INT
			, @eventstatus			NVARCHAR(100)
			, @SettlementStatus		TINYINT			
			, @SettlementStatusID	TINYINT
			, @ParentSettlementStatusID TINYINT
			, @ParentHomeValue		VARCHAR(50)
			, @ParentAwayValue		VARCHAR(50)
			, @IsHoldResourceId		BIT
			, @IsExistMarkedTicket	BIT
			, @IsExistSettledTicket	BIT
			, @IsRefundedSingle		BIT
			, @queryInfo			NVARCHAR(MAX) = ''
			, @execSql				NVARCHAR(MAX) =''


		SELECT  @ParentId = m.ParentId
				, @Eventstatus = m.Eventstatus
				, @SettlementStatus = m.SettlementStatus
		FROM dbo.match m  WITH(NOLOCK) WHERE m.MatchId = @MatchId

		
		CREATE TABLE #tmpResultDetail (ResourceId VARCHAR(20), SettlementStatusId TINYINT, HomeValue VARCHAR(50), AwayValue VARCHAR(50), ResultSetting	TINYINT,  MatchType VARCHAR(1) )
			
		SET @queryInfo = 'SELECT	r.ResourceId
									, r.SettlementStatusId
									, r.HomeValue
									, r.AwayValue 
									, ISNULL(r.ResultSetting,0)
									, CASE r.matchid WHEN @MatchId THEN ''c'' ELSE ''p'' END as MatchType
								FROM  dbo.ResultDetail r WITH(NOLOCK)
								WHERE ( r.matchid = @ParentId and r.ResourceId = ''00'')
									OR ( r.MatchId = @MatchId )
								'

	    SET @execSql = 'DBPRO.bodb02.dbo.sp_executesql @queryInfo, N''@MatchId INT, @ParentId INT'', @MatchId,  @ParentId'
		INSERT INTO #tmpResultDetail (ResourceId, SettlementStatusId, HomeValue, AwayValue, ResultSetting, MatchType)
		EXECUTE	sys.sp_executesql @execSql, N'@queryInfo NVARCHAR(MAX), @MatchId INT,  @ParentId INT', @queryInfo, @MatchId,  @ParentId

		IF @TypeId = 1
		BEGIN

			SELECT	@ParentSettlementStatusId  = r.SettlementStatusId
					, @ParentHomeValue = r.HomeValue
					, @ParentAwayValue = r.AwayValue
			FROM #tmpResultDetail r
			WHERE r.MatchType = 'p' 
			
			SELECT @IsHoldResourceId = MAX(r.ResultSetting)
			FROM #tmpResultDetail r
			WHERE r.MatchType = 'c'

			SELECT @IsExistMarkedTicket		= MAX(CASE WHEN btr.statusID BETWEEN 0 AND 1 AND mt.TransId IS NOT NULL THEN 1 ELSE 0 END)
					,@IsExistSettledTicket  = MAX(CASE WHEN btr.statusID IN (103, 111, 112, 113) AND mt.TransId IS NULL THEN 1 ELSE 0 END)
			FROM dbo.bettrans btr  WITH(NOLOCK)
				OUTER APPLY ( SELECT TOP 1 TransId FROM dbo.MarkedTransaction mt  WITH(NOLOCK) WHERE btr.transID = mt.TransId ) mt
			WHERE btr.statusID IN ( 0 , 103, 111, 112, 113)
				AND btr.matchid = @MatchId
		END

		IF @TypeId = 10 AND EXISTS (SELECT TOP 1 1 FROM #tmpResultDetail r WHERE r.MatchType ='c' AND r.ResourceId = '00' AND r.SettlementStatusId = 1)
		BEGIN
			SELECT @IsRefundedSingle = 1
		END
	
		SELECT 	
			@matchId 			AS matchId				
		, @eventstatus 			AS eventstatus
		, @SettlementStatus		AS SettlementStatus
		, @ParentSettlementStatusId AS ParentSettlementStatusId 
		, @ParentHomeValue 		AS ParentHomeValue
		, @ParentAwayValue 		AS ParentAwayValue	
		, ISNULL(@IsHoldResourceId,0) 	  AS IsHoldResourceId  
		, ISNULL(@IsExistMarkedTicket,0)  AS IsExistMarkedTicket	
		, ISNULL(@IsExistSettledTicket,0) AS IsExistSettledTicket
		, ISNULL(@IsRefundedSingle ,0) 	  AS IsRefundedSingle 

END
GO