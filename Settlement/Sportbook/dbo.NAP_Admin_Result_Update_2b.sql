/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Result_Update_2b]
  @Command			VARCHAR(100) 
 ,@MatchID			INT
 ,@Results			VARCHAR(MAX)= NULL 
 ,@creator			INT			= 0 
 ,@SelectedQuarter	VARCHAR(50) = NULL
AS 
/*
	Created: 20170221@Kathy
	Task: Update the result of basketball
	DB: DBPRO/bodb02 

	Revision
		- 20170613@Kathy: Early Settlement [Redmine:#77835] 
		
	Param's Explanation: 

*/
BEGIN
	SET NOCOUNT ON 

	DECLARE	@sporttype INT
			,@SettlementStatusID TINYINT
	DECLARE @tmpResult TABLE (ResourceId VARCHAR(50), HomeValue VARCHAR(50), AwayValue VARCHAR(50))
	DECLARE @tmpResourceIds TABLE (ResourceId VARCHAR(50))--, QuarterX VARCHAR(2))
	DECLARE @xml XML 
	
	SELECT	@sporttype = Sporttype 
	FROM	Match WITH (NOLOCK)
	WHERE	MatchID = @MatchID

	IF @sporttype <> 2 RETURN -- Apply for basketball ONLY	 
	
	IF @SelectedQuarter IS NOT NULL
	BEGIN
		-- Insert initial ResourceId 00, 01, 02, Q1, Q2, Q3, Q4, OT if they have not created yet
		INSERT INTO dbo.ResultDetail (MatchId, ResourceId, ResultStatusID, SettlementStatusID, CreateDate, LastModifyDate, CreateBy, LastModifyBy)				
		SELECT	@matchid, t.ResourceId, 0, 0, GETDATE(), GETDATE(), @Creator, @Creator
		FROM	(
				VALUES ('00'), ('01'), ('02'), ('OT')
					,('Q1'), ('Q2'), ('Q3'), ('Q4')
		)	t(ResourceId)
		WHERE	NOT EXISTS (SELECT TOP 1 1 FROM dbo.ResultDetail WITH(ROWLOCK) WHERE MatchId = @matchid AND ResourceId = t.ResourceId)
			
		IF @SelectedQuarter LIKE '%FT%'
			INSERT INTO @tmpResourceIds (ResourceId) VALUES ('00'),('OT'),('605')
		
		IF @SelectedQuarter LIKE '%1H%'
			INSERT INTO @tmpResourceIds (ResourceId) VALUES ('01')
		
		IF @SelectedQuarter LIKE '%2H%'
			INSERT INTO @tmpResourceIds (ResourceId) VALUES ('02')
			
		IF @SelectedQuarter LIKE '%801%'
		BEGIN
			INSERT INTO @tmpResourceIds (ResourceId) VALUES ('61701')
			INSERT INTO @tmpResourceIds (ResourceId) VALUES ('Q1')
		END
		IF @SelectedQuarter LIKE '%802%'
		BEGIN
			INSERT INTO @tmpResourceIds (ResourceId) VALUES ('61702')
			INSERT INTO @tmpResourceIds (ResourceId) VALUES ('Q2')
		END
		IF @SelectedQuarter LIKE '%803%'
		BEGIN
			INSERT INTO @tmpResourceIds (ResourceId) VALUES ('61703')
			INSERT INTO @tmpResourceIds (ResourceId) VALUES ('Q3')
		END
		IF @SelectedQuarter LIKE '%804%'
		BEGIN
			INSERT INTO @tmpResourceIds (ResourceId) VALUES ('61704')
			INSERT INTO @tmpResourceIds (ResourceId) VALUES ('Q4')
		END
	END
	ELSE
	BEGIN
		INSERT INTO @tmpResourceIds (ResourceId) VALUES ('604'),('606__'),('607__'),('61301__'),('61302__'),('61303__'),('61304__')		
	END
		
	IF @Command IN ('NAP_Admin_Settlement_1-UNDO', 'NAP_Admin_Settlement_2b-UNDO')
	BEGIN
		UPDATE	r
		SET		 HomeValue			= NULL 
				,AwayValue			= NULL 
				,OtherInfo			= NULL 
				,ResultStatusID		= 0		-- Initial 
				,SettlementStatusID	= 0		-- Initial
				,LastModifyBy		= @Creator 
				,LastModifyDate		= GETDATE() 
		FROM	dbo.ResultDetail r WITH (UPDLOCK,ROWLOCK)
			INNER JOIN @tmpResourceIDs t
				ON	r.ResourceId LIKE t.ResourceId
		WHERE	MatchID = @MatchID
	
	END	
	ELSE IF @Command IN('NAP_Admin_Settlement_1-CAL', 'NAP_Admin_Settlement_Refund_All','NAP_Admin_Settlement_2b-CAL', 'NAP_Admin_Settlement_2b-REFUND')
	BEGIN
		SET @xml = CONVERT(XML,@Results)
				
		INSERT INTO @tmpResult (ResourceId, HomeValue, AwayValue)
		SELECT T.C.value('@Id', 'VARCHAR(50)') AS ResourceId
			,T.C.value('@HomeValue', 'VARCHAR(50)') AS HomeValue
			,T.C.value('@AwayValue', 'VARCHAR(50)') AS AwayValue
		FROM @xml.nodes('/Results/Resource') AS T(C)
		OPTION ( OPTIMIZE FOR ( @xml = NULL ) )	
		
		UPDATE @tmpResult
			SET HomeValue = CASE WHEN HomeValue + AwayValue = 0 THEN NULL ELSE HomeValue END
				,AwayValue = CASE WHEN HomeValue + AwayValue = 0 THEN NULL ELSE AwayValue END
		WHERE ResourceId = 'OT'
		
		IF @Command IN ('NAP_Admin_Settlement_1-CAL', 'NAP_Admin_Settlement_2b-CAL')
			SET @SettlementStatusID = 4
		ELSE
		BEGIN
			SET @SettlementStatusID = 1
			
			IF @SelectedQuarter LIKE '%FT%'
				DELETE
				FROM	dbo.ResultDetail WITH(ROWLOCK, UPDLOCK)
				WHERE	MatchId = @matchid
						AND ResourceId = 'OT'
		END
		
		MERGE dbo.ResultDetail TARGET
		USING (
			SELECT  tr.ResourceId, tr.HomeValue, tr.AwayValue
			FROM	@tmpResourceIds t
				INNER JOIN @tmpResult tr
					ON tr.ResourceId LIKE t.ResourceId
		) AS SOURCE
			ON	TARGET.ResourceId = SOURCE.ResourceId
				AND TARGET.MatchId = @matchid
		WHEN	MATCHED THEN
			UPDATE SET HomeValue = SOURCE.HomeValue
				,AwayValue = SOURCE.AwayValue
				,ResultStatusID = 5
				,SettlementStatusID = @SettlementStatusID
				,LastModifyDate = GETDATE()
				,LastModifyBy = @creator
		WHEN NOT MATCHED BY TARGET THEN	
			INSERT (MatchId, ResourceId, HomeValue, AwayValue
				,ResultStatusID, SettlementStatusID, CreateDate, LastModifyDate, CreateBy, LastModifyBy)				
			VALUES(
				@matchid, SOURCE.ResourceId, SOURCE.HomeValue, SOURCE.AwayValue
				,5,@SettlementStatusID,GETDATE(),GETDATE(),@creator, @creator);	
	END	
END
GO