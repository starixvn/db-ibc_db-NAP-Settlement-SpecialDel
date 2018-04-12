/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_VS_Betradar_Result_Update]
(
	@Command			VARCHAR(100) 
	,@MatchID			INT
	,@ResourceResult	VARCHAR(MAX) = '' 
	,@creator			INT	= 0 
	,@IsAuto			BIT = 1
) 
AS 
/*
	Created: 20180207@Helen
	Task: Update the result of Betradar VS basketball
	DB: DBPRO/bodb02 

	Revision
		- 20180207@Helen: Betradar VS 2 - basketball [Redmine:#90154] 
		
	Param's Explanation: 
	@ResourceResult='<Results>
                            <Resource ResourceId="00" Custom1="100" Custom2="106" />
                            <Resource ResourceId="01" Custom1="60" Custom2="41" />
                            <Resource ResourceId="280920" Custom1="H" Custom2="" />
                            <Resource ResourceId="280940" Custom1="A" Custom2="" />
                            <Resource ResourceId="280960" Custom1="N" Custom2="" />
                    </Results>'
     Table ResultDetail3rd: (ResultID, VendorID, MatchID, GameID, Custom1, Custom2, Custom3, ResultStatusID, SettlementStatusID, GameResult, OtherInfo, CreateBy, CreateDate, LastModifyBy, LastModifyDate)               
	 ResourceID for basketball:FT:'00',1H:'01',RaceToXPoint:'280920','280940','280960' 	
	 
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE	@sporttype INT
			,@SettlementStatusID TINYINT
			,@ResultStatusID TINYINT
			
	DECLARE @tmpResult TABLE (ResourceId VARCHAR(20), HomeValue VARCHAR(20), AwayValue VARCHAR(20))
	DECLARE @tmpResourceIds TABLE (ResourceId VARCHAR(20))
	DECLARE @xml XML 
	
	SELECT	@sporttype = Sporttype 
	FROM	Match WITH (NOLOCK)
	WHERE	MatchID = @MatchID

	IF @sporttype <> 193 RETURN -- Apply for VS Betradar - basketball 
	
	IF @IsAuto = 1
		SET @ResultStatusID = 2
	ELSE
		SET @ResultStatusID = 5	
		
	INSERT INTO @tmpResourceIds (ResourceId) 
	VALUES ('00'),('01'),('280920'),('280940'),('280960')
		
	SET @xml = CONVERT(XML,@ResourceResult)
	
	INSERT INTO @tmpResult (ResourceId, HomeValue, AwayValue)
	SELECT DISTINCT T.C.value('@ResourceId', 'VARCHAR(20)') AS ResourceId
		,T.C.value('@Custom1', 'VARCHAR(20)') AS HomeValue
		,T.C.value('@Custom2', 'VARCHAR(20)') AS AwayValue
	FROM @xml.nodes('/Results/Resource') AS T(C)
	OPTION ( OPTIMIZE FOR ( @xml = NULL ) )		
	
	IF @Command = 'NAP_Admin_Settlement_VS_BetRadar-REFUND'
	BEGIN		
		SET @SettlementStatusID = 1 -- REFUND
		
		UPDATE RD
			 SET ResultStatusID = @ResultStatusID
				,SettlementStatusID = @SettlementStatusID
		FROM ResultDetail3rd RD WITH (ROWLOCK,UPDLOCK) 
		WHERE RD.VendorID = 17 AND RD.GameID = 0 AND RD.MatchID = @MatchID 
		
		INSERT INTO ResultDetail3rd (VendorID, MatchID, GameID,ResourceId, Custom1, Custom2, ResultStatusID, SettlementStatusID, CreateBy, CreateDate, LastModifyBy, LastModifyDate)
		SELECT 17, @matchid,0, RD_tmp.ResourceId, CASE WHEN RD_tmp.ResourceId IN ('00','01') THEN '0' ELSE '' END, CASE WHEN RD_tmp.ResourceId IN ('00','01') THEN '0' ELSE '' END
				,@ResultStatusID,@SettlementStatusID,@creator,GETDATE(),@creator,GETDATE()
		FROM @tmpResourceIds RD_tmp
		WHERE  NOT EXISTS (SELECT TOP 1 1 
							FROM ResultDetail3rd RD WITH (NOLOCK) 
							WHERE  RD.VendorID = 17 AND RD.GameID = 0
								AND RD.MatchID = @MatchID 
								AND RD.ResourceId = RD_tmp.ResourceId)
								
	END	
		
	IF @Command = 'NAP_Admin_Settlement_VS_BetRadar-CAL'
	BEGIN
		
		SET @SettlementStatusID = 4
		
		MERGE dbo.ResultDetail3rd TARGET
		USING (
			SELECT  tr.ResourceId, tr.HomeValue, tr.AwayValue
			FROM	@tmpResourceIds t
				INNER JOIN @tmpResult tr
					ON tr.ResourceId = t.ResourceId
		) AS SOURCE
			ON	TARGET.VendorID = 17 AND TARGET.GameID = 0 AND TARGET.MatchId = @matchid
				AND TARGET.ResourceId = SOURCE.ResourceId
		WHEN	MATCHED THEN
			UPDATE SET Custom1 = SOURCE.HomeValue
				,Custom2 = SOURCE.AwayValue
				,ResultStatusID = @ResultStatusID
				,SettlementStatusID = @SettlementStatusID
				,LastModifyDate = GETDATE()
				,LastModifyBy = @creator
		WHEN NOT MATCHED BY TARGET THEN	
			INSERT (VendorID, MatchID, GameID,ResourceId, Custom1, Custom2, ResultStatusID, SettlementStatusID, CreateBy, CreateDate, LastModifyBy, LastModifyDate)
			VALUES(
				17, @matchid,0, SOURCE.ResourceId, SOURCE.HomeValue, SOURCE.AwayValue
				,@ResultStatusID,@SettlementStatusID,@creator,GETDATE(),@creator,GETDATE())	;
	END
		
		
END
GO

