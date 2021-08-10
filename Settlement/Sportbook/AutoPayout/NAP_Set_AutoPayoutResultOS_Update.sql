/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE dbo.NAP_Set_AutoPayoutResultOS_Update
	@MatchId 				INT
	, @SelectedResources 	VARCHAR(MAX)
	, @StatusId 			TINYINT
	, @UserId				INT	= 0
	, @ErrCode 				INT = 0 OUTPUT
	, @ErrMsg				NVARCHAR(200) = '' OUTPUT
	
AS
/*
	Creator: 20210729@Louisa
	Task: Auto Settle Cricket [Redmine:#154586]
	DB: DBPRO/bodb02
	Revisions:
		- 20210729@Louisa: Auto Settle Cricket [Redmine:#154586]

	Param's Explanation:
		@SelectedResources= '<Resources>
									<Resource Id="H1" Home="1" Away="3" />
									<Resource Id="H2" Home="2" Away="4" />
							   </Resources>'

		@StatusId:
				1: Waitting
				2: Success
				3: Fail
*/
BEGIN
	SET NOCOUNT ON

	IF ISNULL(@SelectedResources,'') = '' AND @StatusId IN (1,2,3)
	RETURN


	DECLARE  @handle INT
	DECLARE @tmpResourceIds TABLE ( ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50) )

	EXEC sp_xml_preparedocument @handle OUTPUT, @SelectedResources
	INSERT INTO @tmpResourceIds (ResourceId, HomeValue, AwayValue)
	SELECT Id, ISNULL(Home,''), ISNULL(Away,'')
	FROM OPENXML(@handle,'Resources/Resource',1) WITH( Id	VARCHAR(20)
														,Home VARCHAR(50)
														,Away VARCHAR(50)
										) AS tbl
	EXEC sp_xml_removedocument @handle

	IF @StatusId = 99 --Mark fail IF exec Settlement Command is failed
	BEGIN
		UPDATE dbo.AutoPayoutResultOS
		SET StatusId = 3
		WHERE MatchId = @MatchId
			AND StatusId = 1
	END

	ELSE
	BEGIN
		MERGE dbo.AutoPayoutResultOS TARGET
		USING (
				SELECT r.ResourceId, r.HomeValue, r.AwayValue
				FROM @tmpResourceIds r	
				) AS SOURCE ON TARGET.ResourceId  = SOURCE.ResourceId AND TARGET.Matchid  = @MatchId

		WHEN MATCHED THEN
			UPDATE SET StatusId		  = @StatusId
						,ModifiedBy	  = @UserId
						,ModifiedDate = GETDATE()
		WHEN NOT MATCHED BY TARGET THEN
			INSERT ( MatchId, ResourceId, HomeValue, AwayValue, StatusId, CreatedBy, ModifiedBy, CreatedDate, ModifiedDate)
			VALUES (@MatchId, SOURCE.ResourceId, SOURCE.HomeValue, SOURCE.AwayValue, @StatusId, @UserId, @UserId, GETDATE(), GETDATE() );
	END

	IF ISNULL(@@ERROR,0) > 0
	BEGIN
		SELECT @ErrCode =  @@ERROR
				,@ErrMsg = ERROR_MESSAGE()
		RETURN
	END

END
GO
