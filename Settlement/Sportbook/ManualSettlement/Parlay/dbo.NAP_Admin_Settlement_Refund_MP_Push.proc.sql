/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Refund_MP_Push] (
	@AdminId 						INT
	,@MatchId 						INT
	,@Action 						VARCHAR(20) = 'REFUND'
	,@SettleAbandonedMatchIBCParlay TINYINT	= 0
	,@IP 							VARCHAR(15) = ''
	,@BroadcastSessionId	VARCHAR(50)		= NULL
	,@ErrCode 						INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) 			= '' OUTPUT
)
AS
/*	Creator: 20161205@Bobby
	Task: #61352 - Implement SDT for parlay tickets
	DB: DBTXN/BODB02
	ORIGINAL:

	Revisions:		
		- 20170215@Kathy: Basketball All-in-One [Redmine:#71372]
		- 20170609@Kathy: Early settlement for BAIO [Redmine:#77835]
		- 20170815@Kathy: Using table ResultDetail to store FGLG result instead of betstatus [Redmine:#81308]
		- 20171204@Kathy: Allow to settle parlay in case Early Settled bettypes have only Single tickets [Redmine:#87544]
		- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]	
		- 20180801@Vicky: Incorporate eSports 2.0 [Redmine #95874]
		- 20190124@Sol: Second Accept Process of Parlay Tickets [Redmine #107296]
		- 20190218@Kathy: Do not allow to settle match which has eventdate = movebet day [Redmine:#108768]
		- 20190620@Kathy: Remove auto betradar bettypes [Redmine:#109584]
		- 20190725@Sol: Incorporate PHAIO 4b - Implement [ResourceID] = '09' to Settle PH4B Bet Types [Redmine:#115232]
		- 20190924@Sol: Incorporate BMAIO - modified sp to support ResultDetailOS [Redmine:#120324]
		- 20200410@Sol: HotFix - Tennis - Refund parlay [Redmine:#132208]
		- 20200703@Kathy: Incorporate New Bet Types of Basketball - Phase 2 [Redmine:#135846]
		- 20201111@Louisa: Prevent process if SettlementStatus turn on bit 1,2,3,5,7 [Redmine:#143441]
		- 20210203@Louisa: Cricket AIO [Redmine:#148870]
		- 20210524@Louisa: SOP for Badminton, Basketball [Redmine:#155361,#155360]
		- 20210729@Louisa: Auto Settle Cricket [Redmine:#154586]
		- 20210514@Kathy: settle parlay ticket [Redmine:#154737]
		- 20220315@Kathy: Change to use STRING_SPLIT [Redmine:#166454]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
	
	Param's Explanation:		
		- @Action: [Refund, Refund-HT, Refund-FT]
		- @SettleAbandonedMatchIBCParlay: TINYINT
			+ 1: Single - Abandoned 1H
			+ 2: Single - Abandoned 2H
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @currentdate DATETIME
	DECLARE  @NotKeyScoreList	VARCHAR(130) = ''
		,@NotAllowCalculating	VARCHAR(200)
		,@HaveWaitingTicket		VARCHAR(200)
		,@NotExecutedFGLG		VARCHAR(200)
		,@MovingMatchIds		VARCHAR(200)
		,@InvalidMatchIds		VARCHAR(MAX) = ''

    DECLARE @matchcode			NVARCHAR(50)
		,@sporttype     		INT
		,@leagueid      		INT		
		,@IsNested      		BIT
		,@ActionId        		INT
		,@procName      		NVARCHAR(128)
		,@sqlCommand			NVARCHAR(1000)
		,@IsExistNetPosition	BIT = 0
		,@Mode					VARCHAR(20)
		,@IsExistsResourceEarlyRunning	BIT = 0
	
	SET @currentdate = CURRENT_TIMESTAMP
    
	DECLARE @tmpBettypes TABLE (bettype SMALLINT, groupId INT, groupname VARCHAR(50), isEarly BIT)
	DECLARE @tmpFGLGBettypes TABLE (bettype SMALLINT PRIMARY KEY, GroupID INT, IsFGLG BIT)
	
	DECLARE @tmpRunningEarlySettle TABLE (matchid INT)
	DECLARE @tmpFGLGMatch TABLE (matchid INT)
	DECLARE @tmpRunningBAIO TABLE (matchid INT, QuarterX NVARCHAR(50), OrdNo SMALLINT)
	
	DECLARE @match TABLE ( 
		matchid		INT
		,ParentId	INT
		,matchcode	NVARCHAR(50)
		,fth		SMALLINT
		,fta		SMALLINT
		,hth		SMALLINT
		,hta		SMALLINT
		,sporttype	SMALLINT
		,leagueid	INT
		,betstatus	VARCHAR(50)
	)
	SELECT	@ActionId = CASE 
							WHEN @Action = 'REFUND' THEN 107 
							WHEN @Action = 'REFUND-HT' THEN 120 
							WHEN @Action = 'REFUND-FT' THEN 106 
							ELSE 0 
						END
			,@Mode = CASE 
						WHEN @Action = 'REFUND' AND @SettleAbandonedMatchIBCParlay =  1 THEN 'ABANDONED-1H'
						WHEN @Action = 'REFUND-FT' AND @SettleAbandonedMatchIBCParlay =  2 THEN 'ABANDONED-2H'
						ELSE @Action
					END
							
	INSERT INTO @tmpBettypes(bettype, groupId, groupname, isEarly)
	SELECT	f.BetType, f.GroupId, f.GroupName, (SELECT 1 FROM dbo.f_Set_GetEarlyBettypes() WHERE bettype = f.BetType) AS isEarly
	FROM	dbo.f_Set_GetGroupBettypes() f
	
	INSERT INTO @tmpFGLGBettypes(bettype,GroupID,IsFGLG)
	SELECT	f.BetType,f.GroupId,f.IsFGLG
	FROM	dbo.f_Set_GetGroupBettypes() f
	WHERE	f.IsUsedGoalRecordValue = 1
	
	INSERT INTO @match ( matchid, ParentId, matchcode, fth, fta, hth, hta, sporttype, leagueid, betstatus)
	SELECT matchid
		,CASE WHEN ISNULL(ChildMatchType,0) = 200 AND ParentId IS NOT NULL AND sporttype = 50 THEN ParentId ELSE MatchId END ParentId
		,matchcode
		,finalhomescore
		,finalawayscore
		,hthomescore
		,htawayscore
		,sporttype
		,leagueid
		,betstatus
	FROM dbo.Match WITH (NOLOCK)
	WHERE matchid = @MatchId

    SELECT	@matchcode    	= m.matchcode
			,@sporttype   	= m.sporttype
			,@leagueid    	= m.leagueid
    FROM @match m
    
     -- CHECK supported actions & sport type
	IF(@Mode NOT IN ('REFUND', 'REFUND-HT','REFUND-FT','ABANDONED-1H','ABANDONED-2H') OR @sporttype IS NULL)
    BEGIN
        SELECT	@ErrCode = 1001001
				,@ErrMsg    = 'The match or action is invalid!'

        RETURN
    END
	
	-- checking validation	
	IF @sporttype = 1
	BEGIN
		;WITH cteBetStatusM
		AS (
			SELECT DISTINCT matchid
					,s.ResourceID
			FROM	dbo.bettransm bm WITH(NOLOCK)
				INNER JOIN dbo.SettlementSpecialBettypeProfile s WITH(NOLOCK)
					ON	bm.bettype = s.BetType
						AND (s.BetID = 0 OR s.BetID = bm.betcheck)
			WHERE	matchid = @MatchId
					AND s.SportType = @sporttype
					AND s.SettleType = 'EAR'
					AND statusID = 0
				
		)
		INSERT INTO @tmpRunningEarlySettle(matchid)
		SELECT	@matchid
		WHERE EXISTS (
			SELECT TOP 1 1
			FROM cteBetStatusM c
			LEFT JOIN DBPRO.BODB02.dbo.ResultDetail r WITH(NOLOCK)
				ON	c.matchid = r.matchid
					AND r.ResourceId = c.ResourceId
			WHERE	ISNULL(r.ResultStatusId,0) NOT IN (2,5)
		)
		
		IF @@ROWCOUNT > 0
			SET @IsExistsResourceEarlyRunning = 1
					
		
		;WITH cteBetStatusM
		AS(
			SELECT	bm.matchid
					,CASE 
						WHEN bm.bettype = 448 THEN '14L'
						WHEN bm.bettype IN (415,454,172) THEN '14F'
						WHEN bm.bettype IN (14, 127) 
							THEN CAST(bm.bettype AS VARCHAR) 
									+ CASE 
										WHEN RIGHT(bm.betteam,1) IN ('0', '1') THEN 'F'
										WHEN RIGHT(bm.betteam,1) = '2' THEN 'L'
										ELSE ''
									END 
						WHEN bt.GroupID = 1 THEN '09'
						ELSE '08'
					END AS ResourceId
			FROM	dbo.bettransm bm WITH(NOLOCK)
				INNER JOIN @tmpFGLGBettypes bt
					ON bm.bettype = bt.bettype
			WHERE	bm.matchid = @MatchId
					AND bm.statusID NOT BETWEEN 101 AND 102
			GROUP BY bm.matchid
					,CASE 
						WHEN bm.bettype = 448 THEN '14L'
						WHEN bm.bettype IN (415,454,172) THEN '14F'
						WHEN bm.bettype IN (14, 127) 
							THEN CAST(bm.bettype AS VARCHAR) 
									+ CASE 
										WHEN RIGHT(bm.betteam,1) IN ('0', '1') THEN 'F'
										WHEN RIGHT(bm.betteam,1) = '2' THEN 'L'
										ELSE ''
									END 
						WHEN bt.GroupID = 1 THEN '09'
						ELSE '08'
					END
		)
		INSERT INTO @tmpFGLGMatch(matchid)
		SELECT	@matchid
		WHERE EXISTS (
			SELECT TOP 1 1
			FROM	cteBetStatusM c
				LEFT JOIN DBPRO.bodb02.dbo.ResultDetail r WITH(NOLOCK)
					ON	c.matchid = r.matchid
						AND c.ResourceId = r.ResourceId
			WHERE ISNULL(r.SettlementStatusId,0) = 0
			GROUP BY c.matchid
		)
	END

	IF EXISTS (SELECT TOP 1 1 FROM @match m CROSS APPLY dbo.f_Set_SettingByProfile(m.sporttype))
	BEGIN
		
		;WITH cteBetstatus
		AS(
			SELECT	bm.matchid
					,m.ParentId
					,bm.bettype
					,bm.betcheck
					,m.sporttype
			FROM	@match m
				INNER JOIN dbo.bettransm bm WITH(NOLOCK) ON m.matchid = bm.matchid
			WHERE bm.statusID = 0
			GROUP BY bm.matchid, m.ParentId, bm.bettype, bm.betcheck,m.sporttype
		)
		,cteResourceID
		AS(
			SELECT c.matchid
					,c.ParentId
					,CASE 
						WHEN f.ResourceID = '70400' THEN '00' 
						WHEN f.RefResourceId IS NOT NULL THEN f.RefResourceId
						ELSE f.ResourceID 
					END AS ResourceID
					,f.SettleType
					,MAX(f.OrdNo) AS OrdNo
			FROM	cteBetstatus c
				INNER JOIN	dbo.SettlementSpecialBettypeProfile f WITH(NOLOCK) ON f.sporttype = c.sporttype AND c.bettype = f.BetType
			WHERE (f.Betid = 0 OR CAST(f.Betid AS NVARCHAR(50)) = c.Betcheck)
			GROUP BY c.matchid, c.ParentId
				,CASE 
					WHEN f.ResourceID = '70400' THEN '00' 
					WHEN f.RefResourceId IS NOT NULL THEN f.RefResourceId
					ELSE f.ResourceID 
				END
				,f.SettleType
		)
			
		INSERT INTO @tmpRunningBAIO (matchid, QuarterX, OrdNo)
		SELECT	c.ParentId, COALESCE(sd.RoundName, 'Early Settle'), MAX(c.OrdNo)
		FROM	cteResourceID c
			OUTER  APPLY(
	  			SELECT ResultStatusID
	  			FROM DBPRO.bodb02.dbo.ResultDetailES rd WITH (NOLOCK) 
	  			WHERE rd.ResourceID = c.ResourceID
	  				AND rd.matchid = c.matchid
				UNION ALL
				SELECT ResultStatusID
	  			FROM DBPRO.bodb02.dbo.ResultDetailOS rd WITH (NOLOCK) 
	  			WHERE rd.ResourceID = c.ResourceID
	  				AND rd.matchid = c.ParentId
				UNION ALL
				SELECT ResultStatusID
	  			FROM DBPRO.bodb02.dbo.ResultDetail rd WITH (NOLOCK) 
	  			WHERE rd.ResourceID = c.ResourceID
	  				AND rd.matchid = c.matchid
	  		) AS rs
			LEFT JOIN dbo.f_Set_MajorRound(@Sporttype) sd ON c.ResourceID = sd.ResourceID
		WHERE	ISNULL(rs.ResultStatusId,'') NOT IN ( 2, 5 )
		GROUP BY c.ParentId, sd.RoundName--,c.OrdNo
		--ORDER BY c.OrdNo
	END
	
	
	IF (
		EXISTS (
			SELECT 1
			FROM @match
			WHERE 1 = CASE 
						WHEN betstatus LIKE 'Abandoned 1H%' THEN CASE WHEN (hth IS NULL OR hta IS NULL) THEN 1 ELSE 0 END
						WHEN MatchId = ParentId AND (fth IS NULL OR fta IS NULL OR hth IS NULL OR hta IS NULL) THEN 1
						ELSE 0
					END
		)
		OR @IsExistsResourceEarlyRunning = 1
	)
	BEGIN
		SELECT @NotKeyScoreList = @matchcode + (CASE WHEN @IsExistsResourceEarlyRunning = 1 THEN '(Early Settle)' ELSE '' END)
	END
	
	IF EXISTS (SELECT TOP 1 1
					FROM @tmpRunningBAIO
				)		
	BEGIN
		SELECT @NotKeyScoreList = @NotKeyScoreList 
								+ m.matchcode +  '(' + STUFF((SELECT ',' + QuarterX 
												FROM @tmpRunningBAIO 
												WHERE m.matchid = matchid 
												ORDER BY OrdNo
												FOR XML PATH('')),1,1,'') + ')' 						
		FROM @match m
			INNER JOIN @tmpRunningBAIO t
				ON	m.matchid = t.matchid		
		GROUP BY m.matchid, m.matchcode
	END
	
	IF EXISTS (SELECT TOP 1 1 FROM @tmpFGLGMatch)
		SET @NotExecutedFGLG = @matchcode
		
	IF EXISTS (SELECT 1
				FROM @match
				WHERE matchid IN (SELECT matchid from Single_Calculate_Queue with(NOLOCK) where IsCalculating IN (0,1))
				OR matchid IN (SELECT matchid from Parlay_Calculate_Queue with(NOLOCK) where IsCalculating IN (0,1)) )
	BEGIN
		SELECT @NotAllowCalculating = @matchcode
	END

	-- check movebet day
	EXEC dbo.NAP_Admin_Settlement_CheckingMoveBetDay
		@MatchIds =  @MatchId 
		,@MovingMatchIds = @InvalidMatchIds OUTPUT

	SELECT	@MovingMatchIds = COALESCE(@MovingMatchIds + ',' + @matchcode, @matchcode)
	FROM	STRING_SPLIT (@InvalidMatchIds, ',') f
	WHERE	f.[value] = @MatchId

	-- check waiting ticket
	SELECT @HaveWaitingTicket = @matchcode
	WHERE EXISTS (
		SELECT TOP 1 1
		FROM dbo.bettransm b WITH(NOLOCK)
			INNER JOIN dbo.[f_Set_GetGroupBettypes]() f
				ON b.bettype = f.BetType
		WHERE b.matchid = @MatchId
			AND 
			( 
				b.statusID = 1 -- waiting status
				OR ( b.statusID = 0 AND b.SecAcceptFlag = 1 AND ISNULL(b.checktime, @currentdate) > @currentdate)
			)
		)
	
	IF (ISNULL(@NotKeyScoreList,'') <> '' or ISNULL(@NotAllowCalculating,'') <> '' OR ISNULL(@HaveWaitingTicket,'') <> '') OR ISNULL(@NotExecutedFGLG,'') <> '' OR ISNULL(@MovingMatchIds,'') <> ''
	BEGIN
		SELECT   @ErrCode = 1001011
				,@ErrMsg = 'This match is being calculated, except following matches ' 
							+ CASE WHEN ISNULL(@NotKeyScoreList, '') <> '' 
									THEN  '(not keyed in score yet): ' + @NotKeyScoreList 
									ELSE ''
								END
							+ CASE when ISNULL(@NotAllowCalculating,'') <> ''
									THEN  ' (being calculated by another user): ' + @NotAllowCalculating
									ELSE ''
								END 
							+ CASE WHEN ISNULL(@HaveWaitingTicket, '') <> ''
									THEN ' (existing some PENDING tickets): ' + @HaveWaitingTicket
									ELSE ''
								END
							+ CASE WHEN ISNULL(@NotExecutedFGLG, '') <> ''
									THEN ' (need to be executed "Calc FGLG"): ' + @NotExecutedFGLG
									ELSE ''
								END
							+ CASE WHEN ISNULL(@MovingMatchIds, '') <> ''
									THEN ' (during move-bet progress): ' + @MovingMatchIds + '. Please contact Starix IT for further support!'
									ELSE ''
								END
		RETURN
	END
	
	SELECT @procName = OBJECT_NAME(@@PROCID)
	
	IF @procName LIKE '%_xtest' or @procName LIKE '%_xpre' OR @procName LIKE '%_UAT_' -- UAT1 -->UAT9
	BEGIN
		IF EXISTS (SELECT TOP 1 1 FROM dbo.SystemSettings WHERE VName = 'isCalculatingParlay' AND VValue = '0')
					AND NOT EXISTS (SELECT TOP 1 1 FROM dbo.ParlayLocking)
		BEGIN
			UPDATE dbo.SystemSettings WITH (ROWLOCK, UPDLOCK)
					SET VValue = 1
			WHERE VName = 'isCalculatingParlay'
					
		END
		ELSE
		BEGIN
			SELECT	@ErrCode = 1000000
				,@ErrMsg = 'Another parlay settlement is in progress or some parlay tickets are being deleted, please wait a few seconds until the on-going process has finished and try again.'
			RETURN	
		END

		BEGIN TRY
			EXEC [NAP_Admin_Settlement_Refund_MP] @matchid = @matchid
				,@creator 	= @AdminId
				,@action 	= @mode
				,@IP 		= @IP
				,@ErrCode 	= @ErrCode OUTPUT
				,@ErrMsg 	= @ErrMsg OUTPUT
		END TRY

		BEGIN CATCH
			SELECT @ErrMsg = ERROR_MESSAGE()
					,@ErrCode = @@ERROR
		END CATCH

		UPDATE dbo.SystemSettings WITH (ROWLOCK, UPDLOCK)
			SET VValue = 0
		WHERE VName = 'isCalculatingParlay'
	END
	ELSE
	BEGIN		
		INSERT INTO dbo.Parlay_Calculate_Queue (matchid, isCalculating, creator, ip, starttime, action, Sporttype, BroadcastSessionId)
		SELECT @matchid, 0, @AdminId, @IP, CURRENT_TIMESTAMP, @mode, @sporttype, @BroadcastSessionId
	END
END
GO 

