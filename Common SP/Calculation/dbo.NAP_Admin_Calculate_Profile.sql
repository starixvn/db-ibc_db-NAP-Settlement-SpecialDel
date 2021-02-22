/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_Profile]
	@transIds		   VARCHAR(MAX) = ''
	,@modds				SMALLMONEY = 1
	,@Oddstype			TINYINT = 0
	,@IsMarked			BIT = 0
AS
/*
	Created by: 20201123@Kathy
	Task: Settlement  
	DB: DBTRANS.BODB02
	
	Revisions:
		- 20201123@Kathy: Apply Settlement by Profile for soccer [Redmine:#142425]
		
	Param's Explanation:  
		   
		@transIds = '<root>
						<r t="104730774034" m="1"/>
						<r t="104729373985" m="0" ot="1"/>
					</root>'
					t:  transid
					m:  modds
					ot: oddstype: 1: DECIMAL ONLY
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
	
	DECLARE @tmpTrans TABLE (TransID BIGINT PRIMARY KEY)
	
	DECLARE @commWinRate		SMALLMONEY
			,@commLostRate		SMALLMONEY
			,@commHalfWLRate	SMALLMONEY
			,@odds				SMALLMONEY
			,@winlost			MONEY
			,@stake				MONEY
			,@statusId			TINYINT
			,@IsUpd_Void		BIT = 0
			,@xml				XML
			,@batchno			INT = 2000
			,@settlementTime DATETIME
	
	SET @xml = CAST(@transIds AS XML)

	INSERT INTO @tmpTrans (TransID)
	SELECT T.C.value('./@t', 'bigint') AS transid
	FROM @xml.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@xml = NULL ))
	
	SET @settlementTime = GETDATE();
		
	UPDATE TOP(@batchno)  b
	SET
		@commWinRate = CASE b.comstatus -- 0 : pay normal, both win/lost -- 1 : pay 'double' ONLY on lost
							WHEN '0' THEN 1
							WHEN '1' THEN 0
							ELSE 1 END
		,@commLostRate = CASE b.comstatus
							WHEN '0' THEN 1
							WHEN '1' THEN 2
							ELSE 1 END
		,@commHalfWLRate = 0.5
		,@odds = (CASE WHEN b.odds < 0 THEN 1 
	   					WHEN @oddstype = 1 THEN b.odds - 1  ----/*DECIMAL ONLY*/
						ELSE b.odds END)
		----------------------------------------------------------------------------------------------------------------
		,@IsUpd_Void = CASE WHEN b.statusID = 102 OR @IsMarked = 1 THEN 0 ELSE 1 END
		
		,modds = @modds
		,statuswinlost = CASE WHEN @modds > 0.25 THEN 2
								WHEN @modds = 0.25 THEN 1 
								WHEN @modds = 0 AND b.oddstype <> 6 THEN 0 
								WHEN @modds = 0 AND b.oddstype = 6 
									THEN CASE
											WHEN b.oddsspread = 0 THEN 0
											WHEN b.oddsspread > 0 THEN 2
											ELSE 4
										END
								WHEN @modds = - 0.25 THEN 3
								WHEN @modds < - 0.25 THEN 4
								WHEN @modds IS NULL THEN 6
							END 			   	
		,@winlost = CASE
				WHEN @modds >  0.25 THEN b.actual_stake + b.stake * @odds
				WHEN @modds =  0.25 THEN b.actual_stake + b.stake * @odds * 0.5
				WHEN @modds =  0 AND b.oddstype <> 6 THEN b.actual_stake
				WHEN @modds =  0 AND b.oddstype = 6 
					THEN CASE 
							WHEN b.oddsspread = 0 THEN b.actual_stake
							WHEN b.oddsspread > 0 THEN b.actual_stake + b.stake * b.odds * (b.oddsspread/100) -- oddsspread > 0: WON
							ELSE b.actual_stake * (1 - ABS(b.oddsspread/100))  -- oddsspread < 0: LOSE
						END
				WHEN @modds = -0.25 THEN actual_stake * 0.5
				WHEN @modds < -0.25 THEN 0
				END 	
		,@stake = b.stake
		-- check winlost or status change to update SettlementTime
		,@statusId = CASE
						WHEN @modds > 0 THEN 112 --WON
						WHEN @modds = 0 AND b.oddstype <> 6 THEN 111 --DRAW
						WHEN @modds = 0 AND b.oddstype = 6 
							THEN CASE 
									WHEN b.oddsspread = 0 THEN 111 
									WHEN b.oddsspread > 0 THEN 112
									ELSE 113
								END
						WHEN @modds < 0 THEN 113 --LOSE
					END
		,SettlementTime = CASE 
								WHEN @IsUpd_Void = 0 THEN b.SettlementTime 
								ELSE CASE WHEN b.winlost <> @winlost OR b.statusID <> @statusId THEN @settlementTime ELSE b.SettlementTime END
							END
						
		,WinLost = CASE 
						WHEN @IsUpd_Void = 0 THEN WinLost 
						ELSE @winlost
					END
		,aWinLost = CASE 
						WHEN @IsUpd_Void = 0 THEN aWinLost 
						ELSE CASE
								WHEN @modds >  0.25 THEN b.stake * @odds * -b.apositiontaking
								WHEN @modds =  0.25 THEN b.stake * @odds * -b.apositiontaking * 0.5
								WHEN @modds =  0 AND b.oddstype <> 6    THEN 0
								WHEN @modds =  0 AND b.oddstype = 6    
									THEN CASE 
											WHEN b.oddsspread = 0 THEN 0
											WHEN b.oddsspread > 0 THEN b.stake * b.odds * (b.oddsspread/100) * -b.apositiontaking -- oddsspread > 0: WON
											ELSE b.actual_stake * ABS(b.oddsspread/100) * b.apositiontaking -- oddsspread < 0: LOSE
										END
								WHEN @modds = -0.25 THEN b.actual_stake * b.apositiontaking * 0.5
								WHEN @modds < -0.25 THEN b.actual_stake * b.apositiontaking
							END
					END
							
		,mWinLost = CASE 
						WHEN @IsUpd_Void = 0 THEN b.mWinLost 
						ELSE CASE
								WHEN @modds >  0.25 THEN b.stake * @odds * -b.mpositiontaking
								WHEN @modds =  0.25 THEN b.stake * @odds * -b.mpositiontaking * 0.5
								WHEN @modds =  0 AND b.oddstype <> 6        THEN 0
								WHEN @modds =  0 AND b.oddstype = 6        
									THEN CASE 
											WHEN oddsspread = 0 THEN 0
											WHEN oddsspread > 0 THEN stake * odds * (oddsspread/100) * -mpositiontaking -- oddsspread > 0: WON
											ELSE actual_stake * ABS(oddsspread/100) * mpositiontaking -- oddsspread < 0: LOSE
										END
								WHEN @modds = -0.25 THEN b.actual_stake * b.mpositiontaking * 0.5
								WHEN @modds < -0.25 THEN b.actual_stake * b.mpositiontaking
							END
					END
					
		,sWinLost = CASE 
						WHEN @IsUpd_Void = 0 THEN b.sWinLost 
						ELSE CASE
								WHEN @modds >  0.25 THEN b.stake * @odds * -b.spositiontaking
								WHEN @modds =  0.25 THEN stake * @odds * -b.spositiontaking * 0.5
								WHEN @modds =  0 AND b.oddstype <> 6       THEN 0
								WHEN @modds =  0 AND b.oddstype = 6       
									THEN CASE 
											WHEN oddsspread = 0 THEN 0
											WHEN oddsspread > 0 THEN stake * odds * (oddsspread/100) * -spositiontaking
											ELSE actual_stake * ABS(oddsspread/100) * spositiontaking 
										END
								WHEN @modds = -0.25 THEN b.actual_stake * b.spositiontaking * 0.5
								WHEN @modds < -0.25 THEN b.actual_stake * b.spositiontaking
							END
					END

		,PlayerComm = CASE 
						WHEN @IsUpd_Void = 0 THEN PlayerComm 
						ELSE CASE
								WHEN @modds >  0.25 THEN @commWinRate * b.playerdiscount * @stake
								WHEN @modds =  0.25 THEN @commWinRate * b.playerdiscount * @stake * @commHalfWLRate
								WHEN @modds =  0 AND b.oddstype <> 6        THEN 0
								WHEN @modds =  0 AND b.oddstype = 6        
									THEN CASE
											WHEN oddsspread = 0 THEN 0
											WHEN oddsspread > 0 THEN @commWinRate * playerdiscount * stake * (oddsspread/100)
											ELSE @commLostRate * playerdiscount * stake * ABS(oddsspread/100)
										END
								WHEN @modds = -0.25 THEN @commLostRate * b.playerdiscount * @stake * @commHalfWLRate
								WHEN @modds < -0.25 THEN @commLostRate * b.playerdiscount * @stake
							END
					END
					
		,Comm = CASE 
					WHEN @IsUpd_Void = 0 THEN Comm 
					ELSE CASE
							WHEN @modds >  0.25 THEN @commWinRate * b.discount * @stake * (1-b.apositiontaking)
							WHEN @modds =  0.25 THEN @commWinRate * b.discount * @stake * (1-b.apositiontaking) * @commHalfWLRate
							WHEN @modds =  0 AND b.oddstype <> 6       THEN 0
							WHEN @modds =  0 AND b.oddstype = 6       
								THEN CASE 
										WHEN oddsspread = 0 THEN 0
										WHEN oddsspread > 0 THEN @commWinRate * discount * stake * (oddsspread/100) * (1-apositiontaking)
										ELSE @commLostRate * discount * stake * ABS(oddsspread/100) * (1-apositiontaking)
									END
							WHEN @modds = -0.25 THEN @commLostRate * b.discount * @stake * (1-b.apositiontaking) * @commHalfWLRate
							WHEN @modds < -0.25 THEN @commLostRate * b.discount * @stake * (1-b.apositiontaking)
						END
				END
					
		,aComm = CASE 
					WHEN @IsUpd_Void = 0 THEN aComm 
					ELSE CASE
							WHEN @modds >  0.25 THEN @commWinRate * b.adiscount * @stake * (1-(b.mpositiontaking+b.apositiontaking))
							WHEN @modds =  0.25 THEN @commWinRate * b.adiscount * @stake * (1-(b.mpositiontaking+b.apositiontaking)) * @commHalfWLRate
							WHEN @modds =  0 AND b.oddstype <> 6        THEN 0
							WHEN @modds =  0 AND b.oddstype = 6        
								THEN CASE
										WHEN oddsspread = 0 THEN 0
										WHEN oddsspread > 0 THEN @commWinRate * adiscount * stake * (oddsspread/100) * (1-(mpositiontaking+apositiontaking))
										ELSE @commLostRate * adiscount * stake * ABS(oddsspread/100) * (1-(mpositiontaking+apositiontaking))
									END
							WHEN @modds = -0.25 THEN @commLostRate * b.adiscount * @stake * (1-(b.mpositiontaking+b.apositiontaking)) * @commHalfWLRate
							WHEN @modds < -0.25 THEN @commLostRate * b.adiscount * @stake * (1-(b.mpositiontaking+b.apositiontaking))
						END
				END
					
		,sComm = CASE 
					WHEN @IsUpd_Void = 0 THEN sComm 
					ELSE CASE
							WHEN @modds >  0.25 THEN @commWinRate * b.sdiscount * @stake * (1-(b.spositiontaking+b.mpositiontaking+b.apositiontaking))
							WHEN @modds =  0.25 THEN @commWinRate * b.sdiscount * @stake * (1-(b.spositiontaking+b.mpositiontaking+b.apositiontaking)) * @commHalfWLRate
							WHEN @modds =  0 AND b.oddstype <> 6        THEN 0
							WHEN @modds =  0 AND b.oddstype = 6        
								THEN CASE
										WHEN oddsspread = 0 THEN 0
										WHEN oddsspread > 0 THEN @commWinRate * sdiscount * stake * (oddsspread/100) * (1-(spositiontaking+mpositiontaking+apositiontaking))
										ELSE @commLostRate * sdiscount * stake * ABS(oddsspread/100) * (1-(spositiontaking+mpositiontaking+apositiontaking))
									END
							WHEN @modds = -0.25 THEN @commLostRate * b.sdiscount * @stake * (1-(b.spositiontaking+b.mpositiontaking+b.apositiontaking)) * @commHalfWLRate
							WHEN @modds < -0.25 THEN @commLostRate * b.sdiscount * @stake * (1-(b.spositiontaking+b.mpositiontaking+b.apositiontaking))
						END
				END
					
		,Status = CASE 
					WHEN @IsUpd_Void = 0 THEN Status 
					ELSE CASE
							WHEN @modds > 0 THEN 'WON'
							WHEN @modds = 0 AND b.oddstype <> 6 THEN 'DRAW'
							WHEN @modds = 0 AND b.oddstype = 6 
								THEN CASE 
										WHEN oddsspread = 0 THEN 'DRAW' 
										WHEN oddsspread > 0 THEN 'WON'
										ELSE 'LOSE'
									END
							WHEN @modds < 0 THEN 'LOSE'
						END
				END
		,StatusID = CASE 
						WHEN @IsUpd_Void = 0 THEN b.StatusID 
						ELSE @statusId
					END
		,ruben=CASE 
					WHEN @IsUpd_Void = 0 THEN b.ruben 
					ELSE 1
				END
	FROM @tmpTrans sr
		INNER JOIN dbo.bettrans b  WITH (ROWLOCK, UPDLOCK) ON  sr.transid = b.transid
	OPTION (OPTIMIZE FOR (@batchNo = 1))

	RETURN
	
END
