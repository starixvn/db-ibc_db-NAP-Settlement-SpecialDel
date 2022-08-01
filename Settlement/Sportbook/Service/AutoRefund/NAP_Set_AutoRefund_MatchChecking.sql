/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Set_AutoRefund_MatchChecking
	@MatchId	INT
	,@ResourceIds	 VARCHAR(500) = ''
	,@TypeId	TINYINT
	,@ErrCode 	INT = 0 OUTPUT
	,@ErrMsg 	NVARCHAR(200) = '' OUTPUT
AS
/*
	Creator: 20201216@Louisa
	Task: Checking child match [Redmine:#145597]
	DB: DBTXN/bodb02
	Revisions:
		- 20201216@Louisa: Checking ET & PEN matches [Redmine:#145597]
		- 20211129@Kathy: New Cashout model [Redmine:#164838]
		- 20220512@Louisa: Auto refund Badminton [Redmine:#171676]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]

	Param's explaination: 
		- @TypeId:  1 - Auto refund single
				   10 - Auto refund parlay

*/
BEGIN
	
	SET NOCOUNT ON

	DECLARE   @ParentId INT
			, @ParentSettlementStatusID TINYINT
			, @ParentHomeValue		VARCHAR(50)
			, @ParentAwayValue		VARCHAR(50)
			, @IsExistSettledTicket	BIT
			, @queryInfo			NVARCHAR(MAX) = ''
			, @execSql				NVARCHAR(MAX) =''
			, @sporttype			SMALLINT
			, @IsCentral			BIT = 0

		IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NULL
			SET @IsCentral = 1
		
		SELECT  @ParentId = m.ParentId
				,@sporttype = m.sporttype
		FROM dbo.match m  WITH(NOLOCK) 
		WHERE m.MatchId = @MatchId

		CREATE TABLE #tmpResultDetail (ResourceId VARCHAR(20), SettlementStatusId TINYINT, HomeValue VARCHAR(50), AwayValue VARCHAR(50), ResultSetting	TINYINT,  MatchType VARCHAR(1), bettype SMALLINT, betid BIGINT  )			
		
		IF @sporttype = 1
		BEGIN
			SELECT @queryInfo = 'SELECT  r.ResourceId
										,r.SettlementStatusId
										, r.HomeValue
										, r.AwayValue 
										, r.ResultSetting
										, CASE r.matchid WHEN @MatchId THEN ''c'' ELSE ''p'' END as MatchType
									FROM  dbo.ResultDetail r WITH(NOLOCK)
									WHERE ( r.matchid = @ParentId AND r.ResourceId = ''00'' AND r.SettlementStatusId = 4 )
										OR ( r.MatchId = @MatchId)
									'

			SET @execSql = 'DBPRO.bodb02.dbo.sp_executesql @queryInfo, N''@MatchId INT, @ParentId INT'', @MatchId,  @ParentId'
			INSERT INTO #tmpResultDetail (ResourceId, SettlementStatusId, HomeValue, AwayValue, ResultSetting, MatchType)
			EXECUTE	sys.sp_executesql @execSql, N'@queryInfo NVARCHAR(MAX), @MatchId INT,  @ParentId INT', @queryInfo, @MatchId,  @ParentId

			SELECT	@ParentSettlementStatusId  = r.SettlementStatusId
					, @ParentHomeValue = r.HomeValue
					, @ParentAwayValue = r.AwayValue
			FROM #tmpResultDetail r
			WHERE r.MatchType = 'p' 

			IF @TypeId = 1
			BEGIN
			
				IF EXISTS ( SELECT TOP 1 1 FROM #tmpResultDetail  r  WHERE r.MatchType = 'c' AND r.ResourceId = '00' AND r.SettlementStatusId <> 0)
				BEGIN
					SELECT @ErrCode = 	1001040   ,@ErrMsg  = 	'Auto refund child match failed: match settled.'
					RETURN
				END

				IF ISNULL(@ParentSettlementStatusId ,0) = 0
				BEGIN
					SELECT @ErrCode = 	1001041   ,@ErrMsg  = 	'Auto refund child match failed: main match not calculated FT.'
					RETURN
				END

				IF ISNULL(@ParentHomeValue , 0) = ISNULL( @ParentAwayValue ,0)
				BEGIN
					SELECT @ErrCode = 	1001042   ,@ErrMsg  = 	'Auto refund child match failed: main match FT score is DRAW.'
					RETURN
				END

				IF EXISTS ( SELECT TOP 1 1 FROM #tmpResultDetail  r  WHERE r.MatchType = 'c' AND ISNULL(r.ResultSetting,0) = 1 )
				BEGIN
					SELECT @ErrCode = 	1001039	   ,@ErrMsg  = 	'Auto refund child match failed: result is in on hold.'
					RETURN
				END

				IF EXISTS (SELECT TOP 1 1  FROM  dbo.bettrans bt WITH(NOLOCK) 
							WHERE bt.matchid = @MatchId 
								AND bt.statusID IN (111,112,113,103) 
								AND ISNULL(bt.betdaqid,0) <> -2
								AND bt.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bt.SiteDBGroupID END
							)
				BEGIN
					SELECT @ErrCode = 	1001070   ,@ErrMsg  = 	'Auto refund child match failed: settled tickets exist.'
					RETURN
				END

			END


			ELSE IF @TypeId = 10 AND NOT EXISTS (SELECT TOP 1 1 FROM #tmpResultDetail r WHERE r.MatchType ='c' AND r.ResourceId = '00' AND r.SettlementStatusId = 1)
			BEGIN
				SELECT @ErrCode = 	1001046	   ,@ErrMsg  = 	'Auto refund parlay failed: match is not settled.'
				RETURN
			END

		END

		ELSE IF @sporttype = 9
		BEGIN
			INSERT INTO #tmpResultDetail ( bettype, betid ) 
			SELECT DISTINCT sp.Bettype, sp.betid
			FROM dbo.SettlementSpecialBettypeProfile sp (NOLOCK)
				INNER JOIN  STRING_SPLIT(@ResourceIds, ',') f  ON sp.ResourceID = f.value
			WHERE sp.SportType = @sportType
				AND sp.SettleType ='MNL'


			SELECT @ErrCode = 	1001070   
				  ,@ErrMsg  = 	'Auto Refund failed: settled tickets exist.' 				  
			FROM ( 
					SELECT TOP 1 b.transid
					FROM dbo.bettrans  b (nolock)
						INNER JOIN #tmpResultDetail tmp ON b.Bettype = tmp.bettype AND (b.Betid = 0 OR b.betid = tmp.betid)
					WHERE b.matchid = @matchid
						AND statusid  IN ( 111, 112, 113, 103 )
				) b

			IF ISNULL(@ErrCode, 0) = 0
			BEGIN
				SELECT @ErrCode = 	1001070   
					  ,@ErrMsg  = 	'Auto Refund failed: settled tickets exist.'		  
				FROM (  
						SELECT TOP 1 b.transid
						FROM dbo.bettransm  b (nolock)
							INNER JOIN #tmpResultDetail tmp ON b.Bettype = tmp.bettype AND (b.betcheck = 0 OR b.betcheck = tmp.betid)
						WHERE b.matchid = @matchid
							AND statusid  IN ( 111, 112, 113, 103 )
							AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
						) b
			END

		END
END
GO
