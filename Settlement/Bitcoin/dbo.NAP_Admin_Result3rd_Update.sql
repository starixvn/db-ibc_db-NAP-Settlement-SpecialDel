/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"  isNested="1"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Result3rd_Update]
	@MatchID			INT
	,@SportType			TINYINT		= 0
	,@Action			VARCHAR(20) = 'CAL'
	,@AdminId			INT
	,@IsAuto			BIT = 1
	,@ResultId			INT			= 0
	,@GameResult		VARCHAR(50) = ''
	,@SelectedResources	VARCHAR(MAX) = ''
AS 
/*
	Created: 20210810@Kathy
	Task: Update result
	DB: DBPRO/bodb02 

	Revision
		- 20210810@Kathy: Incorporate Bitcoin  [Redmine:#159714]
		- 20241023@Louisa: VS6 - Virtually Basketball [Redmine:#210733]
	
	Param's explaination: 
		@SelectedResources= '<Resources>
									<Resource Id="Q1" Home="11" Away="13" />
							   </Resources>'
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @SettlementStatusId TINYINT
			,@ResultStatusId	TINYINT
			,@VendorID			SMALLINT
			,@GameID			INT = 0
			,@hthomescore		INT
			,@htawayscore		INT
			,@handle			INT

	DECLARE @tmpResultDetail3rd TABLE (ResourceID VARCHAR(20), Home	NVARCHAR(100), Away	NVARCHAR(100) )
	-----------------------------------------------------

	SELECT @VendorID = p.VendorID
	FROM dbo.products p  WITH(NOLOCK)
		CROSS APPLY (	SELECT TOP 1 s.SportType
						FROM dbo.SportBettypeMatrix s WITH(NOLOCK)
						WHERE p.ProductID	= s.ProductID
							AND s.SportType = @SportType
							AND s.Enabled	= 1
					)d
	WHERE p.Enabled = 1

	IF @Action = 'CAL'
	BEGIN
		SELECT @SettlementStatusId = 4
				,@ResultStatusId = CASE WHEN @IsAuto = 1 THEN 2 ELSE 5 END
	END
	ELSE IF @Action = 'REFUND'
	BEGIN
		SELECT @SettlementStatusId = 1
				,@ResultStatusId = CASE WHEN @IsAuto = 1 THEN 2 ELSE 5 END
	END
	ELSE
		RETURN

	-----------------------------------------------------
	 --bitcoin
	IF ISNULL(@SelectedResources,'') = ''
	BEGIN
		UPDATE rd
			SET GameResult = CASE WHEN @GameResult <> '' THEN @GameResult ELSE GameResult END
				,SettlementStatusId = @SettlementStatusId
				,ResultStatusId = @ResultStatusId
				,LastModifyBy = @AdminId
				,LastModifyDate = GETDATE()
		FROM	dbo.ResultDetail3rd rd WITH(ROWLOCK, UPDLOCK)
		WHERE	rd.matchid = @MatchId
				AND rd.ResultId = @ResultId
	END

	ELSE
	BEGIN
		EXEC sp_xml_preparedocument @handle OUTPUT, @SelectedResources

		INSERT INTO @tmpResultDetail3rd (ResourceID, Home, Away)
		SELECT Id, ISNULL(Home,''), ISNULL(Away,'')
		FROM OPENXML(@handle,'Resources/Resource',1) WITH(Id VARCHAR(20),Home NVARCHAR(100),Away NVARCHAR(100)) AS tbl

		EXEC sp_xml_removedocument @handle

		MERGE dbo.ResultDetail3rd TARGET
		USING (
				SELECT r.ResourceId, r.Home, r.Away
				FROM @tmpResultDetail3rd r	
				) AS SOURCE ON TARGET.ResourceId  = SOURCE.ResourceId 
								AND TARGET.Matchid  = @MatchId
		WHEN MATCHED THEN
			UPDATE SET  Custom1				= SOURCE.Home
						,Custom2			= SOURCE.Away
						,SettlementStatusId = @SettlementStatusId
						,ResultStatusId		= @ResultStatusId
						,LastModifyBy		= @AdminId
						,LastModifyDate		= GETDATE()  
		WHEN NOT MATCHED BY TARGET THEN
			INSERT (VendorID
					,MatchID
					,GameID
					,Custom1
					,Custom2
					,ResultStatusID
					,SettlementStatusID
					,CreateBy
					,CreateDate
					,LastModifyBy
					,LastModifyDate
					,ResourceId
					)
			VALUES (	@VendorID
						,@MatchID
						,@GameID
						,SOURCE.Home
						,SOURCE.Away
						,@ResultStatusID
						,@SettlementStatusID
						,@AdminId
						,GETDATE()
						,@AdminId
						,GETDATE()
						,SOURCE.ResourceId
					);
	END
	
END 
GO
