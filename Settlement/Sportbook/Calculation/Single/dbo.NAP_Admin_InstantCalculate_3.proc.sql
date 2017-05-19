/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
USE bodb02
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_Admin_InstantCalculate_3]
	@matchid 		INT
    ,@action		VARCHAR(10)
	,@strTransIds 	VARCHAR(MAX)
AS
/*    
	Creator: 20161004@Bobby
    Task: Implement Instant Calculation
    DB: DBTXN.bodb02
	Original:

    Revisions:
		20161222@Bobby: #67760 - Implement IS for FGLG bet types
		
    Param's Explanation:
        
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @xmlInstantTicket 	XML
		, @commWinRate 			SMALLMONEY
        , @commLostRate 		SMALLMONEY
		
	CREATE TABLE #instantTicket (transid BIGINT, modds MONEY)		
	
	SET @xmlInstantTicket = CONVERT(XML, @strTransIds)
	
	INSERT INTO #instantTicket (transid, modds)
	SELECT T.C.value('./@t', 'BIGINT') 		AS transid
			,T.C.value('./@m', 'MONEY') 	AS modds
	FROM @xmlInstantTicket.nodes('/b') AS T(C)
	OPTION (OPTIMIZE FOR (@xmlInstantTicket = NULL ))
	
	IF(@@ROWCOUNT = 0) RETURN
	
	--CALCULATE PROCESS
	IF (@action = 'CAL-INST')
	BEGIN
		UPDATE b
			SET modds = t.modds 
			 ,@commWinRate = CASE comstatus -- 0 : pay normal, both win/lost -- 1 : pay 'double' ONLY on lost
				 WHEN '0' THEN 1
				 WHEN '1' THEN 0
				 ELSE 1
				 END
			 ,@commLostRate = CASE comstatus
				 WHEN '0' THEN 1
				 WHEN '1' THEN 2
				 ELSE 1
				 END
			 ,WinLost = CASE
				WHEN t.modds >  0.25	THEN actual_stake + stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (14, 127, 189, 190, 434, 435) THEN odds - 1 ELSE odds END) END)
				WHEN t.modds =  0.25	THEN actual_stake + stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (14, 127, 189, 190, 434, 435) THEN odds - 1 ELSE odds END) END) * 0.5
				WHEN t.modds =  0	THEN actual_stake
				WHEN t.modds = -0.25	THEN actual_stake * 0.5
				WHEN t.modds < -0.25	THEN 0
				WHEN t.modds IS NULL then winlost
			END
			,aWinLost = CASE
				WHEN t.modds >  0.25	THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (14, 127, 189, 190, 434, 435) THEN odds - 1 ELSE odds END) END) * -apositiontaking
				WHEN t.modds =  0.25	THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (14, 127, 189, 190, 434, 435) THEN odds - 1 ELSE odds END) END) * -apositiontaking * 0.5
				WHEN t.modds =  0	THEN 0
				WHEN t.modds = -0.25	THEN actual_stake * apositiontaking * 0.5
				WHEN t.modds < -0.25	THEN actual_stake * apositiontaking
				WHEN t.modds IS NULL then aWinLost
			END
			,mWinLost = CASE
				WHEN t.modds >  0.25 	THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (14, 127, 189, 190, 434, 435) THEN odds - 1 ELSE odds END) END) * -mpositiontaking
				WHEN t.modds =  0.25 	THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (14, 127, 189, 190, 434, 435) THEN odds - 1 ELSE odds END) END) * -mpositiontaking * 0.5
				WHEN t.modds =  0    	THEN 0
				WHEN t.modds = -0.25 	THEN actual_stake * mpositiontaking * 0.5
				WHEN t.modds < -0.25 	THEN actual_stake * mpositiontaking
				WHEN t.modds IS NULL then mWinLost
			END
			,sWinLost = CASE
				WHEN t.modds >  0.25 	THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (14, 127, 189, 190, 434, 435) THEN odds - 1 ELSE odds END) END) * -spositiontaking
				WHEN t.modds =  0.25 	THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (14, 127, 189, 190, 434, 435) THEN odds - 1 ELSE odds END) END) * -spositiontaking * 0.5
				WHEN t.modds =  0    	THEN 0
				WHEN t.modds = -0.25 	THEN actual_stake * spositiontaking * 0.5
				WHEN t.modds < -0.25 	THEN actual_stake * spositiontaking
				WHEN t.modds IS NULL then sWinLost
			END
			,PlayerComm = CASE 
				WHEN t.modds >= 0.5 THEN @commWinRate * playerdiscount * stake
				WHEN t.modds <= - 0.5 THEN @commLostRate * playerdiscount * stake
				WHEN t.modds IS NULL THEN playercomm
			END
			,Comm = CASE 
				WHEN t.modds >= 0.5 THEN @commWinRate * discount * stake * (1 - apositiontaking)
				WHEN t.modds <= - 0.5 THEN @commLostRate * discount * stake * (1 - apositiontaking)
				WHEN t.modds IS NULL THEN comm
			END
			,aComm = CASE 
				WHEN t.modds >= 0.5 THEN @commWinRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking))
				WHEN t.modds <= - 0.5 THEN @commLostRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking))
				WHEN t.modds IS NULL THEN acomm
			END
			,sComm = CASE 
				WHEN t.modds >= 0.5 THEN @commWinRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
				WHEN t.modds <= - 0.5 THEN @commLostRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
				WHEN t.modds IS NULL THEN scomm
			END
			,STATUS = CASE 
				WHEN t.modds >= 0.5 THEN N'WON'
				WHEN t.modds <= - 0.5 THEN N'LOSE'
				WHEN t.modds IS NULL THEN status
			END
			,StatusID = CASE 
				WHEN t.modds >= 0.5 THEN 112 --WON
				WHEN t.modds <= - 0.5 THEN 113 --LOSE
				WHEN t.modds IS NULL THEN b.statusID
			END
			,ruben = CASE 
				WHEN t.modds IS NULL THEN ruben
				ELSE 1
			END
		
		FROM dbo.bettrans b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #instantTicket t
			ON b.transid = t.transid
			
		OPTION(MAXDOP 1)
	END
	
	--UNDO Process
	IF(@action = 'UNDO-INST')
	BEGIN
		UPDATE b
		SET ruben 		= 0
			,STATUS 	= 'running'
			,statusID 	= 0
			,winlost 	= 0
			,awinlost 	= 0
			,mwinlost 	= 0
			,swinlost 	= 0
			,playercomm = 0
			,comm 		= 0
			,acomm 		= 0
			,scomm 		= 0
		FROM dbo.bettrans b WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #instantTicket t
			ON b.transid = t.transid
			
		OPTION(MAXDOP 1)
	END
	
	DROP TABLE #instantTicket;
	RETURN;
	
END
