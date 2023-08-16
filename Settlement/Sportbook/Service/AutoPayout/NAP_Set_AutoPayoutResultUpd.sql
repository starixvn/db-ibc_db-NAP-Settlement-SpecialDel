/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_AutoPayoutResultUpd 
	  @MatchId 				INT
	, @TypeId 				TINYINT
	, @StatusId 				TINYINT
	, @IsIncludedUpdateMatch 	BIT = 0
	, @IsUndoMatch				BIT = 0	
	, @SourceId 				TINYINT = NULL
	, @SportType 				SMALLINT = 1
	, @SelectedResources		VARCHAR(MAX)	= NULL
	, @IsConfirm				BIT = 0	
AS
/*
	Creator: 20160310@Patrick
	Task: Update status of auto payout result
	DB: DBPRO/bodb02
	Revisions:
		- 20160930@Bobby: #65003 - Implement Instant Calculation
		- 20171226@Kathy: Clear data if match has been undo [Redmine:#86890]
		- 20180208@Benjamin: Implement to determine AutoIntant and ManualInstant [Redmine:#86964]
		- 20190425@Sol: Auto Payout Phase 3 [Redmine:#116073]
		- 20211108@Louisa: In-house Replicator: Updated Action [Redmine:#164393] 
		- 20230214@Aries: Apply Settlement by Profile for Remaining Sports - Prepare data for table tennis [Redmine: #182677]
		- 20230407@Aries: Apply Settlement by Profile for Remaining Sports - Remove code [Redmine: #182677]
		- 20230515@Aries: Apply Settle Instant for Basketball [Redmine:#184124]
		
	Param's Explanation:
		- @StatusId: 0: New
					 1: Waiting
					 2: Completed
					 3: Failed
					 
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @AutoSetting 		TINYINT	
		 , @AutoSettingLeague	TINYINT
		 , @AutoPayoutResultId	INT
		 , @handle				INT

	DECLARE @tmpResourcesWeb TABLE(ResourceID VARCHAR(20))
	
	IF @IsUndoMatch = 1 AND @SportType = 1
	BEGIN
		DELETE
		FROM	dbo.AutoPayoutResult WITH(ROWLOCK, UPDLOCK)
		WHERE matchid = @MatchId
		  AND CalculationType IN (101, 102)
		
		--#90796 Begin modify
		--Auto Setting to OFF Instant for Get minium Risk Meeting #91094
		UPDATE dbo.match WITH(ROWLOCK, UPDLOCK)
		SET AutoSetting =  (CASE WHEN AutoSetting & 2 > 0 THEN AutoSetting ^ 2 ELSE AutoSetting END)
			,changetime = GETDATE()
		WHERE matchid = @MatchId
		
		--Update Confirmed =1 in ProviderResultDetail
		UPDATE dbo.ProviderResultDetail WITH(ROWLOCK,UPDLOCK)
		SET IsConfirmed = 1		
		WHERE MatchId = @MatchId
		  AND SourceID = 100 --Instant only
		--#90796 End modify


	END
	ELSE IF @IsUndoMatch = 1 AND @SportType = 2
	BEGIN
		EXEC sp_xml_preparedocument @handle OUTPUT, @SelectedResources
		INSERT INTO @tmpResourcesWeb(ResourceID)
		SELECT Id
		FROM OPENXML(@handle,'Resources/Resource',1) WITH(Id VARCHAR(20)) AS tbl
		WHERE Id LIKE 'Q[1-4]'  OR  Id IN ('01', '00')
		EXEC sp_xml_removedocument @handle

		IF NOT EXISTS (SELECT 1 FROM @tmpResourcesWeb)
		BEGIN
			RETURN
		END

		UPDATE dbo.match WITH(ROWLOCK, UPDLOCK)
		SET AutoSetting =  (CASE WHEN AutoSetting & 2 > 0 THEN AutoSetting ^ 2 
								 WHEN AutoSetting IS NULL THEN 0
								 ELSE AutoSetting 
							END)
			,changetime = GETDATE()
		WHERE matchid = @MatchId

		IF @IsConfirm = 0
		BEGIN
			DELETE ap
			FROM dbo.AutoPayoutResultOS  AS ap 
			WHERE ap.matchid = @MatchId
			  AND EXISTS (SELECT 1 FROM @tmpResourcesWeb AS rs WHERE ap.ResourceID = rs.ResourceID)
			  AND ap.SourceID = 98

			DELETE p
			FROM dbo.ProviderExternalResultDetail  AS p
			WHERE p.matchid = @MatchId
			  AND EXISTS (SELECT 1 FROM @tmpResourcesWeb AS rs WHERE p.ResourceID = rs.ResourceID)
			  AND p.SourceID = 98
		END 
	END
	ELSE
	BEGIN
		IF(@TypeId IN (101, 102)) --Instant Calculation
		BEGIN
			SELECT @AutoPayoutResultId = MAX(AutoPayoutResultId)
			FROM dbo.AutoPayoutResult rs WITH(NOLOCK)
			WHERE MatchId		  = @MatchId 
		 	  AND CalculationType = @TypeId
			  AND SourceID		  =  ISNULL(@SourceId, SourceID)
			  AND StatusId IN (0, 1) --is waiting/calculating
				
			UPDATE TOP(1) rs
			SET StatusId 				= @StatusId 
			  , ModifiedDate 			= GETDATE()
			FROM dbo.AutoPayoutResult rs WITH(ROWLOCK, UPDLOCK)
			WHERE AutoPayoutResultId	= @AutoPayoutResultId
		END
		ELSE --Auto Payout
		BEGIN
			UPDATE dbo.AutoPayoutResult WITH(ROWLOCK, UPDLOCK)
			SET StatusId = @StatusId 
			  , ModifiedDate = GETDATE()
			WHERE MatchId = @MatchId 
				AND CalculationType = @TypeId
				AND StatusId <> @StatusId
				AND SourceId = ISNULL(@SourceId, SourceId) -- #106901
				
		END
		
		IF (@IsIncludedUpdateMatch = 1)
		BEGIN
			SELECT TOP 1 
				@AutoSetting 		= m.AutoSetting
			   , @AutoSettingLeague	= l.AutoSetting
			FROM dbo.match m WITH(NOLOCK) 
				INNER JOIN dbo.league l WITH(NOLOCK) 
				ON m.leagueid = l.leagueid
				
			WHERE matchid 	= @MatchId 
			
			IF (@AutoSetting IS NULL AND @AutoSettingLeague IS NOT NULL)
			BEGIN
				UPDATE dbo.match WITH(UPDLOCK, ROWLOCK)
				SET AutoSetting =  @AutoSettingLeague
					,changetime = GETDATE()
				WHERE matchid = @MatchId
			END
		END
	END
END
GO