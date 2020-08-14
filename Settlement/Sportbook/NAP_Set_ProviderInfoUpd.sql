/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER  PROC NAP_Set_ProviderInfoUpd
(
	 @GameType		TINYINT 
	,@ProviderSources VARCHAR(MAX)
<<<<<<< 138656-Settlemet-ApplyKeyscoreSOPESSports-Phase2:Settlement/Sportbook/NAP_Set_ProviderInfoUpd.sql
	,@ErrCode		INT				= 0		OUTPUT
	,@ErrMsg		NVARCHAR(200)	= ''	OUTPUT	 
=======
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			NVARCHAR(200)	= ''	OUTPUT	 
>>>>>>> local:Settlement/Sportbook/NAP_Set_ProviderSort.sql
)
AS
/*
    Created by: 20200806@Louisa
    Task: Order provider info [Redmine:#138656]
    DB: DBPRO/BODB02 
    
    Revisions:            
		- 20200806@Louisa: Order provider info [Redmine:#138656]

	Param's Explanation:
		@GameTypes : Single select
		@ProviderSource		VARCHAR(MAX)	 =
					'<Providers><Provider SourceId ="1"  OrderNo="1"/>
								<Provider SourceId ="6"  OrderNo="2"/>
								<Provider SourceId ="7"  OrderNo="3"/>
								<Provider SourceId ="8"  OrderNo="4"/>
					</Providers>'	
*/
BEGIN
	DECLARE @handle			INT
	DECLARE @tmpProviderSort TABLE (SourceId SMALLINT, OrderNo INT)

	IF ISNULL(@ProviderSources, '') <> ''
	BEGIN
		EXEC sp_xml_preparedocument @handle OUTPUT, @ProviderSources
		
		INSERT INTO  @tmpProviderSort  (SourceID ,  OrderNo  )
		SELECT SourceID ,  OrderNo
		FROM OPENXML(@handle,'Providers/Provider',1) WITH( SourceId SMALLINT
															,OrderNo INT
														) AS tbl
									
		EXEC sp_xml_removedocument @handle

		BEGIN TRY
			UPDATE dbo.ProviderGameTypeMapping  WITH(ROWLOCK, UPDLOCK)
				SET OrderNo = tmp.OrderNo
			FROM ProviderGameTypeMapping pgm
			INNER JOIN @tmpProviderSort tmp 
				ON pgm.SourceId = tmp.SourceId
					AND	pgm.GameType  = @GameType
			
		END TRY
		BEGIN CATCH 
				SELECT @ErrCode	= ERROR_NUMBER()
<<<<<<< 138656-Settlemet-ApplyKeyscoreSOPESSports-Phase2:Settlement/Sportbook/NAP_Set_ProviderInfoUpd.sql
					, @ErrMsg 	= @ErrMsg + ISNULL(ERROR_MESSAGE(),'')
=======
					, @ErrMsg 	= ERROR_MESSAGE()
>>>>>>> local:Settlement/Sportbook/NAP_Set_ProviderSort.sql
		END CATCH

	END
END
GO
