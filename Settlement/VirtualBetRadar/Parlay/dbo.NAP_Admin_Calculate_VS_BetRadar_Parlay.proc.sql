/*<info serverAlias="DBTXN-bodb02" executers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_VS_BetRadar_Parlay] 
	@SportType			INT				= 0
	,@MatchId			INT				= 0
	,@TicketInfos 		VARCHAR(MAX)	= NULL
	,@mode 				VARCHAR(10)		= 'CAL'
	,@Fth				SMALLINT		= 0
	,@Fta				SMALLINT		= 0
	,@Hth				SMALLINT		= 0
	,@Hta				SMALLINT		= 0
	,@strRefnos			VARCHAR(MAX)	= ''
	,@matchdate			SMALLDATETIME	= NULL
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			NVARCHAR(200)	= ''	OUTPUT
AS
/*	Creator: 20170106@Bobby
	Task: 77720 - Implement BetRadar VS League & Nation for Parlay
	DB: DBTXN/BODB02
	
	Revisions:
		- 20160606@Bobby: Initialize
		- 20170607@Kent: Integrate Betradar Virtual Sports [Redmine:#77177]
		- 20170829@Kathy: Change datatype of bettransm.TransId, sporttype [Redmine:#73545]
		- 20180207@Helen: Betradar VS 2 - basketball [Redmine:#90154] 
		- 20181212@Alan: Integrate Betradar VS phase 3 [106158]
		- 20200324@Helen: Betradar VS 4 -  [Redmine:#130984] 
		- 20200409@Helen: Virtual Soccer Euro Cup  -  [Redmine:#132048]  
		
	Param's Explanation:
		• @Mode:
			CAL : Settle sub parlay ticket by match
			RECOVER : Re-settle sub parlay ticket by list ticket
		• @TicketInfos : 
			meaning : single transids (bettrans.transid)	
			format xml : <root><r m="1234" t="2333" /></root>
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @xmlRefno	 	XML
		  , @xmlTicket		XML
	DECLARE @IgnoreList 	VARCHAR(200)
	DECLARE @tempRefno 		TABLE (refno BIGINT)
	DECLARE @ResourceResult	VARCHAR(200) = ''
	
	CREATE TABLE #tblTicketInfos (matchid int, transid BIGINT)
	
	CREATE TABLE #tblMatchResult
	(
		matchid 		INT 
		, fth 			INT
		, fta 			INT 
		, hth 			INT 
		, hta 			INT
		, sporttype 	SMALLINT
		, matchdate 	SMALLDATETIME
		, ResourceResult VARCHAR(MAX)
	)
	
	CREATE TABLE #TempData (
		transid			BIGINT
		, statuswinlost	TINYINT
		, statusID		TINYINT
		, matchdate		SMALLDATETIME
	)							
	
	SELECT @ErrCode				= 0
		, @ErrMsg				= ''
		, @IgnoreList 			= 'DB04,DB042,DB043,DB044'
	
	IF @SportType = 193
	BEGIN
		SELECT	 @ResourceResult = @ResourceResult + RIGHT(ResourceID,2) + Custom1 + ',' 
		FROM	DBPRO.bodb02.dbo.ResultDetail3rd WITH (NOLOCK)
		WHERE	MatchID = @MatchID 
			AND SettlementStatusID = 4
			AND ResourceID LIKE '2809__'
		OPTION (maxrecursion 0)
	END		
	
	IF @mode = 'CAL'
	BEGIN
		--CONVERT refno
		SET @xmlRefno = CONVERT(XML, @strRefnos)
	
		INSERT INTO @tempRefno (refno)
		SELECT T.C.value('./@rn', 'BIGINT') AS refno
		FROM @xmlRefno.nodes('/root/r') AS T(C)
		OPTION (OPTIMIZE FOR (@xmlRefno = NULL ))

		IF @@ROWCOUNT = 0 RETURN

		IF @SportType = 193 -- BASKETBALL
		BEGIN
			--SELECT perlay tickets
			INSERT INTO #TempData(transid, statuswinlost, statusID, matchdate)
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
				, @matchdate							
			FROM dbo.bettransm bm WITH(ROWLOCK)
				INNER JOIN @tempRefno temp 
					ON bm.refno = temp.refno
				INNER JOIN dbo.f_Set_VS_BetRadar_GetBettypes() AS f
					ON bm.bettype = f.bettype
				OUTER APPLY [dbo].[f_Set_VS_BetRadar_CalModds_193] (
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
					, bm.betcheck
					, @ResourceResult
				) AS ods
			WHERE bm.matchid = @MatchId
			  AND f.SportType = @SportType
			  AND bm.statusID NOT IN (101,102) --void/reject
		  
		   IF @@ROWCOUNT = 0 RETURN	
			
		END
		ELSE -- SOCCER
		BEGIN
			--SELECT perlay tickets
			INSERT INTO #TempData(transid, statuswinlost, statusID, matchdate)
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
				, @matchdate							
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
					, bm.transdesc
				) AS ods
			WHERE bm.matchid = @MatchId
			  AND f.SportType = @SportType
			  AND bm.statusID NOT IN (101,102) --void/reject
			
			IF @@ROWCOUNT = 0 RETURN	  
		END  
			
	END	
	ELSE IF @Mode = 'RECOVER'
	BEGIN
		--CONVERT Ticket
		SET @xmlTicket = CONVERT(XML, @TicketInfos)
	
		INSERT INTO #tblTicketInfos(matchid, transid)
		SELECT T.C.value('./@m', 'INT') as matchid
			 , T.C.value('./@t', 'BIGINT') as transid					
		FROM @xmlTicket.nodes('/root/r') as [T](C) --T: table, C: column
		OPTION (OPTIMIZE FOR (@xmlTicket = NULL ))

		IF @@ROWCOUNT = 0 RETURN
		-- build match list
		INSERT INTO #tblMatchResult(matchid, fth, fta, hth, hta, sporttype, matchdate,ResourceResult)
		SELECT matchid
			, FinalHomeScore
			, FinalAwayScore
			, HTHomeScore
			, HTAwayScore
			, sporttype
			, eventdate
			, STUFF(Result.ResouceResult,1,1,'') AS ResouceResult
		FROM DBPRO.BODB02.dbo.Match m WITH (NOLOCK)
			OUTER APPLY (SELECT  ',' + RIGHT(ResourceID,2) + Custom1 
							FROM	DBPRO.bodb02.dbo.ResultDetail3rd m1 WITH (NOLOCK)
							WHERE	m1.MatchID = m.matchid 
									AND m1.SettlementStatusID = 4
									AND m1.ResourceId LIKE '2809__'
									AND m.sporttype = 193
							FOR XML PATH ('')		
							) AS Result (ResouceResult)
							
		WHERE matchid IN (SELECT DISTINCT matchid FROM #tblTicketInfos)
			

		IF @@ROWCOUNT = 0 RETURN

		--SELECT perlay tickets
		INSERT INTO #TempData(transid, statuswinlost, statusID, matchdate)
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
			, mr.matchdate							
		FROM dbo.bettransm bm WITH(ROWLOCK)
			INNER JOIN #tblTicketInfos temp 
				ON bm.transid = temp.transid
			INNER JOIN #tblMatchResult mr 
				ON bm.matchid = mr.matchid
			INNER JOIN dbo.f_Set_VS_BetRadar_GetBettypes() AS f
				ON bm.bettype = f.bettype
				   AND mr.sporttype = f.SportType
			OUTER APPLY [dbo].[f_Set_VS_BetRadar_CalModds] (
				bm.bettype 			
				, bm.betteam 			
				, bm.hdp1 			
				, bm.hdp2 			
				, bm.livehomescore	
				, bm.liveawayscore	
				, mr.fth				
				, mr.fta				
				, mr.hth				
				, mr.hta
				, f.CalMode
				, bm.transdesc
			) AS ods
		WHERE bm.statusID NOT IN (101,102) --void/reject	
			AND mr.sporttype IN (190,191,192,194,195,196,197)
			
		IF EXISTS (SELECT 1 FROM #tblMatchResult WHERE sporttype = 193 )
		BEGIN
			--SELECT perlay tickets
			INSERT INTO #TempData(transid, statuswinlost, statusID, matchdate)
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
				, mr.matchdate							
			FROM dbo.bettransm bm WITH(ROWLOCK)
				INNER JOIN #tblTicketInfos temp 
					ON bm.transid = temp.transid
				INNER JOIN #tblMatchResult mr 
					ON bm.matchid = mr.matchid
				INNER JOIN dbo.f_Set_VS_BetRadar_GetBettypes() AS f
					ON bm.bettype = f.bettype
					   AND mr.sporttype = f.SportType
				OUTER APPLY [dbo].[f_Set_VS_BetRadar_CalModds_193] (
					bm.bettype 			
					, bm.betteam 			
					, bm.hdp1 			
					, bm.hdp2 			
					, bm.livehomescore	
					, bm.liveawayscore	
					, mr.fth				
					, mr.fta				
					, mr.hth				
					, mr.hta
					, f.CalMode
					, bm.betcheck
					, mr.ResourceResult
				) AS ods
			WHERE bm.statusID NOT IN (101,102) --void/reject	
				AND mr.sporttype = 193
		END
		
		IF NOT EXISTS (SELECT TOP 1 1 FROM #TempData)
			RETURN
	END
	ELSE
		RETURN
		
	DECLARE @_xml XML, @_sXML varchar(MAX)
	DECLARE @subtable TABLE(
		transid 		BIGINT
		,statuswinlost 	TINYINT
		,statusID 		TINYINT
		,matchdate		SMALLDATETIME
	)
	
	BEGIN TRY
		WHILE (1 = 1)
		BEGIN
			DELETE @subtable
			
			DELETE TOP (1000) #TempData
			OUTPUT deleted.transid, deleted.statuswinlost, deleted.statusID, deleted.matchdate
			INTO @subtable(transid, statuswinlost, statusID, matchdate)	
			
			IF @@ROWCOUNT = 0 BREAK
			
			SET @_xml = (
				SELECT 
					transid '@t'
					,matchdate '@d'
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
				,@Action		= 'CAL'
									
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER()
			, @ErrMsg 	= ERROR_MESSAGE()
	END CATCH
	RETURN
END
GO