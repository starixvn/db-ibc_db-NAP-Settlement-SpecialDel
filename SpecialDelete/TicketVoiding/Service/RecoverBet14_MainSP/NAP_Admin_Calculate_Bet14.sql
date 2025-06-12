/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_Bet14] (
	@transIds VARCHAR(MAX)
	,@MatchId	INT = 0
)
AS
/*
	Created by: 20190715@Helen
	Task: Settlement  
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
	
	Revisions:
		- 20190715@Helen: Recover/Void tickets in Bet 14 - [Redmine:115377]
		- 20210304@Louisa: Cricket AIO [Redmine:#148870]
		- 20210922@Louisa: Remove @CutOffDate [Redmine:#159903]
		- 20240718@Max: [TVS] Integrate Virtual Sports 5 (Virtually Sports) [Redmine: #207545]
		- 20250516@July: Recover 14 - Insert changed data into BalanceTrigger table [Redmine: #227625]
		- 20250612@July: Add new column refno [Redmine: #226514]

	Param's Explanation:  
		   
*/
BEGIN
	
	SET NOCOUNT ON

	-----------------------CHECK SERVER-----------------------------------------
	DECLARE @ServerName			SYSNAME 
			,@AllowCalculation	BIT

	SET @ServerName = @@SERVERNAME

	IF OBJECT_ID('NAP_Set_ServerAction', 'P') IS NOT NULL
	BEGIN
		EXEC [dbo].[NAP_Set_ServerAction]
			@ServerName			= @ServerName
			,@AllowCalculation	= @AllowCalculation	OUTPUT

		IF @AllowCalculation = 0
			RETURN

	END
	-----------------------CHECK SERVER-----------------------------------------
	DECLARE @xml XML
		,@IsSiteDB			BIT 
		,@transInfo			VARBINARY(MAX)
		,@transInfo3rd		VARBINARY(MAX)
		,@IsInsertTrigger	BIT = 0

	IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL 
		SET @IsSiteDB = 1

	IF (OBJECT_ID('BalanceTrigger','U') IS NOT NULL AND @@SERVERNAME IN ('TESTDB053','SITDB05','SITDB05BK1','DB05','DB05BK1'))
		OR @IsSiteDB = 1
	BEGIN
		SET @IsInsertTrigger = 1
	END

	DECLARE @tbl_transIDs AS TABLE (
		transid				BIGINT
		,sporttype			SMALLINT
		,IsCashOut			BIT
		,zzzwinlost			MONEY
		--,modds              SMALLMONEY
		--,Stake				MONEY
		,status				NVARCHAR(10)
		,creator			INT	
	)

	SET @xml = CONVERT(XML, @transIds)
	INSERT INTO @tbl_transIDs (TransId, sporttype, IsCashOut, zzzwinlost/*, modds, Stake*/, status, creator)
	SELECT DISTINCT t.c.value('@transid','BIGINT') AS TransId
				   ,t.c.value('@sporttype','SMALLINT') AS sporttype
				   ,t.c.value('@IsCashOut','BIT') AS IsCashOut
				   ,t.c.value('@zzzwinlost','MONEY') AS zzzwinlost
				  -- ,t.c.value('@modds','SMALLMONEY') AS modds
				   --,t.c.value('@Stake','MONEY') AS Stake
				   ,t.c.value('@status','NVARCHAR(10)') AS status
				   ,t.c.value('@creator','INT') AS creator
	FROM @xml.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@xml = NULL ))
	
	DECLARE @tempTrans TABLE (TransID BIGINT, isDecimalOdd BIT, srecommend INT, bettype SMALLINT, isCN88 BIT, isMajorGroup BIT)
	DECLARE  @commWinRate		SMALLMONEY
			,@commLostRate		SMALLMONEY
			,@commHalfWLRate	SMALLMONEY
			,@odds				SMALLMONEY
			,@winlost			MONEY
			,@stake				MONEY
			,@statusId			TINYINT
			
	CREATE TABLE #BeforeTransId14(
	   matchid INT ,transid BIGINT PRIMARY KEY,betdaqid BIGINT ,sitedbgroupid SMALLINT
      ,bettype SMALLINT ,statusID TINYINT ,Status NVARCHAR(10)
	  ,winlostdate SMALLDATETIME ,SettlementTime DATETIME ,actual_stake MONEY ,modds SMALLMONEY
	  ,srecommend INT ,mrecommend INT,recommend INT ,custid INT	
	  ,winlost MONEY ,awinLost MONEY ,mwinLost MONEY ,swinLost MONEY
	  ,playercomm MONEY ,comm MONEY ,acomm MONEY ,scomm MONEY, refno BIGINT
	)
			
	CREATE TABLE #AfterTransId14(
	    matchid INT ,transid BIGINT PRIMARY KEY,betdaqid BIGINT ,sitedbgroupid SMALLINT
      ,bettype SMALLINT ,statusID TINYINT ,Status NVARCHAR(10)
	  ,winlostdate SMALLDATETIME ,SettlementTime DATETIME ,actual_stake MONEY ,modds SMALLMONEY
	  ,srecommend INT ,mrecommend INT,recommend INT ,custid INT	
	  ,winlost MONEY ,awinLost MONEY ,mwinLost MONEY ,swinLost MONEY
	  ,playercomm MONEY ,comm MONEY ,acomm MONEY ,scomm MONEY, ruben TINYINT, creator INT, ExtraInfo VARCHAR(1000), refno BIGINT
	)
	
	DECLARE @settlementTime DATETIME
	---parse XML
	INSERT INTO @tempTrans(TransID, isDecimalOdd, srecommend, bettype)
	SELECT t.TransID
	, CASE	WHEN (ot.oddstype = 1 OR b14.bettype = 38) THEN 1 
			ELSE 0 
		END AS isDecimalOdd
	, srecommend, b14.bettype
	FROM @tbl_transIDs t
		INNER LOOP JOIN dbo.bettrans14 b14	WITH (NOLOCK) ON b14.transid = t.transid
		LEFT JOIN dbo.f_Set_OddsTypeBettypes() AS ot ON ot.bettype = b14.bettype
		 
	-- update if bettype belongs to the CN88 site or not
	UPDATE tmp
	  SET	isCN88 = CASE WHEN cs.CustId IS NULL THEN 0 ELSE 1 END,
			isMajorGroup = CASE WHEN f.CommBettypeGroupId IS NOT NULL AND f.CommBettypeGroupId = 1 THEN 1 ELSE 0 END
	FROM   @tempTrans tmp
			   LEFT JOIN dbo.CS_CustSuper cs WITH(NOLOCK)
				   ON tmp.srecommend = cs.CustId
				LEFT JOIN dbo.f_Set_GetGroupBettypes() AS f
					ON tmp.bettype = f.BetType
	
	SET @settlementTime = GETDATE();

	IF @IsInsertTrigger = 1 OR @IsSiteDB = 1
	BEGIN
		--capture before for balance trigger
		INSERT INTO #BeforeTransId14( 
			   matchid ,transid ,betdaqid ,sitedbgroupid
			  ,bettype ,statusID ,Status 
			  ,winlostdate ,SettlementTime ,actual_stake ,modds 
			  ,srecommend ,mrecommend ,recommend ,custid	
			  ,winlost ,awinLost ,mwinLost ,swinLost
			  ,playercomm ,comm ,acomm ,scomm, refno
			)
		SELECT b.matchid, t.TransId, b.betdaqid, b.SiteDBGroupID
			,b.bettype, b.statusID, b.status, b.winlostdate, b.SettlementTime, b.actual_stake, b.modds
			,b.srecommend, b.mrecommend, b.recommend, b.custid
			,b.winlost, b.awinlost, b.mwinlost, b.swinlost
			,b.playercomm, b.comm, b.acomm, b.scomm, b.refno
		FROM @tempTrans t
			INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON b.transid = t.TransId
	END

	IF EXISTS (SELECT TOP 1 1 FROM @tbl_transIDs WHERE IsCashOut = 0)
	BEGIN
		UPDATE  b
			SET 
			   @commWinRate = CASE comstatus -- 0 : pay normal, both win/lost -- 1 : pay 'double' ONLY on lost
									WHEN '0' THEN 1
									WHEN '1' THEN 0
									ELSE 1 END
			   ,@commLostRate = CASE comstatus
									WHEN '0' THEN 1
									WHEN '1' THEN 2
									ELSE 1 END
			   ,@commHalfWLRate = CASE WHEN sr.isCN88 = 1 AND sr.isMajorGroup = 1 THEN 1
									ELSE 0.5
								END
			   ,@odds = CASE WHEN b.bettype IN (468,469) THEN b.odds
								 ELSE (CASE WHEN b.odds < 0 THEN 1 
	   										WHEN sr.isDecimalOdd = 1 THEN CASE 
																			WHEN b.statuswinlost = 2 AND b.bettype IN (9538,9539,9540) AND b.betteam LIKE '%l' THEN 1
																			ELSE b.odds - 1 ----/*DECIMAL ONLY*/
																			END
											ELSE b.odds 
										END)
						END
				----------------------------------------------------------------------------------------------------------------
				,@winlost = CASE 
								WHEN b.bettype IN (468,469) THEN CASE 
																	WHEN statuswinlost IN (2,4) THEN actual_stake + stake * @odds
																	WHEN statuswinlost IN (0,6) THEN actual_stake 
																  END	
								ELSE
								CASE
									WHEN statuswinlost = 2 THEN actual_stake + stake * @odds
									WHEN statuswinlost = 1 THEN actual_stake + stake * @odds * 0.5
									WHEN statuswinlost IN (0,6) THEN actual_stake
									WHEN statuswinlost = 3 THEN actual_stake * 0.5
									WHEN statuswinlost = 4 THEN 0
								END 
							END		
				-- check if bettype belongs to major comm group (CommBettypeGroupId = 1) and calc comm with new formula
				,@stake = CASE WHEN sr.isCN88 = 1 AND sr.isMajorGroup = 1 THEN ABS(@winlost - actual_stake)
								ELSE stake 
						  END
				-- check winlost or status change to update SettlementTime
				,@statusId = CASE
								WHEN statuswinlost IN (1,2) THEN 112 --WON
								WHEN statuswinlost = 0 THEN 111 --DRAW
								WHEN statuswinlost IN (3,4) THEN 113 --LOSE
								WHEN statuswinlost = 6 THEN 103
							END
				,SettlementTime = @settlementTime
				,WinLost = @winlost
				,aWinLost = CASE 
								WHEN b.bettype IN (468,469) THEN CASE 
																	WHEN statuswinlost IN (2,4) THEN stake * @odds * -apositiontaking
																	WHEN statuswinlost IN (0,6) THEN 0 
																  END	
								ELSE 
								CASE
									WHEN statuswinlost = 2 THEN stake * -apositiontaking * @odds
									WHEN statuswinlost = 1 THEN stake * @odds * -apositiontaking * 0.5
									WHEN statuswinlost IN (0,6)	THEN 0
									WHEN statuswinlost = 3 THEN actual_stake * apositiontaking * 0.5
									WHEN statuswinlost = 4 THEN actual_stake * apositiontaking
								END
							END
								
				,mWinLost = CASE 
								WHEN b.bettype IN (468,469) THEN CASE 
																	WHEN statuswinlost IN (2,4) THEN stake * @odds * -mpositiontaking
																	WHEN statuswinlost IN (0,6) THEN 0 
																  END	
								ELSE
								CASE
									WHEN statuswinlost = 2 THEN stake * -mpositiontaking *  @odds
									WHEN statuswinlost = 1 THEN stake * @odds * -mpositiontaking * 0.5
									WHEN statuswinlost IN (0,6)	THEN 0
									WHEN statuswinlost = 3 THEN actual_stake * mpositiontaking * 0.5
									WHEN statuswinlost = 4 THEN actual_stake * mpositiontaking
								END
							END
						
				,sWinLost = CASE 
								WHEN b.bettype IN (468,469) THEN CASE 
																	WHEN statuswinlost IN (2,4) THEN stake * @odds * -spositiontaking
																	WHEN statuswinlost IN (0,6) THEN 0 
																  END	
								ELSE
								CASE
									WHEN statuswinlost = 2 THEN stake * -spositiontaking * @odds
									WHEN statuswinlost = 1 THEN stake * @odds * -spositiontaking * 0.5
									WHEN statuswinlost IN (0,6)	THEN 0
									WHEN statuswinlost = 3 THEN actual_stake * spositiontaking * 0.5
									WHEN statuswinlost = 4 THEN actual_stake * spositiontaking
								END
							END

				,PlayerComm = CASE 
								WHEN b.bettype IN (468,469) THEN CASE 
																	WHEN statuswinlost = 2 THEN @commWinRate * playerdiscount * @stake
																	WHEN statuswinlost = 4 THEN @commLostRate * playerdiscount * @stake
																	WHEN statuswinlost IN (0,6) THEN 0 
																  END	
								ELSE
								CASE
									WHEN statuswinlost = 2 THEN @commWinRate * playerdiscount * @stake
									WHEN statuswinlost = 1 THEN @commWinRate * playerdiscount * @stake * @commHalfWLRate
									WHEN statuswinlost IN (0,6)	THEN 0
									WHEN statuswinlost = 3 THEN @commLostRate * playerdiscount * @stake * @commHalfWLRate
									WHEN statuswinlost = 4 THEN @commLostRate * playerdiscount * @stake
								END
							END
				,Comm = CASE 
							WHEN b.bettype IN (468,469) THEN CASE 
																WHEN statuswinlost = 2 THEN @commWinRate * discount * @stake * (1 - apositiontaking)
																WHEN statuswinlost = 4 THEN @commLostRate * discount * @stake * (1 - apositiontaking)
																WHEN statuswinlost IN (0,6) THEN 0 
															  END	
							ELSE
							CASE
								WHEN statuswinlost = 2 THEN @commWinRate * discount * @stake * (1-apositiontaking)
								WHEN statuswinlost = 1 THEN @commWinRate * discount * @stake * (1-apositiontaking) * @commHalfWLRate
								WHEN statuswinlost IN (0,6)	THEN 0
								WHEN statuswinlost = 3 THEN @commLostRate * discount * @stake * (1-apositiontaking) * @commHalfWLRate
								WHEN statuswinlost = 4 THEN @commLostRate * discount * @stake * (1-apositiontaking)
							END
						END	
				,aComm = CASE 
							WHEN b.bettype IN (468,469) THEN CASE 
																WHEN statuswinlost = 2 THEN @commWinRate * adiscount * @stake * (1 - (mpositiontaking + apositiontaking))
																WHEN statuswinlost = 4 THEN @commLostRate * adiscount * @stake * (1 - (mpositiontaking + apositiontaking))
																WHEN statuswinlost IN (0,6) THEN 0 
															  END	
							ELSE 
							CASE
								WHEN statuswinlost = 2 THEN @commWinRate * adiscount * @stake * (1-(mpositiontaking+apositiontaking))
								WHEN statuswinlost = 1 THEN @commWinRate * adiscount * @stake * (1-(mpositiontaking+apositiontaking)) * @commHalfWLRate
								WHEN statuswinlost IN (0,6)	THEN 0
								WHEN statuswinlost = 3 THEN @commLostRate * adiscount * @stake * (1-(mpositiontaking+apositiontaking)) * @commHalfWLRate
								WHEN statuswinlost = 4 THEN @commLostRate * adiscount * @stake * (1-(mpositiontaking+apositiontaking))
							END
						END		
				,sComm = CASE 
							WHEN b.bettype IN (468,469) THEN CASE 
																WHEN statuswinlost = 2 THEN @commWinRate * sdiscount * @stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
																WHEN statuswinlost = 4 THEN @commLostRate * sdiscount * @stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
																WHEN statuswinlost IN (0,6) THEN 0 
															  END	
							ELSE 
							CASE
								WHEN statuswinlost = 2 THEN @commWinRate * sdiscount * @stake * (1-(spositiontaking+mpositiontaking+apositiontaking))
								WHEN statuswinlost = 1 THEN @commWinRate * sdiscount * @stake * (1-(spositiontaking+mpositiontaking+apositiontaking)) * @commHalfWLRate
								WHEN statuswinlost IN (0,6)	THEN 0
								WHEN statuswinlost = 3 THEN @commLostRate * sdiscount * @stake * (1-(spositiontaking+mpositiontaking+apositiontaking)) * @commHalfWLRate
								WHEN statuswinlost = 4 THEN @commLostRate * sdiscount * @stake * (1-(spositiontaking+mpositiontaking+apositiontaking))
							END
						END	
				,Status = CASE
							WHEN @statusId = 112  THEN 'WON'
							WHEN @statusId = 111 THEN 'DRAW'
							WHEN @statusId = 113 THEN 'LOSE'
							WHEN @statusId = 103 THEN 'Refund'
						END
				,StatusID = @statusId
				,ruben= 1
				,ExtraInfo = REPLACE(REPLACE(ExtraInfo, '<p1 ab="1"/>',''),'ab="1"','')
				,creator = b.custID
		FROM @tempTrans sr
			INNER JOIN dbo.bettrans14 b  WITH (ROWLOCK, UPDLOCK) ON  sr.transid = b.transid
	END
	
	IF EXISTS (SELECT TOP 1 1 FROM @tbl_transIDs WHERE IsCashOut = 1)
	BEGIN
		--> re-calculate stake, re-settle for main cash-out + update cash-out bet ticket			
			;WITH CTE_main_cashoutticket AS
			(
				SELECT transid
					 , 1 AS TicketType	 
					-- , modds
					-- , Stake	
					 , zzzwinlost AS winlost
					 , status
					 , CASE WHEN status = 'WON' THEN '112' 
							WHEN status = 'LOSE' THEN '113' 
							WHEN status = 'DRAW' THEN '111' 
						END AS StatusId
					 , creator
					 , SportType
				FROM @tbl_transIDs
			)
			UPDATE	b
			SET status = TCal.status
			  , statusID = TCal.StatusId
			 --, stake = TRef.stake
			  , winlost = TCal.winlost
			  , awinlost = TCal.awinlost
			  , mWinLost = TCal.mWinLost
			  , swinlost = TCal.swinlost
			  , playercomm = TCal.playercomm
			  , comm = TCal.comm
			  , acomm = TCal.acomm
			  , scomm = TCal.scomm
			  , ruben = b.ruben
			  , creator = t.creator
			  , ExtraInfo = dbo.f_SD_SetExtraInfoAbnormalBet(1,'recover',b.ExtraInfo,t.SportType, b.bettype)
			FROM dbo.bettrans14 b WITH(ROWLOCK, UPDLOCK)
				INNER JOIN CTE_main_cashoutticket AS t
						ON b.transid = t.transId	    			
				OUTER APPLY (
								SELECT --b.stake,
									   CASE b.comstatus WHEN '0' THEN 1	WHEN '1' THEN 0 ELSE 1 END AS CommWinRate
									 , CASE b.comstatus WHEN '0' THEN 1	WHEN '1' THEN 2 ELSE 1 END AS CommLostRate
							) AS TRef		
				OUTER APPLY (SELECT CASE WHEN b.statuswinlost = 6 THEN 103 ELSE t.StatusId END AS StatusId
								 , CASE WHEN b.statuswinlost = 6 THEN 'Refund' ELSE t.status END AS status
								 , CASE WHEN b.statuswinlost = 6 THEN b.actual_stake ELSE t.winlost END AS winlost
								 , CASE
									
										WHEN b.statuswinlost = 6 THEN 0
										WHEN t.StatusId = 112 THEN ABS(t.winlost - b.actual_stake) * -b.apositiontaking
										WHEN t.StatusId = 111 THEN 0
										ELSE ABS(t.winlost - b.actual_stake) * b.apositiontaking
									END AS awinlost
								, CASE
										WHEN b.statuswinlost = 6 THEN 0
										WHEN t.StatusId = 112 THEN ABS(t.winlost - b.actual_stake) * -b.mpositiontaking
										WHEN t.StatusId = 111 THEN 0
										ELSE ABS(t.winlost - b.actual_stake) * b.mpositiontaking
									END AS mWinLost
								, CASE
										WHEN b.statuswinlost = 6 THEN 0
										WHEN t.StatusId = 112 THEN ABS(t.winlost - b.actual_stake) * -b.spositiontaking
										WHEN t.StatusId = 111 THEN 0
										ELSE ABS(t.winlost - b.actual_stake) * b.spositiontaking
									END AS swinlost
								  , CASE
										WHEN b.statuswinlost = 6 THEN 0
										WHEN t.StatusId = 112 THEN TRef.CommWinRate * b.stake * b.playerdiscount
										WHEN t.StatusId = 111 THEN TRef.CommWinRate * b.stake * b.playerdiscount
										ELSE TRef.CommLostRate * b.stake * b.playerdiscount
									END AS playercomm
								, CASE
										WHEN b.statuswinlost = 6 THEN 0
										WHEN t.StatusId = 112 THEN TRef.CommWinRate * b.stake * b.discount * (1-apositiontaking)
										WHEN t.StatusId = 111 THEN TRef.CommWinRate * b.stake * b.discount * (1-apositiontaking)
										ELSE TRef.CommLostRate * b.stake * b.discount * (1-apositiontaking)
									END AS comm
								,CASE
										WHEN b.statuswinlost = 6 THEN 0
										WHEN t.StatusId = 112 THEN TRef.CommWinRate * b.stake * b.adiscount * (1-apositiontaking - mpositiontaking)
										WHEN t.StatusId = 111 THEN TRef.CommWinRate * b.stake * b.adiscount * (1-apositiontaking - mpositiontaking)
										ELSE TRef.CommLostRate * b.stake * b.adiscount * (1-apositiontaking - mpositiontaking)
									END AS acomm
								,CASE
										WHEN b.statuswinlost = 6 THEN 0
										WHEN t.StatusId = 112 THEN TRef.CommWinRate * b.stake * b.sdiscount * (1-apositiontaking - mpositiontaking - spositiontaking)
										WHEN t.StatusId = 111 THEN TRef.CommWinRate * b.stake * b.sdiscount * (1-apositiontaking - mpositiontaking - spositiontaking)
										ELSE TRef.CommLostRate * b.stake * b.sdiscount * (1-apositiontaking - mpositiontaking - spositiontaking)
									END AS scomm
							) AS TCal	
	END

	IF @IsInsertTrigger = 1 OR @IsSiteDB = 1
	BEGIN
		--capture after for balance trigger
		INSERT INTO #AfterTransId14( 
			   matchid ,transid ,betdaqid ,sitedbgroupid
			  ,bettype ,statusID ,Status 
			  ,winlostdate ,SettlementTime ,actual_stake ,modds 
			  ,srecommend ,mrecommend ,recommend ,custid	
			  ,winlost ,awinLost ,mwinLost ,swinLost
			  ,playercomm ,comm ,acomm ,scomm, ruben, creator, ExtraInfo, refno
			)
		SELECT b.matchid, t.TransId, b.betdaqid, b.SiteDBGroupID
			,b.bettype, b.statusID, b.status, b.winlostdate, b.SettlementTime, b.actual_stake, b.modds
			,b.srecommend, b.mrecommend, b.recommend, b.custid
			,b.winlost, b.awinlost, b.mwinlost, b.swinlost
			,b.playercomm, b.comm, b.acomm, b.scomm, b.ruben, b.creator, b.ExtraInfo, b.refno
		FROM @tempTrans t
			INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON b.transid = t.TransId
	END

	IF @IsSiteDB = 1
	BEGIN
		SET @transInfo = COMPRESS((
		SELECT	b.transId AS 't'
				, b.winlost AS 'w'
				, b.ruben AS 'r'
				, b.creator AS 'cr'
				, b.awinlost AS 'aw'
				, b.mwinlost AS 'mw'
				, b.swinlost AS 'sw'
				, b.playercomm AS 'pc'
				, b.comm AS 'c'
				, b.acomm AS 'ac'
				, b.scomm AS 'sc'
				, b.statusID AS 'sid'
				, b.status AS 's'
				, b.ExtraInfo AS 'ex'
				, b.SettlementTime AS 'st' --CO not update get old data
		FROM	#AfterTransId14 b
		WHERE b.bettype NOT IN (10)
		FOR JSON PATH))

		IF @transInfo IS NOT NULL
		BEGIN
			INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType)
			SELECT 'TVS', 'Recover_14', 'bettrans14', 'U', @matchid, @transInfo, CASE WHEN @MatchId IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1)) THEN 'p' ELSE 's' END
		END
	END	

	IF @IsInsertTrigger = 1 OR @IsSiteDB = 1
	BEGIN
		-- Insert statements for trigger here
		INSERT INTO dbo.BalanceTrigger (custid, transid, bettype, actual_stake, winlost, playercomm, ActionDate, 
			ActionID, [Action],
			BalanceChanged,
			MatchId, StatusId, SettlementType, swinlost, mwinlost, awinlost, scomm, acomm, comm, modds, winlostdate, bef_statusid, bef_winlost, refno)
		SELECT
			-- if inserted.custid = 0, this should be VOID + Hidden
			-- if deleted.custid = 0, this may be Bet Recover
			case when i.custid = 0 then d.custid else i.custid end,
			i.transid, i.bettype, i.actual_stake, isnull(i.winlost,0) as winlost, isnull(i.playercomm,0) as playercomm, CURRENT_TIMESTAMP, 

			CASE 
				WHEN (
					i.actual_stake <> d.actual_stake 
					OR isnull(i.winlost,0) <> isnull(d.winlost,0) 
					OR isnull(i.playercomm,0) <> isnull(d.playercomm,0)
					OR isnull(i.statusid,0) <> isnull(d.statusid,0)
					OR i.custid <> d.custid
				) THEN
					CASE
					WHEN isnull(i.statusid,0) = 102 THEN 050 -- Void Bet

					WHEN i.bettype < 19001 AND isnull(d.statusid,0) = 1 THEN CASE isnull(i.statusid,0) WHEN 101 THEN 020 WHEN 0 THEN 021 ELSE 0 END -- waiting -> Reject : running : something else
					WHEN i.bettype < 19001 AND isnull(d.statusid,0) = 0 AND isnull(i.statusid,0) > 0  -- Settled : running -> Won/Lose/Draw/Refund
						THEN CASE 
								WHEN ISNULL(i.betdaqid,0) = -2 THEN 029 -- cashout ticket
								ELSE 030 -- settle ticket
							END
					WHEN i.bettype < 19001 AND isnull(d.statusid,0) = 102 AND isnull(i.statusid,0) = 0 THEN 055 -- unvoid/recover : void -> running
					WHEN i.bettype < 19001 AND isnull(d.statusid,0) > 0 
						THEN CASE isnull(i.statusid,0) 
								WHEN 0 THEN CASE WHEN ISNULL(i.betdaqid,0) = -1 AND ISNULL(d.betdaqid,0) = -2 THEN 034 ELSE 032 END
								ELSE 031 
							END -- resettle or unsettle
					WHEN i.bettype > 20000 AND i.custid = 0 THEN 130 -- cancel transfer (custid set to zero)
					WHEN i.bettype > 20000 THEN 120 -- update transfer

					--WHEN i.bettype < 19001 AND d.custid = 0 AND i.custid > 0 THEN 055 -- recover bet
					ELSE 0 END
				ELSE 001
			END,
		
			--CASE WHEN i.custid =0 THEN 'Delete ' ELSE 'Update ' END
			--	+ CASE WHEN i.bettype < 19001 then 'Bet' ELSE 'Transfer' END + 
			--CASE WHEN i.custid <> 0 THEN ', from '+ d.[status] + ' to ' + i.[status] ELSE '' END
			--[Action]--vvv
			CASE 
				WHEN ( i.winlostdate <> d.winlostdate AND i.bettype NOT IN (29, 10)	)
					OR (i.winlostdate > d.winlostdate AND i.bettype = 10 )
					OR (i.winlostdate > d.winlostdate AND i.bettype = 29 AND d.statusID NOT IN (0,1) )
					THEN 'Move WLD from ' 
							+ CASE 
								WHEN ISNULL(d.winlostdate,'') = '' THEN REPLICATE(' ', 10) 
								ELSE CONVERT(VARCHAR,d.winlostdate, 23) 
							END
							+ ' to ' 
							+ CASE 
								WHEN ISNULL(i.winlostdate,'') = '' THEN REPLICATE(' ', 10)
								ELSE CONVERT(VARCHAR,i.winlostdate, 23) 
							END						
				ELSE '' 
			END + 
			ISNULL(CASE
					WHEN i.bettype < 19001 THEN 'Bet'
					WHEN i.bettype > 20000 THEN 'Transfer'
					ELSE isnull(d.[status],'running')
				END +
				CASE
					WHEN i.custid = 0 THEN ' cancelled, ' + isnull(d.[status],'running') + ' to ' + isnull(i.[status],'running')
					WHEN i.bettype > 20000 THEN ' updated, ' + isnull(d.[status],'running') + ' to ' + isnull(i.[status],'running')
					WHEN isnull(d.statusid,0) = 1 THEN
						CASE isnull(i.statusid,0)
						WHEN 0 THEN ' accepted'
						WHEN 101 THEN ' rejected'
						ELSE ' updated, ' + isnull(d.[status],'running') + ' to ' + isnull(i.[status],'running')
						END
					WHEN isnull(d.statusid,0) = 0 THEN
						CASE 
							WHEN isnull(i.statusid,0) = 102 THEN ' voided'
							WHEN (isnull(i.statusid,0) BETWEEN 111 AND 113) OR isnull(i.statusid,0) = 103 
								THEN CASE 
										WHEN ISNULL(i.betdaqid,0) = -2 THEN ' Cash Out, ' + isnull(d.status,' running') + ' to '  + isnull(i.status,' running')
										ELSE  ' settled, ' + isnull(d.[status],'running') + ' to ' + isnull(i.[status],'running')
									END
							ELSE ' updated, ' + isnull(d.[status],'running') + ' to ' + isnull(i.[status],'running')
						END
					WHEN isnull(d.statusid,0) > 0 AND isnull(d.betdaqid,0) = -2 AND isnull(i.statusid,0) = 0 
						THEN ' Cancel Cash Out, ' + isnull(d.status,'running') + ' to ' + isnull(i.status,'running')
					ELSE ' Updated, ' + isnull(d.[status],'running') + ' to ' + isnull(i.[status],'running')
				END,'')
			--[Action]--^^^	
 			, (isnull(i.winlost,0) - ISNULL(i.actual_stake, 0) + ISNULL(i.playercomm,0))
				- (ISNULL(d.winlost,0) - ISNULL(d.actual_stake, 0) + ISNULL(d.playercomm,0))
			,i.matchid
			,isnull(i.statusID,0)
			,CASE 
				WHEN (isnull(i.statusID,0) BETWEEN 111 AND 113 OR isnull(i.statusID,0) = 103) 
					THEN CASE 
							WHEN d.SettlementTime IS NULL THEN 1 -- first settled
							WHEN i.SettlementTime <> d.SettlementTime 
								THEN CASE
										WHEN isnull(d.statusID,0) = 0 THEN 2 -- change from running to settle 
										ELSE 3 
									END -- re-settled: change from settle to settle
							WHEN isnull(d.statusID,0) BETWEEN 111 AND 113 THEN 4 -- settle to settle, no change winlost
							ELSE 0 
						END
				ELSE 0
			END -- SettlementType
			,isnull(i.swinlost,0) as swinlost
			,isnull(i.mwinlost,0) as mwinlost
			,isnull(i.awinlost,0) as awinlost
			,isnull(i.scomm,0) as scomm
			,isnull(i.acomm,0) as acomm
			,isnull(i.comm,0) as comm
			,i.modds
			,i.winlostdate
			,d.statusID AS bef_statusid
			,isnull(d.winlost,0) AS bef_winlost
			,d.refno
		FROM #AfterTransId14 i 
				INNER JOIN #BeforeTransId14 d ON i.transid = d.transid
		WHERE d.custid <> d.recommend 
			AND d.custid <> d.mrecommend 
			AND d.custid <> d.srecommend		
	END

	DROP TABLE #BeforeTransId14
	DROP TABLE #AfterTransId14
END
GO