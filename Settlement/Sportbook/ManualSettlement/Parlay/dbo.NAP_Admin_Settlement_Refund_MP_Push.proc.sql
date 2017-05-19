/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
USE [bodb02]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Refund_MP_Push] (
	@AdminId 						INT
	,@MatchId 						INT
	,@Action 						VARCHAR(20) = 'REFUND'
	,@SettleAbandonedMatchIBCParlay TINYINT	= 0
	,@IP 							VARCHAR(15) = ''
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

	Param's Explanation:		
		- @Action: [Refund, Refund-HT, Refund-FT]
		- @SettleAbandonedMatchIBCParlay: TINYINT
			+ 1: Single - Abandoned 1H
			+ 2: Single - Abandoned 2H
*/
BEGIN
	SET NOCOUNT ON

	DECLARE  @NotKeyScoreList	VARCHAR(130) = ''
		,@NotAllowCalculating	VARCHAR(200)
		,@HaveWaitingTicket		VARCHAR(200)

    DECLARE @matchcode			NVARCHAR(50)
		,@sporttype     		INT
		,@leagueid      		INT		
		,@IsNested      		BIT
		,@ActionId        		INT
		,@procName      		NVARCHAR(128)
		,@sqlCommand			NVARCHAR(1000)
		,@IsExistNetPosition	BIT = 0
		,@Mode					VARCHAR(20)

	DECLARE @match TABLE ( matchid INT
						  ,matchcode NVARCHAR(50)
						  ,fth SMALLINT
						  ,fta SMALLINT
						  ,hth SMALLINT
						  ,hta SMALLINT
						  ,sporttype SMALLINT
						  ,leagueid INT
						  ,betstatus VARCHAR(50)
						)

	SELECT @ActionId		= CASE 
								WHEN @Action = 'REFUND' THEN 107 
								WHEN @Action = 'REFUND-HT' THEN 120 
								WHEN @Action = 'REFUND-FT' THEN 106 
								ELSE 0 
							END
		, @Mode				= CASE 
								WHEN @Action = 'REFUND' AND @SettleAbandonedMatchIBCParlay =  1 THEN 'ABANDONED-1H'
								WHEN @Action = 'REFUND-FT' AND @SettleAbandonedMatchIBCParlay =  2 THEN 'ABANDONED-2H'
								ELSE @Action
							END
	
	INSERT INTO @match ( matchid, matchcode, fth, fta, hth, hta, sporttype, leagueid, betstatus)
	SELECT matchid
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

    IF EXISTS (
            SELECT	1
            FROM	dbo.Single_Calculate_Queue WITH (NOLOCK)
            WHERE	matchid = @matchid
					AND IsCalculating IN (0, 1)
            )

        OR EXISTS (
            SELECT	1
            FROM	dbo.Parlay_Calculate_Queue WITH (NOLOCK)
            WHERE	matchid = @matchid
					AND IsCalculating IN (0, 1)
            )
    BEGIN
        SELECT @ErrCode = 1001003
            ,@ErrMsg    = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'

        RETURN
    END
	
	-- checking validation
	DECLARE @tblRunningAutoSettle TABLE (matchid INT, IsParlay BIT)
	
	IF @sporttype = 1
	BEGIN
		INSERT INTO @tblRunningAutoSettle(matchid, IsParlay)
		SELECT @matchid, 0
		WHERE EXISTS (
			SELECT TOP 1 1
			FROM	dbo.bettrans WITH(NOLOCK)
			WHERE	matchid = @MatchId
					AND statusID = 0
					AND bettype IN (SELECT bettype FROM dbo.[f_Set_GetGroupBettypes]() WHERE GroupId = 8)
			)
	
		;WITH cteBetStatusM
		AS (
			SELECT	matchid
				,CASE 
					WHEN BetType IN (160,164,169,180,216) THEN CAST(BetType AS VARCHAR(20)) + '__'
					ELSE CAST(BetType AS VARCHAR(20))
				END AS ResourceId
			FROM	dbo.bettransm WITH(NOLOCK)
			WHERE	matchid = @MatchId
					AND statusID = 0
					AND bettype IN (SELECT BetType FROM dbo.[f_Set_GetGroupBettypes]() WHERE GroupId = 8)
			GROUP BY matchid, bettype		
		)
		INSERT INTO @tblRunningAutoSettle(matchid, IsParlay)
		SELECT	@matchid, 1
		WHERE EXISTS (
			SELECT TOP 1 1
			FROM cteBetStatusM c
			LEFT JOIN DBPRO.BODB02.dbo.ResultDetail r WITH(NOLOCK)
				ON	c.matchid = r.matchid
					AND r.ResourceId LIKE c.ResourceId
			WHERE	r.ResultStatusId NOT IN (2,5)
		)
	END

	DECLARE @tblRunningBAIO TABLE (matchid INT, QuarterX NVARCHAR(50))
	IF @sporttype = 2
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
			GROUP BY bm.matchid, bm.bettype, bm.betcheck
		)
		,cteResourceID
		AS(
			SELECT c.matchid
					,CASE 
						WHEN f.GroupName = 'FT' THEN '00'
						WHEN f.GroupName = '1H' THEN '01'
						WHEN f.GroupName = '2H' THEN '02'
						WHEN f.GroupName = 'Special' THEN 'Q' + SUBSTRING(c.betid,3,1)
						ELSE NULL
					END AS ResourceID
					,CASE 
						WHEN f.GroupName IN ('FT', '1H', '2H') THEN f.GroupName
						WHEN f.GroupName = 'Special' THEN 'Q' + SUBSTRING(c.betid,3,1)
						ELSE NULL
					END AS QuarterX
			FROM	cteBetstatus c
				INNER JOIN	dbo.[f_Set_GetGroupBettypes]() f
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
	
	IF (
		EXISTS (
			SELECT 1
			FROM @match
			WHERE 1 = CASE 
						WHEN betstatus LIKE 'Abandoned 1H%' THEN CASE WHEN (hth IS NULL OR hta IS NULL) THEN 1 ELSE 0 END
						WHEN (fth IS NULL OR fta IS NULL OR hth IS NULL OR hta IS NULL) THEN 1
						ELSE 0
					END
		)
		OR EXISTS (
			SELECT TOP 1 1
			FROM @tblRunningAutoSettle
		)		
	)
	BEGIN
		SELECT @NotKeyScoreList = @matchcode
	END
	
	IF EXISTS (SELECT TOP 1 1
					FROM @tblRunningBAIO
				)		
	BEGIN
		SELECT @NotKeyScoreList = @NotKeyScoreList 
								+ m.matchcode +  '(' + STUFF((SELECT ',' + QuarterX 
												FROM @tblRunningBAIO 
												WHERE m.matchid = matchid 
												FOR XML PATH('')),1,1,'') + ')' 						
		FROM @match m
			INNER JOIN @tblRunningBAIO t
				ON	m.matchid = t.matchid		
		GROUP BY m.matchid, m.matchcode
	END

	IF EXISTS (SELECT 1
				FROM @match
				WHERE matchid IN (SELECT matchid from Single_Calculate_Queue with(NOLOCK) where IsCalculating IN (0,1))
				OR matchid IN (SELECT matchid from Parlay_Calculate_Queue with(NOLOCK) where IsCalculating IN (0,1)) )
	BEGIN
		SELECT @NotAllowCalculating = @matchcode
	END

	-- check waiting ticket
	SELECT @HaveWaitingTicket = @matchcode
	WHERE EXISTS (
		SELECT TOP 1 1
		FROM dbo.bettransm b WITH(NOLOCK)
			INNER JOIN dbo.[f_Set_GetGroupBettypes]() f
				ON b.bettype = f.BetType
		WHERE b.matchid = @MatchId
			AND b.statusID = 1 -- waiting status
		)

	IF (ISNULL(@NotKeyScoreList,'') <> '' or ISNULL(@NotAllowCalculating,'') <> '' OR ISNULL(@HaveWaitingTicket,'') <> '')
	BEGIN
		SELECT   @ErrCode = 1001011
				,@ErrMsg = 'This match is being calculated, except following matches ' 
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
		RETURN
	END

	SELECT @procName = OBJECT_NAME(@@PROCID)
	
	IF @procName LIKE '%_xtest' or @procName LIKE '%_xpre' OR @procName LIKE '%_UAT_' -- UAT1 -->UAT9
	BEGIN
		BEGIN TRY
			EXEC [NAP_Admin_Settlement_Refund_MP] @matchid = @matchid
				,@creator 	= @AdminId
				,@action 	= @mode
				,@IP 		= @IP
				,@ErrCode 	= @ErrCode OUTPUT
				,@ErrMsg 	= @ErrMsg OUTPUT
		END TRY

		BEGIN CATCH
			SET @ErrMsg = ERROR_MESSAGE()
		END CATCH
	END
	ELSE
	BEGIN		
		INSERT INTO dbo.Parlay_Calculate_Queue (matchid, isCalculating, creator, ip, starttime, action)
		SELECT @matchid, 0, @AdminId, @IP, CURRENT_TIMESTAMP, @mode
	END
END

GO 
 GRANT EXECUTE ON [dbo].[NAP_Admin_Settlement_Refund_MP_Push] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[NAP_Admin_Settlement_Refund_MP_Push] TO [vnteam]
GO 
