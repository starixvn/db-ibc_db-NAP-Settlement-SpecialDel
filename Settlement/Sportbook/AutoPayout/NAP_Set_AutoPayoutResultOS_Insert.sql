/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE dbo.NAP_Set_AutoPayoutResultOS_Insert
	@MatchId 		INT
	, @ResourceIds 	VARCHAR(MAX)
	, @StatusId 	TINYINT
	, @ErrCode 		INT = 0 OUTPUT
	, @ErrMsg		NVARCHAR(200) = '' OUTPUT
	
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

*/
BEGIN
	SET NOCOUNT ON

	IF ISNULL(@ResourceIds,'') = ''
	RETURN


	DECLARE  @handle INT

	DECLARE @tmpResourceIds TABLE ( ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50) )

	BEGIN TRY

		EXEC sp_xml_preparedocument @handle OUTPUT, @ResourceIds
		INSERT INTO @tmpResourceIds (ResourceId, HomeValue, AwayValue)
		SELECT Id, ISNULL(Home,''), ISNULL(Away,'')
		FROM OPENXML(@handle,'Resources/Resource',1) WITH( Id	VARCHAR(20)
															,Home VARCHAR(50)
															,Away VARCHAR(50)
											) AS tbl
		EXEC sp_xml_removedocument @handle


		MERGE dbo.AutoPayoutResultOS TARGET
		USING (
				SELECT r.ResourceId, r.HomeValue, r.AwayValue 
				FROM @tmpResourceIds r	
				) AS SOURCE ON TARGET.ResourceId  = SOURCE.ResourceId AND TARGET.Matchid  = @MatchId

		WHEN MATCHED AND @StatusId IN ( 2, 3 ) THEN
			UPDATE SET StatusId = @StatusId
						,ModifiedDate = GETDATE()
		WHEN NOT MATCHED BY TARGET AND @StatusId IN  ( 1, 3 ) THEN
			INSERT ( MatchId, ResourceId, HomeValue, AwayValue, StatusId, CreatedDate, ModifiedDate)
			VALUES (@MatchId, SOURCE.ResourceId, SOURCE.HomeValue, SOURCE.AwayValue, GETDATE(), GETDATE() );
	END TRY
	BEGIN CATCH
		SELECT @ErrCode =  @@ERROR
				,@ErrMsg = ERROR_MESSAGE()
	END CATCH

END
GO
