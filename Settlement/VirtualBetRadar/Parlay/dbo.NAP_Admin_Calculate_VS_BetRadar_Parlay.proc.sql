/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_VS_BetRadar_Parlay] 
	@SportType			INT
	,@MatchId			INT
	,@Fth				SMALLINT
	,@Fta				SMALLINT
	,@Hth				SMALLINT
	,@Hta				SMALLINT
	,@strRefnos			VARCHAR(MAX)
	,@matchdate			SMALLDATETIME
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			NVARCHAR(200)	= ''	OUTPUT
AS
/*	Creator: 20170106@Bobby
	Task: 77720 - Implement BetRadar VS League & Nation for Parlay
	DB: DBTXN/BODB02
	
	Revisions:
		- 20160606@Bobby: Initialize
		
	Param's Explanation:
 
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @xmlRefno	 	XML
	DECLARE @IgnoreList 	VARCHAR(200)
	DECLARE @tempRefno 		TABLE (refno BIGINT)
	
	--CONVERT refno
	SET @xmlRefno = CONVERT(XML, @strRefnos)
	
	INSERT INTO @tempRefno (refno)
	SELECT T.C.value('./@rn', 'BIGINT') AS refno
	FROM @xmlRefno.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@xmlRefno = NULL ))
	
	IF (@@ROWCOUNT = 0) RETURN
	
	SELECT @ErrCode				= 0
		, @ErrMsg				= ''
		, @IgnoreList 			= 'DB04,DB042,DB043,DB044'
	
	--SELECT perlay tickets
	SELECT bm.transid
		, CASE 
				WHEN ods.modds > 0.25 THEN 2 -- WON
				WHEN ods.modds = 0.25 THEN 1 -- Half WON
				WHEN ods.modds = 0 THEN 0 -- DRAW
				WHEN ods.modds = -0.25 THEN 3 -- Half LOSE
				WHEN ods.modds < -0.25 THEN 4 -- LOSE
				ELSE bm.statuswinlost
			END AS statuswinlost
		, CASE 
				WHEN ods.modds = 0 THEN 111 --DRAW
				WHEN ods.modds > 0 THEN 112 --WON
				WHEN ods.modds < 0 THEN 113 --LOSE
				ELSE bm.statusID
			END AS statusID
		
	INTO #TempData				
	FROM dbo.bettransm bm WITH(ROWLOCK)
		INNER JOIN @tempRefno temp 
			ON bm.refno = temp.refno
		INNER JOIN dbo.f_Set_VS_BetRadar_GetBettypes() AS f
			ON bm.bettype = f.bettype
		OUTER APPLY [dbo].[f_Set_VS_BetRadar_CalModds] (
			bm.bettype 			
			, bm.betteam 			
			, bm.hdp1 			
			, bm.hdp2 			
			, bm.livehomescore	
			, bm.liveawayscore	
			, @fth				
			, @fta				
			, @hth				
			, @hta
			, f.CalMode
		) AS ods
	WHERE bm.matchid = @matchid 
		AND f.sportType = @sportType
		AND bm.statusID NOT IN (101,102) --void/reject

	IF @@ROWCOUNT = 0 RETURN	
		
	DECLARE @_xml XML, @_sXML varchar(MAX)
	DECLARE @subtable TABLE(
		transid 		INT
		,statuswinlost 	TINYINT
		,statusID 		TINYINT
	)
		
	WHILE (1 = 1)
	BEGIN
		DELETE @subtable
		
		DELETE TOP (1000) #TempData
		OUTPUT deleted.transid, deleted.statuswinlost, deleted.statusID
		INTO @subtable(transid, statuswinlost, statusID)	
		
		IF @@ROWCOUNT = 0 BREAK
		
		SET @_xml = (
			SELECT 
				transid '@t'
				,@matchdate '@d'
				,statuswinlost '@w'
				,statusID '@s'				
			FROM @subtable
			FOR XML PATH('r'), ROOT('root'), TYPE
		) 
		SELECT @_sXML = CONVERT(VARCHAR(MAX), @_xml)
		
		EXEC dbo.Bet_ExecRep_05 
			@IgnoreList 	= @IgnoreList
			, @updatetype 	= 5
			, @_sXML 		= @_sXML
			 					
	END
	RETURN
END
GO