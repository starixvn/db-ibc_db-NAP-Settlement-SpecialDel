/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_MP_Push] (
	@MatchIds VARCHAR(4000)
	,@AdminId INT
	,@Action VARCHAR(20) = 'CAL'
	,@IP VARCHAR(15) = ''
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
	)
AS
/*	Creator: 20140213@Kathy
	Task: Main SP for Mix parly settlement
	DB: DBTXN/BODB02
	ORIGINAL: Admin_Settlement_MP

	Revisions:		
		- 20140506@Kathy: Don't allow to calculate exists matches in queue
		- 20140512@Kathy: allow to execute undo action without score [Redmine:#14449]
		- 20141117@Jamie: Change ErrCode [Redmine:#23034]		
		- 20150401@Kathy: Add checking ticket status before performing settlement [Redmine:#33493]		
		- 20150922@Johnson: check result status from ResultDetail [Redmine: #43806]
		- 20151002@Kathy: add more UAT version for testing (UAT1,UAT2,UAT3,UAT4)
		- 20160429@Kathy: Enhance performance [Redmine:#52426]
		- 20160714@Kathy: Add checking SystemSettings before doing Parlay Settlement on UAT
		- 20160801@Patrick: Auto Payout - User can cal MP before calculating FT FGLG [Redmine: #61767]
		- 20161125@Bobby: #67822 - check single and parlay ticket for AUTO bet types
		- 20170313@Kathy: Check betstatus result for bettype 14,127 to notify user do CAL FGLG [Redmine:#73218]
		- 20170215@Kathy: Basketball All-in-One [Redmine:#71372]
		- 20170609@Kathy: Early settlement for BAIO [Redmine:#77835]
		
	Param's Explanation:		
		
*/
SET NOCOUNT ON

