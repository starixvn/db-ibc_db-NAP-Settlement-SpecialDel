/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Admin_Calculate_221 @matchid INT
	, @result VARCHAR(MAX)
	, @action VARCHAR(20)
	, @IsReSettledTickets BIT = 1
AS
/*
    Created: 20160428@Patrick
    Task: Fast Market - Calculate
    DB: DBTXN/BODB02
    Original:

    Revisions:
		- 20170113@Kathy:  Enhancement for Fast Market [Redmine:#69951]
		- 20180227@Kathy: Integrate Fast Market Phase 2 [Redmine:#90632]
		- 20181129@Kathy: Do not settle ticket on DB04x [Redmine:#105327]
		- 20190320@Kathy: Settlement with Tickets Exclusion [Redmine:#106823]
		- 20190409@Sol: Settlement Time [Redmine:#99638]
		- 20190715@Helen: Recover/Void tickets in Bet 14 - Update statuswinlost for VOID Tickets [Redmine:115377]
		- 20200928@Helen: Implement New Bettype 288 Time Machine Over/Under [Redmine:#142001]
		
    Param's Explanation:

*/
BEGIN
    SET NOCOUNT ON
	
	DECLARE @ServerName			SYSNAME 
			,@AllowCalculation	BIT
			,@AllowUndo			BIT
			,@AllowRefund		BIT

	SET @ServerName = @@SERVERNAME

	IF OBJECT_ID('NAP_Set_ServerAction', 'P') IS NOT NULL
	BEGIN
		EXEC [dbo].[NAP_Set_ServerAction]
			@ServerName			= @ServerName
			,@AllowCalculation	= @AllowCalculation	OUTPUT
			,@AllowUndo			= @AllowUndo		OUTPUT
			,@AllowRefund		= @AllowRefund		OUTPUT

		IF @action = 'CAL' AND @AllowCalculation = 0
			RETURN

		IF @action = 'UNDO' AND @AllowUndo = 0
			RETURN

		IF @action = 'REFUND' AND @AllowRefund = 0
			RETURN
	END
	    
    DECLARE @modds			MONEY
			,@commWinRate	SMALLMONEY
			,@commLostRate	SMALLMONEY
			,@xmlData		XML
			,@statusId TINYINT
			,@winlost MONEY
			,@IsUpd_Void BIT = 0
			,@SDT_totalGoals_228 TINYINT = 0
			,@SDT_Position_228 TINYINT = 0
			,@bettype_228 SMALLINT = 228
	
	DECLARE @settlementTime DATETIME
			
	SET @xmlData = CONVERT(XML, @result)
	
	CREATE TABLE #tblTransIds(transid BIGINT PRIMARY KEY, BetOption TINYINT)	
	DECLARE @TmpData AS TABLE (bettype SMALLINT, Position TINYINT,BetOption TINYINT )
	
	INSERT INTO @TmpData (bettype,Position,BetOption)
	SELECT T.C.value('@Id', 'SMALLINT') AS Bettype
		,X.C.value('@p','TINYINT') as Position
		,X.C.value('@r','TINYINT') as BetOption
	FROM @xmlData.nodes('/r/b') AS T(C)
		CROSS APPLY
			C.nodes('r') AS X(C)
	OPTION ( OPTIMIZE FOR ( @XmlData = NULL ) )			
	
	SELECT TOP 1 @SDT_totalGoals_228 = BetOption
			,@SDT_Position_228 = CASE 
										WHEN Position >= 46 THEN (Position -1) 
										ELSE Position 
								END
	FROM  @TmpData WHERE bettype = @bettype_228
	ORDER BY Position DESC
	
	INSERT INTO #tblTransIds (transid, BetOption)
	SELECT	b.transid, t.BetOption
	FROM	@TmpData t
		INNER JOIN dbo.bettrans b WITH(NOLOCK)
			ON	b.matchid = @matchid
				AND b.bettype = t.Bettype
	WHERE	b.statusID NOT IN (101,102)
			AND 1 = CASE WHEN t.bettype = @bettype_228 AND t.Position IN (44,45,90) THEN 0 ELSE 1 END
			AND (
				(b.hdp1 = (CASE WHEN t.Bettype = @bettype_228 AND t.Position >= 46 THEN (t.Position -1) ELSE t.Position END)) 				
				-- SDT 228
				OR (@action = 'CAL' AND t.bettype = @bettype_228 
					AND hdp1 > @SDT_Position_228 
					AND @SDT_totalGoals_228 - b.oddsspread  > 0.25 ) 
			)
	
	IF @action = 'CAL'
	BEGIN		
		SET @settlementTime = GETDATE();

		UPDATE b
			SET @modds = CASE 
							WHEN bettype = 228 AND b.betteam = 'o' THEN t.BetOption - b.oddsspread 
							WHEN bettype = 228 AND b.betteam = 'u' THEN b.oddsspread  - t.BetOption
							WHEN bettype <> 228 AND betteam > 0 AND (CAST(hdp2 AS INT) & t.betoption) > 0 THEN 1
							WHEN bettype <> 228 AND betteam = 0 AND (CAST(hdp2 AS INT) & (t.betoption ^ 65535)) > 0 THEN 1
						ELSE -1 END
			, @IsUpd_Void = CASE WHEN (statusID = 102) OR (mt.TransId IS NOT NULL) THEN 0 ELSE 1 END
			, modds = @modds
			, statuswinlost = CASE WHEN @modds > 0.25 THEN 2
								WHEN @modds = 0.25 THEN 1 
								WHEN @modds = 0 THEN 0 
								WHEN @modds = - 0.25 THEN 3
								WHEN @modds < - 0.25 THEN 4
								WHEN @modds IS NULL THEN 6
							END
							
			, @commWinRate = CASE comstatus -- 0 : pay normal, both win/lost -- 1 : pay 'double' ONLY on lost
								WHEN '0' THEN 1
								WHEN '1' THEN 0
							ELSE 1 END
			, @commLostRate = CASE comstatus
								WHEN '0' THEN 1
								WHEN '1' THEN 2
							ELSE 1 END
	        -- check winlost or status change to update SettlementTime
			,@statusId = CASE
							WHEN @modds > 0 THEN 112 --WON
							WHEN @modds = 0 THEN 111 --DRAW
							WHEN @modds < 0 THEN 113 --LOSE
						END
			,@winlost = CASE 
							WHEN @modds > 0.25 THEN actual_stake + stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype = @bettype_228 THEN odds ELSE (odds - 1) END) END)
							WHEN @modds = 0.25 THEN actual_stake + stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype = @bettype_228 THEN odds ELSE (odds - 1) END) END) * 0.5
							WHEN @modds = 0 THEN actual_stake
							WHEN @modds = -0.25 THEN actual_stake * 0.5
							WHEN @modds < -0.25 THEN 0
						END
			,SettlementTime = CASE 
							WHEN @IsUpd_Void = 0 THEN SettlementTime 
							ELSE CASE WHEN winlost <> @winlost OR statusID <> @statusId THEN @settlementTime ELSE SettlementTime END
						END
						
			, WinLost = CASE 
							WHEN @IsUpd_Void = 0 THEN WinLost 
							ELSE @winlost
						END
			, aWinLost = CASE 
							WHEN @IsUpd_Void = 0 THEN aWinLost 
							ELSE CASE 
									WHEN @modds > 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype = @bettype_228 THEN odds ELSE (odds - 1) END) END) * -apositiontaking
									WHEN @modds = 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype = @bettype_228 THEN odds ELSE (odds - 1) END) END) * -apositiontaking * 0.5
									WHEN @modds = 0 THEN 0
									WHEN @modds = -0.25 THEN actual_stake * apositiontaking * 0.5
									WHEN @modds < -0.25 THEN actual_stake * apositiontaking
								END
						END
						
			, mWinLost = CASE 
							WHEN @IsUpd_Void = 0 THEN mWinLost 
							ELSE CASE
									WHEN @modds > 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype = @bettype_228 THEN odds ELSE (odds - 1) END) END) * -mpositiontaking
									WHEN @modds = 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype = @bettype_228 THEN odds ELSE (odds - 1) END) END) * -mpositiontaking * 0.5
									WHEN @modds = 0 THEN 0
									WHEN @modds = -0.25 THEN actual_stake * mpositiontaking * 0.5
									WHEN @modds < -0.25 THEN actual_stake * mpositiontaking
								END
						END
						
			, sWinLost = CASE 
							WHEN @IsUpd_Void = 0 THEN sWinLost 
							ELSE CASE
									WHEN @modds > 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype = @bettype_228 THEN odds ELSE (odds - 1) END) END) * -spositiontaking
									WHEN @modds = 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype = @bettype_228 THEN odds ELSE (odds - 1) END) END) * -spositiontaking * 0.5
									WHEN @modds = 0 THEN 0
									WHEN @modds = -0.25 THEN actual_stake * spositiontaking * 0.5
									WHEN @modds < -0.25 THEN actual_stake * spositiontaking
								 END
						END
						
			, PlayerComm = CASE 
							WHEN @IsUpd_Void = 0 THEN PlayerComm 
							ELSE CASE
									WHEN @modds > 0.25 THEN @commWinRate * playerdiscount * stake
									WHEN @modds = 0.25 THEN @commWinRate * playerdiscount * stake * 0.5
									WHEN @modds = 0 THEN 0
									WHEN @modds = -0.25 THEN @commLostRate * playerdiscount * stake * 0.5
									WHEN @modds < -0.25 THEN @commLostRate * playerdiscount * stake
								END
						END
						
			, Comm = CASE 
							WHEN @IsUpd_Void = 0 THEN Comm 
							ELSE CASE
									WHEN @modds > 0.25 THEN @commWinRate * discount * stake * (1-apositiontaking)
									WHEN @modds = 0.25 THEN @commWinRate * discount * stake * (1-apositiontaking) * 0.5
									WHEN @modds = 0 THEN 0
									WHEN @modds = -0.25 THEN @commLostRate * discount * stake * (1-apositiontaking) * 0.5
									WHEN @modds < -0.25 THEN @commLostRate * discount * stake * (1-apositiontaking)
								END
						END
						
			, aComm = CASE 
							WHEN @IsUpd_Void = 0 THEN aComm 
							ELSE CASE
									WHEN @modds > 0.25 THEN @commWinRate * adiscount * stake * (1-(mpositiontaking+apositiontaking))
									WHEN @modds = 0.25 THEN @commWinRate * adiscount * stake * (1-(mpositiontaking+apositiontaking)) * 0.5
									WHEN @modds = 0 THEN 0
									WHEN @modds = -0.25 THEN @commLostRate * adiscount * stake * (1-(mpositiontaking+apositiontaking)) * 0.5
									WHEN @modds < -0.25 THEN @commLostRate * adiscount * stake * (1-(mpositiontaking+apositiontaking))
								END
						END
						
			, sComm = CASE 
							WHEN @IsUpd_Void = 0 THEN sComm 
							ELSE CASE
									WHEN @modds > 0.25 THEN @commWinRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking))
									WHEN @modds = 0.25 THEN @commWinRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking)) * 0.5
									WHEN @modds = 0 THEN 0
									WHEN @modds = -0.25 THEN @commLostRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking)) * 0.5
									WHEN @modds < -0.25 THEN @commLostRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking))
								END
						END
						

			, Status = CASE 
							WHEN @IsUpd_Void = 0 THEN b.[status] 
							ELSE CASE
									WHEN @modds > 0 THEN N'WON'
									WHEN @modds = 0 THEN 'DRAW'
									WHEN @modds < 0 THEN N'LOSE'
								END
						END
						
			, StatusID = CASE 
							WHEN @IsUpd_Void = 0 THEN StatusID 
							ELSE @statusId
						END
						
			, ruben = CASE 
							WHEN @IsUpd_Void = 0 THEN ruben 
							ELSE 1
						END
						
			FROM	dbo.bettrans b WITH (ROWLOCK, UPDLOCK)
				INNER JOIN #tblTransIds t
					ON b.transid = t.transid
				OUTER APPLY (
					SELECT	mt.TransId
					FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
					WHERE	mt.TransId = b.transId
				)mt
			WHERE	1 = CASE WHEN @IsReSettledTickets = 0 AND statusID IN (0,102) THEN 1
						 WHEN @IsReSettledTickets = 1 THEN 1
						 ELSE 0
					END
	END
	ELSE IF @action = 'UNDO'
	BEGIN
		UPDATE	b
			SET 
				@IsUpd_Void = CASE WHEN statusID = 102 THEN 0 ELSE 1 END
				, STATUS = CASE WHEN @IsUpd_Void = 0 THEN [status] ELSE 'running' END
				, statusID = CASE WHEN @IsUpd_Void = 0 THEN statusID ELSE 0 END
				, winlost = CASE WHEN @IsUpd_Void = 0 THEN winlost ELSE 0 END 
				, awinlost = 0
				, mwinlost = 0
				, swinlost = 0
				, playercomm = 0
				, comm = 0
				, acomm = 0
				, scomm = 0
				, ruben = CASE WHEN @IsUpd_Void= 0 THEN ruben ELSE 0 END 
				, statuswinlost = NULL
		FROM	dbo.bettrans b WITH (ROWLOCK, UPDLOCK)
			INNER JOIN #tblTransIds t
				ON	b.transid = t.transid				
	END
	ELSE IF @action = 'REFUND'
	BEGIN
		SET @settlementTime = GETDATE();
		UPDATE	b
			SET 
				@IsUpd_Void = CASE WHEN statusID = 102 THEN 0 ELSE 1 END
				,status = CASE WHEN @IsUpd_Void = 0 THEN [status] ELSE N'Refund' END
				,SettlementTime = CASE 
									WHEN @IsUpd_Void = 0 THEN SettlementTime 
									ELSE CASE WHEN winlost <> actual_stake OR statusID <> 103 THEN @settlementTime ELSE SettlementTime END
								END
								
				, statusID = CASE 
								WHEN @IsUpd_Void = 0 THEN statusID 
								ELSE 103
							END
									
				, winlost = actual_stake
				, awinlost = 0
				, mwinlost = 0
				, swinlost = 0
				, playercomm = 0
				, comm = 0
				, acomm = 0
				, scomm = 0
				, ruben = 1
				, statuswinlost = 6
								
		FROM	dbo.bettrans b WITH (ROWLOCK, UPDLOCK)
			INNER JOIN #tblTransIds t
				ON	b.transid = t.transid	
	END
END
GO