/*<info serverAlias="DBCTG-bodb02, DBSIC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculation_NetPosition]
    @MatchId	INT
	,@CustId	INT
    ,@Bettype	SMALLINT
	,@Action	VARCHAR(20) = ''
AS
/*	Creator: 20230616@Kathy
	Task: Net postion

	Revisions:
		- 20230616@Kathy: Migrate NetPosition API & Services to NAP Settlement System [Redmine:#187311]
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @AStake					MONEY = 0
			,@Pay1					MONEY = 0
			,@Pay2					MONEY = 0
			,@minPay				MONEY = 0
			,@NPAdjust				MONEY = 0
			,@NPCalculationLogID	BIGINT = 0
			,@Balcount				INT = 0
			,@AccumNPCredit			MONEY = 0
			,@AccumNPDebit			MONEY = 0

	DECLARE @tmpCalculateNP TABLE (Custid INT, Transid BIGINT, Matchid INT, bettype SMALLINT, actual_stake MONEY, Payout1 MONEY, Payout2 MONEY)
	
	-- get trans data
	INSERT INTO @tmpCalculateNP(CustId, TransId, MatchId, bettype, actual_stake, Payout1, Payout2)
	SELECT	NPT.Custid, NPT.Transid, NPT.Matchid, NPT.bettype, NPT.actual_stake, NPT.Payout1, NPT.Payout2 
	FROM	dbo.NetPositionTrans NPT WITH (NOLOCK)
		INNER JOIN bettrans BT WITH (NOLOCK) 
			ON	BT.transid = NPT.transID
	WHERE	NPT.Custid = @Custid 
			AND NPT.Matchid = @Matchid 
			AND NPT.bettype = @bettype 
			AND ISNULL(BT.checkTime,'1999-01-01') < CURRENT_TIMESTAMP 
			AND BT.statusid = 0

	-- get minimum payout(actual_stake, payout1, payout2)
	SELECT	@AStake=SUM(actual_stake)
			,@Pay1=SUM(Payout1)
			,@Pay2 = SUM(Payout2)
			,@mINPay = CASE 
							WHEN @AStake < @Pay1 AND @AStake < @Pay2 THEN @AStake
							WHEN @Pay1 < @AStake AND @Pay1< @Pay2 THEN @Pay1
							ELSE @Pay2 
						END
	FROM	@tmpCalculateNP

	SET @NPAdjust = @minPay

	-- get latest data FROM NPCalculatiONLog
	-- @NPAdjust = totalNP - AccumNP
	SELECT	@NPCalculationLogID = NPCalculationLogID
			,@AccumNPCredit = AccumNPCredit 
			,@AccumNPDebit = AccumNPDebit
			,@NPAdjust = @minPay - (AccumNPCredit - AccumNPDebit)
	FROM	dbo.NetPositionCalculationLog 
	WHERE	Custid = @Custid 
			AND Matchid = @Matchid 
			AND bettype = @bettype 
			AND IsLatest=1 

	-- set accum NP credit and debit 
	SELECT @AccumNPCredit = CASE WHEN @NPAdjust>0 THEN @AccumNPCredit + @NPAdjust ELSE @AccumNPCredit END,
			@AccumNPDebit = CASE WHEN @NPAdjust<0 THEN @AccumNPDebit + ABS(@NPAdjust) ELSE @AccumNPDebit END
	
	-- IF need adjust NP
	IF (@NPAdjust <> 0)
	BEGIN
		-- SELECT NetPositiONCalculatiONLog
		INSERT INTO dbo.NetPositionCalculationLog (Custid,Matchid,Bettype,AccumNPDebit,AccumNPCredit,NPAdjust,IsLatest,CreatedDate,ModifiedDate)
		VALUES (@Custid,@Matchid,@bettype,@AccumNPDebit,@AccumNPCredit,@NPAdjust,1,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)					

		IF(@NPCalculationLogID > 0)
		BEGIN
			-- UPDATE IsLatest = 0
			UPDATE	dbo.NetPositionCalculationLog WITH (ROWLOCK, UPDLOCK)
				SET IsLatest = 0
					,ModifiedDate = CURRENT_TIMESTAMP
			WHERE	NPCalculationLogID = @NPCalculationLogID
		END
	END

	-- if (need adjust NP) or (Action=UNDO): insert/update BalNetPosition
	IF (@NPAdjust <> 0 ) OR @Action = 'UNDO'
	BEGIN
		SELECT	@Balcount = COUNT(1) 
		FROM	dbo.BalNetPosition WITH (NOLOCK) 
		WHERE	Custid = @Custid 
				AND Matchid = @Matchid 
				AND bettype = @bettype

		IF (@Balcount > 0)
		BEGIN
			UPDATE	dbo.BalNetPosition WITH (ROWLOCK, UPDLOCK) 
				SET Credit = @AccumNPCredit
					,Debit = @AccumNPDebit
			WHERE	Custid = @Custid 
					AND Matchid = @Matchid 
					AND bettype = @bettype
		END
		ELSE
		BEGIN
			INSERT INTO dbo.BalNetPosition (Custid, Matchid, Bettype, Debit, Credit)
			VALUES (@Custid, @Matchid, @Bettype, @AccumNPDebit, @AccumNPCredit)
		END
	END
	
	UPDATE	dbo.NetPositionTrans WITH (ROWLOCK, UPDLOCK)
		SET SyncStatus = 1, ModifiedDate = CURRENT_TIMESTAMP
	WHERE	Transid IN (SELECT Transid FROM @tmpCalculateNP)

END

