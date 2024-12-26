/*<info serverAlias="DBTXN-bodb02" executers="svc_tig" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_VS_BetRadar_MP] 
	@AdminId			INT
	,@MatchId			INT
	,@SportType			INT				= 0
	,@matchdate			SMALLDATETIME
	,@Fth				SMALLINT		= NULL
	,@Fta				SMALLINT		= NULL
	,@Hth				SMALLINT		= NULL
	,@Hta				SMALLINT		= NULL
	,@ResourceResult	VARCHAR(200)	= ''
	,@Action			VARCHAR(10)		= 'CAL'
	,@IP				VARCHAR(30)		= ''
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			NVARCHAR(200)	= ''	OUTPUT
AS
/*	
	Creator: 20170106@Bobby
	Task: 77721 - Implement parlay bettype for BetRadar VS
	DB: DBTXN/BODB02
	
	Revisions:
		- 20160606@Bobby: Initialize
		- 20220513@Louisa: Change write log from exec dbo.WriteLog_UserLog  to exec LogDB.dbo.Logfile_V2 [Redmine:#172708]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
		- 20230214@Aries: Use Service Broker to Write Log to DB Log [Redmine: #187252]
		- 20231016@Aries: Auto Send Announcement When Refund VS [Redmine:#195333]
		- 20241220@Louisa: Change excuter Dot_Member to svc_tig  [Redmine:#215599]
		
	Param's Explanation:
 
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @strRefnos			VARCHAR(MAX)
		, @TotalAccount			INT
		, @ActionID				INT

		, @avaiableProcess		BIT
		, @IsCentral			BIT  = 0
	
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT
		
	DECLARE @tempRefno			TABLE (refno BIGINT)
	
	
	SELECT @ErrCode				= 0
		, @ErrMsg				= ''
		, @ActionID 			= CASE @Action
									WHEN 'CAL'		THEN 187
									WHEN 'REFUND'	THEN 188
								END
	
	--PARLAY checking	
	INSERT INTO @tempRefno (refno)
	SELECT bm.refno 
	FROM dbo.bettransm bm WITH(ROWLOCK)
		OUTER APPLY (
			SELECT TOP 1 refno 
			FROM dbo.bettransm WITH(NOLOCK) 
			WHERE refno = bm.refno 
				AND statusID IN(1, 101)
		) AS chk
	WHERE matchid = @matchid
		AND EXISTS (
					SELECT 1 
					FROM dbo.f_Set_VS_BetRadar_GetBettypes() AS f
					WHERE f.bettype 	= bm.bettype
						AND f.sportType = @sportType
				)
		AND chk.refno IS NULL
		AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
		
	IF (@@ROWCOUNT = 0) RETURN
	
	--LOCKING process
	EXEC dbo.NAP_Admin_CheckingProcess
		@IsExistParlayVSBetradar	= 1
		, @avaiableProcess 			= @avaiableProcess OUTPUT
		, @ErrCode					= @ErrCode OUTPUT
		, @ErrMsg					= @ErrMsg OUTPUT
	
	IF(@ErrCode <> 0 OR @avaiableProcess = 0) RETURN
	
	SELECT @strRefnos = CAST((
				SELECT refno AS '@rn'
				FROM @tempRefno AS r
				FOR XML PATH('r'), ROOT('root'), TYPE
		) AS VARCHAR(MAX))
	
	
	IF(@Action = 'CAL')
	BEGIN
		EXEC [dbo].[NAP_Admin_Calculate_VS_BetRadar_Parlay] 
			@SportType			= @SportType
			,@MatchId			= @MatchId
			,@Fth				= @fth
			,@Fta				= @fta
			,@Hth				= @hth
			,@Hta				= @hta
			,@ResourceResult	= @ResourceResult
			,@strRefnos 		= @strRefnos
			,@matchdate			= @matchdate
			,@ErrCode			= @ErrCode OUTPUT
			,@ErrMsg			= @ErrMsg OUTPUT
	END
	ELSE IF (@Action = 'REFUND')
	BEGIN
		EXEC [dbo].[NAP_Admin_Calculate_VS_BetRadar_Parlay_Refund] 
			@MatchId			= @MatchId
			,@strRefnos 		= @strRefnos
			,@matchdate			= @matchdate
			,@ErrCode			= @ErrCode OUTPUT
			,@ErrMsg			= @ErrMsg OUTPUT
	END
	
	--CAL mains ticket with refno
	IF(@ErrCode = 0) 
	BEGIN	
		EXEC [dbo].[NAP_Admin_Calculate_VS_BetRadar_Parlay_Main]
			@MatchId			= @MatchId
			,@strRefnos 		= @strRefnos
			,@matchdate			= @matchdate
			,@ActionID			= @ActionID
			,@ErrCode			= @ErrCode OUTPUT
			,@ErrMsg			= @ErrMsg OUTPUT
	END	
	
	EXEC dbo.NAP_Admin_CheckingProcess
		@IsExistParlayVSBetradar	= 1
		,@IsReleased				= 1
END
GO