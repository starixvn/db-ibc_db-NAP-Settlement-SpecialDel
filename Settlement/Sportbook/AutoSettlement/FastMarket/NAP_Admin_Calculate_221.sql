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

	SET @xmlData = CONVERT(XML, @result)
	
	CREATE TABLE #tblTransIds(transid BIGINT PRIMARY KEY, BetOption TINYINT)	
	
	;WITH TmpData AS (
		SELECT T.C.value('@Id', 'SMALLINT') AS Bettype
			,X.C.value('@p','TINYINT') as Position
			,X.C.value('@r','TINYINT') as BetOption
		FROM @xmlData.nodes('/r/b') AS T(C)
			CROSS APPLY
				C.nodes('r') AS X(C)
	)
	INSERT INTO #tblTransIds (transid, BetOption)
	SELECT	b.transid, t.BetOption
	FROM	tmpData t
		INNER JOIN dbo.bettrans b WITH(NOLOCK)
			ON	b.matchid = @matchid
				AND b.bettype = t.Bettype
				AND b.hdp1 = t.Position
	WHERE	b.statusID NOT IN (101, 102)
	OPTION ( OPTIMIZE FOR ( @XmlData = NULL ) )	
	
	IF @action = 'CAL'
	BEGIN		
		UPDATE b
			SET @modds = CASE WHEN betteam > 0 AND (CAST(hdp2 AS INT) & t.betoption) > 0 THEN 1
							WHEN betteam = 0 AND (CAST(hdp2 AS INT) & (t.betoption ^ 65535)) > 0 THEN 1
						ELSE -1 END
			, modds = @modds
			, @commWinRate = CASE comstatus -- 0 : pay normal, both win/lost -- 1 : pay 'double' ONLY on lost
								WHEN '0' THEN 1
								WHEN '1' THEN 0
							ELSE 1 END
			, @commLostRate = CASE comstatus
								WHEN '0' THEN 1
								WHEN '1' THEN 2
							ELSE 1 END
	        
			, WinLost = CASE 
				WHEN @modds > 0.25 THEN actual_stake + stake * (CASE WHEN odds < 0 THEN 1 ELSE odds - 1 END)
				WHEN @modds = 0.25 THEN actual_stake + stake * (CASE WHEN odds < 0 THEN 1 ELSE odds - 1 END) * 0.5
				WHEN @modds = 0 THEN actual_stake
				WHEN @modds = -0.25 THEN actual_stake * 0.5
				WHEN @modds < -0.25 THEN 0
			END
			, aWinLost = CASE 
				WHEN @modds > 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE odds - 1 END) * -apositiontaking
				WHEN @modds = 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE odds - 1 END) * -apositiontaking * 0.5
				WHEN @modds = 0 THEN 0
				WHEN @modds = -0.25 THEN actual_stake * apositiontaking * 0.5
				WHEN @modds < -0.25 THEN actual_stake * apositiontaking
			END
			, mWinLost = CASE
				WHEN @modds > 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE odds - 1 END) * -mpositiontaking
				WHEN @modds = 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE odds - 1 END) * -mpositiontaking * 0.5
				WHEN @modds = 0 THEN 0
				WHEN @modds = -0.25 THEN actual_stake * mpositiontaking * 0.5
				WHEN @modds < -0.25 THEN actual_stake * mpositiontaking
				END
			, sWinLost = CASE
				WHEN @modds > 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE odds - 1 END) * -spositiontaking
				WHEN @modds = 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE odds - 1 END) * -spositiontaking * 0.5
				WHEN @modds = 0 THEN 0
				WHEN @modds = -0.25 THEN actual_stake * spositiontaking * 0.5
				WHEN @modds < -0.25 THEN actual_stake * spositiontaking
			 END
			, PlayerComm = CASE
				WHEN @modds > 0.25 THEN @commWinRate * playerdiscount * stake
				WHEN @modds = 0.25 THEN @commWinRate * playerdiscount * stake * 0.5
				WHEN @modds = 0 THEN 0
				WHEN @modds = -0.25 THEN @commLostRate * playerdiscount * stake * 0.5
				WHEN @modds < -0.25 THEN @commLostRate * playerdiscount * stake
				END
			, Comm = CASE
				WHEN @modds > 0.25 THEN @commWinRate * discount * stake * (1-apositiontaking)
				WHEN @modds = 0.25 THEN @commWinRate * discount * stake * (1-apositiontaking) * 0.5
				WHEN @modds = 0 THEN 0
				WHEN @modds = -0.25 THEN @commLostRate * discount * stake * (1-apositiontaking) * 0.5
				WHEN @modds < -0.25 THEN @commLostRate * discount * stake * (1-apositiontaking)
				END
			, aComm = CASE
				WHEN @modds > 0.25 THEN @commWinRate * adiscount * stake * (1-(mpositiontaking+apositiontaking))
				WHEN @modds = 0.25 THEN @commWinRate * adiscount * stake * (1-(mpositiontaking+apositiontaking)) * 0.5
				WHEN @modds = 0 THEN 0
				WHEN @modds = -0.25 THEN @commLostRate * adiscount * stake * (1-(mpositiontaking+apositiontaking)) * 0.5
				WHEN @modds < -0.25 THEN @commLostRate * adiscount * stake * (1-(mpositiontaking+apositiontaking))
				END
			, sComm = CASE
				WHEN @modds > 0.25 THEN @commWinRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking))
				WHEN @modds = 0.25 THEN @commWinRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking)) * 0.5
				WHEN @modds = 0 THEN 0
				WHEN @modds = -0.25 THEN @commLostRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking)) * 0.5
				WHEN @modds < -0.25 THEN @commLostRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking))
				END

			, Status = CASE
				WHEN @modds > 0 THEN N'WON'
				WHEN @modds = 0 THEN 'DRAW'
				WHEN @modds < 0 THEN N'LOSE'
				END
			, StatusID = CASE
				WHEN @modds > 0 THEN 112 --WON
				WHEN @modds = 0 THEN 111 --DRAW
				WHEN @modds < 0 THEN 113 --LOSE
				END
			, ruben = 1
			FROM	dbo.bettrans b WITH (ROWLOCK, UPDLOCK)
				INNER JOIN #tblTransIds t
					ON b.transid = t.transid
				OUTER APPLY (
					SELECT	mt.TransId
					FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
					WHERE	mt.TransId = b.transId
				)mt
			WHERE	b.statusID = CASE WHEN @IsReSettledTickets = 0 THEN 0 ELSE b.statusID END
					AND mt.TransId IS NULL
	END
	ELSE IF @action = 'UNDO'
	BEGIN
		UPDATE	b
			SET STATUS = 'running'
				, statusID = 0
				, winlost = 0
				, awinlost = 0
				, mwinlost = 0
				, swinlost = 0
				, playercomm = 0
				, comm = 0
				, acomm = 0
				, scomm = 0
				, ruben = 0
		FROM	dbo.bettrans b WITH (ROWLOCK, UPDLOCK)
			INNER JOIN #tblTransIds t
				ON	b.transid = t.transid				
	END
	ELSE IF @action = 'REFUND'
	BEGIN
		UPDATE	b
			SET status = N'Refund'
				, statusID = 103
				, winlost = actual_stake
				, awinlost = 0
				, mwinlost = 0
				, swinlost = 0
				, playercomm = 0
				, comm = 0
				, acomm = 0
				, scomm = 0
				, ruben = 1
				, statuswinlost = 0
		FROM	dbo.bettrans b WITH (ROWLOCK, UPDLOCK)
			INNER JOIN #tblTransIds t
				ON	b.transid = t.transid	
	END
END
GO