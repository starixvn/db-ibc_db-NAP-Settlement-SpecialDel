/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_ReCalculate_Single_Update]
(
	@TransIds	VARCHAR(MAX)
)
AS
/*	Created by: Max
	Date 20200212
	Task: Abnormal Void Bets Automation [Redmine: #128359]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20200212@Max: Create new SP [Redmine: #128359]
		- 20200924@Louisa: Implement for Myanmar odds - bettype 1,3,7,8 [Redmine:#142220]	
		
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	-----------------------CHECK SERVER-----------------------------------------
	DECLARE @ServerName			SYSNAME 
			,@AllowCalculation	BIT
			,@xml XML
			
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
	SET @xml = CONVERT(XML, @TransIds)
	DECLARE @tbl_transIDs AS TABLE(transid BIGINT)
	
	INSERT INTO @tbl_transIDs (transid)
	SELECT	T.C.value('./@transid', 'bigint')
	FROM	@xml.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@xml = NULL ))
	
	DECLARE @tempTrans TABLE (TransID BIGINT, isDecimalOdd BIT, srecommend INT, bettype SMALLINT, isCN88 BIT, isMajorGroup BIT)
	DECLARE  @commWinRate		SMALLMONEY
			,@commLostRate		SMALLMONEY
			,@commHalfWLRate	SMALLMONEY
			,@odds				SMALLMONEY
			,@winlost			MONEY
			,@stake				MONEY
			,@statusId			TINYINT
			
			
	DECLARE @settlementTime DATETIME
	---parse XML
	INSERT INTO @tempTrans(TransID, isDecimalOdd, srecommend, bettype)
	SELECT t.TransID, CASE WHEN ot.oddstype = 1 THEN 1 ELSE 0 END AS isDecimalOdd, srecommend, b.bettype
	FROM @tbl_transIDs t
		INNER LOOP JOIN dbo.bettrans b	WITH (NOLOCK) ON b.transid = t.transid
		LEFT JOIN dbo.f_Set_OddsTypeBettypes() AS ot ON ot.bettype = b.bettype
	WHERE b.statuswinlost IS NOT NULL
		 
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
	   									WHEN sr.isDecimalOdd = 1 THEN b.odds - 1 ----/*DECIMAL ONLY*/
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
								WHEN statuswinlost = 2 THEN CASE WHEN b.oddstype = 6 THEN actual_stake + stake * odds * (oddsspread/100) -- oddsspread > 0: WON
															ELSE actual_stake + stake * @odds
															END
								WHEN statuswinlost = 1 THEN actual_stake + stake * @odds * 0.5
								WHEN statuswinlost IN (0,6) THEN actual_stake
								WHEN statuswinlost = 3 THEN actual_stake * 0.5
								WHEN statuswinlost = 4 THEN  CASE WHEN b.oddstype = 6 THEN actual_stake * (1 - ABS(oddsspread/100))
															 ELSE 0
															 END
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
								WHEN statuswinlost = 2 THEN CASE WHEN b.oddstype = 6 THEN stake * odds * (oddsspread/100) * -apositiontaking
															ELSE stake * @odds * -apositiontaking
															END
								WHEN statuswinlost = 1 THEN stake * @odds * -apositiontaking * 0.5
								WHEN statuswinlost IN (0,6)	THEN 0
								WHEN statuswinlost = 3 THEN actual_stake * apositiontaking * 0.5
								WHEN statuswinlost = 4 THEN CASE WHEN b.oddstype = 6 THEN actual_stake * ABS(oddsspread/100) * apositiontaking
															ELSE actual_stake * apositiontaking
															END
							END
						END
								
			,mWinLost = CASE 
							WHEN b.bettype IN (468,469) THEN CASE 
																WHEN statuswinlost IN (2,4) THEN stake * @odds * -mpositiontaking
																WHEN statuswinlost = 0 THEN 0 
															  END	
							ELSE
							CASE
								WHEN statuswinlost = 2 THEN CASE WHEN b.oddstype = 6 THEN  stake * odds * (oddsspread/100) * -mpositiontaking
															ELSE stake * @odds * -mpositiontaking
															END
								WHEN statuswinlost = 1 THEN stake * @odds * -mpositiontaking * 0.5
								WHEN statuswinlost IN (0,6)	THEN 0
								WHEN statuswinlost = 3 THEN actual_stake * mpositiontaking * 0.5
								WHEN statuswinlost = 4 THEN CASE WHEN b.oddstype = 6 THEN actual_stake * ABS(oddsspread/100) * mpositiontaking
															ELSE actual_stake * mpositiontaking
															END
							END
						END
						
			,sWinLost = CASE 
							WHEN b.bettype IN (468,469) THEN CASE 
																WHEN statuswinlost IN (2,4) THEN stake * @odds * -spositiontaking
																WHEN statuswinlost = 0 THEN 0 
															  END	
							ELSE
							CASE
								WHEN statuswinlost = 2 THEN CASE WHEN b.oddstype = 6 THEN stake * odds * (oddsspread/100) * -spositiontaking
															ELSE stake * @odds * -spositiontaking
															END
								WHEN statuswinlost = 1 THEN stake * @odds * -spositiontaking * 0.5
								WHEN statuswinlost IN (0,6)	THEN 0
								WHEN statuswinlost = 3 THEN actual_stake * spositiontaking * 0.5
								WHEN statuswinlost = 4 THEN CASE WHEN b.oddstype = 6 THEN actual_stake * ABS(oddsspread/100) * spositiontaking
															ELSE actual_stake * spositiontaking
															END
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
								WHEN statuswinlost = 2 THEN CASE WHEN b.oddstype = 6 THEN @commWinRate * playerdiscount * stake * odds * (oddsspread/100)
															ELSE @commWinRate * playerdiscount * @stake
															END
								WHEN statuswinlost = 1 THEN @commWinRate * playerdiscount * @stake * @commHalfWLRate
								WHEN statuswinlost IN (0,6)	THEN 0
								WHEN statuswinlost = 3 THEN @commLostRate * playerdiscount * @stake * @commHalfWLRate
								WHEN statuswinlost = 4 THEN CASE WHEN b.oddstype = 6 THEN @commLostRate * playerdiscount * stake * ABS(oddsspread/100)
															ELSE @commLostRate * playerdiscount * @stake
															END
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
							WHEN statuswinlost = 2 THEN CASE WHEN b.oddstype = 6 THEN  @commWinRate * discount * stake * odds * (oddsspread/100) * (1-apositiontaking)
														ELSE @commWinRate * discount * @stake * (1-apositiontaking)
														END
							WHEN statuswinlost = 1 THEN @commWinRate * discount * @stake * (1-apositiontaking) * @commHalfWLRate
							WHEN statuswinlost IN (0,6)	THEN 0
							WHEN statuswinlost = 3 THEN @commLostRate * discount * @stake * (1-apositiontaking) * @commHalfWLRate
							WHEN statuswinlost = 4 THEN CASE WHEN b.oddstype = 6 THEN @commLostRate * discount * stake * ABS(oddsspread/100) * (1-apositiontaking)
														ELSE @commLostRate * discount * @stake * (1-apositiontaking)
														END
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
							WHEN statuswinlost = 2 THEN CASE WHEN b.oddstype = 6 THEN @commWinRate * adiscount * stake * odds * (oddsspread/100) * (1-(mpositiontaking+apositiontaking))
														ELSE @commWinRate * adiscount * @stake * (1-(mpositiontaking+apositiontaking))
														END
							WHEN statuswinlost = 1 THEN @commWinRate * adiscount * @stake * (1-(mpositiontaking+apositiontaking)) * @commHalfWLRate
							WHEN statuswinlost IN (0,6)	THEN 0
							WHEN statuswinlost = 3 THEN @commLostRate * adiscount * @stake * (1-(mpositiontaking+apositiontaking)) * @commHalfWLRate
							WHEN statuswinlost = 4 THEN CASE WHEN b.oddstype = 6 THEN @commLostRate * adiscount * stake * ABS(oddsspread/100) * (1-(mpositiontaking+apositiontaking))
														ELSE @commLostRate * adiscount * @stake * (1-(mpositiontaking+apositiontaking))
														END
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
							WHEN statuswinlost = 2 THEN CASE WHEN b.oddstype = 6 THEN @commWinRate * sdiscount * stake * odds * (oddsspread/100) * (1-(spositiontaking+mpositiontaking+apositiontaking))
														ELSE @commWinRate * sdiscount * @stake * (1-(spositiontaking+mpositiontaking+apositiontaking))
														END
							WHEN statuswinlost = 1 THEN @commWinRate * sdiscount * @stake * (1-(spositiontaking+mpositiontaking+apositiontaking)) * @commHalfWLRate
							WHEN statuswinlost IN (0,6)	THEN 0
							WHEN statuswinlost = 3 THEN @commLostRate * sdiscount * @stake * (1-(spositiontaking+mpositiontaking+apositiontaking)) * @commHalfWLRate
							WHEN statuswinlost = 4 THEN CASE WHEN b.oddstype =6 THEN @commLostRate * sdiscount * stake * ABS(oddsspread/100) * (1-(spositiontaking+mpositiontaking+apositiontaking))
														ELSE @commLostRate * sdiscount * @stake * (1-(spositiontaking+mpositiontaking+apositiontaking))
														END
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
	FROM @tempTrans sr
		INNER JOIN dbo.bettrans b  WITH (ROWLOCK, UPDLOCK) ON  sr.transid = b.transid
END