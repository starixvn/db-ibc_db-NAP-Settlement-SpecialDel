/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE  NAP_Admin_Settlement_s178
	@AdminId			INT		
	,@MatchId			INT
	,@Action			VARCHAR(10)		
	,@SelectedResources	VARCHAR(MAX)
	,@IsReSettledTickets BIT			= 1
	,@IP				VARCHAR(50)		= ''
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			NVARCHAR(200)	= ''	OUTPUT
AS
/*	
	Creator: 20230704@Louisa 
	Task: Virtual Leap Gaming - VS3
	DB: DBTXN/bodb02 
	
	Revisions:
		- 20230704@Louisa:  Virtual Leap Gaming - VS3 [Redmine:#189854]
	
	Param's Explanation:
		@Action - CAL
				- REFUND

		 <Resources>
                <Resource Id="00" Home="1" Away="3" /> 
                <Resource Id="01" Home="1" Away="2" />
        </Resources>
 
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @StartTime				DATETIME
			,@EndTime				DATETIME
			,@avaiableProcess		BIT
			,@ActionId				INT
			,@batchCount			INT = 2000
			,@strTransIds			VARCHAR(MAX)  
			,@procName				SYSNAME
			,@remark				VARCHAR(200)
			,@IsCentral				BIT
			,@handle				INT		

	DECLARE @tmpTransIDBatch TABLE (TransID BIGINT, modds SMALLMONEY)	 
	DECLARE @tmpSelectedResources TABLE (ResourceID VARCHAR(20), HomeValue VARCHAR(2000), AwayValue VARCHAR(2000),
								  BetType SMALLINT, BetID BIGINT, pfID SMALLINT ,PRIMARY KEY (BetType,BetID))

	CREATE TABLE #tmpTransID (TransID BIGINT, modds SMALLMONEY, isFinish BIT)
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT) 
	
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	SELECT @ActionID  = CASE @Action
							WHEN 'CAL'      THEN 81043
							WHEN 'REFUND'   THEN 81044
						END
			,@StartTime	= CURRENT_TIMESTAMP

	INSERT INTO #tblMatchProcess (matchid, KeyID)
	SELECT	@matchid AS matchid, 1 AS KeyID
	----------------------------------------------------------------------------------------------	
	
	--check settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		  @isExistMatch			= 1
		  , @SPName				= @procName
		  , @avaiableProcess 	= @avaiableProcess OUTPUT
		  , @ErrCode			= @ErrCode OUTPUT
		  , @ErrMsg				= @ErrMsg OUTPUT
			
	IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
	BEGIN
		SELECT	@ErrCode 
				,@ErrMsg	
		RETURN
	END	

	EXEC sp_xml_preparedocument @handle OUTPUT, @SelectedResources

	INSERT INTO @tmpSelectedResources(ResourceID, HomeValue, AwayValue, BetType, BetID, pfID )  
	SELECT Id, ISNULL(Home,''), ISNULL(Away,''), sp.BetType, sp.BetID, sp.pfID 
	FROM OPENXML(@handle,'Resources/Resource',1) WITH( Id	VARCHAR(20)
														,Home VARCHAR(50)
														,Away VARCHAR(50)
										) AS tbl
		INNER LOOP JOIN dbo.SettlementSpecialBettypeProfile sp WITH (NOLOCK) 
		ON	sp.ResourceID = tbl.Id
	WHERE sp.SportType = 178 

	EXEC sp_xml_removedocument @handle
    
	BEGIN TRY
		IF @Action = 'CAL'
		BEGIN
			INSERT INTO #tmpTransID (TransID, modds)
				SELECT	transid, m.modds
				FROM	dbo.bettrans b WITH (NOLOCK)
				CROSS APPLY(
								SELECT TOP 1 pfID, HomeValue, AwayValue
								FROM @tmpSelectedResources t
								WHERE b.BetType = t.BetType AND (t.BetID = 0 OR b.BetID = t.BetID) 
							) sr
						CROSS APPLY dbo.f_Set_Calculate_modds(sr.pfID, b.betteam, b.hdp1, b.hdp2, sr.HomeValue, sr.AwayValue, b.livehomescore, b.liveawayscore, b.transdesc, NULL) m
				WHERE	b.matchid = @MatchId
						AND b.statusID <> 101
						AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
						AND 1 = CASE WHEN @IsReSettledTickets = 0 AND statusID IN (0,102) THEN 1
									 WHEN @IsReSettledTickets = 1 THEN 1
									 ELSE 0
								END
		END

		IF @action = 'REFUND'  
		BEGIN
			INSERT INTO #tmpTransID(TransID)
	  		SELECT	transid
	  		FROM	dbo.bettrans b WITH (NOLOCK)
	  			INNER JOIN @tmpSelectedResources t 
					ON	b.BetType = t.BetType 
						AND (t.BetID = 0 OR b.BetID = t.BetID) 
	  		WHERE	b.matchid = @MatchId
					AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
	  				AND	b.statusID NOT IN (103, 101)
		END
	
		WHILE 1=1
		BEGIN
			DELETE @tmpTransIDBatch
			
			UPDATE TOP(@batchCount) t
			SET isFinish = 1
			OUTPUT deleted.transid, deleted.modds
			INTO @tmpTransIDBatch(transid, modds)
			FROM #tmpTransID t 
			WHERE isFinish IS NULL

			SELECT @batchCount 	= @@ROWCOUNT
			
			IF @batchCount = 0 BREAK

			--filter selectedRID by current Profile and BetType
			SET @strTransIds = (SELECT transid		AS '@t'
										,modds		AS '@m'
										,0			AS '@ot'
								FROM @tmpTransIDBatch
								FOR XML PATH('r'), ROOT( 'root' ))

			EXEC dbo.NAP_Admin_Calculate_OtherSports
				@matchid			 = @MatchID 
			   ,@action				 = @Action  
			   ,@strTransIds		 = @strTransIds
			   ,@EventTable			 = 1
			   ,@Is3rd				 = 1 
			   ,@IsCalculateBalance  = 1
			   ,@CWLBettype			 = 1210
			   ,@BalanceType		 = 4

		END	
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = ERROR_NUMBER()
				,@ErrMsg = ERROR_MESSAGE()	
				
		EXEC dbo.NAP_Admin_CheckingProcess
				@isExistMatch 	= 1
				,@IsReleased	= 1

		RETURN

	END CATCH

	
	-- Releasing settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch 	= 1
		,@IsReleased	= 1

END
GO