/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
USE [bodb02]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_Admin_Result_Update_1s]
  @Command						VARCHAR(100) 
 ,@MatchID						INT
 ,@ResourceIDs					VARCHAR(MAX)= NULL 
 ,@Results						VARCHAR(MAX)= NULL 
 ,@fth							SMALLINT	= NULL
 ,@fta							SMALLINT	= NULL
 ,@hth							SMALLINT	= NULL
 ,@hta							SMALLINT	= NULL
 ,@fthCorners					SMALLINT	= NULL
 ,@ftaCorners					SMALLINT	= NULL
 ,@hthCorners					SMALLINT	= NULL
 ,@htaCorners					SMALLINT	= NULL 
 ,@ftFCorner					VARCHAR(1)	= NULL
 ,@ftLCorner					VARCHAR(1)	= NULL
 ,@htFCorner					VARCHAR(1)	= NULL
 ,@htLCorner					VARCHAR(1)	= NULL
 ,@isExistTotalCorner			BIT			= 0 
 ,@isExistHTFCorner				BIT			= 0 
 ,@isExistHTLCorner				BIT			= 0 
 ,@isExistFTFCorner				BIT			= 0 
 ,@isExistFTLCorner				BIT			= 0 
 ,@isExcludeCorner				BIT			= 0 
 ,@Action						VARCHAR(10) = 'CAL'
 ,@IsAuto						BIT			= 0 
 ,@creator						INT			= 0 
 ,@SDTRecord					TINYINT		= 0
