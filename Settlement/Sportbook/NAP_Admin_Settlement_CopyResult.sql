/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Admin_Settlement_CopyResult
	 @MatchId	INT
	,@DestinationMatchId INT
	,@IsOverrideResult BIT = 0
	,@AdminId	INT
AS
/*	
	Creator: Louisa
	Date: 20210930
	Task: Move ticket
	DB: DBPRO/bodb02

	Revisions:
		- 20210930@Louisa: Copy result to New match [Redmine:#159271]	   
				  
*/

BEGIN

SET NOCOUNT ON

	DECLARE @tmpResultDetail TABLE
	(
		ResourceID VARCHAR(20)
		,HomeValue VARCHAR(50)
		,AwayValue VARCHAR(50)
		,ResultStatusID TINYINT
		,SettlementStatusID TINYINT
		,OtherInfo VARCHAR(50)
		,ResultSetting TINYINT
	)

	INSERT INTO @tmpResultDetail
	(
		ResourceID
		,HomeValue
		,AwayValue
		,ResultStatusID
		,SettlementStatusID
		,OtherInfo
		,ResultSetting
	)
	SELECT	ResourceID
		 , HomeValue
		 , AwayValue
		 , ResultStatusID
		 , SettlementStatusID
		 , OtherInfo
		 , ResultSetting
	FROM dbo.ResultDetailES r WITH(NOLOCK)
	WHERE r.MatchID = @MatchId
	
	IF @IsOverrideResult = 0 -- IF HomeValue OR AwayValue are differenet, then ignore
	BEGIN	
		DELETE tmp
		FROM @tmpResultDetail tmp
			INNER JOIN dbo.ResultDetailES r WITh(NOLOCK)
				ON r.ResourceID = tmp.ResourceID
		WHERE r.MatchID = @DestinationMatchId
			AND r.SettlementStatusID = 0
			AND r.ResultStatusID < 4
			AND ( ISNULL(r.HomeValue,'') <> ISNULL(tmp.HomeValue,'') OR ISNULL(r.AwayValue,'') <> ISNULL(tmp.AwayValue,'') )
	END
	
	MERGE dbo.ResultDetailES TARGET
	    USING (
	        SELECT  tmp.ResourceId, tmp.HomeValue, tmp.AwayValue, tmp.ResultStatusID, tmp.SettlementStatusID, tmp.OtherInfo, tmp.ResultSetting
	        FROM    @tmpResultDetail tmp
	        ) AS SOURCE ON  TARGET.ResourceId = SOURCE.ResourceId AND TARGET.MatchId = @DestinationMatchId
	WHEN MATCHED 
			AND @IsOverrideResult = 1 
			AND TARGET.SettlementStatusID = 0 
			AND TARGET.ResultStatusID < 4
			AND ( ISNULL(TARGET.HomeValue,'') <> ISNULL(SOURCE.HomeValue,'') OR ISNULL(TARGET.AwayValue,'') <> ISNULL(SOURCE.AwayValue,'') )
			THEN
		UPDATE SET  HomeValue		= SOURCE.HomeValue
					,AwayValue		= SOURCE.AwayValue
					,LastModifyBy	= @AdminId
					,LastModifyDate	= GETDATE()
	WHEN NOT MATCHED BY TARGET THEN
		INSERT ( MatchId, ResourceID, HomeValue, AwayValue, ResultStatusID, SettlementStatusID, CreateBy, CreateDate, LastModifyBy, LastModifyDate, OtherInfo, ResultSetting)
		VALUES (@DestinationMatchId, ResourceID, HomeValue, AwayValue, ResultStatusID, SettlementStatusID, @AdminId, GETDATE(), @AdminId, GETDATE(), OtherInfo, ResultSetting);

END
GO
