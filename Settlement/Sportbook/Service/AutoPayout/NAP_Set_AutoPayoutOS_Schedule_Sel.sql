/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Set_AutoPayoutOS_Schedule_Sel
	@Sporttype SMALLINT = 0
	,@AutoSetting TINYINT  = 1
	,@MatchType	  TINYINT  = 1
AS
/*
	Creator: 20210729@Louisa
	Task: Auto Settle Cricket [Redmine:#154586]
	DB: DBPRO/bodb02
	Revisions:
		- 20210729@Louisa: Auto Settle Cricket [Redmine:#154586]
		- 20210915@Louisa: Checking invalid result of Virtual Cricket [Redmine:#161640]
		- 20211006@Louisa: Get results after 90 seconds - [Redmine:#162808]
		- 20211206@Louisa: Enhancemant [Redmine:#165659]
		- 20220309@Louisa: Auto settle Volleyball [Redmine:#168346]
		- 20220512@Kathy: Improve performance [Redmine:#172386]
		- 20220512@Louisa: Auto settle for Badminton [Redmine:#171676]
		- 20220929@Louisa: check deployment flag [Redmine:#178765]
		- 20221205@Louisa: Auto Payout Real Cricket [Redmine:#181137]
		- 20221213@Kathy: Upgrade Auto Payout for Badminton & Volleyball [Redmine:#181458]
		- 20221223@Kathy: Support Direct Payout for Early Results. [Redmine:#181718]
		- 20230315@Aries: Support Direct Payout for Child Tennis Matches [Redmine:#182330]
		- 20230403@Louisa: Exclude some Cricket results from direct payout [Redmine:#186311]
		- 20230404@Louisa: Checking related resourceid for result early badminton,volleyball [Redmine:#185818]
		- 20230801@Aries: Support Instant Settlement for Basketball [Redmine:#189662]
		- 20230724@Louisa: Enhance for Tennis - exclude Auto for match has confirm score is 0-0 [Redmine:#189433]
		- 20240301@Aries: Direct payout run before waiting time [Redmine:#201698]
		- 20240308@Aries: Direct Ice Hockey [Redmine:#201836]
		- 20240412@Aries: Direct Payout for Virtual Kabaddi [Redmine:#203590]

	Param's Explanation:
		- @AutoSetting: 
			+ 1:  Auto Payout (Default)
			+ 16: Auto Payout Direct  
		- @MatchType:
			+ 1: Main Match
			+ 2: Child Match

*/
BEGIN
	
	SET NOCOUNT ON

	DECLARE @checkTime INT = 300
			,@n INT
			,@ExternalResultTable TINYINT = 0
			,@ResultTable TINYINT = 0
			,@procName		SYSNAME	= OBJECT_NAME(@@procid)
			,@WaitingTime	VARCHAR(10)
			,@IsWaiting		BIT = 0

	DECLARE @tmpLatestResult TABLE (matchid INT, leagueid INT, SettlementStatus INT, ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50) , Ranking INT , IsFinal BIT )
	SET @n = 2147483647


	SELECT @ExternalResultTable =	r.ExternalResultTable 
		  ,@ResultTable			=	r.ResultTable 
	FROM dbo.SettlementResultTableSetting r (NOLOCK)
	WHERE r.Sporttype = @Sporttype

	IF OBJECT_ID('tempdb..#MatchInfo') IS NOT NULL
		DROP TABLE #MatchInfo

	CREATE  TABLE #MatchInfo (
		 MatchId			INT
		,leagueid			INT
		,betstatus			NVARCHAR(100)
		,ChildMatchType		TINYINT
		,SubType			SMALLINT
		,SettlementStatus	TINYINT
		,ResourceId			VARCHAR(20)
		,RelateResources	VARCHAR(20)
		,HomeValue			VARCHAR(50)
		,AwayValue			VARCHAR(50)
		,StatusId			TINYINT
		,InitConfirmDate	BIT DEFAULT 0
		,Ranking			INT
	)

	EXEC dbo.NAP_Set_SPDeploymentInfo 
		 @SPName = @procName
		,@WaitingTime = @WaitingTime OUTPUT
		,@IsWaiting = @IsWaiting OUTPUT

	IF ISNULL(@IsWaiting,0) = 1
	BEGIN
		--not return data if in deployment progress
		SELECT matchid
			, @Sporttype AS sporttype
			, leagueid
			, SettlementStatus
			, ResourceId
			, HomeValue
			, AwayValue
		FROM #MatchInfo m

		RETURN
	END
	
	IF @Sporttype =  50
	BEGIN
		INSERT INTO #MatchInfo  ( MatchId, leagueid, SettlementStatus, ResourceId, HomeValue, AwayValue)
		SELECT m.matchid
				, m.leagueid
				, m.SettlementStatus
				, r.ResourceId
				, r.HomeValue
				, r.AwayValue
		FROM dbo.match m WITH(NOLOCK)
			INNER JOIN dbo.League l WITH(NOLOCK)
				ON m.leagueid = l.leagueid
			OUTER APPLY(
							SELECT TOP 1 ss.WaitingTime
							FROM	dbo.SettlementSetting ss WITH (NOLOCK)
							WHERE	ss.LeagueId = m.leagueid
									AND ss.AutoType = 5 -- direct Auto Payout
						) ss
			CROSS APPLY (
				SELECT TOP (@n) r.MatchID, r.ResourceID, r.HomeValue, r.AwayValue
				FROM	dbo.ResultDetailOS r WITH(NOLOCK)
				WHERE	r.MatchID = m.matchid
						AND r.ResultStatusID = 3
						AND ISNULL(r.ResultSetting,0) & 1  = 0
						AND 1 =  CASE WHEN ISNULL(r.HomeValue,'') = '' AND ISNULL(r.AwayValue,'') = '' THEN 0 ELSE 1 END
						AND r.LastModifyDate <= DATEADD(SECOND, - ISNULL(ss.WaitingTime,@checkTime), GETDATE() )
						AND 1 = CASE WHEN l.LeagueGroupID = 42 THEN 1 --Virtual Cricket
									 WHEN l.LeagueGroupID <> 42
											AND ( 	r.ResourceID LIKE '94901_____'
													OR r.ResourceID LIKE '94221_____'
													OR r.ResourceID LIKE '96161_____'
													OR r.ResourceID LIKE '94841___'
													OR r.ResourceID LIKE '94101___'
													OR r.ResourceID LIKE '94281___'
													OR r.ResourceID LIKE '96241___'
													OR r.ResourceID LIKE '96301___'
													OR r.ResourceID LIKE '94911_____'
													OR r.ResourceID LIKE '94231_____'
													OR r.ResourceID LIKE '96171_____'
													OR r.ResourceID LIKE '94851___'
													OR r.ResourceID LIKE '94111___'
													OR r.ResourceID LIKE '94291___'
													OR r.ResourceID LIKE '96251___'
													OR r.ResourceID LIKE '96311___'
													OR r.ResourceID LIKE '94902_____'
													OR r.ResourceID LIKE '94222_____'
													OR r.ResourceID LIKE '96162_____'
													OR r.ResourceID LIKE '94842___'
													OR r.ResourceID LIKE '94102___'
													OR r.ResourceID LIKE '94282___'
													OR r.ResourceID LIKE '96242___'
													OR r.ResourceID LIKE '96302___'
													OR r.ResourceID LIKE '94912_____'
													OR r.ResourceID LIKE '94232_____'
													OR r.ResourceID LIKE '96172_____'
													OR r.ResourceID LIKE '94852___'
													OR r.ResourceID LIKE '94112___'
													OR r.ResourceID LIKE '94292___'
													OR r.ResourceID LIKE '96252___'
													OR r.ResourceID LIKE '96312___'

												)
											THEN 1
									 ELSE 0
									 END	
						
			) r
			OUTER APPLY (	SELECT os.MatchId, os.ResourceId,  MIN(os.StatusId) AS MinStatusId
							FROM dbo.AutoPayoutResultOS os WITH(NOLOCK)
							WHERE os.MatchId = r.matchid
								AND os.ResourceId = r.ResourceID 
								AND ISNULL(os.SourceID,0) = 0
							GROUP BY os.MatchId, os.ResourceId
						) os
		WHERE m.sporttype = @Sporttype
			AND ISNULL(ISNULL(m.AutoSetting, l.AutoSetting),0) & 16 > 0
			AND ISNULL(m.SettlementStatus,0) & 87 = 0
			AND os.MinStatusId IS NULL -- ResourceId has never been run before
					
	END
	ELSE IF @AutoSetting = 1 
	BEGIN
		IF @ExternalResultTable = 1 
		BEGIN
			INSERT INTO @tmpLatestResult (  matchid, leagueid, SettlementStatus, ResourceId, HomeValue, AwayValue, Ranking, IsFinal )
			SELECT m.matchid, m.leagueid, m.SettlementStatus, r.ResourceId, r.HomeValue, r.AwayValue
					,ROW_NUMBER() OVER(PARTITION BY r.MatchId, r.ResourceId ORDER BY r.CreateDate DESC) AS Ranking
					,MAX(CASE WHEN r.ResourceId = '00' THEN 1 ELSE 0 END ) OVER(PARTITION BY r.MatchId ) AS IsFinal
			FROM dbo.match m WITH(NOLOCK)
				INNER JOIN dbo.League l WITH(NOLOCK)
					ON m.leagueid = l.leagueid
				INNER JOIN dbo.ProviderExternalResultDetail r WITH(NOLOCK)
					ON m.matchid = r.MatchId				
			WHERE m.sporttype = @Sporttype
			AND ISNULL(ISNULL(m.AutoSetting, l.AutoSetting),0) & 1 = 1
				AND ISNULL(m.SettlementStatus,0) & 87 = 0
				AND m.eventstatus = 'running'
				AND ISNULL(m.IsDeleted,0) = 0
				AND r.SourceId = 1 --SBO
		END 
		ELSE IF @ExternalResultTable = 2 
		BEGIN
			INSERT INTO @tmpLatestResult (  matchid, leagueid, SettlementStatus, ResourceId, HomeValue, AwayValue, Ranking, IsFinal )
			SELECT m.matchid, m.leagueid, m.SettlementStatus, ex.ResourceId, ex.HomeValue, ex.AwayValue
					,ROW_NUMBER() OVER(PARTITION BY ex.MatchId, ex.ResourceId ORDER BY ex.CreateDate DESC) AS Ranking
					,MAX(CASE WHEN ex.ResourceId = '00' THEN 1 ELSE 0 END ) OVER(PARTITION BY ex.MatchId ) AS IsFinal
			FROM dbo.match m WITH(NOLOCK)
				INNER JOIN dbo.League l WITH(NOLOCK)
					ON m.leagueid = l.leagueid
				INNER JOIN dbo.ProviderExternalResultDetailOS ex WITH(NOLOCK)
					ON m.matchid = ex.MatchId
				CROSS APPLY ( SELECT ResourceID FROM f_Set_MajorRound (@sporttype)  f WHERE ex.ResourceId = f.ResourceID) f
			WHERE m.sporttype = @Sporttype
			AND ISNULL(ISNULL(m.AutoSetting, l.AutoSetting),0) & 1 = 1	--Turn on bit[1] and turn off bit[5]
				AND ISNULL(m.SettlementStatus,0) & 87 = 0
				AND m.eventstatus = 'running'
				AND ISNULL(m.IsDeleted,0) = 0
				AND ex.SourceId = 1 --SBO
		END
	END
	ELSE IF @AutoSetting = 16 
	BEGIN
		IF @ResultTable = 1 AND @MatchType = 2
		BEGIN
			INSERT INTO #MatchInfo  ( MatchId, leagueid, SettlementStatus, ResourceId, HomeValue, AwayValue)
			SELECT m.matchid
					, m.leagueid
					, m.SettlementStatus
					, r.ResourceId
					, r.HomeValue
					, r.AwayValue
			FROM dbo.match m WITH(NOLOCK)
				INNER JOIN dbo.League l WITH(NOLOCK)
					ON m.leagueid = l.leagueid
				OUTER APPLY(
								SELECT TOP 1 ss.WaitingTime
								FROM	dbo.SettlementSetting ss WITH (NOLOCK)
								WHERE	ss.LeagueId = m.leagueid
										AND ss.AutoType = 5 -- direct Auto Payout
							) ss
				CROSS APPLY (
					SELECT TOP (@n) r.MatchID, r.ResourceID, r.HomeValue, r.AwayValue
					FROM	dbo.ResultDetail r WITH(NOLOCK)
					WHERE	r.MatchID = m.matchid
							AND r.ResultStatusID = 3
							AND ISNULL(r.ResultSetting,0) & 3  = 0
							AND 1 =  CASE WHEN ISNULL(r.HomeValue,'') = '' AND ISNULL(r.AwayValue,'') = '' THEN 0 ELSE 1 END
							AND 1 =  CASE WHEN @Sporttype = 5 AND r.HomeValue = '0' AND  r.AwayValue = '0' THEN 0 ELSE 1 END
							AND r.LastModifyDate <= DATEADD(SECOND, - ISNULL(ss.WaitingTime,@checkTime), GETDATE() )						
				) r
				OUTER APPLY (	SELECT os.MatchId, os.ResourceId,  MIN(os.StatusId) AS MinStatusId
								FROM dbo.AutoPayoutResultOS os WITH(NOLOCK)
								WHERE os.MatchId = r.matchid
									AND os.ResourceId = r.ResourceID
									AND ISNULL(os.SourceID,0) = 0
								GROUP BY os.MatchId, os.ResourceId
							) os
			WHERE m.sporttype = @Sporttype
                AND m.ChildMatchType IN (12, 14, 15, 16, 17)
				AND ISNULL(ISNULL(m.AutoSetting, l.AutoSetting),0) & 16 > 0
				AND ISNULL(m.SettlementStatus,0) & 87 = 0
				AND os.MinStatusId IS NULL

		END
		ELSE IF @ResultTable = 2
		BEGIN
			INSERT INTO #MatchInfo  ( MatchId, leagueid, SettlementStatus, ResourceId, HomeValue, AwayValue)
			SELECT m.matchid
					, m.leagueid
					, m.SettlementStatus
					, r.ResourceId
					, r.HomeValue
					, r.AwayValue
			FROM dbo.match m WITH(NOLOCK)
				INNER JOIN dbo.League l WITH(NOLOCK)
					ON m.leagueid = l.leagueid
				OUTER APPLY(
								SELECT TOP 1 ss.WaitingTime
								FROM	dbo.SettlementSetting ss WITH (NOLOCK)
								WHERE	ss.LeagueId = m.leagueid
										AND ss.AutoType = 5 -- direct Auto Payout
							) ss
				CROSS APPLY (
					SELECT TOP (@n) r.MatchID, r.ResourceID, r.HomeValue, r.AwayValue
					FROM	dbo.ResultDetailOS r WITH(NOLOCK)
					WHERE	r.MatchID = m.matchid
							AND r.ResultStatusID = 3
							AND ISNULL(r.ResultSetting,0) & 3  = 0
							AND 1 =  CASE WHEN ISNULL(r.HomeValue,'') = '' AND ISNULL(r.AwayValue,'') = '' THEN 0 ELSE 1 END
							AND r.LastModifyDate <= DATEADD(SECOND, - ISNULL(ss.WaitingTime,@checkTime), GETDATE() )						
				) r
				OUTER APPLY (	SELECT os.MatchId, os.ResourceId,  MIN(os.StatusId) AS MinStatusId
								FROM dbo.AutoPayoutResultOS os WITH(NOLOCK)
								WHERE os.MatchId = r.matchid
									AND os.ResourceId = r.ResourceID 
									AND ISNULL(os.SourceID,0) = 0
								GROUP BY os.MatchId, os.ResourceId
							) os
				OUTER APPLY ( SELECT ResourceID FROM f_Set_MajorRound (@sporttype)  f WHERE r.ResourceId = f.ResourceID) f
			WHERE m.sporttype = @Sporttype
				AND ISNULL(ISNULL(m.AutoSetting, l.AutoSetting),0) & @AutoSetting > 0
				AND ISNULL(m.SettlementStatus,0) & 87 = 0
				AND os.MinStatusId IS NULL -- ResourceId has never been run before
				AND f.ResourceID IS NULL -- EARLY result

			IF @Sporttype IN (6,9)
			BEGIN
				UPDATE m SET RelateResources = '01' + SUBSTRING(  CAST(BetID AS VARCHAR(10)), 2, 2)
				FROM #MatchInfo m
				CROSS APPLY (	SELECT TOP 1 sp.BetID
								FROM dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK)
								WHERE sp.SportType = @Sporttype 
									AND sp.ResourceID = m.ResourceId
									AND sp.SettleType = 'EAR'
									AND sp.BetID > 0
							)sp

				;WITH cte_RelateResources ( MatchId, ResourceId) AS
				(	SELECT  r.MatchId, cte.ResourceId
					FROM #MatchInfo cte
						INNER JOIN  dbo.ResultDetailOS r WITH(NOLOCK) 
							ON cte.MatchId = r.MatchID
								AND cte.RelateResources = r.ResourceID
					WHERE r.ResultStatusID IN (2,5) AND r.SettlementStatusID <> 1
				)
				DELETE m 
				FROM #MatchInfo m
					LEFT JOIN cte_RelateResources cte
						ON cte.MatchId = m.MatchId
							AND cte.ResourceId = m.ResourceId
				WHERE cte.ResourceID IS NULL
					AND m.RelateResources IS NOT NULL

			END

		END
		ELSE IF @ResultTable = 0  
		BEGIN
			DECLARE	  @currentdate		DATETIME
					 ,@fromdate			DATETIME
					 ,@todate			DATETIME
					 ,@checktimeGST		DATETIME
			
			SET @currentdate = CAST(GETDATE() AS DATE)
			SELECT	@fromdate = DATEADD(DAY,-1,@currentdate)
				   ,@todate = DATEADD(DAY,1,@currentdate)
				   ,@checktimeGST = DATEADD(HOUR, 3, GETDATE())

			INSERT INTO #MatchInfo  ( MatchId, leagueid,ChildMatchType,SubType, SettlementStatus, ResourceId,HomeValue, AwayValue,betstatus,InitConfirmDate)
			SELECT m.matchid AS MatchId
				, l.leagueid
				, m.ChildMatchType
				, mr.SubType
				, m.SettlementStatus
				, '00' AS ResourceId
				, CAST(m.finalhomescore AS VARCHAR(50))
				, CAST(m.finalawayscore  AS VARCHAR(50))
				, m.betstatus
				, IIF(pe.ConfirmDate IS NULL, 1,0)
			FROM dbo.match AS m WITH(NOLOCK)
				INNER JOIN dbo.match_remark AS mr WITH(NOLOCK) ON	m.matchid = mr.matchid
				INNER JOIN dbo.League AS l WITH(NOLOCK) ON	m.leagueid = l.leagueid
				OUTER APPLY (
					SELECT TOP 1 1 AS IsExistAP 
					FROM dbo.AutoPayoutResultOS AS os WITH(NOLOCK)
					WHERE os.MatchId = m.matchid 
						AND os.ResourceId = '00'
						AND ISNULL(os.SourceID,0) = 0
				) AS rs
				OUTER APPLY (
					SELECT TOP 1 pr.ProviderExternalId AS LastProviderExternalId
					FROM dbo.ProviderExternalResultDetailOS AS pr WITH(NOLOCK)
					WHERE pr.MatchId = m.matchid 
						AND pr.ResourceId = '00'
						AND pr.SourceId = 97
					ORDER BY pr.ProviderExternalId DESC
				) AS pid
				OUTER APPLY (
					SELECT TOP 1 p.CreateDate  AS ConfirmDate
					FROM dbo.ProviderExternalResultDetailOS AS p WITH(NOLOCK)
					WHERE p.ProviderExternalId = pid.LastProviderExternalId
						AND p.HomeValue = CAST(m.finalhomescore AS VARCHAR(50))
						AND p.AwayValue = CAST(m.finalawayscore  AS VARCHAR(50))
				) AS pe
				OUTER APPLY(
					SELECT TOP 1 ss.WaitingTime
					FROM	dbo.SettlementSetting ss WITH (NOLOCK)
					WHERE	ss.LeagueId = l.leagueid
							AND ss.AutoType = 5 -- Direct Auto Payout
				) AS ss
			WHERE	m.eventstatus = 'running' 
					AND m.sporttype = @Sporttype
					AND m.eventdate BETWEEN @fromdate AND @todate 
					AND GlobalShowTime <= @checktimeGST
					AND l.LeagueGroupID = 42
					AND 1 = CASE WHEN @Sporttype = 4 AND m.ChildMatchType IN (18,19,20,23,24) THEN 1 -- Child match Ice Hockey
								 WHEN @Sporttype = 47 AND m.ChildMatchType IN (1,2,3,4) THEN 1 -- Child match Kabaddi
								 WHEN ISNULL(m.ParentID,0) = 0 THEN 1 -- main match
								 ELSE 0
							 END

					AND mr.ConfirmFT > 0
					AND m.finalhomescore IS NOT NULL 
					AND m.finalawayscore IS NOT NULL
					AND ISNULL(m.AutoSetting, ISNULL(l.AutoSetting, 0)) & 16 = 16
					AND rs.IsExistAP IS NULL
					AND 1 = CASE WHEN pe.ConfirmDate IS NULL THEN 1
					             WHEN pe.ConfirmDate IS NOT NULL AND pe.ConfirmDate <= DATEADD(SECOND, - ISNULL(ss.WaitingTime,@checkTime), GETDATE() )	 THEN 1
								 ELSE 0
							END
				
		END
	END 

	IF EXISTS (SELECT 1 FROM @tmpLatestResult)
	BEGIN
		INSERT INTO #MatchInfo ( matchid, leagueid, SettlementStatus, ResourceId, HomeValue, AwayValue)
		SELECT r.matchid, r.leagueid, r.SettlementStatus, r.ResourceId, r.HomeValue, r.AwayValue				
		FROM @tmpLatestResult r
			OUTER APPLY (	SELECT	TOP 1 os.MatchId
							FROM	dbo.AutoPayoutResultOS os WITH(NOLOCK)
							WHERE	os.MatchId = r.matchid		
									AND ISNULL(os.SourceID,0) = 0
									AND os.ResourceId IN (SELECT f.ResourceID FROM dbo.f_Set_MajorRound(@Sporttype) f)
						) os				
		WHERE Ranking = 1 --Latest
			AND r.IsFinal = 1 --exist FT
			AND os.MatchId IS NULL --not yet run Auto
	END

	SELECT MatchId
		, @Sporttype AS SportType
		, LeagueId
		, ChildMatchType
		, SubType
		, SettlementStatus
		, betstatus
		, ResourceId
		, HomeValue
		, AwayValue
		, InitConfirmDate
	FROM #MatchInfo m

END
GO


 