AS 
/*
	Created by: Jamie
	Date: 20140204
	Task: Update the result of Tennis 
	DB: DBPRO/bodb02 

	Revision
		- 20150604@Jamie: Apply for Soccer ONLY 
		- 20150618@Jamie: Offer the option Exclude Corner tickets [Feature #38099]
		- 20150928@Johnson: update result of corner without single corner ticket [Redmine: #44415]
		- 20160705@Kathy: PH-AIO phase 2 (67 bettypes ) [Redmine:#53154]
		- 20161118@Bobby: #67551 - Update changes for refunding SDT - ABANDONED match
		
	Param's Explanation: 
		@Results: 'H,1,X,NL,...'  NL: Blank result of Bettype 216 
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE	@sporttype			INT
		,@OtherInfo				VARCHAR(50)
		,@GoalSequence			VARCHAR(50)
		,@betstatus				NVARCHAR(50) 
		,@SettlementStatusID	TINYINT 

	SELECT	@sporttype 			= Sporttype 
		,@GoalSequence 			= GoalRecord
	FROM dbo.Match WITH (NOLOCK)
	WHERE	MatchID = @MatchID

	IF @sporttype <> 1 RETURN -- Apply for Soccer ONLY
	 

	DECLARE @tmpResultDetail TABLE(
			ResourceID		VARCHAR(20)
		,HomeValue		VARCHAR(50)
		,AwayValue		VARCHAR(50)
	)

	DECLARE	@tmpResourceIDs	TABLE(
		 ID			INT IDENTITY(1,1)
		,ResourceID	VARCHAR(20)
	)
	IF @ResourceIDs IS NOT NULL 
	BEGIN
		INSERT INTO @tmpResourceIDs(ResourceID)
		SELECT	Val FROM dbo.StrSplit(@ResourceIDs,',') 
	END 

	IF @Command ='NAP_Admin_Settlement_Auto_1s-CAL'
	BEGIN
		IF @IsAuto = 1 
		BEGIN
			UPDATE	ResultDetail WITH (UPDLOCK,ROWLOCK)
			SET		 ResultStatusID		= 2		-- Auto Settlement 
					,SettlementStatusID	= 4		-- Completed
					,LastModifyBy		= @Creator 
					,LastModifyDate		= GETDATE() 
			WHERE	MatchID = @MatchID
					AND ResourceID IN (SELECT ResourceID FROM @tmpResourceIDs)
		END
		ELSE IF @IsAuto = 0 
		BEGIN 
			DECLARE	@tmpResults TABLE(
				 ID			INT IDENTITY(1,1)
				,Value		VARCHAR(50)
			)

			IF @Results IS NOT NULL 
			BEGIN
				INSERT INTO @tmpResults(Value)
				SELECT	Val FROM dbo.StrSplit(@Results,',') 
			END 

			UPDATE	@tmpResults
			SET		Value = NULL
			WHERE	Value ='NL' --Blank result of Goal Scorer 

			DECLARE @tmpOdds TABLE(
				 MatchID		INT 
				,Bettype		INT
				,BetChoice		VARCHAR(20)
				,OddsInfo		VARCHAR(50)
			)

			IF EXISTS(
				SELECT TOP 1 1 
				FROM	@tmpResourceIDs
				WHERE	ResourceID LIKE '216__'
						OR ResourceID ='217'
			)
			BEGIN
				INSERT INTO @tmpOdds(MatchID,Bettype, BetChoice, OddsInfo)
				SELECT	DISTINCT 
						 o.MatchID 
						,o.bettype
						,x.betChoice 
						,x.OddsInfo
				FROM	[dbo].[odds_flex] x WITH (NOLOCK)
						INNER JOIN [dbo].[odds] o WITH (NOLOCK) ON x.oddsid = o.oddsid
				WHERE	o.MatchID = @MatchID
						AND o.Bettype BETWEEN 216 AND 217  
				ORDER BY o.bettype 
			END 

			MERGE	ResultDetail AS TARGET
			USING(
				SELECT	 @MatchID AS MatchID
						,r.ResourceID 
						,CASE WHEN r.ResourceID NOT IN ('214','215') THEN t.Value ELSE NULL END AS HomeValue 
						,CASE WHEN r.ResourceID IN ('214','215') THEN t.Value ELSE NULL END AS AwayValue 
						,CASE WHEN r.ResourceID LIKE '216__' OR r.ResourceID = '217' THEN o.OddsInfo ELSE NULL END AS OtherInfo  
				FROM	@tmpResourceIDs r 
						INNER JOIN @tmpResults t ON r.ID = t.ID 
						LEFT JOIN @tmpOdds o ON ( (r.ResourceID = '217' AND o.Bettype = 217 AND t.Value = o.BetChoice) OR (r.ResourceID LIKE '216__' AND o.Bettype = 216 AND t.Value = o.BetChoice)) 
													
			) AS SOURCE ON (TARGET.MatchID = SOURCE.MatchID AND TARGET.ResourceID = SOURCE.ResourceID)
			WHEN	MATCHED THEN				 
					UPDATE SET
						TARGET.HomeValue			= SOURCE.HomeValue
						,TARGET.AwayValue			= SOURCE.AwayValue  
						,TARGET.OtherInfo			= CASE WHEN ((TARGET.ResourceID ='217' OR TARGET.ResourceID LIKE '216__') AND SOURCE.OtherInfo IS NULL AND SOURCE.HomeValue IS NOT NULL) THEN TARGET.OtherInfo ELSE SOURCE.OtherInfo END
						,TARGET.ResultStatusID		= 5		-- Manual Settlement 
						,TARGET.SettlementStatusID	= 4		-- Completed
						,TARGET.LastModifyBy		= @Creator 
						,TARGET.LastModifyDate		= GETDATE() 
			WHEN	NOT MATCHED BY TARGET THEN 
					INSERT(
						 MatchID
						,ResourceID
						,HomeValue
						,AwayValue
						,OtherInfo 
						,ResultStatusID
						,SettlementStatusID
						,CreateBy
						,CreateDate
						,LastModifyBy
						,LastModifyDate
					)
					VALUES(
						 SOURCE.MatchID
						,SOURCE.ResourceID
						,SOURCE.HomeValue
						,SOURCE.AwayValue 
						,SOURCE.OtherInfo 
						,5 -- Manual Settlement 
						,4 -- Completed
						,@Creator
						,GETDATE()
						,@Creator
						,GETDATE()
					);		
		END

	END 
	/* END - @Command = 'NAP_Admin_Settlement_Auto_1s-CAL' */
	ELSE IF @Command ='NAP_Admin_Settlement_Auto_1s-UNDO'
	BEGIN
		UPDATE	ResultDetail WITH (UPDLOCK,ROWLOCK)
		SET		 HomeValue			= NULL 
				,AwayValue			= NULL 
				,OtherInfo			= NULL 
				,ResultStatusID		= 0		-- Initial 
				,SettlementStatusID	= 0		-- Initial
				,LastModifyBy		= @Creator 
				,LastModifyDate		= GETDATE() 
		WHERE	MatchID = @MatchID
				AND ResourceID IN (SELECT ResourceID FROM @tmpResourceIDs)
	END
	/* END - @Command = 'NAP_Admin_Settlement_Auto_1s-UNDO' */
	ELSE IF @Command ='NAP_Admin_Settlement_Auto_1s-REFUND'
	BEGIN
		MERGE	ResultDetail AS TARGET
		USING	@tmpResourceIDs AS SOURCE ON TARGET.MatchID = @MatchID AND TARGET.ResourceID = SOURCE.ResourceID 
		WHEN MATCHED THEN 
				UPDATE SET
					 TARGET.ResultStatusID		= 5
					,TARGET.SettlementStatusID	= 1
					,TARGET.LastModifyBy		= @Creator
					,TARGET.LastModifyDate		= GETDATE()
		WHEN NOT MATCHED BY TARGET THEN 
				INSERT(
						 MatchID
						,ResourceID
						,HomeValue
						,AwayValue
						,OtherInfo 
						,ResultStatusID
						,SettlementStatusID
						,CreateBy
						,CreateDate
						,LastModifyBy
						,LastModifyDate
					)
					VALUES(
						 @MatchID
						,SOURCE.ResourceID
						,NULL
						,NULL
						,NULL 
						,5 -- Manual Settlement 
						,1 -- Refund
						,@Creator
						,GETDATE()
						,@Creator
						,GETDATE()
					);		
	END 
	/* END - @Command = 'NAP_Admin_Settlement_Auto_1s-REFUND' */
	ELSE IF @Command = 'NAP_Admin_Settlement_1-CAL'
	BEGIN
		SELECT	@GoalSequence = GoalRecord
		FROM	Match WITH (NOLOCK) 
		WHERE	MatchID = @MatchID

		INSERT INTO @tmpResultDetail(ResourceID,HomeValue,AwayValue)
		-- HalfTime 
		SELECT '01', CAST(@hth AS VARCHAR(50)), CAST(@hta AS VARCHAR(50))
		UNION ALL 
		SELECT '05', CAST(@hthCorners AS VARCHAR(50)), CAST( @htaCorners AS VARCHAR(50)) WHERE @hthCorners IS NOT NULL AND @htaCorners IS NOT NULL AND @isExcludeCorner = 0
		UNION ALL 
		SELECT '207', @HTFCorner, NULL WHERE @HTFCorner IS NOT NULL AND @isExcludeCorner = 0
		UNION ALL 
		SELECT '209', @HTLCorner, NULL WHERE @HTLCorner IS NOT NULL AND @isExcludeCorner = 0	
	
		-- FullTime 
		UNION ALL 
		SELECT'00', CAST(@fth AS VARCHAR(50)), CAST(@fta AS VARCHAR(50)) WHERE @fth IS NOT NULL AND @fta IS NOT NULL 
		UNION ALL 
		SELECT '04', CAST(@fthCorners AS VARCHAR(50)), CAST( @ftaCorners AS VARCHAR(50)) WHERE @fthCorners IS NOT NULL AND @ftaCorners IS NOT NULL AND @isExcludeCorner = 0
		UNION ALL 
		SELECT '206', @FTFCorner, NULL WHERE @FTFCorner IS NOT NULL  AND @isExcludeCorner = 0
		UNION ALL 
		SELECT '208', @FTLCorner, NULL WHERE @FTLCorner IS NOT NULL  AND @isExcludeCorner = 0

		UNION ALL 
		SELECT '08', @GoalSequence,NULL WHERE @GoalSequence IS NOT NULL 

		SELECT @SettlementStatusID = 4 -- Completed

		MERGE	ResultDetail AS TARGET
		USING	@tmpResultDetail AS SOURCE ON (TARGET.MatchID = @MatchID AND TARGET.ResourceID = SOURCE.ResourceID)
		WHEN	MATCHED THEN				 
				UPDATE SET
					TARGET.HomeValue			= SOURCE.HomeValue
					,TARGET.AwayValue			= SOURCE.AwayValue  
					,TARGET.OtherInfo			= NULL
					,TARGET.ResultStatusID		= 5		-- Manual Settlement 
					,TARGET.SettlementStatusID	= @SettlementStatusID		-- Completed
					,TARGET.LastModifyBy		= @Creator 
					,TARGET.LastModifyDate		= GETDATE() 
		WHEN	NOT MATCHED BY TARGET THEN 
				INSERT(
					 MatchID
					,ResourceID
					,HomeValue
					,AwayValue
					,OtherInfo 
					,ResultStatusID
					,SettlementStatusID
					,CreateBy
					,CreateDate
					,LastModifyBy
					,LastModifyDate
				)
				VALUES(
					 @MatchID
					,SOURCE.ResourceID
					,SOURCE.HomeValue
					,SOURCE.AwayValue 
					,NULL 
					,5 -- Manual Settlement 
					,@SettlementStatusID -- Completed
					,@Creator
					,GETDATE()
					,@Creator
					,GETDATE()
				);	 

	END
	/* END - @Command = 'NAP_Admin_Settlement_1-CAL' */
	ELSE IF @Command = 'NAP_Admin_Settlement_1-UNDO'
	BEGIN
		UPDATE ResultDetail WITH (UPDLOCK,ROWLOCK)
		SET		HomeValue			= CASE WHEN ResourceID = '08' THEN '' ELSE NULL END 
				,AwayValue			= NULL
				,ResultStatusID		= 0		-- Initial 
				,SettlementStatusID	= 0		-- Initial
				,LastModifyBy		= @Creator 
				,LastModifyDate		= GETDATE() 
		WHERE	MatchID = @MatchID
				AND ResourceID IN ('00','01','04','05','08','206','207','208','209')

	END 
	/* END - @Command = 'NAP_Admin_Settlement_1-UNDO' */
	ELSE IF @Command ='NAP_Admin_Settlement_Refund_All'
	BEGIN
		SELECT	 @fth			= finalhomescore
				,@fta			= finalawayscore
				,@hth			= hthomescore
				,@hta			= htawayscore 
				,@GoalSequence	= GoalRecord
		FROM	Match WITH (NOLOCK)
		WHERE	MatchID = @MatchID

		INSERT INTO @tmpResultDetail(ResourceID,HomeValue,AwayValue)

		SELECT'00', CAST(@fth AS VARCHAR(50)), CAST(@fta AS VARCHAR(50)) 
		UNION ALL 
		SELECT '01', CAST(@hth AS VARCHAR(50)), CAST(@hta AS VARCHAR(50))
		UNION ALL 
		SELECT '08', @GoalSequence,NULL 
		UNION ALL 
		SELECT '04', '0', '0' WHERE @isExistTotalCorner = 1
								OR EXISTS (SELECT 1 FROM ResultDetail WITH(NOLOCK)
										WHERE matchid = @matchid AND ResourceID = '04'
								) 
		UNION ALL 
		SELECT '05', '0', '0' WHERE @isExistTotalCorner = 1 
								OR EXISTS (SELECT 1 FROM ResultDetail WITH(NOLOCK)
										WHERE matchid = @matchid AND ResourceID = '05'
								)
		UNION ALL 
		SELECT '206', 'N', NULL WHERE @isExistFTFCorner = 1 
								OR EXISTS (SELECT 1 FROM ResultDetail WITH(NOLOCK)
										WHERE matchid = @matchid AND ResourceID = '206'
								)
		UNION ALL 
		SELECT '207', 'N', NULL WHERE @isExistHTFCorner = 1 
								OR EXISTS (SELECT 1 FROM ResultDetail WITH(NOLOCK)
										WHERE matchid = @matchid AND ResourceID = '207'
								)
		UNION ALL 
		SELECT '208', 'N', NULL WHERE @isExistFTLCorner = 1 
								OR EXISTS (SELECT 1 FROM ResultDetail WITH(NOLOCK)
										WHERE matchid = @matchid AND ResourceID = '208'
								)	
		UNION ALL 
		SELECT '209', 'N', NULL WHERE @isExistHTLCorner = 1 
								OR EXISTS (SELECT 1 FROM ResultDetail WITH(NOLOCK)
										WHERE matchid = @matchid AND ResourceID = '209'
								)

		SELECT @SettlementStatusID = 1 -- Refund

		MERGE	ResultDetail AS TARGET
		USING	@tmpResultDetail AS SOURCE ON (TARGET.MatchID = @MatchID AND TARGET.ResourceID = SOURCE.ResourceID)
		WHEN	MATCHED THEN				 
				UPDATE SET
					TARGET.HomeValue			= SOURCE.HomeValue
					,TARGET.AwayValue			= SOURCE.AwayValue  
					,TARGET.OtherInfo			= NULL
					,TARGET.ResultStatusID		= 5		-- Manual Settlement 
					,TARGET.SettlementStatusID	= @SettlementStatusID	-- Refund
					,TARGET.LastModifyBy		= @Creator 
					,TARGET.LastModifyDate		= GETDATE() 
		WHEN	NOT MATCHED BY TARGET THEN 
				INSERT(
					 MatchID
					,ResourceID
					,HomeValue
					,AwayValue
					,OtherInfo 
					,ResultStatusID
					,SettlementStatusID
					,CreateBy
					,CreateDate
					,LastModifyBy
					,LastModifyDate
				)
				VALUES(
					 @MatchID
					,SOURCE.ResourceID
					,SOURCE.HomeValue
					,SOURCE.AwayValue 
					,NULL 
					,5 -- Manual Settlement 
					,@SettlementStatusID -- Refund
					,@Creator
					,GETDATE()
					,@Creator
					,GETDATE()
				);	 
	END 
	/* END - @Command = 'NAP_Admin_Settlement_Refund_All' */
	ELSE IF @Command ='NAP_Admin_Settlement_Refund_All-ABANDONED'
	BEGIN
		
		INSERT INTO @tmpResultDetail(ResourceID,HomeValue,AwayValue)
		SELECT '00', NULL, NULL
		UNION ALL
		SELECT '01', CAST(@hth AS VARCHAR(50)), CAST(@hta AS VARCHAR(50))
		UNION ALL
		SELECT '04', CAST(@hthCorners AS VARCHAR(50)), CAST(@htaCorners AS VARCHAR(50))
		WHERE @isExistTotalCorner = 1
			OR EXISTS (
				SELECT 1 FROM dbo.ResultDetail WITH(NOLOCK)
				WHERE matchid 		= @matchid 
					AND ResourceID 	= '04'
			) 
		UNION ALL
		SELECT '05', CAST(@hthCorners AS VARCHAR(50)), CAST(@htaCorners AS VARCHAR(50))
		WHERE @isExistTotalCorner = 1 
			OR EXISTS (
				SELECT 1 FROM dbo.ResultDetail WITH(NOLOCK)
				WHERE matchid 		= @matchid 
					AND ResourceID 	= '05'
			)
		UNION ALL 
		SELECT '206', @htFCorner, 'NA' 
		WHERE @isExistFTFCorner = 1 
			OR EXISTS (
				SELECT 1 FROM dbo.ResultDetail WITH(NOLOCK)
					WHERE matchid = @matchid AND ResourceID = '206'
			)
		UNION ALL 
		SELECT '207', @htFCorner, 'NA'
		WHERE @isExistHTFCorner = 1 
			OR EXISTS (
				SELECT 1 FROM dbo.ResultDetail WITH(NOLOCK)
				WHERE matchid 		= @matchid 
					AND ResourceID 	= '207'
			)
		UNION ALL 
		SELECT '208', NULL, 'NA' 
		WHERE @isExistFTLCorner = 1 
			OR EXISTS (
				SELECT 1 FROM dbo.ResultDetail WITH(NOLOCK)
				WHERE matchid 		= @matchid 
					AND ResourceID 	= '208'
			)	
		UNION ALL 
		SELECT '209', NULL, 'NA' 
		WHERE @isExistHTLCorner = 1 
			OR EXISTS (
				SELECT 1 FROM ResultDetail WITH(NOLOCK)
				WHERE matchid 		= @matchid 
					AND ResourceID 	= '209'
			)
		UNION ALL 
		SELECT '08', @GoalSequence, 'NA' 
								
		MERGE	dbo.ResultDetail AS TARGET
		USING	@tmpResultDetail AS SOURCE ON (TARGET.MatchID = @MatchID AND TARGET.ResourceID = SOURCE.ResourceID)
		WHEN	MATCHED THEN				 
				UPDATE SET
					TARGET.HomeValue			= CASE WHEN SOURCE.HomeValue  = 'NA' THEN TARGET.HomeValue ELSE SOURCE.HomeValue END
					,TARGET.AwayValue			= CASE WHEN SOURCE.AwayValue  = 'NA' THEN TARGET.AwayValue ELSE SOURCE.AwayValue END
					,TARGET.OtherInfo			= CASE WHEN SOURCE.ResourceID  = '01' THEN TARGET.OtherInfo ELSE NULL END
					,TARGET.ResultStatusID		= 5		-- Manual Settlement 
					,TARGET.SettlementStatusID	= 5		-- ABANDONED 1H
					,TARGET.LastModifyBy		= @Creator 
					,TARGET.LastModifyDate		= GETDATE() 
		WHEN	NOT MATCHED BY TARGET THEN 
				INSERT(
					 MatchID
					,ResourceID
					,HomeValue
					,AwayValue
					,OtherInfo 
					,ResultStatusID
					,SettlementStatusID
					,CreateBy
					,CreateDate
					,LastModifyBy
					,LastModifyDate
				)
				VALUES(
					 @MatchID
					,SOURCE.ResourceID
					,CASE WHEN SOURCE.HomeValue = 'NA' THEN NULL ELSE SOURCE.HomeValue END
					,CASE WHEN SOURCE.AwayValue = 'NA' THEN NULL ELSE SOURCE.AwayValue END
					,NULL 
					,5 -- Manual Settlement 
					,5 -- ABANDONED 1H
					,@Creator
					,GETDATE()
					,@Creator
					,GETDATE()
				);	 		
		
		-- UPDATE OtherInfo
		SELECT @OtherInfo = ISNULL(OtherInfo,'')
		FROM dbo.ResultDetail WITH(NOLOCK)
		WHERE matchid 		= @matchid 
			AND ResourceID 	= '01' --HT
		
		SET @OtherInfo = CASE 
							WHEN CHARINDEX('SDT:',@OtherInfo) > 0 THEN REPLACE(@OtherInfo,SUBSTRING(@OtherInfo,CHARINDEX('SDT:',@OtherInfo) + 4, 1),CAST(ISNULL(@SDTRecord,0) AS VARCHAR(50))) 
							ELSE @OtherInfo + 'SDT:' + CAST(ISNULL(@SDTRecord,0) AS VARCHAR(50)) + ';'  
						END
		
		UPDATE dbo.ResultDetail WITH(ROWLOCK,UPDLOCK)
		SET OtherInfo 		=  @OtherInfo
		WHERE matchid 		= @matchid 
			AND ResourceID 	= '01' -- ABANDONED 1H
			
	END
	/* END - @Command = 'NAP_Admin_Settlement_Refund_All-ABANDONED' */
	ELSE IF @Command ='NAP_Admin_Settlement_RefundFT'
	BEGIN
		SELECT	 @fth			= finalhomescore
				,@fta			= finalawayscore
				,@betstatus		= betstatus
		FROM	Match WITH (NOLOCK)
		WHERE	MatchID = @MatchID

		SELECT	@SettlementStatusID = CASE WHEN CHARINDEX('Refund;', @betstatus) > 0 THEN 1 
										   WHEN CHARINDEX('Refund FT;',@betstatus) > 0 THEN 3 
										   ELSE 3 END --Refund FT 

		INSERT INTO @tmpResultDetail(ResourceID,HomeValue,AwayValue)

		SELECT'00', CAST(@fth AS VARCHAR(50)), CAST(@fta AS VARCHAR(50)) 
		UNION ALL 
		SELECT '08', @GoalSequence,NULL 
		UNION ALL 
		SELECT '04', '0', '0' WHERE @isExistTotalCorner = 1 
								OR EXISTS (SELECT 1 FROM ResultDetail WITH(NOLOCK)
										WHERE matchid = @matchid AND ResourceID = '04'
								)
		UNION ALL 
		SELECT '206', 'N', NULL WHERE @isExistFTFCorner = 1 
								OR EXISTS (SELECT 1 FROM ResultDetail WITH(NOLOCK)
										WHERE matchid = @matchid AND ResourceID = '206'
								)
		UNION ALL 
		SELECT '208', 'N', NULL WHERE @isExistFTLCorner = 1 
								OR EXISTS (SELECT 1 FROM ResultDetail WITH(NOLOCK)
										WHERE matchid = @matchid AND ResourceID = '208'
								)

		MERGE	ResultDetail AS TARGET
		USING	@tmpResultDetail AS SOURCE ON (TARGET.MatchID = @MatchID AND TARGET.ResourceID = SOURCE.ResourceID)
		WHEN	MATCHED THEN				 
				UPDATE SET
					TARGET.HomeValue			= SOURCE.HomeValue
					,TARGET.AwayValue			= SOURCE.AwayValue  
					,TARGET.OtherInfo			= NULL
					,TARGET.ResultStatusID		= 5		-- Manual Settlement 
					,TARGET.SettlementStatusID	= @SettlementStatusID	-- Refund/RefundFT
					,TARGET.LastModifyBy		= @Creator 
					,TARGET.LastModifyDate		= GETDATE() 
		WHEN	NOT MATCHED BY TARGET THEN 
				INSERT(
					 MatchID
					,ResourceID
					,HomeValue
					,AwayValue
					,OtherInfo 
					,ResultStatusID
					,SettlementStatusID
					,CreateBy
					,CreateDate
					,LastModifyBy
					,LastModifyDate
				)
				VALUES(
					 @MatchID
					,SOURCE.ResourceID
					,SOURCE.HomeValue
					,SOURCE.AwayValue 
					,NULL 
					,5 -- Manual Settlement 
					,@SettlementStatusID -- Refund/RefundFT
					,@Creator
					,GETDATE()
					,@Creator
					,GETDATE()
				);	 
	END	
	/* END - @Command = ''NAP_Admin_Settlement_RefundFT' */
	ELSE IF @Command ='NAP_Admin_Settlement_RefundFT-ABANDONED'
	BEGIN
				
		INSERT INTO @tmpResultDetail(ResourceID,HomeValue,AwayValue)
		--SELECT '00', 'NA', 'NA'
		SELECT'00', CAST(@fth AS VARCHAR(50)), CAST(@fta AS VARCHAR(50)) 
		UNION ALL 
		SELECT '04', CAST(@fthCorners AS VARCHAR(50)), CAST(@ftaCorners AS VARCHAR(50))
		WHERE @isExistTotalCorner = 1 
			OR EXISTS (
				SELECT 1 FROM dbo.ResultDetail WITH(NOLOCK)
				WHERE matchid 		= @matchid 
					AND ResourceID 	= '04'
			)
		UNION ALL 
		SELECT '206', @ftFCorner, 'NA' 
		WHERE @isExistFTFCorner = 1 
			OR EXISTS (
				SELECT 1 FROM dbo.ResultDetail WITH(NOLOCK)
				WHERE matchid = @matchid AND ResourceID = '206'
			)
		UNION ALL 
		SELECT '208', NULL, 'NA'
		WHERE @isExistFTLCorner = 1 
			OR EXISTS (
				SELECT 1 FROM dbo.ResultDetail WITH(NOLOCK)
				WHERE matchid 	= @matchid 
				AND ResourceID 	= '208'
			)
		UNION ALL 
		SELECT '08', @GoalSequence, 'NA'
			
		MERGE	dbo.ResultDetail AS TARGET
		USING	@tmpResultDetail AS SOURCE ON (TARGET.MatchID = @MatchID AND TARGET.ResourceID = SOURCE.ResourceID)
		WHEN	MATCHED THEN				 
				UPDATE SET
					TARGET.HomeValue			= CASE WHEN SOURCE.HomeValue  = 'NA' THEN TARGET.HomeValue ELSE SOURCE.HomeValue END
					,TARGET.AwayValue			= CASE WHEN SOURCE.AwayValue  = 'NA' THEN TARGET.AwayValue ELSE SOURCE.AwayValue END
					,TARGET.OtherInfo			= CASE WHEN SOURCE.ResourceID  = '00' THEN TARGET.OtherInfo ELSE NULL END
					,TARGET.ResultStatusID		= 5		-- Manual Settlement 
					,TARGET.SettlementStatusID	= 6		-- ABANDONED 2H
					,TARGET.LastModifyBy		= @Creator 
					,TARGET.LastModifyDate		= GETDATE() 
		WHEN	NOT MATCHED BY TARGET THEN 
				INSERT(
					 MatchID
					,ResourceID
					,HomeValue
					,AwayValue
					,OtherInfo 
					,ResultStatusID
					,SettlementStatusID
					,CreateBy
					,CreateDate
					,LastModifyBy
					,LastModifyDate
				)
				VALUES(
					 @MatchID
					,SOURCE.ResourceID
					,CASE WHEN SOURCE.HomeValue = 'NA' THEN NULL ELSE SOURCE.HomeValue END
					,CASE WHEN SOURCE.AwayValue = 'NA' THEN NULL ELSE SOURCE.AwayValue END
					,NULL 
					,5 -- Manual Settlement 
					,6 -- ABANDONED 2H
					,@Creator
					,GETDATE()
					,@Creator
					,GETDATE()
				);	
		
		--UPDATE OtherInfo
		SELECT @OtherInfo = ISNULL(OtherInfo,'')
		FROM dbo.ResultDetail WITH(NOLOCK)
		WHERE matchid 		= @matchid 
			AND ResourceID 	= '00' --FT
		
		SET @OtherInfo = CASE 
							WHEN CHARINDEX('SDT:',@OtherInfo) > 0 THEN REPLACE(@OtherInfo,SUBSTRING(@OtherInfo,CHARINDEX('SDT:',@OtherInfo) + 4, 1),CAST(ISNULL(@SDTRecord,0) AS VARCHAR(50))) 
							ELSE @OtherInfo + 'SDT:' + CAST(ISNULL(@SDTRecord,0) AS VARCHAR(50)) + ';'  
						END
		
		UPDATE dbo.ResultDetail WITH(ROWLOCK,UPDLOCK)
		SET OtherInfo 		= @OtherInfo
		WHERE matchid 		= @matchid 
			AND ResourceID 	= '00' -- ABANDONED 2H
			
	END
	/* END - @Command = 'NAP_Admin_Settlement_RefundFT-ABANDONED' */
	ELSE IF @Command ='NAP_Admin_Settlement_RefundHT'
	BEGIN
		SELECT	 @hth			= hthomescore
				,@hta			= htawayscore
				,@betstatus		= betstatus
		FROM	Match WITH (NOLOCK)
		WHERE	MatchID = @MatchID

		SELECT	@SettlementStatusID = CASE WHEN CHARINDEX('Refund;', @betstatus) > 0 THEN 1 
										   WHEN CHARINDEX('Refund HT;',@betstatus) > 0 THEN 2 
										   ELSE 2 END --Refund HT 

		INSERT INTO @tmpResultDetail(ResourceID,HomeValue,AwayValue)

		SELECT'01', CAST(@hth AS VARCHAR(50)), CAST(@hta AS VARCHAR(50)) 
		UNION ALL 
		SELECT '05', '0', '0' WHERE @isExistTotalCorner = 1
								OR EXISTS (SELECT 1 FROM ResultDetail WITH(NOLOCK)
									WHERE matchid = @matchid AND ResourceID = '05'
								) 
		UNION ALL 
		SELECT '207', 'N', NULL WHERE @isExistHTFCorner = 1
								OR EXISTS (SELECT 1 FROM ResultDetail WITH(NOLOCK)
										WHERE matchid = @matchid AND ResourceID = '207'
								) 
		UNION ALL 
		SELECT '209', 'N', NULL WHERE @isExistHTLCorner = 1 
								OR EXISTS (SELECT 1 FROM ResultDetail WITH(NOLOCK)
										WHERE matchid = @matchid AND ResourceID = '209'
								)

		MERGE	ResultDetail AS TARGET
		USING	@tmpResultDetail AS SOURCE ON (TARGET.MatchID = @MatchID AND TARGET.ResourceID = SOURCE.ResourceID)
		WHEN	MATCHED THEN				 
				UPDATE SET
					TARGET.HomeValue			= SOURCE.HomeValue
					,TARGET.AwayValue			= SOURCE.AwayValue  
					,TARGET.OtherInfo			= NULL
					,TARGET.ResultStatusID		= 5		-- Manual Settlement 
					,TARGET.SettlementStatusID	= @SettlementStatusID	-- Refund/RefundHT
					,TARGET.LastModifyBy		= @Creator 
					,TARGET.LastModifyDate		= GETDATE() 
		WHEN	NOT MATCHED BY TARGET THEN 
				INSERT(
					 MatchID
					,ResourceID
					,HomeValue
					,AwayValue
					,OtherInfo 
					,ResultStatusID
					,SettlementStatusID
					,CreateBy
					,CreateDate
					,LastModifyBy
					,LastModifyDate
				)
				VALUES(
					 @MatchID
					,SOURCE.ResourceID
					,SOURCE.HomeValue
					,SOURCE.AwayValue 
					,NULL 
					,5 -- Manual Settlement 
					,@SettlementStatusID -- Refund/RefundHT
					,@Creator
					,GETDATE()
					,@Creator
					,GETDATE()
				);	 
	END 
	/* END - @Command = 'NAP_Admin_Settlement_RefundHT' */
	ELSE IF @Command ='NAP_Admin_Settlement_FGLG'
	BEGIN
		SELECT	@GoalSequence	= GoalRecord
		FROM	Match WITH (NOLOCK)
		WHERE	MatchID = @MatchID		

		SELECT	@SettlementStatusID = 4 

		INSERT INTO @tmpResultDetail(ResourceID,HomeValue,AwayValue)
		SELECT '08', @GoalSequence,NULL 

		MERGE	ResultDetail AS TARGET
		USING	@tmpResultDetail AS SOURCE ON (TARGET.MatchID = @MatchID AND TARGET.ResourceID = SOURCE.ResourceID)
		WHEN	MATCHED THEN				 
				UPDATE SET
					TARGET.HomeValue			= SOURCE.HomeValue
					,TARGET.AwayValue			= SOURCE.AwayValue  
					,TARGET.OtherInfo			= NULL
					,TARGET.ResultStatusID		= 5		-- Manual Settlement 
					,TARGET.SettlementStatusID	= @SettlementStatusID	-- Completed
					,TARGET.LastModifyBy		= @Creator 
					,TARGET.LastModifyDate		= GETDATE() 
		WHEN	NOT MATCHED BY TARGET THEN 
				INSERT(
					 MatchID
					,ResourceID
					,HomeValue
					,AwayValue
					,OtherInfo 
					,ResultStatusID
					,SettlementStatusID
					,CreateBy
					,CreateDate
					,LastModifyBy
					,LastModifyDate
				)
				VALUES(
					 @MatchID
					,SOURCE.ResourceID
					,SOURCE.HomeValue
					,SOURCE.AwayValue 
					,NULL 
					,5 -- Manual Settlement 
					,@SettlementStatusID -- Completed
					,@Creator
					,GETDATE()
					,@Creator
					,GETDATE()
				);	 
	END 
	/* END - @Command = 'NAP_Admin_Settlement_FGLG' */
	ELSE IF @Command ='NAP_Admin_Settlement_Corner-CAL'
	BEGIN
		INSERT INTO @tmpResultDetail(ResourceID,HomeValue,AwayValue)
		SELECT '05', CAST(@hthCorners AS VARCHAR(50)), CAST( @htaCorners AS VARCHAR(50)) WHERE @hthCorners IS NOT NULL AND @htaCorners IS NOT NULL 
		UNION ALL 
		SELECT '207', @HTFCorner, NULL WHERE @HTFCorner IS NOT NULL
		UNION ALL 
		SELECT '209', @HTLCorner, NULL WHERE @HTLCorner IS NOT NULL 
	
		-- FullTime 
		UNION ALL 
		SELECT '04', CAST(@fthCorners AS VARCHAR(50)), CAST( @ftaCorners AS VARCHAR(50)) WHERE @fthCorners IS NOT NULL AND @ftaCorners IS NOT NULL 
		UNION ALL 
		SELECT '206', @FTFCorner, NULL WHERE @FTFCorner IS NOT NULL  
		UNION ALL 
		SELECT '208', @FTLCorner, NULL WHERE @FTLCorner IS NOT NULL 

		SELECT @SettlementStatusID = 4 -- Completed

		SELECT * FROM @tmpResultDetail

		MERGE	ResultDetail AS TARGET
		USING	@tmpResultDetail AS SOURCE ON (TARGET.MatchID = @MatchID AND TARGET.ResourceID = SOURCE.ResourceID)
		WHEN	MATCHED THEN				 
				UPDATE SET
					TARGET.HomeValue			= SOURCE.HomeValue
					,TARGET.AwayValue			= SOURCE.AwayValue  
					,TARGET.OtherInfo			= NULL
					,TARGET.ResultStatusID		= 5		-- Manual Settlement 
					,TARGET.SettlementStatusID	= @SettlementStatusID		-- Completed
					,TARGET.LastModifyBy		= @Creator 
					,TARGET.LastModifyDate		= GETDATE() 
		WHEN	NOT MATCHED BY TARGET THEN 
				INSERT(
					 MatchID
					,ResourceID
					,HomeValue
					,AwayValue
					,OtherInfo 
					,ResultStatusID
					,SettlementStatusID
					,CreateBy
					,CreateDate
					,LastModifyBy
					,LastModifyDate
				)
				VALUES(
					 @MatchID
					,SOURCE.ResourceID
					,SOURCE.HomeValue
					,SOURCE.AwayValue 
					,NULL 
					,5 -- Manual Settlement 
					,@SettlementStatusID -- Completed
					,@Creator
					,GETDATE()
					,@Creator
					,GETDATE()
				);	 
	END 
	/* END - @Command = 'NAP_Admin_Settlement_Corner-CAL' */
END
GO
GRANT EXECUTE ON [dbo].[NAP_Admin_Result_Update_1s] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Admin_Result_Update_1s] TO [vnteam] AS [dbo]
GO