/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_VS_BetRadar_Main] 
	@Creator 		INT
	,@SportType		INT
	,@matchid 		INT
	,@mode 			VARCHAR(6) = 'CAL'
	,@CALBettypes 	VARCHAR(MAX)
	,@maxTransId	BIGINT
	,@ErrCode		INT				= 0		OUTPUT
	,@ErrMsg		NVARCHAR(200)	= ''	OUTPUT
AS
/*
	Created: 20160606@Bobby
	Task :  77720 - Implement BetRadar VS League & Nation
	DB: DBTXN/BODB02
	Revisions:
		- 20160606@Bobby: Initialize
		

	Param's Explanation:
	• @Mode:
		CAL : All single BetTypes (HT-FT)
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @fth 			INT
		, @fta 				INT
		, @hth 				INT
		, @hta 				INT
		, @xmlBettype		XML
		, @IgnoreList 		VARCHAR(200)
		, @commWinRate 		SMALLMONEY
		, @commLostRate 	SMALLMONEY
		, @fromTransId		BIGINT
		, @batchCount		INT 
	
	DECLARE @tempBettype TABLE (bettype SMALLINT, CalMode TINYINT)
	
	--SET Ignore DB-Servers
	SELECT @IgnoreList 		= 'DB04,DB042,DB043,DB044'	
			, @ErrCode 		= 0
			, @ErrMsg  		= ''
			, @fromTransId 	= 0
			, @batchCount 	= 2000
		
	--CONVERT bettype
	SET @xmlBettype = CONVERT(XML, @CALBettypes)
	
	;WITH CTE_Bettype AS (
		SELECT T.C.value('./@t', 'SMALLINT') AS bettype
		FROM @xmlBettype.nodes('/root/r') AS T(C)
	)
	INSERT INTO @tempBettype (bettype, CalMode)
	SELECT temp.bettype, f.CalMode
	FROM CTE_Bettype temp
		INNER JOIN dbo.f_Set_VS_BetRadar_GetBettypes () AS f
		ON temp.bettype = f.bettype
	OPTION (OPTIMIZE FOR (@xmlBettype = NULL ))
	
	IF (@@ROWCOUNT = 0) RETURN
	
	SELECT TOP(1)
		@fth 	= FinalHomeScore
		, @fta 	= FinalAwayScore
		, @hth 	= HTHomeScore
		, @hta 	= HTAwayScore
	FROM DBPRO.BODB02.dbo.Match WITH (NOLOCK)
	WHERE matchid = @matchid
	
	--CLone table structure
	INSERT INTO @tempBatchTicket (batchNo, fromTransId, toTransId)
	SELECT batchNo
		, MIN(transid) AS fromTransId
		, MAX(transid) AS toTransId
	FROM (
		SELECT transid
			, batchNo = (
				ROW_NUMBER() OVER (
					ORDER BY rn
					) + 1
				) / 2
		FROM (
			SELECT transid
				, rn = ROW_NUMBER() OVER (
					ORDER BY transid
					)
				, rn_rev = ROW_NUMBER() OVER (
					ORDER BY transid DESC
					)
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @tempBettype AS temp
				ON b.bettype = temp.bettype
			WHERE matchid = @matchid
				
				AND b.statusID NOT IN (101,102) --void/reject
		) x
		WHERE rn % @batchcount = 0 -- toTransId
			OR (rn - 1) % @batchcount = 0 -- fromTransId
			OR rn_rev = 1 --maxTransId
	) AS t
	GROUP BY batchNo
	ORDER BY batchNo
	
	DECLARE @batchNo INT = 1
	
	--SELECT tickets for calculating
	WHILE (EXISTS(SELECT 1 FROM @tempBatchTicket WHERE batchNo = @batchNo))
	BEGIN
		
		SELECT @fromTransId = fromTransId
			,@fromTransId 	= fromTransId
		FROM @tempBatchTicket
		WHERE batchNo = @batchNo
		
		SELECT TOP (@batchCount)
			transid, actual_stake, stake, odds, comstatus, 
			betteam, hdp1, hdp2, livehomescore, liveawayscore,
			apositiontaking, mpositiontaking, spositiontaking, 
			playerdiscount,discount, adiscount, sdiscount,
			WinLost, aWinLost, mWinLost, sWinLost, 
			PlayerComm, comm, acomm, scomm,
			StatusID, ods.modds
		INTO #TempData				
		FROM dbo.bettrans b WITH(ROWLOCK)
			INNER JOIN @tempBettype AS temp
				ON b.bettype = temp.bettype
			OUTER APPLY dbo.f_Set_VS_BetRadar_CalModds (
				b.bettype 			
				, b.betteam 			
				, b.hdp1 			
				, b.hdp2 			
				, b.livehomescore	
				, b.liveawayscore	
				, @fth				
				, @fta				
				, @hth				
				, @hta
				, temp.CalMode
			) AS ods
			
		WHERE b.matchid 	= @matchid 
			AND b.statusID 	NOT IN (101,102) --void/reject
			AND b.transid  	BETWEEN @fromTransId AND @toTransId
			
		SET @batchNo += 1
		
	END
	
	UPDATE #TempData
	SET 
		@commWinRate = CASE comstatus -- 0 : pay normal, both win/lost -- 1 : pay 'double' ONLY on lost
			WHEN '0' THEN 1
			WHEN '1' THEN 0 
			ELSE 1 END,
		@commLostRate = CASE comstatus
			WHEN '0' THEN 1
			WHEN '1' THEN 2 
			ELSE 1 END, 
		
		WinLost = CASE
				WHEN modds >  0.25	THEN actual_stake + stake * (case when odds<0 then 1 else odds end)
				WHEN modds =  0.25	THEN actual_stake + stake * (case when odds<0 then 1 else odds end) * 0.5
				WHEN modds =  0	THEN actual_stake
				WHEN modds = -0.25	THEN actual_stake * 0.5
				WHEN modds < -0.25	THEN 0
			END,

		aWinLost = CASE
				WHEN modds >  0.25	THEN stake * (case when odds<0 then 1 else odds end) * -apositiontaking
				WHEN modds =  0.25	THEN stake * (case when odds<0 then 1 else odds end) * -apositiontaking * 0.5
				WHEN modds =  0	THEN 0
				WHEN modds = -0.25	THEN actual_stake * apositiontaking * 0.5
				WHEN modds < -0.25	THEN actual_stake * apositiontaking
			END,
		mWinLost = CASE
				WHEN modds >  0.25 THEN stake * (case when odds<0 then 1 else odds end) * -mpositiontaking
				WHEN modds =  0.25 THEN stake * (case when odds<0 then 1 else odds end) * -mpositiontaking * 0.5
				WHEN modds =  0    THEN 0
				WHEN modds = -0.25 THEN actual_stake * mpositiontaking * 0.5
				WHEN modds < -0.25 THEN actual_stake * mpositiontaking
			END,
		sWinLost = CASE
				WHEN modds >  0.25 THEN stake * (case when odds<0 then 1 else odds end) * -spositiontaking
				WHEN modds =  0.25 THEN stake * (case when odds<0 then 1 else odds end) * -spositiontaking * 0.5
				WHEN modds =  0    THEN 0
				WHEN modds = -0.25 THEN actual_stake * spositiontaking * 0.5
				WHEN modds < -0.25 THEN actual_stake * spositiontaking
			END,

		PlayerComm = CASE
				WHEN modds >  0.25 THEN @commWinRate * playerdiscount * stake
				WHEN modds =  0.25 THEN @commWinRate * playerdiscount * stake * 0.5
				WHEN modds =  0    THEN 0
				WHEN modds = -0.25 THEN @commLostRate * playerdiscount * stake * 0.5
				WHEN modds < -0.25 THEN @commLostRate * playerdiscount * stake
			END,
		Comm = CASE
				WHEN modds >  0.25 THEN @commWinRate * discount * stake * (1-apositiontaking)
				WHEN modds =  0.25 THEN @commWinRate * discount * stake * (1-apositiontaking) * 0.5
				WHEN modds =  0    THEN 0
				WHEN modds = -0.25 THEN @commLostRate * discount * stake * (1-apositiontaking) * 0.5
				WHEN modds < -0.25 THEN @commLostRate * discount * stake * (1-apositiontaking)
			END,
		aComm = CASE
				WHEN modds >  0.25 THEN @commWinRate * adiscount * stake * (1-(mpositiontaking+apositiontaking))
				WHEN modds =  0.25 THEN @commWinRate * adiscount * stake * (1-(mpositiontaking+apositiontaking)) * 0.5
				WHEN modds =  0    THEN 0
				WHEN modds = -0.25 THEN @commLostRate * adiscount * stake * (1-(mpositiontaking+apositiontaking)) * 0.5
				WHEN modds < -0.25 THEN @commLostRate * adiscount * stake * (1-(mpositiontaking+apositiontaking))
			END,
		sComm = CASE
				WHEN modds >  0.25 THEN @commWinRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking))
				WHEN modds =  0.25 THEN @commWinRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking)) * 0.5
				WHEN modds =  0    THEN 0
				WHEN modds = -0.25 THEN @commLostRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking)) * 0.5
				WHEN modds < -0.25 THEN @commLostRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking))
			END,
		StatusID = CASE
			WHEN modds > 0 THEN 112 --WON
			WHEN modds = 0 THEN 111 --DRAW
			WHEN modds < 0 THEN 113 --LOSE
		END	

	--UPDATE tickets by batch
	DECLARE @_xml 		XML
		, @_sXML 		VARCHAR(MAX)
	DECLARE @subtable 	TABLE (
		transid 		BIGINT
		, winlost 		MONEY
		, awinlost 		MONEY
		, mwinlost 		MONEY
		, swinlost 		MONEY
		, playercomm 	MONEY
		, comm 			MONEY
		, acomm 		MONEY
		, scomm 		MONEY
		, statusid 		TINYINT
		, modds 		MONEY
		, custid		INT
	)
	
	BEGIN TRY	
		WHILE (1 = 1)
		BEGIN
			DELETE @subtable
			
			DELETE TOP (1000) #TempData
			OUTPUT deleted.transid, deleted.winlost, deleted.awinlost, deleted.mwinlost, deleted.swinlost, 	
				deleted.playercomm, deleted.comm, deleted.acomm, deleted.scomm, deleted.statusid, deleted.modds	
			INTO @subtable(transid, winlost, awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, statusid, modds)	
			
			IF @@ROWCOUNT = 0 BREAK
			
			SET @_xml = (
				SELECT 
					transid '@q'
					,NULLIF(winlost,0) '@a'
					,NULLIF(awinlost,0) '@z'
					,NULLIF(mwinlost,0) '@w'				
					,NULLIF(swinlost,0) '@s'
					,NULLIF(playercomm,0) '@x'
					,NULLIF(comm,0) '@e'
					,NULLIF(acomm,0) '@d'
					,NULLIF(scomm,0) '@c'	
					,statusid '@r'	
					,NULLIF(modds,0) '@f'
				FROM @subtable
				FOR XML PATH('r'), ROOT('root'), TYPE
			) 
			SELECT @_sXML = CONVERT(varchar(max), @_xml)
			
			EXEC dbo.Bet_ExecRep_05 
				@IgnoreList		= @IgnoreList
				,@updatetype	= 1
				,@_sXML			= @_sXML
									
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER()
			, @ErrMsg 	= ERROR_MESSAGE()
	END CATCH
	
	RETURN
END
GO