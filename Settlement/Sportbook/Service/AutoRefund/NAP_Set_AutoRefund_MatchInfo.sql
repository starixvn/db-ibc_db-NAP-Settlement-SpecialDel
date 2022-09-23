/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Set_AutoRefund_MatchInfo
	@MatchId INT
	, @TypeId TINYINT
AS
/*
	Created by: 20220719@Louisa
	Task: Scale Out BetTrans [Redmine:#175251]
	DB: DBTXN/BODB02
	
	Revisions:
		- 20220719@Louisa: Check match info Auto Refund [Redmine:#175251]
	
	Param's explaination: 
		Old SP is located on DBTXN
		
		@TypeId:   1 - Auto refund single
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
			, @IsRefundedSingle		BIT


		SELECT  @ParentId = m.ParentId
				, @Eventstatus = m.Eventstatus
				, @SettlementStatus = m.SettlementStatus
		FROM dbo.match m  WITH(NOLOCK) WHERE m.MatchId = @MatchId
		
		CREATE TABLE #tmpResultDetail (ResourceId VARCHAR(20), SettlementStatusId TINYINT, HomeValue VARCHAR(50), AwayValue VARCHAR(50), ResultSetting	TINYINT,  MatchType VARCHAR(1) )
		
		INSERT INTO #tmpResultDetail (ResourceId, SettlementStatusId, HomeValue, AwayValue, ResultSetting, MatchType)
		SELECT	r.ResourceId
				, r.SettlementStatusId
				, r.HomeValue
				, r.AwayValue 
				, ISNULL(r.ResultSetting,0)
				, CASE r.matchid WHEN @MatchId THEN 'c' ELSE 'p' END as MatchType
			FROM  dbo.ResultDetail r WITH(NOLOCK)
			WHERE ( r.matchid = @ParentId and r.ResourceId = '00')
				OR ( r.MatchId = @MatchId )

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

		END

		IF @TypeId = 10 AND EXISTS (SELECT TOP 1 1 FROM #tmpResultDetail r WHERE r.MatchType ='c' AND r.ResourceId = '00' AND r.SettlementStatusId = 1)
		BEGIN
			SELECT @IsRefundedSingle = 1
		END
	
		SELECT 	@matchId 			AS matchId				
				, @eventstatus 			AS eventstatus
				, @SettlementStatus		AS SettlementStatus
				, @ParentSettlementStatusId AS ParentSettlementStatusId 
				, @ParentHomeValue 		AS ParentHomeValue
				, @ParentAwayValue 		AS ParentAwayValue	
				, ISNULL(@IsHoldResourceId,0) 	  AS IsHoldResourceId
				, ISNULL(@IsRefundedSingle ,0) 	  AS IsRefundedSingle 

END
GO