/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_InstantCalculate_3]
	@matchid 		INT
    ,@action		VARCHAR(10)
	,@strTransIds 	VARCHAR(MAX)
	,@strTransCashout VARCHAR(MAX) = '' OUTPUT
AS
/*    
	Creator: 20161004@Bobby
    Task: Implement Instant Calculation
    DB: DBTXN.bodb02
	Original:

    Revisions:
		- 20161222@Bobby: #67760 - Implement IS for FGLG bet types
		- 20170919@Kathy: Offer new 4 bettypes (461, 462, 463, 464) [Redmine:#83261]
		- 20181109@Helen: Wrong member balance while doing Cashout /Bettrade at the same time of Instant settle [Redmine:101652]
		- 20181129@Kathy: Do not settle ticket on DB04x [Redmine:#105327]
		- 20190225@Sol:  New Formula for Comm [Redmine:#109007]
		- 20190320@Kathy: Settlement with Tickets Exclusion [Redmine:#106823]
		- 20190409@Sol: Settlement Time [Redmine:#99638]
		- 20190715@Helen: Recover/Void tickets in Bet 14 - Update statuswinlost - [Redmine:115377]
		- 20191210@Max: Instant Settlement for Corner Bettype [Redmine:#124951]
		- 20210414@Kathy: Add New DB Server Name for AWS [Redmine:#149852]
		- 20211130@Kathy: New cashout model [Redmine:#164838]
		- 20220405@Louisa: Add New server alias ( new local test 2019) [Redmine:#171615]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]

    Param's Explanation:
        
*/
BEGIN
	SET NOCOUNT ON;

	-- CHECK SERVER BEFORE CALCULATING
	DECLARE @ServerName			SYSNAME 
			,@AllowCalculation	BIT
			,@AllowUndo			BIT
			,@transInfo			XML

	SET @ServerName = @@SERVERNAME

	IF OBJECT_ID('NAP_Set_ServerAction', 'P') IS NOT NULL
	BEGIN
		EXEC [dbo].[NAP_Set_ServerAction]
			@ServerName			= @ServerName
			,@AllowCalculation	= @AllowCalculation	OUTPUT
			,@AllowUndo			= @AllowUndo		OUTPUT

		IF @action = 'CAL-INST' AND @AllowCalculation = 0
			RETURN

		IF @action = 'UNDO-INST' AND @AllowUndo = 0
			RETURN
	END
	-- END CHECK

	DECLARE @xmlInstantTicket 	XML
		, @commWinRate 			SMALLMONEY
        , @commLostRate 		SMALLMONEY
		, @winlost MONEY
		, @stake MONEY
		, @commBettypeGroupId SMALLINT
		, @statusId TINYINT
		
	CREATE TABLE #InstantTicket_Input (transid BIGINT, modds MONEY, actual_stake MONEY, bettype SMALLINT, srecommend INT, isCN88 BIT, isMajorGroup BIT)		
	
	-- This table to store data from dbo.deleted WHEN UPDATE BETTRANS
	DECLARE @tmpTransInfo TABLE (transId BIGINT
			,modds MONEY, statuswinlost TINYINT,SettlementTime DATETIME
			,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
			,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
			,Status NVARCHAR(10),StatusID TINYINT,ruben TINYINT
			,custid INT, winlost_before MONEY, actual_stake MONEY,playercomm_before MONEY,betdaqid BIGINT
		)
	DECLARE @instantTicket_beforeUpd AS TABLE (transid BIGINT,custid INT, winlost MONEY, actual_stake MONEY,playercomm MONEY,betdaqid BIGINT)
	
	SET @xmlInstantTicket = CONVERT(XML, @strTransIds)
	
	INSERT INTO #InstantTicket_Input (transid, modds,actual_stake, bettype, srecommend)
	SELECT T.C.value('./@t', 'BIGINT') 		AS transid
			,T.C.value('./@m', 'MONEY') 	AS modds
			,T.C.value('./@a', 'MONEY') 	AS actual_stake
			,T.C.value('./@bt', 'SMALLINT') 	AS bettype
			,T.C.value('./@sr', 'INT') 	AS srecommend
	FROM @xmlInstantTicket.nodes('/b') AS T(C)
	OPTION (OPTIMIZE FOR (@xmlInstantTicket = NULL ))
	
	IF(@@ROWCOUNT = 0) RETURN
	DECLARE @settlementTime DATETIME

	--CALCULATE PROCESS
	IF (@action = 'CAL-INST')
	BEGIN

		-- update if bettype belongs to the CN88 site or not
		UPDATE tmp
			SET	isCN88 = CASE WHEN cs.CustId IS NULL THEN 0 ELSE 1 END,
				isMajorGroup = CASE WHEN f.CommBettypeGroupId IS NOT NULL AND f.CommBettypeGroupId = 1 THEN 1 ELSE 0 END
		FROM   #InstantTicket_Input tmp
					LEFT JOIN dbo.CS_CustSuper cs WITH(NOLOCK)
						ON tmp.srecommend = cs.CustId
					LEFT JOIN dbo.f_Set_GetGroupBettypes() AS f
						ON tmp.bettype = f.BetType

		IF @@SERVERNAME IN ('DBTRANS','DB230','DB206','TESTDBTRANS','SITDBTRANS', 'DBBAL', 'SITDBAWS', 'SITDBBAL')
		BEGIN
			SET @settlementTime = GETDATE();

			UPDATE b
				SET modds = t.modds 
					 ,statuswinlost = CASE WHEN t.modds > 0.25 THEN 2
											WHEN t.modds = 0.25 THEN 1 
											WHEN t.modds = 0  THEN 0 
											WHEN t.modds = - 0.25 THEN 3
											WHEN t.modds < - 0.25 THEN 4
											WHEN t.modds IS NULL THEN 6
										END 
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
					 ,@winlost = CASE
						WHEN t.modds >  0.25	THEN b.actual_stake + stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN b.bettype IN (14, 127, 189, 190, 434, 435, 461, 462, 463, 464, 475, 476, 482, 483, 484, 485, 486, 487) THEN odds - 1 ELSE odds END) END)
						WHEN t.modds =  0.25	THEN b.actual_stake + stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN b.bettype IN (14, 127, 189, 190, 434, 435, 461, 462, 463, 464, 475, 476, 482, 483, 484, 485, 486, 487) THEN odds - 1 ELSE odds END) END) * 0.5
						WHEN t.modds =  0	THEN b.actual_stake
						WHEN t.modds = -0.25	THEN b.actual_stake * 0.5
						WHEN t.modds < -0.25	THEN 0
						WHEN t.modds IS NULL then winlost
						END
					-- check if bettype belongs to major comm group (CommBettypeGroupId = 1) and calc comm with new formula
					,@stake = CASE WHEN t.isCN88 = 1 AND t.isMajorGroup = 1 THEN ABS(@winlost - b.actual_stake)
								ELSE stake 
							END
					-- check winlost or status change to update SettlementTime
					,@statusId = CASE 
									WHEN t.modds >= 0.5 THEN 112 --WON
									WHEN t.modds <= - 0.5 THEN 113 --LOSE
									WHEN t.modds IS NULL THEN b.statusID
								END
					,SettlementTime = CASE WHEN winlost <> @winlost OR statusID <> @statusId THEN @settlementTime ELSE SettlementTime END
					,WinLost = @winlost
					,aWinLost = CASE
						WHEN t.modds >  0.25	THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN b.bettype IN (14, 127, 189, 190, 434, 435, 461, 462, 463, 464, 475, 476, 482, 483, 484, 485, 486, 487) THEN odds - 1 ELSE odds END) END) * -apositiontaking
						WHEN t.modds =  0.25	THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN b.bettype IN (14, 127, 189, 190, 434, 435, 461, 462, 463, 464, 475, 476, 482, 483, 484, 485, 486, 487) THEN odds - 1 ELSE odds END) END) * -apositiontaking * 0.5
						WHEN t.modds =  0	THEN 0
						WHEN t.modds = -0.25	THEN b.actual_stake * apositiontaking * 0.5
						WHEN t.modds < -0.25	THEN b.actual_stake * apositiontaking
						WHEN t.modds IS NULL then aWinLost
					END
					,mWinLost = CASE
						WHEN t.modds >  0.25 	THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN b.bettype IN (14, 127, 189, 190, 434, 435, 461, 462, 463, 464, 475, 476, 482, 483, 484, 485, 486, 487) THEN odds - 1 ELSE odds END) END) * -mpositiontaking
						WHEN t.modds =  0.25 	THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN b.bettype IN (14, 127, 189, 190, 434, 435, 461, 462, 463, 464, 475, 476, 482, 483, 484, 485, 486, 487) THEN odds - 1 ELSE odds END) END) * -mpositiontaking * 0.5
						WHEN t.modds =  0    	THEN 0
						WHEN t.modds = -0.25 	THEN b.actual_stake * mpositiontaking * 0.5
						WHEN t.modds < -0.25 	THEN b.actual_stake * mpositiontaking
						WHEN t.modds IS NULL then mWinLost
					END
					,sWinLost = CASE
						WHEN t.modds >  0.25 	THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN b.bettype IN (14, 127, 189, 190, 434, 435, 461, 462, 463, 464, 475, 476, 482, 483, 484, 485, 486, 487) THEN odds - 1 ELSE odds END) END) * -spositiontaking
						WHEN t.modds =  0.25 	THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN b.bettype IN (14, 127, 189, 190, 434, 435, 461, 462, 463, 464, 475, 476, 482, 483, 484, 485, 486, 487) THEN odds - 1 ELSE odds END) END) * -spositiontaking * 0.5
						WHEN t.modds =  0    	THEN 0
						WHEN t.modds = -0.25 	THEN b.actual_stake * spositiontaking * 0.5
						WHEN t.modds < -0.25 	THEN b.actual_stake * spositiontaking
						WHEN t.modds IS NULL then sWinLost
					END
					,PlayerComm = CASE 
						WHEN t.modds >= 0.5 THEN @commWinRate * playerdiscount * @stake
						WHEN t.modds <= - 0.5 THEN @commLostRate * playerdiscount * @stake
						WHEN t.modds IS NULL THEN playercomm
					END
					,Comm = CASE 
						WHEN t.modds >= 0.5 THEN @commWinRate * discount * @stake * (1 - apositiontaking)
						WHEN t.modds <= - 0.5 THEN @commLostRate * discount * @stake * (1 - apositiontaking)
						WHEN t.modds IS NULL THEN comm
					END
					,aComm = CASE 
						WHEN t.modds >= 0.5 THEN @commWinRate * adiscount * @stake * (1 - (mpositiontaking + apositiontaking))
						WHEN t.modds <= - 0.5 THEN @commLostRate * adiscount * @stake * (1 - (mpositiontaking + apositiontaking))
						WHEN t.modds IS NULL THEN acomm
					END
					,sComm = CASE 
						WHEN t.modds >= 0.5 THEN @commWinRate * sdiscount * @stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
						WHEN t.modds <= - 0.5 THEN @commLostRate * sdiscount * @stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
						WHEN t.modds IS NULL THEN scomm
					END
					,STATUS = CASE 
						WHEN t.modds >= 0.5 THEN N'WON'
						WHEN t.modds <= - 0.5 THEN N'LOSE'
						WHEN t.modds IS NULL THEN status
					END
					,StatusID = @statusId
					,ruben = CASE 
						WHEN t.modds IS NULL THEN ruben
						ELSE 1
					END
			OUTPUT	inserted.transid
					,inserted.modds, inserted.statuswinlost
					,CASE WHEN inserted.SettlementTime <> deleted.SettlementTime THEN inserted.SettlementTime ELSE NULL END
					,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
					,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm
					,inserted.Status,inserted.StatusID,inserted.ruben
					,deleted.custid
					,deleted.winlost  
					,deleted.actual_stake
					,deleted.playercomm
					,deleted.betdaqid 
				INTO @tmpTransInfo (
					transId
					,modds, statuswinlost,SettlementTime,WinLost,aWinLost
					,mWinLost,sWinLost,PlayerComm,Comm,aComm,sComm,Status,StatusID,ruben
					,custid 
					,winlost_before 
					,actual_stake
					,playercomm_before
					,betdaqid 
				)
			FROM dbo.bettrans b WITH(ROWLOCK, UPDLOCK)
				INNER JOIN #InstantTicket_Input t ON b.transid = t.transid
				OUTER APPLY(
					SELECT TOP 1 mt.TransId
					FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
					WHERE	mt.TransId = t.transid
				)mt
			WHERE	mt.TransId IS NULL
					AND ISNULL(b.betdaqid,0) <> -2

			OPTION(MAXDOP 1)

			INSERT	INTO @instantTicket_beforeUpd (transid,custid, winlost, actual_stake,playercomm,betdaqid )
			SELECT transid,custid, winlost_before, actual_stake,playercomm_before,betdaqid
			FROM @tmpTransInfo
			
			IF OBJECT_ID('Service_SiteDB_CalculationLog','U') IS NOT NULL 
			BEGIN
				SET @transInfo = (
					SELECT	transId AS '@t'
							,modds AS '@m'				
							,statuswinlost AS '@statuswl' 
							,SettlementTime AS '@st' 
							,WinLost AS '@w' 
							,aWinLost AS '@aw' 
							,mWinLost AS '@mw' 
							,sWinLost AS '@sw' 
							,PlayerComm AS '@pc' 
							,Comm AS '@c' 
							,aComm AS '@ac' 
							,sComm AS '@sc' 
							,Status AS '@s' 
							,StatusID AS '@sid' 
							,ruben AS '@r'				
					FROM	@tmpTransInfo
					FOR XML PATH('r'),ROOT('root'), TYPE
				)

				INSERT INTO dbo.Service_SiteDB_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo)
				VALUES ('Settlement', 'CalculateOtherSport', 'bettrans', @MatchId, @transInfo)		
			END
			-- Process for cashout tickets make change Balance before
			SET @strTransCashout = ISNULL(CAST((SELECT t,c,b,s
												FROM
												(SELECT b.transid AS t
														, b.custid AS c
														, b.winlost-b.actual_stake + b.playercomm as b
														, 1  AS 's'
												FROM @instantTicket_beforeUpd b
													INNER JOIN #InstantTicket_Input t ON b.transid = t.transid
												WHERE 	b.betdaqid = 0 AND b.actual_stake <> t.actual_stake
												UNION ALL
												SELECT  t.transid AS t
														,0 AS c
														,0 AS b
														,0 AS 's'
												FROM 	#InstantTicket_Input t
													LEFT JOIN @instantTicket_beforeUpd b 
														ON t.transid = b.transid
												WHERE b.transid IS NULL
											)b
												FOR XML AUTO) AS VARCHAR(MAX)
										),'')
				
		END
		ELSE
		BEGIN
			SET @settlementTime = GETDATE();

			UPDATE b
				SET modds = t.modds 
					 ,statuswinlost = CASE WHEN t.modds > 0.25 THEN 2
											WHEN t.modds = 0.25 THEN 1 
											WHEN t.modds = 0  THEN 0 
											WHEN t.modds = - 0.25 THEN 3
											WHEN t.modds < - 0.25 THEN 4
											WHEN t.modds IS NULL THEN 6
										END 
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
					 ,@winlost = CASE
						WHEN t.modds >  0.25	THEN b.actual_stake + stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN b.bettype IN (14, 127, 189, 190, 434, 435, 461, 462, 463, 464, 475, 476, 482, 483, 484, 485, 486, 487) THEN odds - 1 ELSE odds END) END)
						WHEN t.modds =  0.25	THEN b.actual_stake + stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN b.bettype IN (14, 127, 189, 190, 434, 435, 461, 462, 463, 464, 475, 476, 482, 483, 484, 485, 486, 487) THEN odds - 1 ELSE odds END) END) * 0.5
						WHEN t.modds =  0	THEN b.actual_stake
						WHEN t.modds = -0.25	THEN b.actual_stake * 0.5
						WHEN t.modds < -0.25	THEN 0
						WHEN t.modds IS NULL then winlost
					END 
					-- check if bettype belongs to major comm group (CommBettypeGroupId = 1) and calc comm with new formula
					,@stake = CASE WHEN t.isCN88 = 1 AND t.isMajorGroup = 1 THEN ABS(@winlost - b.actual_stake)
								ELSE stake 
							END
					-- check winlost or status change to update SettlementTime
					,@statusId = CASE 
									WHEN t.modds >= 0.5 THEN 112 --WON
									WHEN t.modds <= - 0.5 THEN 113 --LOSE
									WHEN t.modds IS NULL THEN b.statusID
								END
					,SettlementTime = CASE WHEN winlost <> @winlost OR statusID <> @statusId THEN @settlementTime ELSE SettlementTime END
					,WinLost = @winlost
					,aWinLost = CASE
						WHEN t.modds >  0.25	THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN b.bettype IN (14, 127, 189, 190, 434, 435, 461, 462, 463, 464, 475, 476, 482, 483, 484, 485, 486, 487) THEN odds - 1 ELSE odds END) END) * -apositiontaking
						WHEN t.modds =  0.25	THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN b.bettype IN (14, 127, 189, 190, 434, 435, 461, 462, 463, 464, 475, 476, 482, 483, 484, 485, 486, 487) THEN odds - 1 ELSE odds END) END) * -apositiontaking * 0.5
						WHEN t.modds =  0	THEN 0
						WHEN t.modds = -0.25	THEN b.actual_stake * apositiontaking * 0.5
						WHEN t.modds < -0.25	THEN b.actual_stake * apositiontaking
						WHEN t.modds IS NULL then aWinLost
					END
					,mWinLost = CASE
						WHEN t.modds >  0.25 	THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN b.bettype IN (14, 127, 189, 190, 434, 435, 461, 462, 463, 464, 475, 476, 482, 483, 484, 485, 486, 487) THEN odds - 1 ELSE odds END) END) * -mpositiontaking
						WHEN t.modds =  0.25 	THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN b.bettype IN (14, 127, 189, 190, 434, 435, 461, 462, 463, 464, 475, 476, 482, 483, 484, 485, 486, 487) THEN odds - 1 ELSE odds END) END) * -mpositiontaking * 0.5
						WHEN t.modds =  0    	THEN 0
						WHEN t.modds = -0.25 	THEN b.actual_stake * mpositiontaking * 0.5
						WHEN t.modds < -0.25 	THEN b.actual_stake * mpositiontaking
						WHEN t.modds IS NULL then mWinLost
					END
					,sWinLost = CASE
						WHEN t.modds >  0.25 	THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN b.bettype IN (14, 127, 189, 190, 434, 435, 461, 462, 463, 464, 475, 476, 482, 483, 484, 485, 486, 487) THEN odds - 1 ELSE odds END) END) * -spositiontaking
						WHEN t.modds =  0.25 	THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN b.bettype IN (14, 127, 189, 190, 434, 435, 461, 462, 463, 464, 475, 476, 482, 483, 484, 485, 486, 487) THEN odds - 1 ELSE odds END) END) * -spositiontaking * 0.5
						WHEN t.modds =  0    	THEN 0
						WHEN t.modds = -0.25 	THEN b.actual_stake * spositiontaking * 0.5
						WHEN t.modds < -0.25 	THEN b.actual_stake * spositiontaking
						WHEN t.modds IS NULL then sWinLost
					END
					,PlayerComm = CASE 
						WHEN t.modds >= 0.5 THEN @commWinRate * playerdiscount * @stake
						WHEN t.modds <= - 0.5 THEN @commLostRate * playerdiscount * @stake
						WHEN t.modds IS NULL THEN playercomm
					END
					,Comm = CASE 
						WHEN t.modds >= 0.5 THEN @commWinRate * discount * @stake * (1 - apositiontaking)
						WHEN t.modds <= - 0.5 THEN @commLostRate * discount * @stake * (1 - apositiontaking)
						WHEN t.modds IS NULL THEN comm
					END
					,aComm = CASE 
						WHEN t.modds >= 0.5 THEN @commWinRate * adiscount * @stake * (1 - (mpositiontaking + apositiontaking))
						WHEN t.modds <= - 0.5 THEN @commLostRate * adiscount * @stake * (1 - (mpositiontaking + apositiontaking))
						WHEN t.modds IS NULL THEN acomm
					END
					,sComm = CASE 
						WHEN t.modds >= 0.5 THEN @commWinRate * sdiscount * @stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
						WHEN t.modds <= - 0.5 THEN @commLostRate * sdiscount * @stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
						WHEN t.modds IS NULL THEN scomm
					END
					,STATUS = CASE 
						WHEN t.modds >= 0.5 THEN N'WON'
						WHEN t.modds <= - 0.5 THEN N'LOSE'
						WHEN t.modds IS NULL THEN status
					END
					,StatusID = @statusId
					,ruben = CASE 
						WHEN t.modds IS NULL THEN ruben
						ELSE 1
					END
				OUTPUT	inserted.transid
						,inserted.modds, inserted.statuswinlost
						,CASE WHEN inserted.SettlementTime <> deleted.SettlementTime THEN inserted.SettlementTime ELSE NULL END
						,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
						,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm
						,inserted.Status,inserted.StatusID,inserted.ruben		
					INTO @tmpTransInfo (
						transId
						,modds, statuswinlost,SettlementTime,WinLost,aWinLost
						,mWinLost,sWinLost,PlayerComm,Comm,aComm,sComm,Status,StatusID,ruben
					)	
				FROM dbo.bettrans b WITH(ROWLOCK, UPDLOCK)
					INNER JOIN #InstantTicket_Input t
						ON	b.transid = t.transid
					OUTER APPLY(
						SELECT TOP 1 mt.TransId
						FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
						WHERE	mt.TransId = t.transid
				)mt
			WHERE	mt.TransId IS NULL
					AND ISNULL(b.betdaqid,0) <> -2

				OPTION(MAXDOP 1)

			IF OBJECT_ID('Service_SiteDB_CalculationLog','U') IS NOT NULL 
			BEGIN
				SET @transInfo = (
					SELECT	transId AS '@t'
							,modds AS '@m'				
							,statuswinlost AS '@statuswl' 
							,SettlementTime AS '@st' 
							,WinLost AS '@w' 
							,aWinLost AS '@aw' 
							,mWinLost AS '@mw' 
							,sWinLost AS '@sw' 
							,PlayerComm AS '@pc' 
							,Comm AS '@c' 
							,aComm AS '@ac' 
							,sComm AS '@sc' 
							,Status AS '@s' 
							,StatusID AS '@sid' 
							,ruben AS '@r'				
					FROM	@tmpTransInfo
					FOR XML PATH('r'),ROOT('root'), TYPE
				)

				INSERT INTO dbo.Service_SiteDB_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo)
				VALUES ('Settlement', 'CalculateOtherSport', 'bettrans', @MatchId, @transInfo)		
			END	
		END
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
			,statuswinlost = NULL
		OUTPUT	inserted.transid
				,inserted.statuswinlost
				,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
				,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm
				,inserted.Status,inserted.StatusID		
			INTO @tmpTransInfo (
				transId
				,statuswinlost,WinLost,aWinLost
				,mWinLost,sWinLost,PlayerComm,Comm,aComm,sComm,Status,StatusID
			)
		FROM dbo.bettrans b WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #InstantTicket_Input t
			ON b.transid = t.transid
			
		OPTION(MAXDOP 1)

		IF OBJECT_ID('Service_SiteDB_CalculationLog','U') IS NOT NULL 
		BEGIN
			SET @transInfo = (
				SELECT	transId AS '@t'
						,statuswinlost AS '@statuswl' 
						,WinLost AS '@w' 
						,aWinLost AS '@aw' 
						,mWinLost AS '@mw' 
						,sWinLost AS '@sw' 
						,PlayerComm AS '@pc' 
						,Comm AS '@c' 
						,aComm AS '@ac' 
						,sComm AS '@sc' 
						,Status AS '@s' 
						,StatusID AS '@sid'				
				FROM	@tmpTransInfo
				FOR XML PATH('r'),ROOT('root'), TYPE
			)

			INSERT INTO dbo.Service_SiteDB_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo)
			VALUES ('Settlement', 'CalculateOtherSport', 'bettrans', @MatchId, @transInfo)		
		END	
	END
	
	DROP TABLE #InstantTicket_Input;
	
	RETURN;
	
END
GO