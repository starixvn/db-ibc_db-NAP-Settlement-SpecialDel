/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Set_MatchDeleteChecking
	@matchids VARCHAR(MAX)
	,@ErrCode INT  = 0 OUTPUT
	,@ErrMsg  VARCHAR(200) = '' OUTPUT 
AS
/*
		Created By : 20211125@Louisa
		Task: Delete Match no ticket
		DB: DBPRO-bodb02

		Revisions:
				- 20211125@Louisa: Checking before call API [Redmine:#163469]

*/
BEGIN
	
	SET NOCOUNT ON;

	DECLARE @tmpMatchId	TABLE ( MatchId INT, eventstatus NVARCHAR(100), SettlementStatus TINYINT, OddsTable TINYINT )

	INSERT INTO @tmpMatchId ( Matchid, eventstatus, SettlementStatus, OddsTable )
	SELECT m.matchid, m.eventstatus, ISNULL(m.SettlementStatus,0)
			, CASE WHEN m.sporttype IN ( 9, 45, 50) THEN 2
					WHEN m.sporttype = 43 THEN 3
					ELSE 1
			 END AS OddsTable			
	FROM dbo.match m WITH(NOLOCK)
		INNER JOIN dbo.f_SplitString( @matchids, ',' ) f
			ON m.MatchId = CAST( f.val AS INT)
	WHERE ISNULL(m.IsDeleted,0) = 0
	OPTION (MAXRECURSION 0)	
	
	IF EXISTS (	SELECT TOP 1 1 FROM @tmpMatchId tmp	WHERE tmp.eventstatus <> 'closed' OR tmp.SettlementStatus & 87 > 1	 )
	BEGIN
		SELECT	@ErrCode = 1001069
				,@ErrMsg =  'WARNING! Cannot continue due to selected matches are not ready to delete or are on-hold. Please check and try again.'
		RETURN
	END

	IF EXISTS ( SELECT TOP 1 1 FROM @tmpMatchId tmp
								INNER JOIN dbo.match m WITH(NOLOCK)
									ON m.ParentID IS NOT NULL
									AND m.ParentID = tmp.MatchId
							WHERE ISNULL(m.IsDeleted,0) = 0
				)
	BEGIN
		SELECT	@ErrCode = 1001069
				,@ErrMsg =  'WARNING! Cannot continue due to selected matches are not ready to delete or are on-hold. Please check and try again.'
		RETURN
	END

	IF EXISTS (SELECT TOP 1 1 FROM @tmpMatchId WHERE OddsTable = 1	)
	BEGIN
		SELECT	@ErrCode = 1001069
				,@ErrMsg =  'WARNING! Cannot continue due to selected matches are not ready to delete or are on-hold. Please check and try again.'
		FROM (	SELECT TOP 1 o.matchid 
				FROM dbo.odds o WITH(NOLOCK)
					INNER JOIN @tmpMatchId tmp
						ON o.matchid = tmp.MatchId
					WHERE o.OddsStatus NOT IN ('closed', 'internal')
						AND ISNULL(o.IsDeleted,0) = 0
						AND tmp.OddsTable = 1
			) err
		IF ISNULL(@ErrCode,0) > 0
		RETURN
	END
	
	IF EXISTS (SELECT TOP 1 1 FROM @tmpMatchId WHERE OddsTable = 2 )
	BEGIN
		SELECT	@ErrCode = 1001069
				,@ErrMsg =  'WARNING! Cannot continue due to selected matches are not ready to delete or are on-hold. Please check and try again.'
		FROM (	SELECT TOP 1 o.matchid 
				FROM dbo.oddsOS o WITH(NOLOCK)
					INNER JOIN @tmpMatchId tmp
						ON o.matchid = tmp.MatchId
					WHERE o.OddsStatus NOT IN ('closed', 'internal')
						AND ISNULL(o.IsDeleted,0) = 0
						AND tmp.OddsTable = 2
			) err
		IF ISNULL(@ErrCode,0) > 0
		RETURN
	END

	IF EXISTS (SELECT TOP 1 1 FROM @tmpMatchId WHERE OddsTable = 3)
	BEGIN
		SELECT	@ErrCode = 1001069
				,@ErrMsg =  'WARNING! Cannot continue due to selected matches are not ready to delete or are on-hold. Please check and try again.'
		FROM (	SELECT TOP 1 o.matchid 
				FROM dbo.oddsES o WITH(NOLOCK)
					INNER JOIN @tmpMatchId tmp
						ON o.matchid = tmp.MatchId
					WHERE o.OddsStatus NOT IN ('closed', 'internal')
						AND ISNULL(o.IsDeleted,0) = 0
						AND tmp.OddsTable = 3
			) err
		IF ISNULL(@ErrCode,0) > 0
		RETURN
	END

	
	IF EXISTS ( SELECT TOP 1 1 FROM @tmpMatchId tmp
					INNER JOIN DBTXN.bodb02.dbo.Bettrans b WITH(NOLOCK)
						ON tmp.MatchId = b.matchid
				)
	BEGIN
		SELECT	@ErrCode = 1001069
				,@ErrMsg =  'WARNING! Cannot continue due to selected matches are not ready to delete or are on-hold. Please check and try again.'
		RETURN
	END

	IF EXISTS ( SELECT TOP 1 1 FROM @tmpMatchId tmp
					INNER JOIN DBTXN.bodb02.dbo.Bettransm bm WITH(NOLOCK)
						ON tmp.MatchId = bm.matchid
				)
	BEGIN
		SELECT	@ErrCode = 1001069
				,@ErrMsg =  'WARNING! Cannot continue due to selected matches are not ready to delete or are on-hold. Please check and try again.'
		RETURN
	END
	

END
GO
