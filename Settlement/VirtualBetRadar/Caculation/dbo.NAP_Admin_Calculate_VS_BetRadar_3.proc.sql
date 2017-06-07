/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Admin_Calculate_VS_BetRadar_3]
	@matchid 		INT
	,@bettype 		SMALLINT
	,@totalgoal 	SMALLMONEY
AS
/*
	Created: 20160606@Bobby
	Task :  77720 - Implement BetRadar VS League & Nation
	DB: DBTXN/BODB02
	Revisions:
		- 20160606@Bobby: Initialize
		

	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @IgnoreList varchar(200)
	SET @IgnoreList = 'DB04,DB042,DB043,DB044'	
	
	Declare @modds money, @commWinRate smallmoney, @commLostRate smallmoney
		--,@LASCommand NVARCHAR(max)
		,@createdDate DATETIME--, @Remark varchar(500)

	SELECT	transid, actual_stake, stake, odds, comstatus, modds,
			betteam, hdp1, hdp2, livehomescore, liveawayscore,
			apositiontaking, mpositiontaking, spositiontaking, 
			playerdiscount,discount, adiscount, sdiscount,
			WinLost, aWinLost, mWinLost, sWinLost, 
			PlayerComm, comm, acomm, scomm,
			StatusID, bettype
	INTO #TempData				
	FROM dbo.bettrans with(rowlock)
	WHERE matchid = @matchid 
		AND bettype = @bettype 
		AND statusID NOT IN (101,102) --void/reject
	
	IF @@ROWCOUNT = 0 RETURN	
			
	UPDATE #TempData
	SET @modds = CASE betteam
		WHEN N'h' THEN @totalgoal-hdp1
		WHEN N'a' THEN hdp1-@totalgoal
		END,
		modds = @modds,
		@commWinRate = CASE comstatus -- 0 : pay normal, both win/lost -- 1 : pay 'double' ONLY on lost
		WHEN '0' THEN 1
		WHEN '1' THEN 0
		ELSE 1 END,
		@commLostRate = CASE comstatus
		WHEN '0' THEN 1
		WHEN '1' THEN 2
		ELSE 1 END,
		
	WinLost = CASE
		WHEN @modds >  0.25	THEN actual_stake + stake * (case when odds<0 then 1 else odds end)
		WHEN @modds =  0.25	THEN actual_stake + stake * (case when odds<0 then 1 else odds end) * 0.5
		WHEN @modds =  0	THEN actual_stake
		WHEN @modds = -0.25	THEN actual_stake * 0.5
		WHEN @modds < -0.25	THEN 0
		END,

	aWinLost = CASE
		WHEN @modds >  0.25	THEN stake * (case when odds<0 then 1 else odds end) * -apositiontaking
		WHEN @modds =  0.25	THEN stake * (case when odds<0 then 1 else odds end) * -apositiontaking * 0.5
		WHEN @modds =  0	THEN 0
		WHEN @modds = -0.25	THEN actual_stake * apositiontaking * 0.5
		WHEN @modds < -0.25	THEN actual_stake * apositiontaking
		END,
	mWinLost = CASE
		WHEN @modds >  0.25 	THEN stake * (case when odds<0 then 1 else odds end) * -mpositiontaking
		WHEN @modds =  0.25 	THEN stake * (case when odds<0 then 1 else odds end) * -mpositiontaking * 0.5
		WHEN @modds =  0    	THEN 0
		WHEN @modds = -0.25 	THEN actual_stake * mpositiontaking * 0.5
		WHEN @modds < -0.25 	THEN actual_stake * mpositiontaking
		END,
	sWinLost = CASE
		WHEN @modds >  0.25 	THEN stake * (case when odds<0 then 1 else odds end) * -spositiontaking
		WHEN @modds =  0.25 	THEN stake * (case when odds<0 then 1 else odds end) * -spositiontaking * 0.5
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
	
	DECLARE @_xml XML, @_sXML varchar(MAX)
	DECLARE @subtable TABLE(transid bigint, winlost money, awinlost money, mwinlost money, swinlost money,
		playercomm money, comm money, acomm money, scomm money, statusid tinyint, modds money)
		
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
		
		EXEC dbo.Bet_ExecRep_05 @IgnoreList, 1, @_sXML						
	END
END
GO