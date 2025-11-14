/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_HybridParlay_Validate] 
	@MatchId		INT
	,@Action		VARCHAR(20) = 'CAL'	
	,@ErrCode		INT = 0 OUTPUT
	,@ErrMsg		NVARCHAR(200) = NULL OUTPUT
AS
/*
    Created by: Max
	Date 20251027
	Task: [Settlement] - Integration - Jacktime - Basketball Main Bettype Hybrid Parlay [Redmine: #241652]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20251027@Max: Init new SP [Redmine: #241652]

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @procName SYSNAME = OBJECT_NAME(@@procid)
	DECLARE @IsCalculating TINYINT 
		,@IsCentral BIT = 0	
		,@totalRowCount INT = 0

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT 

	DECLARE @tmpMainTransIdResult TABLE (TransId BIGINT)
	DECLARE @tmpRefNo TABLE (refno BIGINT, MaxSubTransId BIGINT)
	
	IF @procName LIKE '%_xtest' OR @procName LIKE '%_xpre' OR @procName LIKE '%_UAT[1-9]'
	BEGIN
		WAITFOR DELAY '00:00:10.000'
	END	
	ELSE 
	BEGIN
		WAITFOR DELAY '00:00:02.000'

		SET @IsCalculating = (SELECT TOP 1 1 FROM dbo.Parlay_Calculate_Queue p WITH (NOLOCK) WHERE p.matchid = @MatchId ORDER BY Starttime DESC)
	END

	IF @IsCalculating = 2 OR @IsCalculating IS NULL
	BEGIN	
		IF @Action NOT LIKE 'UNDO%'
		BEGIN
			--Get list main transid running to update new legodds & settle
			INSERT INTO @tmpMainTransIdResult (TransId)
			SELECT DISTINCT b.TransId
			FROM dbo.bettransm bm WITH (NOLOCK)
				INNER HASH JOIN dbo.bettrans b WITH (NOLOCK) ON b.refno = bm.refno
			WHERE b.oddsspread = 3
				AND b.matchid = 29
				AND b.bettype = 29	
				AND bm.statuswinlost IS NOT NULL
				AND bm.statusID IN (0,1)
				AND bm.matchid = @MatchId
				AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END

			SET @totalRowCount = @totalRowCount + @@ROWCOUNT
			
			--Get more settled transid with status(halfWON/LOSE, DRAW, REFUND) but need to update new legodds for betlist
			;WITH cte AS (
				SELECT refno, MAX(transid) AS MaxSubTransId
							, SUM(CASE WHEN bm.statusID IN (0,1) THEN 1 ELSE 0 END) AS total_running
							, SUM(CASE WHEN bm.statuswinlost IN (0,1,3) THEN 1 ELSE 0 END) AS total_getnewodds
							, SUM(CASE WHEN bm.statuswinlost IN (4) THEN 1 ELSE 0 END) AS total_lose
				FROM dbo.bettransm bm WITH (NOLOCK)
				WHERE bm.matchid = @MatchId
					AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
				GROUP BY refno
			)
			INSERT INTO @tmpRefNo (refno, MaxSubTransId)
			SELECT refno, MaxSubTransId 
			FROM cte c
			WHERE c.total_running = 0
				AND c.total_lose = 0
				AND c.total_getnewodds > 0
			
			INSERT INTO @tmpMainTransIdResult (TransId)
			SELECT DISTINCT b.TransId
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @tmpRefNo c ON c.refno = b.refno
				CROSS APPLY (
								SELECT odds
								FROM dbo.bettransm bm WITH (NOLOCK)
								WHERE c.refno = bm.refno AND bm.TransId = c.MaxSubTransId
						) AS t
				CROSS APPLY (
							SELECT o AS odds_transdesc
							FROM OPENJSON(b.transdesc, '$.legOdds')
							WITH (
								m BIGINT '$.m',
								o MONEY '$.o'
							)
							WHERE m = @MatchId
						)j
			WHERE b.oddsspread = 3
				AND b.matchid = 29
				AND b.bettype = 29	
				AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
				AND j.odds_transdesc = t.odds 

			SET @totalRowCount = @totalRowCount + @@ROWCOUNT

			IF @totalRowCount = 0
			BEGIN
				SELECT @ErrCode = 101
					, @ErrMsg = 'No valid ticket found.'
			END
			ELSE
			BEGIN
				SELECT t.TransId
				FROM @tmpMainTransIdResult t
			END
		END
	END
	ELSE IF @IsCalculating IN (0,1)
	BEGIN
		SELECT @ErrCode = 100
			, @ErrMsg = 'The parlay queue has not been completed yet.'
		
	END
	ELSE
	BEGIN
		SELECT @ErrCode = 99
			, @ErrMsg = 'The parlay queue failed.'
		
	END
END