/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_AutoPayoutResult_Update
	  @MatchId 				INT
	, @SelectedResources 	VARCHAR(MAX) = ''
	, @StatusId 			TINYINT
	, @CalculationType		TINYINT = 5
	, @Remark				VARCHAR(1000) = NULL	
AS
/*
	Creator: 20241028@Aries
	Task: Auto Settle Soccer [Redmine:#211079]
	DB: DBPRO/bodb02
	Revisions:
		- 20241028@Aries: Direct payout for early soccer [Redmine:#211079]

	Param's Explanation:
		@SelectedResources= '<Resources>
									<Resource Id="H1" Home="1" Away="3" />
									<Resource Id="H2" Home="2" Away="4" />
							   </Resources>'
		@StatusId:
				1: Waitting
				2: Success
				3: Fail
		@CalculationType: 5 - Direct early soccer
			
*/
BEGIN
	SET NOCOUNT ON

	DECLARE  @handle INT
	CREATE TABLE #tmpResourceIds ( ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50),PRIMARY KEY(ResourceId) )

	EXEC sp_xml_preparedocument @handle OUTPUT, @SelectedResources
	INSERT INTO #tmpResourceIds (ResourceId, HomeValue, AwayValue)
	SELECT Id, ISNULL(Home,''), ISNULL(Away,'')
	FROM OPENXML(@handle,'Resources/Resource',1) WITH( Id	VARCHAR(20)
														,Home VARCHAR(50)
														,Away VARCHAR(50)
										) AS tbl
	EXEC sp_xml_removedocument @handle
	
	MERGE dbo.AutoPayoutResult TARGET
	USING (SELECT r.ResourceId, r.HomeValue, r.AwayValue
		   FROM #tmpResourceIds r	
		  ) AS SOURCE ON TARGET.ResourceId  = SOURCE.ResourceId 
							AND TARGET.Matchid  = @MatchId 
							AND TARGET.CalculationType = @CalculationType 
	WHEN MATCHED THEN
		UPDATE SET   StatusId	  = @StatusId
					,Remark		  = ISNULL(@Remark,Remark)
					,ModifiedDate = GETDATE()
	WHEN NOT MATCHED BY TARGET THEN
		INSERT ( MatchId, ResourceId, HomeValue, AwayValue, StatusId,CalculationType, SourceId, CreatedDate, ModifiedDate,Remark)
		VALUES (@MatchId, SOURCE.ResourceId, SOURCE.HomeValue, SOURCE.AwayValue, @StatusId, 5, 100, GETDATE(), GETDATE(),@Remark);


END
GO
