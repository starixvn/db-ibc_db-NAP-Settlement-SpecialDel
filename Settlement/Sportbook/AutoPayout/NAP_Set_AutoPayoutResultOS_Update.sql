/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_AutoPayoutResultOS_Update
	@MatchId 				INT
	, @SelectedResources 	VARCHAR(MAX) = ''
	, @StatusId 			TINYINT
	, @UserId				INT	= 0
	, @SourceID				TINYINT = 0
	, @ErrCode 				INT = 0 OUTPUT
	, @ErrMsg				NVARCHAR(200) = '' OUTPUT
	
AS
/*
	Creator: 20210729@Louisa
	Task: Auto Settle Cricket [Redmine:#154586]
	DB: DBPRO/bodb02
	Revisions:
		- 20210729@Louisa: Auto Settle Cricket [Redmine:#154586]
		- 20230801@Aries: Support Instant Settlement for Basketball [Redmine:#189662]
		- 20231002@Aries: Apply Auto Payout for Cricket by using TheSports Provider  [Redmine: #195768]

	Param's Explanation:
		@SelectedResources= '<Resources>
									<Resource Id="H1" Home="1" Away="3" />
									<Resource Id="H2" Home="2" Away="4" />
							   </Resources>'

		@StatusId:
				1: Waitting
				2: Success
				3: Fail
		@SourceID: 0 - AutoPayout,  98 - Instant
			
*/
BEGIN
	SET NOCOUNT ON

	IF ISNULL(@SelectedResources,'') = '' AND @StatusId IN (1,2,3)
	RETURN


	DECLARE  @handle INT
	CREATE TABLE #tmpResourceIds ( ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50),PRIMARY KEY(ResourceId) )

	IF @StatusId = 99 -- Mark fail IF exec Settlement Command NAP_Admin_Settlement_Profile failed
	BEGIN
		UPDATE dbo.AutoPayoutResultOS
		SET StatusId = 3
		WHERE MatchId = @MatchId
			AND StatusId = 1
			AND ISNULL(SourceID,0) = 0
	END

	ELSE
	BEGIN
		EXEC sp_xml_preparedocument @handle OUTPUT, @SelectedResources
		INSERT INTO #tmpResourceIds (ResourceId, HomeValue, AwayValue)
		SELECT Id, ISNULL(Home,''), ISNULL(Away,'')
		FROM OPENXML(@handle,'Resources/Resource',1) WITH( Id	VARCHAR(20)
															,Home VARCHAR(50)
															,Away VARCHAR(50)
											) AS tbl
		EXEC sp_xml_removedocument @handle

		MERGE dbo.AutoPayoutResultOS TARGET
		USING (
				SELECT r.ResourceId, r.HomeValue, r.AwayValue
				FROM #tmpResourceIds r	
				) AS SOURCE ON TARGET.ResourceId  = SOURCE.ResourceId 
								AND TARGET.Matchid  = @MatchId 
								AND ISNULL(TARGET.SourceID,0) = @SourceID 
								AND 1 = CASE WHEN @SourceID  = 98 AND  TARGET.HomeValue  = SOURCE.HomeValue AND TARGET.AwayValue  = SOURCE.AwayValue THEN 1
											 WHEN @SourceID = 0 THEN 1
											 ELSE 0
										END
		WHEN MATCHED THEN
			UPDATE SET StatusId		  = @StatusId
						,ModifiedBy	  = @UserId
						,ModifiedDate = GETDATE()
		WHEN NOT MATCHED BY TARGET THEN
			INSERT ( MatchId, ResourceId, HomeValue, AwayValue, StatusId, CreatedBy, ModifiedBy, CreatedDate, ModifiedDate,SourceID)
			VALUES (@MatchId, SOURCE.ResourceId, SOURCE.HomeValue, SOURCE.AwayValue, @StatusId, @UserId, @UserId, GETDATE(), GETDATE(),@SourceID);
	END

	IF ISNULL(@@ERROR,0) > 0
	BEGIN
		SELECT @ErrCode =  @@ERROR
				,@ErrMsg = ERROR_MESSAGE()
		RETURN
	END

END
GO
