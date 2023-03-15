/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
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
		- 202212-5@Louisa: Auto Payout Real Cricket [Redmine:#181137]
		- 20221213@Kathy: Upgrade Auto Payout for Badminton & Volleyball [Redmine:#181458]
		- 20221223@Kathy: Support Direct Payout for Early Results. [Redmine:#181718]
		- 20230315@Aries: Support Direct Payout for Child Tennis Matches [Redmine:#182330]

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

	DECLARE @checkTime TINYINT = 30
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

	CREATE TABLE #MatchInfo (
		MatchId			INT
		,leagueid		INT
		,SettlementStatus TINYINT
		,ResourceId		VARCHAR(20)
		,HomeValue		VARCHAR(50)
		,AwayValue		VARCHAR(50)
		,StatusId		TINYINT
		,Ranking		INT
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
									AND ss.AutoType = 1 -- Auto Payout
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
													OR r.ResourceID LIKE '94341___'
													OR r.ResourceID LIKE '96361___'
													OR r.ResourceID LIKE '96241___'
													OR r.ResourceID LIKE '96301___'
													OR r.ResourceID LIKE '94911_____'
													OR r.ResourceID LIKE '94231_____'
													OR r.ResourceID LIKE '96171_____'
													OR r.ResourceID LIKE '94851___'
													OR r.ResourceID LIKE '94111___'
													OR r.ResourceID LIKE '94291___'
													OR r.ResourceID LIKE '94351___'
													OR r.ResourceID LIKE '96371___'
													OR r.ResourceID LIKE '96251___'
													OR r.ResourceID LIKE '96311___'
													OR r.ResourceID LIKE '94902_____'
													OR r.ResourceID LIKE '94222_____'
													OR r.ResourceID LIKE '96162_____'
													OR r.ResourceID LIKE '94842___'
													OR r.ResourceID LIKE '94102___'
													OR r.ResourceID LIKE '94282___'
													OR r.ResourceID LIKE '94342___'
													OR r.ResourceID LIKE '96362___'
													OR r.ResourceID LIKE '96242___'
													OR r.ResourceID LIKE '96302___'
													OR r.ResourceID LIKE '94912_____'
													OR r.ResourceID LIKE '94232_____'
													OR r.ResourceID LIKE '96172_____'
													OR r.ResourceID LIKE '94852___'
													OR r.ResourceID LIKE '94112___'
													OR r.ResourceID LIKE '94292___'
													OR r.ResourceID LIKE '94352___'
													OR r.ResourceID LIKE '96372___'
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
							AND r.LastModifyDate <= DATEADD(SECOND, - ISNULL(ss.WaitingTime,@checkTime), GETDATE() )						
				) r
				OUTER APPLY (	SELECT os.MatchId, os.ResourceId,  MIN(os.StatusId) AS MinStatusId
								FROM dbo.AutoPayoutResultOS os WITH(NOLOCK)
								WHERE os.MatchId = r.matchid
									AND os.ResourceId = r.ResourceID 
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
								GROUP BY os.MatchId, os.ResourceId
							) os
				OUTER APPLY ( SELECT ResourceID FROM f_Set_MajorRound (@sporttype)  f WHERE r.ResourceId = f.ResourceID) f
			WHERE m.sporttype = @Sporttype
				AND ISNULL(ISNULL(m.AutoSetting, l.AutoSetting),0) & @AutoSetting > 0
				AND ISNULL(m.SettlementStatus,0) & 87 = 0
				AND os.MinStatusId IS NULL -- ResourceId has never been run before
				AND f.ResourceID IS NULL -- EARLY result
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
									AND os.ResourceId IN (SELECT f.ResourceID FROM dbo.f_Set_MajorRound(@Sporttype) f)
						) os				
		WHERE Ranking = 1 --Latest
			AND r.IsFinal = 1 --exist FT
			AND os.MatchId IS NULL --not yet run Auto
	END

	SELECT MatchId
		, @Sporttype AS SportType
		, LeagueId
		, SettlementStatus
		, ResourceId
		, HomeValue
		, AwayValue
	FROM #MatchInfo m

END
GO


 