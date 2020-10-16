/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_CheckingProcess]
	@IsExistParlay 				BIT = 0
	, @IsExistOutright 			BIT = 0
	, @IsExistMG				BIT = 0
	, @IsExistMatch				BIT = 0
	, @IsExistNG				BIT = 0
	, @IsExistVS				BIT = 0
	, @IsExistParlayVSBetradar 	BIT = 0
	, @IsExistBB				BIT	= 0  --BetBuilder
	, @checkKeyValue2			BIT = 0
	, @IsReleased				BIT	= 0
	, @IsExistFM				BIT = 0	
	, @IsExistFM2				BIT = 0
	, @AvaiableProcess			BIT = 0 OUTPUT
	, @ErrCode					INT = 0 OUTPUT
	, @ErrMsg					NVARCHAR(200) = '' OUTPUT
AS 
/* Created by: Bobby  
 Task:  VOID BY BET ID (Running & Settled tickets)  
 DB: DBTXN/bodb02  
 Original:   
   
 Revisions:  
	-20160318@bobby.nguyen: #54311 - Correct checking process on match with specific product/sport
	-20160318@bobby.nguyen: #55930 - Exclude bettype 9 from match locking table
	-20160413@bobby.nguyen: #55756 - Update changes for checking process
	- 20170530@Kent: Integrate Betradar Virtual Sports [Redmine:#77177]
	- 20190404@Kathy: New keyId for Fast Market [Redmine:#106823]
	- 20190103@Vicky: Incorporate BetBuilder  [Redmine:#106903]
	 - 20201013@Max: Integrate new bet type Time Machine OU [Redmine: #143032]
	
 Param's Explanation:   
 
 Dependences:
	1. CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	OR CREATE TABLE #tblMatchProcessKeyValue2 (matchid INT, KeyID TINYINT, KeyValue2 VARCHAR(20))  -- BetBuilder
	
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @isExistTempVariable	BIT = 0
	CREATE TABLE #checkProcess(KeyId TINYINT)
	
	SELECT @avaiableProcess = 0
		, @ErrCode			= 0
		, @ErrMsg			= ''
		, @isExistTempVariable = CASE WHEN (
										@isExistMatch = 1
										OR @isExistOutright = 1
										OR @isExistMG = 1
										OR @isExistNG = 1
										OR @isExistVS = 1
										OR @IsExistFM = 1
										OR @isExistBB = 1
										OR @IsExistFM2 = 1
									) THEN 1 ELSE 0 
								END
	-- checking dependency				
	IF (@isExistTempVariable = 1
		AND (OBJECT_ID('tempdb..#tblMatchProcess') IS NULL AND OBJECT_ID('tempdb..#tblMatchProcessKeyValue2') IS NULL)
	)
	BEGIN
		SELECT @ErrCode		= 109
			, @ErrMsg		= N'Store Procedure NAP_Admin_CheckingProcess is missing table dependency.'
			
		RETURN
	END

	-- Locking process
	IF(@IsReleased = 0 )
	BEGIN
		
		IF (@isExistParlay  = 1)
		BEGIN
			IF EXISTS(
				SELECT 1 
				FROM dbo.SystemSettings WITH (NOLOCK)
				WHERE VValue 	= 1 
				AND VName 		= 'isCalculatingParlay'
			)  
			BEGIN  
				SELECT @ErrCode	= 100  
					,@ErrMsg 	= 'Another parlay settlement is in progress or some parlay tickets are being deleted, please wait a few seconds until the on-going process has finished and try again.'  
				
				RETURN
			END
			ELSE
			BEGIN
				UPDATE	dbo.systemSettings WITH (ROWLOCK, UPDLOCK)
				SET VValue 		= '1'  
				WHERE VName 	= 'isCalculatingParlay'
				
				SET @avaiableProcess = 1
			END
		END
		
		IF (@IsExistParlayVSBetradar  = 1)
		BEGIN		
			IF EXISTS(
				SELECT 1 
				FROM dbo.SystemSettings WITH (NOLOCK) 
				WHERE VValue 	= 1 
				AND VName 		= 'isCalculatingParlayVSBetradar'
			)  
			BEGIN  
				SELECT @ErrCode	= 100  
					,@ErrMsg 	= 'Another parlay settlement is in progress or some parlay tickets are being deleted, please wait a few seconds until the on-going process has finished and try again.'  
				
				RETURN
			END  
			ELSE
			BEGIN
				UPDATE	dbo.systemSettings WITH (ROWLOCK, UPDLOCK)
				SET VValue 		= '1'  
				WHERE VName 	= 'isCalculatingParlayVSBetradar' 
				
				SET @avaiableProcess = 1
			END
		END
		
		IF (@isExistNG = 1)
		BEGIN
			IF EXISTS (
				SELECT 1
				FROM dbo.SystemSettings WITH (NOLOCK)
				WHERE VValue 	= 1 
				AND VName 		= 'isCalculatingNGManual'
			)
			BEGIN
				UPDATE	dbo.systemSettings WITH (ROWLOCK, UPDLOCK)  
				SET VValue 		= '0'  
				WHERE VName 	= 'isCalculatingParlay' 
				AND @isExistParlay 	= 1
				
				SELECT @ErrCode = 101
					,@ErrMsg 	= 'Another number game re-calculation is in progress or some tickets of this match are being voided, please wait a few seconds until the on-going process has finished and try again.'
				
				SELECT @avaiableProcess = 0
				
				RETURN
			END
			ELSE
			BEGIN
				UPDATE dbo.systemSettings WITH (ROWLOCK, UPDLOCK)
				SET VValue 	= '1'
				WHERE VName = 'isCalculatingNGManual'
				
				SET @avaiableProcess = 1
			END
		END
		
		IF (@checkKeyValue2 = 1)
		BEGIN
			IF EXISTS(SELECT 1
					  FROM dbo.TempVariableNumber ck WITH(ROWLOCK)
							INNER JOIN #tblMatchProcessKeyValue2 tp ON ck.KeyValue = tp.matchid AND ck.KeyID = tp.KeyID
					  WHERE tp.KeyID > 0 AND ck.KeyValue2 = tp.KeyValue2
					  UNION ALL
					  SELECT 1
					  FROM dbo.TempVariableNumber ck WITH(ROWLOCK)
							INNER JOIN #tblMatchProcessKeyValue2 tp ON ck.KeyValue = tp.matchid AND ck.KeyID = tp.KeyID
					  WHERE tp.KeyID > 0 AND ck.KeyValue2 = '0'
					)
			BEGIN
				SELECT @ErrCode = 103
						,@ErrMsg	= 'These matches are being calculated or some tickets of matches are being voided, please wait a few seconds until the on-going process is completed and try again.'
				SELECT @avaiableProcess = 0
				 
				RETURN
			END
			BEGIN TRY
					
				INSERT INTO dbo.TempVariableNumber (KeyID, KeyValue, KeyValue2) 
				SELECT DISTINCT KeyID, matchid, KeyValue2
				FROM #tblMatchProcessKeyValue2
				WHERE KeyID > 0
				
				SET @avaiableProcess = 1
				
			END TRY
			BEGIN CATCH
				
				SELECT @ErrCode = 103
					,@ErrMsg	= 'These matches are being calculated or some tickets of matches are being voided, please wait a few seconds until the on-going process is completed and try again.'
				
				SELECT @avaiableProcess = 0	
			END CATCH
			
			RETURN
		END
		
		IF (@isExistTempVariable = 1)
		BEGIN
				 
			INSERT INTO #checkProcess(KeyId)
			SELECT DISTINCT
				CASE 
					WHEN ((@isExistMatch = 1 OR @isExistNG = 1)	AND ck.KeyId = 1) THEN 1 -- SB,NG,LC
					WHEN @isExistOutright = 1 	AND ck.KeyId = 2 THEN 2	-- Outright
					WHEN @isExistMG = 1 		AND ck.KeyId = 3 THEN 3	-- MG
					WHEN @isExistVS = 1 		AND ck.KeyId = 4 THEN 4	-- VS Racing
					WHEN @isExistFM = 1 		AND ck.KeyId = 6 THEN 6	-- Fast market
					WHEN @IsExistBB = 1			AND ck.KeyId = 5 THEN 5 -- BetBuilder
					WHEN @IsExistFM2 = 1		AND ck.KeyID = 7 THEN 7 -- Fast market 228
					ELSE 0
				END AS KeyId
			FROM dbo.TempVariableNumber ck WITH(ROWLOCK)
				INNER JOIN #tblMatchProcess tp 
				ON ck.KeyValue = tp.matchid AND ck.KeyID = tp.KeyID
				
			WHERE tp.KeyID > 0
			
			IF ( NOT EXISTS (SELECT TOP 1 1 FROM #checkProcess))
			BEGIN
				BEGIN TRY	
					
					INSERT INTO dbo.TempVariableNumber (KeyID, KeyValue) 
					SELECT DISTINCT KeyID, matchid
					FROM #tblMatchProcess
					WHERE KeyID > 0
					
					SET @avaiableProcess = 1
					
				END TRY
				BEGIN CATCH
					SELECT @ErrCode = ERROR_NUMBER()
						,@ErrMsg 	= ERROR_MESSAGE()
							
				END CATCH
				
				IF (@ErrCode > 0)
				BEGIN 
					
					UPDATE	dbo.systemSettings WITH (ROWLOCK, UPDLOCK)  
					SET VValue 			= '0'  
					WHERE VName 		= 'isCalculatingParlay' 
					AND @isExistParlay 	= 1
					
					UPDATE	dbo.systemSettings WITH (ROWLOCK, UPDLOCK)  
					SET VValue 			= '0'  
					WHERE VName 		= 'isCalculatingParlayVSBetradar' 
					AND @IsExistParlayVSBetradar 	= 1
									
					UPDATE dbo.systemSettings WITH (ROWLOCK, UPDLOCK)
					SET VValue 		= '0'
					WHERE VName 	= 'isCalculatingNGManual'
					AND @isExistNG 	= 1
					
					SELECT @ErrCode = 103
						,@ErrMsg	= 'These matches are being calculated or some tickets of matches are being voided, please wait a few seconds until the on-going process is completed and try again.'
					
					SELECT @avaiableProcess = 0
					
					RETURN
				END
						
			END
			ELSE
			BEGIN
				UPDATE	dbo.systemSettings WITH (ROWLOCK, UPDLOCK)  
				SET VValue 			= '0'  
				WHERE VName 		= 'isCalculatingParlay' 
				AND @isExistParlay 	= 1
				
				UPDATE	dbo.systemSettings WITH (ROWLOCK, UPDLOCK)  
				SET VValue 			= '0'  
				WHERE VName 		= 'isCalculatingParlayVSBetradar' 
				AND @IsExistParlayVSBetradar 	= 1
								
				UPDATE dbo.systemSettings WITH (ROWLOCK, UPDLOCK)
				SET VValue 		= '0'
				WHERE VName 	= 'isCalculatingNGManual'
				AND @isExistNG 	= 1
					
				SELECT @ErrCode = 102
					,@ErrMsg	= 'These matches are being calculated or some tickets of matches are being voided, please wait a few seconds until the on-going process is completed and try again.'
					
				SELECT @avaiableProcess = 0
				RETURN
			END
		END
	END

	-- releasing process
	IF (@IsReleased = 1)
	BEGIN
		
		UPDATE	dbo.systemSettings WITH (ROWLOCK, UPDLOCK)  
		SET VValue 			= '0'  
		WHERE VName 		= 'isCalculatingParlay' 
		AND @isExistParlay 	= 1
		
		UPDATE	dbo.systemSettings WITH (ROWLOCK, UPDLOCK)  
		SET VValue 			= '0'  
		WHERE VName 		= 'isCalculatingParlayVSBetradar' 
		AND @IsExistParlayVSBetradar = 1
						
		UPDATE dbo.systemSettings WITH (ROWLOCK, UPDLOCK)
		SET VValue 			= '0'
		WHERE VName 		= 'isCalculatingNGManual'
		AND @isExistNG 		= 1
		
		IF (@checkKeyValue2 = 1)
		BEGIN
			DELETE ck
			FROM dbo.TempVariableNumber ck
				INNER JOIN #tblMatchProcessKeyValue2 tp
				ON ck.KeyValue = tp.matchid AND ck.KeyID = tp.KeyID
			WHERE ck.KeyValue2 = tp.KeyValue2
			
			RETURN
		END
		
		IF (@isExistTempVariable = 1)
		BEGIN
			DELETE ck
			FROM dbo.TempVariableNumber ck
				INNER JOIN #tblMatchProcess tp
				ON ck.KeyValue = tp.matchid AND ck.KeyID = tp.KeyID
					
		END
	END
	
	RETURN
	
END
GO