BEGIN
	DECLARE  @NotKeyScoreList VARCHAR(130) = ''
			,@NotAllowCalculating VARCHAR(200)
			,@HaveWaitingTicket VARCHAR(200)
			,@NotExecutedFGLG VARCHAR(200)
			,@procName nvarchar(50)	
			,@matchid int
		
	DECLARE @subErrCode		INT
			,@subErrMsg		NVARCHAR(200)
	
	DECLARE @match TABLE ( matchid INT
						  ,matchcode NVARCHAR(50)
						  ,fth SMALLINT
						  ,fta SMALLINT
						  ,hth SMALLINT
						  ,hta SMALLINT
						  ,betstatus NVARCHAR(50)
						  ,sporttype SMALLINT
						 )
						 
	
	SELECT	 @ErrCode = 0
			,@ErrMsg = ''
			,@procName = OBJECT_NAME(@@procid)
			,@subErrCode = 0
			,@subErrMsg = ''
			
	INSERT INTO @match ( matchid, matchcode, fth, fta, hth, hta, betstatus, sporttype)
	SELECT DISTINCT matchid
			,matchcode
			,finalhomescore
			,finalawayscore
			,hthomescore
			,htawayscore
			,betstatus
			,sporttype
	FROM DBPRO.BODB02.dbo.Match WITH (NOLOCK)
	WHERE matchid IN ( SELECT val
					   FROM dbo.strSplit(@matchids, ',') ) 
	
	DECLARE @tblFGLGMatch TABLE(matchid INT, matchcode NVARCHAR(50))
	DECLARE @tblRunningAutoSettle TABLE (matchid INT)
	
	DECLARE @tblRunningBAIO TABLE (matchid INT, QuarterX NVARCHAR(50))
	DECLARE @tmpBettypes TABLE (bettype SMALLINT, groupId INT, groupname VARCHAR(50), isEarly BIT)
	
	INSERT INTO @tmpBettypes(bettype, groupId, groupname, isEarly)
	SELECT	f.BetType, f.GroupId, f.GroupName, (SELECT 1 FROM dbo.f_Set_GetEarlyBettypes() WHERE bettype = f.BetType) AS isEarly
	FROM	dbo.f_Set_GetGroupBettypes() f
	
	IF EXISTS (SELECT TOP 1 1 FROM @match WHERE sporttype = 1)
	BEGIN
		INSERT INTO @tblRunningAutoSettle
		SELECT matchid
		FROM	dbo.bettrans WITH(NOLOCK)
		WHERE	matchid IN (SELECT matchid FROM @match)
				AND statusID = 0
				AND bettype IN (SELECT bettype FROM dbo.[f_Set_GetGroupBettypes]() WHERE GroupId = 8)
		GROUP BY matchid
	
		;WITH cteBetStatusM
		AS(
			SELECT	matchid
					,CASE 
						WHEN BetType IN (160,164,169,180,216) THEN CAST(BetType AS VARCHAR(20)) + '__'
						ELSE CAST(BetType AS VARCHAR(20))
					END AS ResourceId
			FROM	dbo.bettransm WITH(NOLOCK)
			WHERE	matchid IN (SELECT matchid FROM @match)
					AND statusID = 0
					AND bettype IN (SELECT BetType FROM dbo.[f_Set_GetGroupBettypes]() WHERE GroupId = 8)
			GROUP BY matchid, bettype		
		)
		INSERT INTO @tblRunningAutoSettle (matchid)
		SELECT	c.matchid
		FROM	cteBetStatusM c
			LEFT JOIN DBPRO.BODB02.dbo.ResultDetail r WITH(NOLOCK)
				ON	c.matchid = r.matchid
					AND r.ResourceId LIKE c.ResourceId
		WHERE	ISNULL(r.ResultStatusId,'') NOT IN (2,5)
	END

	IF EXISTS (SELECT TOP 1 1 FROM @match WHERE sporttype = 2)
	BEGIN
		;WITH cteBetstatus
		AS(
			SELECT	b.matchid
					,b.bettype
					,CAST(b.betid AS NVARCHAR(50)) betid
			FROM	dbo.bettrans b WITH(NOLOCK)
			WHERE	b.matchid IN (SELECT matchid FROM @match)
					AND b.statusID = 0
			GROUP BY b.matchid, b.bettype, b.betid
			UNION ALL
			SELECT	bm.matchid
					,bm.bettype
					,bm.betcheck
			FROM	dbo.bettransm bm WITH(NOLOCK)
			WHERE	bm.matchid IN (SELECT matchid FROM @match)
					AND bm.statusID = 0
			GROUP BY bm.matchid, bm.bettype, bm.betcheck
		)
		,cteResourceID
		AS(
			SELECT c.matchid
					,CASE 
						WHEN f.isEarly = 1 OR c.bettype IN (605, 617) THEN CAST(c.bettype AS VARCHAR) + ISNULL(SUBSTRING(c.betid, 2, LEN(c.betid)), '')
						WHEN f.GroupName = 'FT' THEN '00'
						WHEN f.GroupName = '1H' THEN '01'
						WHEN f.GroupName = '2H' THEN '02'
						WHEN f.GroupName = 'Special' THEN 'Q' + SUBSTRING(c.betid,3,1)
						ELSE NULL
					END AS ResourceID
					,CASE 
						WHEN f.isEarly = 1 THEN 'Early Settle'
						WHEN f.GroupName IN ('FT', '1H', '2H') THEN f.GroupName
						WHEN f.GroupName = 'Special' THEN 'Q' + SUBSTRING(c.betid,3,1)
						ELSE NULL
					END AS QuarterX
			FROM	cteBetstatus c
				INNER JOIN	@tmpBettypes f
					ON c.bettype = f.BetType
		)
		INSERT INTO @tblRunningBAIO (matchid, QuarterX)
		SELECT	c.matchid, c.QuarterX
		FROM	cteResourceID c
			LEFT JOIN DBPRO.bodb02.dbo.ResultDetail r WITH(NOLOCK)
				ON	c.matchid = r.matchid
					AND c.ResourceId = r.ResourceId
		WHERE	ISNULL(r.ResultStatusId,'') <> 5
		GROUP BY c.matchid, c.QuarterX
	END

	IF EXISTS (SELECT 1
				FROM @match
				WHERE fth IS NULL OR fta IS NULL OR hth IS NULL OR hta IS NULL ) AND @action <> 'UNDO'
		OR EXISTS (SELECT TOP 1 1
					FROM @tblRunningAutoSettle
				)	
		OR EXISTS (SELECT TOP 1 1
					FROM @tblRunningBAIO
				)					
	BEGIN
		SELECT @NotKeyScoreList = @NotKeyScoreList + matchcode + ','
		FROM @match
		WHERE fth IS NULL OR fta IS NULL OR hth IS NULL OR hta IS NULL
			OR matchid IN (SELECT matchid FROM @tblRunningAutoSettle)

		-- exclude matches were not keyscore yet
		DELETE
		FROM @match
		WHERE fth IS NULL OR fta IS NULL OR hth IS NULL OR hta IS NULL
				OR matchid IN (SELECT matchid FROM @tblRunningAutoSettle)
				
		
		SELECT @NotKeyScoreList = @NotKeyScoreList 
								+ m.matchcode +  '(' + STUFF((SELECT ',' + QuarterX 
												FROM @tblRunningBAIO 
												WHERE m.matchid = matchid 
												FOR XML PATH('')),1,1,'') + ')' 
								+ ',' 
						
		FROM @match m
			INNER JOIN @tblRunningBAIO t
				ON	m.matchid = t.matchid		
		GROUP BY m.matchid, m.matchcode
		
		IF RIGHT(@NotKeyScoreList,1) = ','
			SET @NotKeyScoreList = LEFT(@NotKeyScoreList,LEN(@NotKeyScoreList)-1)
			
		DELETE m
		FROM @match m
		WHERE EXISTS (SELECT TOP 1 1 FROM @tblRunningBAIO WHERE matchid = m.matchid)
		
	END

	--have running tickets of 14 & 127 on bettrans for auto payout
	DECLARE @Tmp TABLE(MatchId INT, matchcode VARCHAR(100))
	IF EXISTS (SELECT TOP 1 1
				FROM dbo.bettrans WITH(NOLOCK)
				WHERE matchid IN (SELECT matchid FROM @match)
					AND bettype IN (14,127)
					AND statusID = 0
			)
	BEGIN
		-- exclude matches were not keyscore yet
		DELETE m
		OUTPUT DELETED.matchid, DELETED.matchcode INTO @Tmp(MatchId, matchcode)
		FROM @match m
		WHERE EXISTS (SELECT 1 FROM dbo.bettrans b WITH(NOLOCK)
						WHERE m.matchid = b.matchid
							AND bettype IN (14,127)
							AND statusID = 0)
	END
	
	IF EXISTS (SELECT TOP 1 1 FROM @Tmp)
	BEGIN
		SELECT @NotKeyScoreList = COALESCE(@NotKeyScoreList + ',' + matchcode, matchcode)
		FROM @Tmp
	END
	--End: have running tickets of 14 & 127 on bettrans for auto payout
	
	DELETE m
	OUTPUT DELETED.matchid, DELETED.matchcode INTO @tblFGLGMatch(matchid, matchcode)
	FROM @match m
	WHERE EXISTS (SELECT	TOP 1 1 
					FROM	dbo.bettransm bm WITH(NOLOCK)
					WHERE	bm.matchid = m.matchid
							AND bm.bettype = 127
							AND bm.statusId = 0
							AND CHARINDEX('1FL',m.betstatus) = 0 )
							
	DELETE m
	OUTPUT DELETED.matchid, DELETED.matchcode INTO @tblFGLGMatch(matchid, matchcode)
	FROM @match m
	WHERE EXISTS (SELECT	TOP 1 1 
					FROM	dbo.bettransm bm WITH(NOLOCK)
					WHERE	bm.matchid = m.matchid
							AND bm.bettype = 14
							AND bm.statusId = 0
							AND CHARINDEX('FL',REPLACE(m.betstatus,'1FL','')) = 0 )
	
	IF EXISTS (SELECT TOP 1 1 FROM @tblFGLGMatch)
	BEGIN
		SELECT @NotExecutedFGLG = COALESCE(@NotExecutedFGLG + ',' + matchcode, matchcode)
		FROM @tblFGLGMatch
	END
	IF EXISTS (SELECT 1
				FROM @match
				WHERE matchid IN (SELECT matchid from Single_Calculate_Queue with(NOLOCK) where IsCalculating IN (0,1))
				OR matchid IN (SELECT matchid from Parlay_Calculate_Queue with(NOLOCK) where IsCalculating IN (0,1)) )
	BEGIN
		SELECT @NotAllowCalculating = COALESCE(@NotAllowCalculating + ',' + matchcode, matchcode)
		FROM @match 
		WHERE matchid IN (SELECT matchid from Single_Calculate_Queue with(NOLOCK) where IsCalculating IN (0,1) )
		OR matchid IN (SELECT matchid FROM Parlay_Calculate_Queue with(NOLOCK) WHERE IsCalculating IN (0,1) ) 

		-- exclude matches were not allow to calculate
		DELETE
		FROM @match
		WHERE matchid IN (SELECT matchid from Single_Calculate_Queue with(NOLOCK) where IsCalculating IN (0,1) )
		OR matchid IN (SELECT matchid FROM Parlay_Calculate_Queue with(NOLOCK) WHERE IsCalculating IN (0,1) ) 
	END
	
	-- check waiting ticket
	EXEC [NAP_Admin_Settlement_Checking] 		@MatchIds = @MatchIds	OUTPUT
		,@Action = @Action
		,@Mode = 'CAL-MP'	
	
	SELECT @HaveWaitingTicket = COALESCE(@HaveWaitingTicket + ',' + m.matchcode, m.matchcode)
	FROM dbo.match m WITH(NOLOCK)
	WHERE m.matchid IN (SELECT val FROM dbo.strSplit(@MatchIds, ','))
	
	DELETE FROM @match
	WHERE matchid IN (SELECT val FROM dbo.strSplit(@MatchIds, ','))

	IF (ISNULL(@NotKeyScoreList,'') <> '' or ISNULL(@NotAllowCalculating,'') <> '' OR ISNULL(@HaveWaitingTicket,'') <> '') OR ISNULL(@NotExecutedFGLG,'') <> ''
	BEGIN
		SELECT   @ErrCode = 1001011
				,@ErrMsg = 'All matches are being calculated, except following matches ' 
							+ CASE WHEN ISNULL(@NotKeyScoreList, '') <> '' 
									THEN  '(not keyed in score yet): ' + @NotKeyScoreList 
									ELSE ''
								END
							+ CASE when ISNULL(@NotAllowCalculating,'') <> ''
									THEN  '(being calculated by another user): ' + @NotAllowCalculating
									ELSE ''
								END 
							+ CASE WHEN ISNULL(@HaveWaitingTicket, '') <> ''
									THEN '(existing some PENDING tickets): ' + @HaveWaitingTicket
									ELSE ''
								END
							+ CASE WHEN ISNULL(@NotExecutedFGLG, '') <> ''
									THEN '(need to be executed "Calc FGLG"):' + @NotExecutedFGLG
									ELSE ''
								END
	END
	
	IF EXISTS (
				SELECT TOP 1 1
				FROM @match
				)
	BEGIN
		IF @procName LIKE '%_xtest' or @procName LIKE '%_xpre' OR @procName LIKE '%_UAT_' -- UAT1 -->UAT9
		BEGIN

			WHILE(1 = 1)
			BEGIN
				SELECT TOP 1 @matchid = matchid
				FROM @match

				IF @@ROWCOUNT = 0
					BREAK
				
				IF EXISTS (SELECT TOP 1 1 FROM dbo.SystemSettings WHERE VName = 'isCalculatingParlay' AND VValue = 1)
				BEGIN
					SELECT	@ErrCode = 1000000
						,@ErrMsg = 'Another parlay settlement is in progress or some parlay tickets are being deleted, please wait a few seconds until the on-going process has finished and try again.'
					RETURN	
				END
				ELSE
				BEGIN
					UPDATE dbo.SystemSettings WITH (ROWLOCK, UPDLOCK)
							SET VValue = 1
					WHERE VName = 'isCalculatingParlay'
				END
				
				BEGIN TRY
					EXEC [NAP_Admin_Settlement_MP] @matchid = @matchid
						,@creator = @AdminId
						,@action  = @action
						,@IP      = @IP
						,@ErrCode = @subErrCode OUTPUT
						,@ErrMsg  = @subErrMsg   OUTPUT
				END TRY
				BEGIN CATCH					
					UPDATE dbo.SystemSettings WITH (ROWLOCK, UPDLOCK)
							SET VValue = 0
					WHERE VName = 'isCalculatingParlay'
						
					SELECT @ErrMsg  = @subErrMsg + ISNULL(ERROR_MESSAGE(),'')
						  ,@ErrCode = @@error
					RETURN
				END CATCH
								
				UPDATE dbo.SystemSettings WITH (ROWLOCK, UPDLOCK)
						SET VValue = 0
				WHERE VName = 'isCalculatingParlay'

				DELETE 
				FROM @match
				WHERE matchid = @matchid
			END
			
		END
		ELSE
		BEGIN		
			INSERT INTO dbo.Parlay_Calculate_Queue (matchid, isCalculating, creator, ip, starttime, action)
			SELECT matchid, 0, @AdminId, @IP, CURRENT_TIMESTAMP, @action
			FROM @match
		END
	END
END


GO