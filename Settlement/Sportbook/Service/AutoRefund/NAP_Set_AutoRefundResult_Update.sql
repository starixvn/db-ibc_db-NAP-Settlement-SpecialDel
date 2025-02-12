/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_AutoRefundResult_Update
	  @MatchId 				INT
	, @SelectedResources 	VARCHAR(MAX) = ''
	, @StatusId 			TINYINT
	, @TypeId				TINYINT = 7
AS
/*
	Creator: 214410@Aries
	Task: Auto Refund Soccer [Redmine:#214832]
	DB: DBPRO/bodb02
	Revisions:
		 - 20241223@Aries: Support Auto Refund for Soccer's Early Results [Redmine:#214410]

	Param's Explanation:
		@SelectedResources= '<Resources>
									<Resource Id="H1" SourceId="0" Home="1" Away="3" />
									<Resource Id="H2" SourceId="1" Home="2" Away="4" />
							   </Resources>'
		@StatusId:
				1: Waitting
				2: Success
				3: Fail
		@CalculationType: 7 - Auto Refund
			
*/
BEGIN
	SET NOCOUNT ON

	DECLARE  @handle INT
	CREATE TABLE #tmpResourceIds ( ResourceId VARCHAR(20),SourceId TINYINT, HomeValue VARCHAR(50), AwayValue VARCHAR(50),Remark VARCHAR(1000),OtherInfo VARCHAR(MAX), PRIMARY KEY(ResourceId) )

	EXEC sp_xml_preparedocument @handle OUTPUT, @SelectedResources
	INSERT INTO #tmpResourceIds (ResourceId,SourceId, HomeValue, AwayValue,Remark,OtherInfo)
	SELECT Id, ISNULL(SourceId,0), ISNULL(Home,''), ISNULL(Away,''),Remark,OtherInfo
	FROM OPENXML(@handle,'Resources/Resource',1) WITH( Id	VARCHAR(20)
														,SourceId VARCHAR(50)
														,Home VARCHAR(50)
														,Away VARCHAR(50)
														,Remark VARCHAR(1000)
														,OtherInfo VARCHAR(MAX)
										) AS tbl
	EXEC sp_xml_removedocument @handle
	
	MERGE dbo.AutoRefundResult TARGET
	USING (SELECT r.ResourceId, r.SourceId, r.HomeValue, r.AwayValue, r.Remark, r.OtherInfo
		   FROM #tmpResourceIds r	
		  ) AS SOURCE ON TARGET.ResourceId  = SOURCE.ResourceId 
							AND TARGET.Matchid  = @MatchId 
							AND TARGET.TypeId = @TypeId 
							AND TARGET.SourceId  = SOURCE.SourceId 
	WHEN MATCHED THEN
		UPDATE SET   StatusId	  = @StatusId
					,Remark		  = IIF(ISNULL(SOURCE.Remark,'') != '',SOURCE.Remark,TARGET.Remark)
					,ModifiedDate = GETDATE()
	WHEN NOT MATCHED BY TARGET THEN
		INSERT ( MatchId, ResourceId, HomeValue, AwayValue, StatusId,TypeId, SourceId, CreateDate, ModifiedDate,Remark,OtherInfo)
		VALUES (@MatchId, SOURCE.ResourceId, SOURCE.HomeValue, SOURCE.AwayValue, @StatusId, @TypeId, SOURCE.SourceId, GETDATE(), GETDATE(),SOURCE.Remark,SOURCE.OtherInfo);


END
GO
