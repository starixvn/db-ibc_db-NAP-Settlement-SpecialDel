/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_PreCalculate_24]
	@matchid int,
	@bettype smallint,
	@scorediff smallmoney,
	@IsCentral	BIT = 0
AS
/*
	Created by: Kathy
	Date: 20140213
	Task: Settlement 
	DB: DBTRANS.BODB02
	Original: Admin_PreCalculate_24

	Revisions:
		- 20140514@Kathy: insert settled command into LAS queue [Redmine:#14286]	
		- 20151210@Patrick: Database - Change datatype [Redmine: #48660]
		- 20220711@Kathy: Do not use SELECT INTO [Redmine:#175276]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
		- 20230908@Louisa: Apply Company Max Payout for Non-sports [Redmine:#193259]
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @IgnoreList varchar(200)
			,@SiteDBGroupId SMALLINT
			,@modds money, @commWinRate smallmoney, @commLostRate smallmoney 
			,@createdDate DATETIME
			,@TotalTransMaxPO		INT = 0
			,@batchPO				SMALLINT = 500
			,@TransInfoMaxPO		VARCHAR(MAX)
			,@transMPO				VARCHAR(MAX)
			,@sporttype				TINYINT
	
	DECLARE @tmpTransMPO TABLE (TransID BIGINT,custid INT, actualPO MONEY, winlost MONEY,transdate DATETIME, bettype SMALLINT)
	DECLARE @tmpTransMPOBatch TABLE (TransID BIGINT,custid INT, actualPO MONEY, winlost MONEY,transdate DATETIME, bettype SMALLINT)
	DECLARE @tmpMaxWinLimit	TABLE( CustId INT, MaxWinLimit MONEY)

	SET @IgnoreList = 'DB04,DB042,DB043,DB044'

	SELECT @SiteDBGroupId = (SELECT dbo.f_Get_SiteDBGroupID())
	SELECT @sporttype = m.sporttype FROM match m WITH(NOLOCK) WHERE m.matchid = @matchid

	------------------
	CREATE TABLE #TempData (transid BIGINT, actual_stake MONEY, stake MONEY, odds MONEY, comstatus NVARCHAR(20), modds MONEY,
			betteam NVARCHAR(10), hdp1 SMALLMONEY, hdp2 SMALLMONEY, livehomescore SMALLINT, liveawayscore SMALLINT,
			apositiontaking SMALLMONEY, mpositiontaking SMALLMONEY, spositiontaking SMALLMONEY, 
			playerdiscount DECIMAL(9,8),discount DECIMAL(9,8), adiscount DECIMAL(9,8), sdiscount DECIMAL(9,8),
			WinLost MONEY, aWinLost MONEY, mWinLost MONEY, sWinLost MONEY, 
			PlayerComm MONEY, comm MONEY, acomm MONEY, scomm MONEY,
			StatusID TINYINT, bettype SMALLINT,
			custid INT, currency TINYINT, transdate DATETIME, actualPO MONEY, IsApplyMaxPO BIT)

	INSERT INTO #TempData(transid, actual_stake, stake, odds, comstatus, modds,
			betteam, hdp1, hdp2, livehomescore, liveawayscore,
			apositiontaking, mpositiontaking, spositiontaking, 
			playerdiscount,discount, adiscount, sdiscount,
			WinLost, aWinLost, mWinLost, sWinLost, 
			PlayerComm, comm, acomm, scomm,
			StatusID, bettype, custid, currency, transdate)
	SELECT	transid, actual_stake, stake, odds, comstatus, modds,
			betteam, hdp1, hdp2, livehomescore, liveawayscore,
			apositiontaking, mpositiontaking, spositiontaking, 
			playerdiscount,discount, adiscount, sdiscount,
			WinLost, aWinLost, mWinLost, sWinLost, 
			PlayerComm, comm, acomm, scomm,
			StatusID, bettype, custid, currency, transdate			
	FROM dbo.bettrans with(rowlock)
	WHERE matchid = @matchid 
		AND bettype = @bettype 
		AND statusID NOT IN (101,102) --void/reject
		AND SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE SiteDBGroupID END
		
	IF @@ROWCOUNT = 0 RETURN
	-----------------		
	
	UPDATE #TempData
	SET @modds = CASE
		WHEN betteam = '1X' AND @scorediff >= 0 THEN 1
		WHEN betteam = '2X' AND @scorediff <= 0 THEN 1
		WHEN betteam = '12' AND @scorediff <> 0 THEN 1
		ELSE -1
		END,
		modds = @modds,
		@commWinRate = CASE comstatus -- 0 : pay normal, both win/lost -- 1 : pay 'double' ONLY on lost
		WHEN '0' THEN 1
		WHEN '1' THEN 0 
		ELSE 1 END,
		@commLostRate = CASE comstatus
		WHEN '0' THEN 1
		WHEN '1' THEN 2 
		ELSE 1 END,--'s','m'
		
	WinLost = CASE
		WHEN @modds >  0.25	THEN actual_stake + stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,13,15,16,24,25,26,27,28,1224) then odds-1 else odds end) end)
		WHEN @modds =  0.25	THEN actual_stake + stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,13,15,16,24,25,26,27,28,1224) then odds-1 else odds end) end) * 0.5
		WHEN @modds =  0	THEN actual_stake
		WHEN @modds = -0.25	THEN actual_stake * 0.5
		WHEN @modds < -0.25	THEN 0
		END,

	aWinLost = CASE
		WHEN @modds >  0.25	THEN stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,13,15,16,24,25,26,27,28,1224) then odds-1 else odds end) end) * -apositiontaking
		WHEN @modds =  0.25	THEN stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,13,15,16,24,25,26,27,28,1224) then odds-1 else odds end) end) * -apositiontaking * 0.5
		WHEN @modds =  0	THEN 0
		WHEN @modds = -0.25	THEN actual_stake * apositiontaking * 0.5
		WHEN @modds < -0.25	THEN actual_stake * apositiontaking
		END,
	mWinLost = CASE
		WHEN @modds >  0.25 	THEN stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,13,15,16,24,25,26,27,28,1224) then odds-1 else odds end) end) * -mpositiontaking
		WHEN @modds =  0.25 	THEN stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,13,15,16,24,25,26,27,28,1224) then odds-1 else odds end) end) * -mpositiontaking * 0.5
		WHEN @modds =  0    	THEN 0
		WHEN @modds = -0.25 	THEN actual_stake * mpositiontaking * 0.5
		WHEN @modds < -0.25 	THEN actual_stake * mpositiontaking
		END,
	sWinLost = CASE
		WHEN @modds >  0.25 	THEN stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,13,15,16,24,25,26,27,28,1224) then odds-1 else odds end) end) * -spositiontaking
		WHEN @modds =  0.25 	THEN stake * (case when odds<0 then 1 else (case when bettype in (4,5,6,13,15,16,24,25,26,27,28,1224) then odds-1 else odds end) end) * -spositiontaking * 0.5
		WHEN @modds =  0    	THEN 0
		WHEN @modds = -0.25 	THEN actual_stake * spositiontaking * 0.5
		WHEN @modds < -0.25 	THEN actual_stake * spositiontaking
		END,

	PlayerComm = CASE
		WHEN @modds >  0.25 	THEN @commWinRate * playerdiscount * stake
		WHEN @modds =  0.25 	THEN @commWinRate * playerdiscount * stake * 0.5
		WHEN @modds =  0    	THEN 0
		WHEN @modds = -0.25 	THEN @commLostRate * playerdiscount * stake * 0.5
		WHEN @modds < -0.25 	THEN @commLostRate * playerdiscount * stake
		END,
	Comm = CASE
		WHEN @modds >  0.25 	THEN @commWinRate * discount * stake * (1-apositiontaking)
		WHEN @modds =  0.25 	THEN @commWinRate * discount * stake * (1-apositiontaking) * 0.5
		WHEN @modds =  0    	THEN 0
		WHEN @modds = -0.25 	THEN @commLostRate * discount * stake * (1-apositiontaking) * 0.5
		WHEN @modds < -0.25 	THEN @commLostRate * discount * stake * (1-apositiontaking)
		END,
	aComm = CASE
		WHEN @modds >  0.25 	THEN @commWinRate * adiscount * stake * (1-(mpositiontaking+apositiontaking))
		WHEN @modds =  0.25 	THEN @commWinRate * adiscount * stake * (1-(mpositiontaking+apositiontaking)) * 0.5
		WHEN @modds =  0    	THEN 0
		WHEN @modds = -0.25 	THEN @commLostRate * adiscount * stake * (1-(mpositiontaking+apositiontaking)) * 0.5
		WHEN @modds < -0.25 	THEN @commLostRate * adiscount * stake * (1-(mpositiontaking+apositiontaking))
		END,
	sComm = CASE
		WHEN @modds >  0.25 	THEN @commWinRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking))
		WHEN @modds =  0.25 	THEN @commWinRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking)) * 0.5
		WHEN @modds =  0    	THEN 0
		WHEN @modds = -0.25 	THEN @commLostRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking)) * 0.5
		WHEN @modds < -0.25 	THEN @commLostRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking))
		END,
	StatusID = CASE
		WHEN @modds > 0 THEN 112 --WON
		WHEN @modds = 0 THEN 111 --DRAW
		WHEN @modds < 0 THEN 113 --LOSE
		END
		
	IF EXISTS (SELECT TOP 1 1 FROM dbo.f_NAP_Site_MaxPayoutSetting() WHERE SiteDBGroupId = @SiteDBGroupId)
	BEGIN
		;WITH cteCustIds
		AS(
			SELECT DISTINCT custid, currency
			FROM	#TempData t
			WHERE	modds >= 0.25
		)
		INSERT INTO @tmpMaxWinLimit (CustId, MaxWinLimit)
		SELECT	t.custid, fc.MaxWinLimit
		FROM	CustDB.dbo.Customer c WITH(NOLOCK)
			INNER JOIN cteCustIds t
				ON t.custid = c.custid
			INNER JOIN CustDB.dbo.Site s WITH(NOLOCK)
				ON s.site = c.site
			INNER JOIN dbo.f_NAP_Site_MaxPayoutSetting() fs
				ON s.siteid = fs.siteid
			INNER JOIN dbo.f_NAP_Currency_MaxPayoutSetting() fc
				ON	t.currency = fc.ExchangeId
					AND fc.SiteDBGroupId = @SiteDBGroupId

		IF @@ROWCOUNT > 0
		BEGIN
			UPDATE t 
				SET IsApplyMaxPO = 1
					,actualPO = WinLost
					,winlost = m.MaxWinLimit
					,aWinLost = CASE WHEN t.modds >= 0.25 THEN (m.MaxWinLimit - t.actual_stake) * - apositiontaking
									   ELSE 0
								  END
					,mWinLost = CASE WHEN t.modds >= 0.25 THEN (m.MaxWinLimit - t.actual_stake) * - mpositiontaking
									   ELSE 0
								  END
					,sWinLost = CASE WHEN t.modds >= 0.25 THEN (m.MaxWinLimit - t.actual_stake) * - spositiontaking
									   ELSE 0
								  END
			OUTPUT  deleted.transid, deleted.custid, deleted.winlost, inserted.winlost, deleted.transdate, deleted.bettype
			INTO @tmpTransMPO(TransID,custid, actualPO, winlost, transdate, bettype)
			FROM	#TempData t
				INNER JOIN	@tmpMaxWinLimit m
					ON t.CustId = m.CustId
			WHERE	t.WinLost > m.MaxWinLimit

			SET @TotalTransMaxPO = @@ROWCOUNT
		END
	END
	
	DECLARE @_xml XML, @_sXML varchar(MAX)
	DECLARE @subtable TABLE(transid bigint, winlost money, awinlost money, mwinlost money, swinlost money,
		playercomm money, comm money, acomm money, scomm money, statusid tinyint, modds money, actualPO MONEY, IsApplyMaxPO BIT)
				
	WHILE (1 = 1)
	BEGIN
		DELETE @subtable
		
		DELETE TOP (20) #TempData
		OUTPUT deleted.transid, deleted.winlost, deleted.awinlost, deleted.mwinlost, deleted.swinlost, 	
			deleted.playercomm, deleted.comm, deleted.acomm, deleted.scomm, deleted.statusid, deleted.modds, deleted.actualPO ,deleted.IsApplyMaxPO		
		INTO @subtable(transid, winlost, awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, statusid, modds, actualPO, IsApplyMaxPO)	
		
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
				,NULLIF(actualPO,0) '@apo'
				,NULLIF(IsApplyMaxPO,0) '@iMPO'
			FROM @subtable
			FOR XML PATH('r'), ROOT('root'), TYPE
		) 
		SELECT @_sXML = CONVERT(varchar(max), @_xml)
		
		EXEC dbo.Bet_ExecRep_05 
			@IgnoreList = @IgnoreList
			,@updatetype = 1
			,@_sXML = @_sXML
			,@Action = 'CAL'
			,@matchid = @matchid	 				
	END	
	
	-- notify
	WHILE (@TotalTransMaxPO > 0)
	BEGIN
			DELETE @tmpTransMPOBatch

			DELETE TOP (@batchPO) t
			OUTPUT deleted.custid, deleted.winlost, deleted.actualPO, deleted.transdate, deleted.bettype, deleted.transid 
			INTO @tmpTransMPOBatch(custid, winlost, actualPO, transdate, bettype, transid)
			FROM @tmpTransMPO t

			SET @TransInfoMaxPO = CAST((
									SELECT	TOP (@batchPO) CustId AS a1
											,@sporttype AS a2 -- productid
											,0 AS a3 -- groupid
											,winlost AS a4 -- maxwinlimit
											,actualPO AS a6 -- winamt
											,255 AS a7 -- levelid
											,255 AS a8 -- actionid
											,NULL AS a12 -- createdby
											,transdate AS a13 -- winlostdate
											,bettype AS a16
											,transid AS a17
									FROM	@tmpTransMPOBatch
									FOR XML PATH('r'), ROOT('root')
							) AS VARCHAR(MAX))

		SET @TotalTransMaxPO = @TotalTransMaxPO - @batchPO

		EXEC DBCUST.CustDB.dbo.Task_Winlimit_InsertHistoryData
			@XmlData = @TransInfoMaxPO
	END
END