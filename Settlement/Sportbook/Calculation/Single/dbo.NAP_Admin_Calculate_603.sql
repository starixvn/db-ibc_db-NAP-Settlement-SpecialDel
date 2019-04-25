/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_603] 
	@matchid 			INT
	,@bettype			SMALLINT		= NULL		
	,@strResourceIds	VARCHAR(MAX)	= NULL
	,@result			VARCHAR(MAX)	= NULL	
	,@Action			VARCHAR(20)		= 'CAL'
AS
/*
    Created: 20170220@Kathy
    Task: Basketball - Calculate [Redmine:#71372]
    DB: DBTXN/BODB02
    Original:

    Revisions:
		 - 20170613@Kathy: Early Settlement [Redmine:#77835] 
		 - 20180904@Kathy: Change CIX on DB054 [Redmine:#100828]
		 - 20181004@Kathy: Change CIX on DB053 [Redmine:#102594]
		 - 20181030@Kathy: Change CIX on DB052 [Redmine:#103985]
		 - 20181129@Kathy: Do not settle ticket on DB04x [Redmine:#105327]
		 - 20190227@Sol:  New Formula for Comm [Redmine:#109007]
		 - 20190409@Sol: Settlement Time [Redmine:#99638]
		 
    Param's Explanation:

*/
BEGIN
    SET NOCOUNT ON
	
	-- CHECK SERVER BEFORE CALCULATING
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
			,@AllowUndo			= @AllowUndo OUTPUT
			,@AllowRefund		= @AllowRefund OUTPUT

		IF @Action = 'CAL' AND @AllowCalculation = 0
			RETURN

		IF @Action = 'UNDO' AND @AllowUndo = 0
			RETURN
			
		IF @Action = 'REFUND' AND @AllowRefund = 0
			RETURN
	END
	-- END CHECK
	
	DECLARE @modds				MONEY
			,@commWinRate		SMALLMONEY
			,@commLostRate		SMALLMONEY
			,@commHalfWLRate	SMALLMONEY
			,@xml				XML
			,@top				INT = 1000
			,@winlost			MONEY
			,@stake				MONEY
			,@commBettypeGroupId SMALLINT
			,@statusId			TINYINT
		
	DECLARE @FTHighestQuarter	VARCHAR(10)	
			,@Q1Home			INT
			,@Q2Home			INT
			,@Q3Home			INT
			,@Q4Home			INT			
			,@Q1Away			INT
			,@Q2Away			INT
			,@Q3Away			INT
			,@Q4Away			INT
	
	DECLARE @tmpResultDetail TABLE(ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50))
	CREATE TABLE #tmpTransIds (TransId BIGINT PRIMARY KEY, modds MONEY, custid INT, recommend INT, srecommend INT)	
	DECLARE @settlementTime DATETIME

	IF @Action = 'UNDO'
	BEGIN
		WHILE 1 = 1
		BEGIN
			UPDATE	TOP (@top) b
				SET ruben = 0
					,STATUS = 'running'
					,statusID = 0
					,winlost = 0
					,awinlost = 0
					,mwinlost = 0
					,swinlost = 0
					,playercomm = 0
					,comm = 0
					,acomm = 0
					,scomm = 0
			FROM	dbo.bettrans b WITH (ROWLOCK, UPDLOCK)
				CROSS APPLY (
					SELECT CAST(b.bettype AS VARCHAR) + ISNULL(SUBSTRING(CAST(b.betid AS VARCHAR), 2, LEN(b.betid)), '') AS ResourceId
				) r
			WHERE	b.matchid = @matchid 
					AND	b.statusID NOT IN (0, 1, 102, 101)  ---('running','waiting','void','reject')
					AND CHARINDEX(',' + r.ResourceId + ',', ',' + @strResourceIds + ',') > 0
					
			IF @@ROWCOUNT < @top
				BREAK
		END
	END
	ELSE IF @Action = 'REFUND'
	BEGIN
		WHILE 1 = 1
		BEGIN
			SET @settlementTime = GETDATE();
			UPDATE	TOP (@top) b
				SET [status] = N'Refund'
					,SettlementTime = CASE WHEN winlost <> actual_stake OR statusID <> 103 THEN @settlementTime ELSE SettlementTime END
					,statusID = 103
					,winlost = actual_stake
					,awinlost = 0
					,mwinlost = 0
					,swinlost = 0
					,playercomm = 0
					,comm = 0
					,acomm = 0
					,scomm = 0
					,ruben = 1
					,statuswinlost = 0
			FROM	dbo.bettrans b WITH (ROWLOCK, UPDLOCK)
				CROSS APPLY(
					SELECT CAST(b.bettype AS VARCHAR) + ISNULL(SUBSTRING(CAST(b.betid AS VARCHAR), 2, LEN(b.betid)), '') AS ResourceId
				)r
			WHERE	matchid = @matchid 
					AND statusID NOT IN (103, 101, 102) 
					AND CHARINDEX(',' + r.ResourceId + ',', ',' + @strResourceIds + ',') > 0
					
			IF @@ROWCOUNT < @top
				BREAK
		END
	END
	ELSE IF @Action = 'CAL'
	BEGIN
		SET @xml = CONVERT(XML, @result)	
	
		;WITH cteResult
		AS(
			SELECT	T.c.value('./@rid','VARCHAR(20)') AS ResourceId
					,T.c.value('./@home','VARCHAR(50)') AS HomeValue
					,T.c.value('./@away','VARCHAR(50)') AS AwayValue
			FROM	@xml.nodes('/root/r') AS T(c)
		)
		INSERT INTO @tmpResultDetail(ResourceId, HomeValue, AwayValue)
		SELECT	ResourceId, HomeValue, AwayValue
		FROM	cteResult r
		OPTION ( OPTIMIZE FOR ( @xml = NULL ) )
		
		IF @bettype = 603
		BEGIN		
			SELECT	@FTHighestQuarter = CASE
											WHEN MAX(result.HomeValue) > MAX(result.AwayValue) THEN 'H'
											WHEN MAX(result.HomeValue) < MAX(result.AwayValue) THEN 'A'
											ELSE 'N'
										END
			FROM	@tmpResultDetail t
				CROSS APPLY (
					SELECT CAST(t.HomeValue AS INT) HomeValue
						,CAST(t.AwayValue AS INT) AwayValue
				)result
			WHERE	ResourceId LIKE 'Q[1-4]'
		END	
		
		SELECT	@Q1Home = HomeValue
				,@Q1Away = AwayValue
		FROM	@tmpResultDetail
		WHERE	ResourceId = 'Q1'
		
		SELECT	@Q2Home = HomeValue
				,@Q2Away = AwayValue
		FROM	@tmpResultDetail
		WHERE	ResourceId = 'Q2'
		
		SELECT	@Q3Home = HomeValue
				,@Q3Away = AwayValue
		FROM	@tmpResultDetail
		WHERE	ResourceId = 'Q3'
		
		SELECT	@Q4Home = HomeValue
				,@Q4Away = AwayValue
		FROM	@tmpResultDetail
		WHERE	ResourceId = 'Q4'
		
		INSERT INTO #tmpTransIds (TransId, modds, custid, recommend, srecommend)
		SELECT	b.transid
				,CASE
					WHEN b.bettype = 603 
						THEN CASE 
								WHEN @FTHighestQuarter = 'N' THEN 0
								WHEN b.betteam = @FTHighestQuarter THEN 1 
								ELSE -1 
								END
					WHEN b.bettype IN (604, 605, 606, 607, 613, 617) 
						THEN CASE 
								WHEN t.HomeValue = 'N' THEN 0
								WHEN b.betteam = t.HomeValue THEN 1 
								ELSE -1 
								END
					WHEN b.bettype = 609 
						THEN CASE 
								WHEN betteam = 'h' THEN (m.QXHome - hdp1) - (m.QXAway - hdp2)
								WHEN betteam = 'a' THEN (m.QXAway - hdp2) - (m.QXHome - hdp1)
								ELSE -1
								END
					WHEN b.bettype = 610 
						THEN CASE 
								WHEN betteam = 'o' THEN m.QXHome + m.QXAway - hdp1
								WHEN betteam = 'u' THEN hdp1 - (m.QXHome + m.QXAway) 
								ELSE -1
								END
					WHEN b.bettype = 611 
						THEN CASE
								WHEN b.betteam = 'o' AND (m.QXHome + m.QXAway) % 2 = 1 THEN 1
								WHEN b.betteam = 'e' AND (m.QXHome + m.QXAway) % 2 = 0 THEN 1
								ELSE -1
								END
					WHEN b.bettype = 612 
						THEN CASE
								WHEN b.betteam = 'h' THEN (m.QXHome - m.QXAway)
								WHEN b.betteam = 'a' THEN (m.QXAway - m.QXHome)
								ELSE -1
								END
					WHEN b.bettype = 614 
						THEN CASE 
								WHEN b.betteam = 'H1-4' AND (m.QXHome - m.QXAway) BETWEEN 1 AND 4 THEN 1
								WHEN b.betteam = 'H5-8' AND (m.QXHome - m.QXAway) BETWEEN 5 AND 8 THEN 1
								WHEN b.betteam = 'H9+' AND (m.QXHome - m.QXAway) >= 9 THEN 1
								WHEN b.betteam = 'D' AND (m.QXHome - m.QXAway) = 0 THEN 1
								WHEN b.betteam = 'A1-4' AND (m.QXAway - m.QXHome) BETWEEN 1 AND 4 THEN 1
								WHEN b.betteam = 'A5-8' AND (m.QXAway - m.QXHome) BETWEEN 5 AND 8 THEN 1
								WHEN b.betteam = 'A9+' AND (m.QXAway - m.QXHome) >= 9 THEN 1
								ELSE -1
								END
					WHEN b.bettype = 615 
						THEN CASE
								WHEN b.betteam = 'o' THEN m.QXHome - b.hdp1
								WHEN b.betteam = 'u' THEN b.hdp1 - m.QXHome
								ELSE -1
								END
					WHEN b.bettype = 616 
						THEN CASE
								WHEN b.betteam = 'o' THEN m.QXAway - b.hdp1
								WHEN b.betteam = 'u' THEN b.hdp1 - m.QXAway
								ELSE -1
								END
					ELSE -1
				END AS modds
				,b.custid
				,b.recommend	
				,b.srecommend
		FROM	dbo.bettrans b WITH(ROWLOCK)
			CROSS APPLY (
				SELECT	CASE 
							WHEN @strResourceIds IS NOT NULL 
								THEN CASE 
										WHEN b.bettype IN (605, 607, 617, 604, 606, 613) THEN CAST(b.bettype AS VARCHAR) + ISNULL(SUBSTRING(CAST(b.betid AS VARCHAR), 2, LEN(b.betid)), '')
										ELSE ISNULL(LEFT(CAST(b.betid AS VARCHAR),3),'') -- QuarterX
										END
							
							ELSE ''
						END AS ResourceId
						
			) r
			CROSS APPLY (
				SELECT CASE
							WHEN b.betid = 801 THEN @Q1Home
							WHEN b.betid = 802 THEN @Q2Home
							WHEN b.betid = 803 THEN @Q3Home
							WHEN b.betid = 804 THEN @Q4Home
							ELSE 0
						END AS QXHome
						,CASE
							WHEN b.betid = 801 THEN @Q1Away
							WHEN b.betid = 802 THEN @Q2Away
							WHEN b.betid = 803 THEN @Q3Away
							WHEN b.betid = 804 THEN @Q4Away
							ELSE 0
						END AS QXAway
			) m
			LEFT JOIN @tmpResultDetail t
				ON r.ResourceId = t.ResourceId
		WHERE	matchid = @Matchid
				AND bettype = @BetType
				AND 1 = CASE
							WHEN b.bettype = 603 THEN 1
							WHEN @strResourceIds IS NOT NULL AND CHARINDEX(',' + r.ResourceId + ',', ',' + @strResourceIds + ',') > 0 THEN 1
							ELSE 0
						END
					
		CREATE TABLE #tempCust(custid INT PRIMARY KEY, isCN88 BIT)

		INSERT INTO #tempCust(custid, isCN88)
		SELECT	tmp.custid, CASE WHEN cs.CustId IS NULL THEN 0 ELSE 1 END
		FROM	#tmpTransIds tmp
			LEFT JOIN dbo.CS_CustSuper cs WITH(NOLOCK)
				   ON tmp.srecommend = cs.CustId
		GROUP BY tmp.custid, cs.CustId

		-- get CommBettypeGroupId 
		SELECT @commBettypeGroupId = CommBettypeGroupId FROM dbo.f_Set_GetGroupBettypes() AS f WHERE BetType = @bettype;

		CREATE TABLE #currList (custid INT PRIMARY KEY, isCN88 BIT)
		DECLARE @MinCustId INT

		WHILE (1=1)
		BEGIN
			DELETE FROM #currList

			DELETE TOP (1000)
			FROM #tempCust OUTPUT DELETED.custid, DELETED.isCN88 INTO #currList
			IF @@ROWCOUNT = 0 BREAK

			SELECT @MinCustId = MIN(CustId) FROM #currList
			SET @settlementTime = GETDATE();

			UPDATE	b 
				SET @modds = t.modds
					,modds = @modds
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
					,@commHalfWLRate = CASE WHEN c.isCN88 = 1 AND @commBettypeGroupId = 1 THEN 1
							ELSE 0.5
						END		
					, @winlost = CASE 
						WHEN @modds > 0.25 THEN actual_stake + stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype = 614 THEN odds - 1 ELSE odds END) END)
						WHEN @modds = 0.25 THEN actual_stake + stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype = 614 THEN odds - 1 ELSE odds END) END) * 0.5
						WHEN @modds = 0 THEN actual_stake
						WHEN @modds = -0.25 THEN actual_stake * 0.5
						WHEN @modds < -0.25 THEN 0
						END  
					-- check if bettype belongs to major comm group (CommBettypeGroupId = 1) and calc comm with new formula
					, @stake = CASE WHEN c.isCN88 = 1 AND @commBettypeGroupId = 1 THEN ABS(@winlost - actual_stake)
									ELSE stake 
								END
					-- check winlost or status change to update SettlementTime
					,@statusId = CASE
									WHEN @modds > 0 THEN 112 --WON
									WHEN @modds = 0 THEN 111 --DRAW
									WHEN @modds < 0 THEN 113 --LOSE
								END
					,SettlementTime = CASE WHEN winlost <> @winlost OR statusID <> @statusId THEN @settlementTime ELSE SettlementTime END
					, WinLost = @winlost
					, aWinLost = CASE 
						WHEN @modds > 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype = 614 THEN odds - 1 ELSE odds END) END) * -apositiontaking
						WHEN @modds = 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype = 614 THEN odds - 1 ELSE odds END) END) * -apositiontaking * 0.5
						WHEN @modds = 0 THEN 0
						WHEN @modds = -0.25 THEN actual_stake * apositiontaking * 0.5
						WHEN @modds < -0.25 THEN actual_stake * apositiontaking
						END
					, mWinLost = CASE
						WHEN @modds > 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype = 614 THEN odds - 1 ELSE odds END) END) * -mpositiontaking
						WHEN @modds = 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype = 614 THEN odds - 1 ELSE odds END) END) * -mpositiontaking * 0.5
						WHEN @modds = 0 THEN 0
						WHEN @modds = -0.25 THEN actual_stake * mpositiontaking * 0.5
						WHEN @modds < -0.25 THEN actual_stake * mpositiontaking
						END
					, sWinLost = CASE
						WHEN @modds > 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype = 614 THEN odds - 1 ELSE odds END) END) * -spositiontaking
						WHEN @modds = 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype = 614 THEN odds - 1 ELSE odds END) END) * -spositiontaking * 0.5
						WHEN @modds = 0 THEN 0
						WHEN @modds = -0.25 THEN actual_stake * spositiontaking * 0.5
						WHEN @modds < -0.25 THEN actual_stake * spositiontaking
						END
					, PlayerComm = CASE
						WHEN @modds > 0.25 THEN @commWinRate * playerdiscount * @stake
						WHEN @modds = 0.25 THEN @commWinRate * playerdiscount * @stake * @commHalfWLRate
						WHEN @modds = 0 THEN 0
						WHEN @modds = -0.25 THEN @commLostRate * playerdiscount * @stake * @commHalfWLRate
						WHEN @modds < -0.25 THEN @commLostRate * playerdiscount * @stake
						END
					, Comm = CASE
						WHEN @modds > 0.25 THEN @commWinRate * discount * @stake * (1-apositiontaking)
						WHEN @modds = 0.25 THEN @commWinRate * discount * @stake * (1-apositiontaking) * @commHalfWLRate
						WHEN @modds = 0 THEN 0
						WHEN @modds = -0.25 THEN @commLostRate * discount * @stake * (1-apositiontaking) * @commHalfWLRate
						WHEN @modds < -0.25 THEN @commLostRate * discount * @stake * (1-apositiontaking)
						END
					, aComm = CASE
						WHEN @modds > 0.25 THEN @commWinRate * adiscount * @stake * (1-(mpositiontaking+apositiontaking))
						WHEN @modds = 0.25 THEN @commWinRate * adiscount * @stake * (1-(mpositiontaking+apositiontaking)) * @commHalfWLRate
						WHEN @modds = 0 THEN 0
						WHEN @modds = -0.25 THEN @commLostRate * adiscount * @stake * (1-(mpositiontaking+apositiontaking)) * @commHalfWLRate
						WHEN @modds < -0.25 THEN @commLostRate * adiscount * @stake * (1-(mpositiontaking+apositiontaking))
						END
					, sComm = CASE
						WHEN @modds > 0.25 THEN @commWinRate * sdiscount * @stake * (1-(spositiontaking+mpositiontaking+apositiontaking))
						WHEN @modds = 0.25 THEN @commWinRate * sdiscount * @stake * (1-(spositiontaking+mpositiontaking+apositiontaking)) * @commHalfWLRate
						WHEN @modds = 0 THEN 0
						WHEN @modds = -0.25 THEN @commLostRate * sdiscount * @stake * (1-(spositiontaking+mpositiontaking+apositiontaking)) * @commHalfWLRate
						WHEN @modds < -0.25 THEN @commLostRate * sdiscount * @stake * (1-(spositiontaking+mpositiontaking+apositiontaking))
						END
					, Status = CASE
						WHEN @modds > 0 THEN N'WON'
						WHEN @modds = 0 THEN 'DRAW'
						WHEN @modds < 0 THEN N'LOSE'
						END
					, StatusID = @statusId
					, ruben = 1
			FROM	#currList c
				INNER JOIN dbo.bettrans b WITH (ROWLOCK, UPDLOCK)
					ON c.custid = b.custid
				INNER JOIN #tmpTransIds t
					ON b.transid = t.TransId
			WHERE	b.matchid = @matchid
					AND b.custid >= @MinCustId
					AND b.bettype = @bettype
					AND b.statusID NOT IN (101, 102)
			OPTION (FORCE ORDER)
		END
	END
	
END

GO
