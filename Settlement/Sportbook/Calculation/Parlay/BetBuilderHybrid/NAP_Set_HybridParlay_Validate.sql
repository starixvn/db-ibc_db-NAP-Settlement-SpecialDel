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
			SELECT DISTINCT b.TransId
			FROM dbo.bettransm bm WITH (NOLOCK)
				INNER HASH JOIN dbo.bettrans b WITH (NOLOCK) ON b.refno = bm.refno
			WHERE b.oddsspread = 3
				AND b.matchid = 29
				AND b.bettype = 29	
				AND bm.statuswinlost IS NOT NULL
				AND bm.statusID IN (0,1)
				AND bm.matchid = @MatchId

			IF @@ROWCOUNT = 0
			BEGIN
				SELECT @ErrCode = 101
					, @ErrMsg = 'No valid ticket found.'
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