/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_Bet14] (
	@transIds VARCHAR(MAX)
	,@MatchId	INT = 0
)
AS
/*
	Created by: 20190715@Helen
	Task: Settlement  
	DB: DBTRANS/BODB02
	
	Revisions:
		- 20190715@Helen: Recover/Void tickets in Bet 14 - [Redmine:115377]
		- 20210304@Louisa: Cricket AIO [Redmine:#148870]
		- 20210922@Louisa: Remove @CutOffDate [Redmine:#159903]
		
	Param's Explanation:  
		   
		@transIds = '104730774034,104729373985'
					
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

	IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL 
		SET @IsSiteDB = 1

	DECLARE @tbl_transIDs AS TABLE(transid BIGINT)

	SET @XML = N'<root><r>' + REPLACE(@transIds, ',', '</r><r>') + '</r></root>'
	
	INSERT INTO @tbl_transIDs (transid)
	SELECT r.value('.','BIGINT')
	FROM @xml.nodes('//root/r') AS RECORDS(r)
	OPTION (OPTIMIZE FOR (@xml = NULL))
	
	DECLARE @tempTrans TABLE (TransID BIGINT, isDecimalOdd BIT, srecommend INT, bettype SMALLINT, isCN88 BIT, isMajorGroup BIT)
	DECLARE  @commWinRate		SMALLMONEY
			,@commLostRate		SMALLMONEY
			,@commHalfWLRate	SMALLMONEY
			,@odds				SMALLMONEY
			,@winlost			MONEY
			,@stake				MONEY
			,@statusId			TINYINT
			
			
	CREATE TABLE #AfterTransId14(
	    matchid INT ,transid BIGINT PRIMARY KEY,betdaqid BIGINT ,sitedbgroupid SMALLINT
      ,bettype SMALLINT ,statusID TINYINT ,Status NVARCHAR(10)
	  ,winlostdate SMALLDATETIME ,SettlementTime DATETIME ,actual_stake MONEY ,modds SMALLMONEY
	  ,srecommend INT ,mrecommend INT,recommend INT ,custid INT	
	  ,winlost MONEY ,awinLost MONEY ,mwinLost MONEY ,swinLost MONEY
	  ,playercomm MONEY ,comm MONEY ,acomm MONEY ,scomm MONEY, ruben TINYINT, creator INT, ExtraInfo VARCHAR(1000)
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
																WHEN statuswinlost = 0 THEN actual_stake 
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
																WHEN statuswinlost = 0 THEN 0 
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
																WHEN statuswinlost = 0 THEN 0 
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
																WHEN statuswinlost = 0 THEN 0 
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
																WHEN statuswinlost = 0 THEN 0 
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
															WHEN statuswinlost = 0 THEN 0 
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
															WHEN statuswinlost = 0 THEN 0 
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
															WHEN statuswinlost = 0 THEN 0 
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
	
	
	IF @IsSiteDB = 1
	BEGIN
		--capture after for balance trigger
		INSERT INTO #AfterTransId14( 
			   matchid ,transid ,betdaqid ,sitedbgroupid
			  ,bettype ,statusID ,Status 
			  ,winlostdate ,SettlementTime ,actual_stake ,modds 
			  ,srecommend ,mrecommend ,recommend ,custid	
			  ,winlost ,awinLost ,mwinLost ,swinLost
			  ,playercomm ,comm ,acomm ,scomm, ruben, creator, ExtraInfo
			)
		SELECT b.matchid, t.TransId, b.betdaqid, b.SiteDBGroupID
			,b.bettype, b.statusID, b.status, b.winlostdate, b.SettlementTime, b.actual_stake, b.modds
			,b.srecommend, b.mrecommend, b.recommend, b.custid
			,b.winlost, b.awinlost, b.mwinlost, b.swinlost
			,b.playercomm, b.comm, b.acomm, b.scomm, b.ruben, b.creator, b.ExtraInfo
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
				, b.SettlementTime AS 'st'
		FROM	#AfterTransId14 b
		WHERE b.bettype NOT IN (10)
		FOR JSON PATH))

		IF @transInfo IS NOT NULL
		BEGIN
			INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType)
			SELECT 'TVS', 'Recover_14', 'bettrans14', 'U', @matchid, @transInfo, CASE WHEN @MatchId IN (29, 2799) THEN 'p' ELSE 's' END
		END
	END	

	DROP TABLE #AfterTransId14
END
GO