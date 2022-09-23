/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Parlay_Calculate_9001] (
	@matchId 			INT
	, @matchdate		SMALLDATETIME
	, @Mode 			VARCHAR(20)
	, @sportType		SMALLINT
	, @resultDetail		VARCHAR(MAX) = NULL
	, @IsCentral		BIT = 0
	, @ErrCode 			INT = 0 OUTPUT
	, @ErrMsg 			NVARCHAR(200) = '' OUTPUT
	, @ticketCount		INT OUTPUT
)
AS
/*	Created by: 20180801@Vicky
    Task: Incorporate eSports 2.0  
    DB: DBTRANS.BODB02

	Revisions:		
			- 20180801@Vicky: Incorporate eSports 2.0 [Redmine #95874]
			- 20190715@Helen: Recover/Void tickets in Bet 14 - Update statuswinlost for VOID Tickets [Redmine:115377]
			- 20190924@Sol: Incorporate BMAIO - modified sp to support new bettype [Redmine:#120324]
			- 20191112@Sol: Incorporate PHAIO 5 [Redmine:#121681]
			- 20200210@Sol: Settlement with Ticket Exclusion for Other Sports - Tennis - [Redmine:#129316]
			- 20200701@Kathy: Incorporate New Bet Types of Basketball - Phase 2 [Redmine:#135846]
			- 20200721@Kathy: Add more param for function f_Set_Calculate_modds [Redmine:#135846]
			- 20211022@Kathy: Support Settlement Exclusion for Parlay Sub Tickets [Redmine:#163172]
			- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]

	Param's Explanation:		
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @strTransIds VARCHAR(MAX),@resultDetail_All VARCHAR(MAX),@handle INT
	DECLARE @tmpResultDetail TABLE (ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50))
	CREATE TABLE #bettypeCAL (bettype SMALLINT PRIMARY KEY, groupId SMALLINT, groupName NVARCHAR(50), isEarly BIT)
	
	SELECT @ticketCount		= 0
		
	--Start process
	DECLARE 
		@fromTransId		INT
		,@batchNo			INT
		,@batchCount		INT
		,@strTicket			VARCHAR(MAX)
		,@ResourcesStr		VARCHAR(MAX) = ''
		,@TotalPointHomeValue VARCHAR(50) = NULL
		,@TotalPointAwayValue VARCHAR(50) = NULL
		,@homeRound			TINYINT
		,@awayRound			TINYINT
		,@IsExistDetermined BIT = 0

		,@DummyResourceIds VARCHAR(MAX) = ''
		,@DummyResourceResults VARCHAR(MAX) = ''
	
	DECLARE @tempRefno TABLE (transid BIGINT, refno BIGINT, statusId TINYINT, modds SMALLMONEY, IsRefundGame BIT, isMarked BIT)
	DECLARE @tempBatch TABLE (transid BIGINT, refno BIGINT, statusId TINYINT, modds SMALLMONEY, IsRefundGame BIT, isMarked BIT)
	DECLARE @tempResultDetail TABLE (ResourceID VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50), Bettype SMALLINT, Betid NVARCHAR(50), pfID SMALLINT, ssID TINYINT, IsDetermined BIT)
	DECLARE @tempSelectedResource TABLE (ResourceID VARCHAR(20))
	DECLARE @tempResource TABLE (ResourceID VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50), ssID TINYINT)
	
	
	--get resultDetail
	IF @resultDetail IS NULL --resourceid
	BEGIN
		INSERT INTO @tempResource (ResourceID, HomeValue, AwayValue, ssId)
		EXEC dbo.NAP_Admin_Settlement_2
             @mode = 'all_profile'
            ,@matchid = @matchid
            ,@sportType = @sportType
            ,@str_resultDetail = @resultDetail_All OUTPUT	
	END 
	ELSE
	BEGIN
		EXEC sp_xml_preparedocument @handle OUTPUT, @resultDetail
	    INSERT INTO @tempSelectedResource(ResourceID)
	    SELECT Id
	    FROM OPENXML(@handle,'Resources/Resource',1) WITH (Id VARCHAR(20)) AS tbl
	    EXEC sp_xml_removedocument @handle
	    
	    SELECT @ResourcesStr   = @ResourcesStr   + ',' + ResourceID
	  	FROM @tempSelectedResource sr
	
	  	
	  	SELECT @ResourcesStr   = CASE WHEN @ResourcesStr = ''   THEN NULL ELSE @ResourcesStr   + ',' END
	  	
	  	INSERT INTO @tempResource (ResourceID, HomeValue, AwayValue, ssId)
	  	EXEC dbo.NAP_Admin_Settlement_2
             @mode = 'resourceid_profile'
            ,@matchid = @matchid
            ,@resourceid = @ResourcesStr
            ,@sportType = @sportType
            ,@str_resultDetail = @resultDetail_All OUTPUT	
	END 
	
	IF (@sportType = 9) AND Exists (SELECT 1 FROM @tempResource WHERE ResourceID = '00')
	BEGIN 
		IF @Mode = 'CAL' 
		BEGIN
			
			INSERT INTO @tempResource (ResourceID, HomeValue, AwayValue, ssId)
			SELECT '70400' AS ResourceID, CAST(SUM(CAST(HomeValue AS INT)) AS VARCHAR(50)) AS HomeValue, CAST(SUM(CAST(AwayValue AS INT)) AS VARCHAR(50)) AS AwayValue, MAX(ssID) AS ssID
			FROM @tempResource
			WHERE ResourceID IN ('0101','0102','0103','0104','0105') 
				AND ssID = 4

			--Get total home value/total away value of ResourceId = '70400' 
			SELECT TOP 1 @TotalPointHomeValue = HomeValue, @TotalPointAwayValue = AwayValue
			FROM @tempResource
			WHERE ResourceID = '70400'

		END
		ELSE
		BEGIN
			INSERT INTO @tempResource (ResourceID, HomeValue, AwayValue, ssId)
			SELECT '70400' AS ResourceID, '' AS HomeValue, '' AS AwayValue, ssId
			FROM @tempResource
			WHERE ResourceID = '00'
			
		END
	END
	-- Tennis
	ELSE IF (@sportType = 5) AND Exists (SELECT 1 FROM @tempResource WHERE ResourceID = '00')
	BEGIN
		SELECT  @TotalPointHomeValue = CAST(SUM(CAST(HomeValue AS INT)) AS VARCHAR(50)), 
				@TotalPointAwayValue = CAST(SUM(CAST(AwayValue AS INT)) AS VARCHAR(50))
		FROM @tempResource
		WHERE ResourceID IN ('01','02','03','04','05')
				AND ssID = 4
	END
	
	-- insert dummy resourceid
	SELECT	@DummyResourceIds = @DummyResourceIds + s.ResourceID + ','
	FROM	dbo.SettlementSpecialBettypeProfile s WITH(NOLOCK)
		INNER JOIN @tempResource t
			ON s.RefResourceId = t.ResourceID
	WHERE	s.SportType = @sportType
			AND s.RefResourceId IS NOT NULL

	EXEC dbo.NAP_Set_DummyResourceResult
		@matchId = @matchId
		,@sportType = @sportType
		,@DummyResourceIds = @DummyResourceIds
		,@DummyResourceResults = @DummyResourceResults OUTPUT

	EXEC sp_xml_preparedocument @handle OUTPUT, @DummyResourceResults
	INSERT INTO @tempResource (ResourceID, HomeValue, AwayValue, ssID)
	SELECT Id, Home, Away, ssID
	FROM OPENXML(@handle,'root/r',1) WITH( Id	VARCHAR(20)
											,Home VARCHAR(50)
											,Away VARCHAR(50)
											,ssId TINYINT
										) AS tbl
	EXEC sp_xml_removedocument @handle
	
	INSERT INTO @tempResultDetail(ResourceID, HomeValue, AwayValue, ssID, Bettype, Betid, pfID, IsDetermined)
    SELECT rs.ResourceID, 
			CASE WHEN sf.BetType = 153 THEN @TotalPointHomeValue ELSE rs.HomeValue END AS HomeValue, 
			CASE WHEN sf.BetType = 153 THEN @TotalPointAwayValue ELSE rs.AwayValue END AS AwayValue, 
			rs.ssID, sf.Bettype, CAST(sf.Betid AS NVARCHAR(50)) AS Betid, sf.pfID, 
			CASE WHEN @Mode = 'REFUND' AND ssID = 7 THEN 1 ELSE 0 END AS IsDetermined
    FROM @tempResource rs
	    INNER JOIN SettlementSpecialBettypeProfile sf WITH (NOLOCK) ON sf.ResourceID = rs.ResourceID
	WHERE sf.sporttype = @sporttype
		AND 1 = CASE WHEN @Mode = 'CAL' 	AND ssID = 4 THEN 1
					 WHEN @Mode = 'REFUND' 	AND ssID IN (1, 7) THEN 1 -- ssid = 7 -> early refund with determined
					 WHEN @Mode = 'UNDO' 	AND ssID = 0 THEN 1
					 ELSE 0 END
	
	IF (@Mode = 'REFUND' AND EXISTS (SELECT TOP 1 1 FROM @tempResultDetail WHERE IsDetermined = 1))
	BEGIN
		SET @IsExistDetermined = 1
	END

	--get transid
	IF @Mode = 'CAL'
	BEGIN
	
		--Bettype 2,3: using match score or total point, badminton only
		UPDATE t
			SET HomeValue = CASE WHEN ISNULL(@TotalPointHomeValue, '') <> '' THEN @TotalPointHomeValue ELSE HomeValue END,
				AwayValue = CASE WHEN ISNULL(@TotalPointAwayValue, '') <> '' THEN @TotalPointAwayValue ELSE AwayValue END
		FROM @tempResultDetail t
		WHERE t.BetType IN (2, 3) AND t.ResourceID = '00' AND @sportType IN (5, 9)

		INSERT INTO @tempRefno (refno, transid, modds)
		SELECT bm.refno, bm.transid, m.modds
		FROM dbo.bettransm bm WITH (NOLOCK)
			INNER JOIN @tempResultDetail rs ON rs.Bettype = bm.Bettype AND (rs.Betid = '0' OR rs.Betid = bm.betcheck)
			CROSS APPLY dbo.f_Set_Calculate_modds(rs.pfID, bm.betteam, bm.hdp1, bm.hdp2, rs.HomeValue, rs.AwayValue, bm.livehomescore, bm.liveawayscore, bm.transdesc, NULL) m
		WHERE bm.matchid = @matchid
			AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
			AND bm.statusID NOT IN (101)
	END
	ELSE IF @Mode = 'REFUND' AND @IsExistDetermined = 0
	BEGIN
	
		INSERT INTO @tempRefno (refno, transid, modds)
		SELECT bm.refno, bm.transid, 0
		FROM dbo.bettransm bm WITH (NOLOCK)
			INNER JOIN @tempResultDetail rs ON rs.Bettype = bm.Bettype AND (rs.Betid = '0' OR rs.Betid = bm.betcheck)
		WHERE bm.matchid = @matchid
			AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
			AND statusID NOT IN (103, 101)
	END
	ELSE IF @Mode = 'REFUND' AND @IsExistDetermined = 1
	BEGIN
	
		SELECT 
			@homeRound = ISNULL(RIGHT(MAX(CASE WHEN ResourceID LIKE '3820[12345]' THEN ResourceID END),1),0), 
			@awayRound = ISNULL(RIGHT(MAX(CASE WHEN ResourceID LIKE '3810[12345]' THEN ResourceID END),1),0) 
		FROM DBPRO.BODB02.dbo.ResultDetail WITH(NOLOCK)
		WHERE MatchID = @MatchID 
				AND ResourceID LIKE '38[12]0[12345]'
				AND SettlementStatusID = 4
				AND ResultStatusID = 5
		
		INSERT INTO @tempRefno (refno, transid, modds)
		SELECT bm.refno, bm.transid, m.modds
		FROM dbo.bettransm bm WITH (NOLOCK)
			INNER JOIN @tempResultDetail rs ON rs.Bettype = bm.Bettype AND (rs.Betid = '0' OR rs.Betid = bm.betcheck)
			CROSS APPLY dbo.f_Set_SDT_CalModds_Early(rs.pfID, bm.betteam, bm.hdp1, bm.hdp2, rs.HomeValue, rs.AwayValue, bm.livehomescore, bm.liveawayscore, @homeRound, @awayRound) m
		WHERE bm.matchid = @matchid
			AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
			AND bm.statusID NOT IN (101)
			AND rs.IsDetermined = 1

		INSERT INTO @tempRefno (refno, transid, modds)
		SELECT bm.refno, bm.transid, NULL
		FROM dbo.bettransm bm WITH (NOLOCK)
			INNER JOIN @tempResultDetail rs ON rs.Bettype = bm.Bettype AND (rs.Betid = '0' OR rs.Betid = bm.betcheck)
		WHERE bm.matchid = @matchid
			AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
			AND statusID NOT IN (103, 101)
			AND rs.IsDetermined = 0

	END
	ELSE IF @Mode = 'UNDO'
	BEGIN
	
		INSERT INTO @tempRefno (refno, transid, modds)
		SELECT bm.refno, bm.transid, 0
		FROM dbo.bettransm bm WITH (NOLOCK)
			INNER JOIN @tempResultDetail rs ON rs.Bettype = bm.Bettype AND (rs.Betid = '0' OR rs.Betid = bm.betcheck)
		WHERE bm.matchid = @matchid
			AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
			AND statusID NOT IN (101, 1, 0)
	END
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.MarkedTransaction mt WITH(NOLOCK) WHERE MatchId = @matchId)
	BEGIN
		;WITH cteMarkedTrans
		AS(
			SELECT	b.refno
			FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
				INNER JOIN dbo.bettrans b WITH(NOLOCK)
					ON mt.TransId = b.transid
			WHERE	mt.MatchId = @matchid
					AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
					AND b.matchid = 29
		)
		UPDATE r 
			SET ismarked = 1
		FROM	@tempRefno r
			INNER JOIN cteMarkedTrans c
				ON r.refno = c.refno
	END

	SELECT @batchNo			= 2000
		, @batchCount		= 0
		, @fromTransId		= 0
		
	WHILE (1 = 1)
	BEGIN
		
		DELETE @tempBatch
		
		DELETE TOP(@batchNo) t
		OUTPUT DELETED.refno, DELETED.transid, DELETED.modds, DELETED.isMarked
		INTO @tempBatch(refno, transid, modds, isMarked)
		FROM @tempRefno t	

		SELECT @batchCount 	= @@ROWCOUNT
			, @ticketCount	+= @batchCount

		IF @batchCount = 0 BREAK
		
		IF (@IsExistDetermined = 1)
		BEGIN
			SET @strTransIds = CAST(
        				(
        					SELECT * 
        					FROM ( 
								 SELECT transid  AS t
									  ,refno	AS r
	                                  ,modds    AS m
	                                  ,'0'      AS i
									  ,isMarked AS im
	                             FROM @tempBatch
								 WHERE modds IS NOT NULL
	                        )AS b FOR XML AUTO
	                     ) AS VARCHAR(MAX))
                           			
			IF(@strTransIds IS NOT NULL)
			BEGIN
				EXEC dbo.[NAP_Admin_Calculate_MP_broker] 
					@matchid 		= @matchid
					,@matchdate		= @matchdate
					,@mode 			= 'CAL'
					,@strTransIds	= @strTransIds
			END

			-- refund after cal
			SET @strTransIds = CAST(
        				(
        					SELECT * 
        					FROM ( 
								 SELECT transid  AS t
									  ,refno	AS r
	                                  ,'0'    AS m
	                                  ,'0'      AS i
									  ,isMarked AS im
	                             FROM @tempBatch
								 WHERE modds IS NULL
	                        )AS b FOR XML AUTO
	                     ) AS VARCHAR(MAX))
                           			
			IF(@strTransIds IS NOT NULL)
			BEGIN
				EXEC dbo.[NAP_Admin_Calculate_MP_broker] 
					@matchid 		= @matchid
					,@matchdate		= @matchdate
					,@mode 			= 'REFUND'
					,@strTransIds	= @strTransIds
			END
		END
		ELSE 
		BEGIN
			SET @strTransIds = CAST(
        					(
        						SELECT * 
        						FROM ( 
									 SELECT transid  AS t
										  ,refno	AS r
										  ,modds    AS m
										  ,'0'      AS i
										  ,isMarked AS im
									 FROM @tempBatch
								)AS b FOR XML AUTO
							 ) AS VARCHAR(MAX))
                           			
			IF(@strTransIds IS NOT NULL)
			BEGIN
				EXEC dbo.[NAP_Admin_Calculate_MP_broker] 
					@matchid 		= @matchid
					,@matchdate		= @matchdate
					,@mode 			= @Mode
					,@strTransIds	= @strTransIds
			END
		END
	END
	
	DROP TABLE #bettypeCAL
	RETURN
END
GO


