/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Admin_Calculate_609 
	@matchid 			INT
	,@result			VARCHAR(MAX)
	,@SelectedQuarter	VARCHAR(50)
AS
/*
    Created: 20170220@Kathy
    Task: Basketball - Calculate [Redmine:#71372]
    DB: DBTXN/BODB02
    Original:

    Revisions:
			- 20170525@Kathy: Add logic for bettype 617 [Redmine:#77046]
			
    Param's Explanation:
	

*/
BEGIN
    SET NOCOUNT ON
	
	IF @@SERVERNAME IN ('DB04', 'DB042', 'DB043', 'DB044') RETURN
	
	DECLARE	@modds MONEY
			,@commWinRate SMALLMONEY
			,@commLostRate SMALLMONEY
			,@xml		XML
	
	CREATE TABLE #tmpTransIds (transid BIGINT PRIMARY KEY, modds MONEY)
	
	SET @xml = CONVERT(XML, @result)
		
	DECLARE @tmpData TABLE (QuarterX VARCHAR(3), QXHome INT, QXAway INT, QXRaceTo10 VARCHAR(10), QXRaceTo15 VARCHAR(10), QXRaceTo20 VARCHAR(20), QXLastBasket VARCHAR(10))
	INSERT INTO @tmpData
	SELECT	'801' AS QuarterX
			,CAST(ISNULL(T.C.value('./@Q1Home[1]', 'INT'), 0) AS INT) QXHome
			,CAST(ISNULL(T.C.value('./@Q1Away[1]', 'INT'), 0) AS INT) QXAway
			,CAST(ISNULL(T.C.value('./@Q1RaceTo10[1]', 'VARCHAR(10)'), '') AS VARCHAR(10)) QXRaceTo10
			,CAST(ISNULL(T.C.value('./@Q1RaceTo15[1]', 'VARCHAR(10)'), '') AS VARCHAR(10)) QXRaceTo15
			,CAST(ISNULL(T.C.value('./@Q1RaceTo20[1]', 'VARCHAR(10)'), '') AS VARCHAR(10)) QXRaceTo20
			,CAST(ISNULL(T.C.value('./@Q1LastBasket[1]', 'VARCHAR(10)'), '') AS VARCHAR(10)) QXLastBasket
	FROM	@xml.nodes('/root/r') AS T(c) -- Table/Column
	WHERE	@SelectedQuarter LIKE '%801%'
	
	UNION ALL		
	SELECT	'802' AS QuarterX
			,ISNULL(T.C.value('./@Q2Home[1]', 'INT'), 0) QXHome
			,ISNULL(T.C.value('./@Q2Away[1]', 'INT'), 0) QXAway
			,ISNULL(T.C.value('./@Q2RaceTo10[1]', 'VARCHAR(10)'), '') QXRaceTo10
			,ISNULL(T.C.value('./@Q2RaceTo15[1]', 'VARCHAR(10)'), '') QXRaceTo15
			,ISNULL(T.C.value('./@Q2RaceTo20[1]', 'VARCHAR(10)'), '') QXRaceTo20
			,ISNULL(T.C.value('./@Q2LastBasket[1]', 'VARCHAR(10)'), '') QXLastBasket
	FROM	@xml.nodes('/root/r') AS T(c) -- Table/Column
	WHERE	@SelectedQuarter LIKE '%802%'
	
	UNION ALL		
	SELECT	'803' AS QuarterX
			,ISNULL(T.C.value('./@Q3Home[1]', 'INT'), 0) QXHome
			,ISNULL(T.C.value('./@Q3Away[1]', 'INT'), 0) QXAway
			,ISNULL(T.C.value('./@Q3RaceTo10[1]', 'VARCHAR(10)'), '') QXRaceTo10
			,ISNULL(T.C.value('./@Q3RaceTo15[1]', 'VARCHAR(10)'), '') QXRaceTo15
			,ISNULL(T.C.value('./@Q3RaceTo20[1]', 'VARCHAR(10)'), '') QXRaceTo20
			,ISNULL(T.C.value('./@Q3LastBasket[1]', 'VARCHAR(10)'), '') QXLastBasket
	FROM	@xml.nodes('/root/r') AS T(c) -- Table/Column
	WHERE	@SelectedQuarter LIKE '%803%'
	
	UNION ALL		
	SELECT	'804' AS QuarterX
			,ISNULL(T.C.value('./@Q4Home[1]', 'INT'), 0) QXHome
			,ISNULL(T.C.value('./@Q4Away[1]', 'INT'), 0) QXAway
			,ISNULL(T.C.value('./@Q4RaceTo10[1]', 'VARCHAR(10)'), '') QXRaceTo10
			,ISNULL(T.C.value('./@Q4RaceTo15[1]', 'VARCHAR(10)'), '') QXRaceTo15
			,ISNULL(T.C.value('./@Q4RaceTo20[1]', 'VARCHAR(10)'), '') QXRaceTo20
			,ISNULL(T.C.value('./@Q4LastBasket[1]', 'VARCHAR(10)'), '') QXLastBasket
	FROM	@xml.nodes('/root/r') AS T(c) -- Table/Column
	WHERE	@SelectedQuarter LIKE '%804%'
	OPTION ( OPTIMIZE FOR ( @xml = NULL )) 
			
	
	IF @@SERVERNAME IN ('DB052', 'DB053', 'DB054','DB231','DB215')
    BEGIN
        DECLARE @affectedagents INT

        CREATE TABLE #tmpRecommend(recommend INT  PRIMARY KEY)
        
        INSERT INTO #tmpRecommend(recommend)
        SELECT	DISTINCT recommend
        FROM	dbo.bettrans WITH(NOLOCK) 
        WHERE	matchid = @matchid 
				AND bettype BETWEEN 609 AND 617

        DECLARE @currecommend TABLE(recommend int PRIMARY KEY)
        
        WHILE (1=1)
        BEGIN
			DELETE 
            FROM @currecommend

            DELETE TOP (100)
            FROM #tmpRecommend OUTPUT DELETED.recommend INTO @currecommend

            SET @affectedagents = @@rowcount
            
            UPDATE	b 
				SET @modds = CASE b.bettype
						WHEN 609 THEN CASE 
										WHEN b.betteam = 'h' THEN (QXHome - b.hdp1) - (QXAway - b.hdp2)
										WHEN b.betteam = 'a' THEN (QXAway - b.hdp2) - (QXHome - b.hdp1)
										ELSE - 1
									END
						WHEN 610 THEN CASE 
										WHEN b.betteam = 'o' THEN QXHome + QXAway - b.hdp1
										WHEN b.betteam = 'u' THEN b.hdp1 - (QXHome + QXAway)	
										ELSE -1
									END
						WHEN 611 THEN CASE
										WHEN b.betteam = 'o' AND (QXHome + QXAway) % 2 = 1 THEN 1
										WHEN b.betteam = 'e' AND (QXHome + QXAway) % 2 = 0 THEN 1
										ELSE -1
									END
						WHEN 612 THEN CASE
										WHEN b.betteam = 'h' THEN (QXHome - QXAway)
										WHEN b.betteam = 'a' THEN (QXAway - QXHome)
										ELSE -1
									END
						WHEN 613 THEN CASE
										WHEN b.betid LIKE '___10' AND QXRaceTo10 = 'N' THEN 0
										WHEN b.betid LIKE '___15' AND QXRaceTo15 = 'N' THEN 0
										WHEN b.betid LIKE '___20' AND QXRaceTo20 = 'N' THEN 0
										WHEN b.betid LIKE '___10' AND b.betteam = QXRaceTo10 THEN 1
										WHEN b.betid LIKE '___15' AND b.betteam = QXRaceTo15 THEN 1
										WHEN b.betid LIKE '___20' AND b.betteam = QXRaceTo20 THEN 1
										ELSE -1
									END
						WHEN 614 THEN CASE 
										WHEN b.betteam = 'H1-4' AND (QXHome - QXAway) BETWEEN 1 AND 4 THEN 1
										WHEN b.betteam = 'H5-8' AND (QXHome - QXAway) BETWEEN 5 AND 8 THEN 1
										WHEN b.betteam = 'H9+' AND (QXHome - QXAway) >= 9 THEN 1
										WHEN b.betteam = 'D' AND (QXHome - QXAway) = 0 THEN 1
										WHEN b.betteam = 'A1-4' AND (QXAway - QXHome) BETWEEN 1 AND 4 THEN 1
										WHEN b.betteam = 'A5-8' AND (QXAway - QXHome) BETWEEN 5 AND 8 THEN 1
										WHEN b.betteam = 'A9+' AND (QXAway - QXHome) >= 9 THEN 1
										ELSE -1
									END
						WHEN 615 THEN CASE
										WHEN b.betteam = 'o' THEN QXHome - b.hdp1
										WHEN b.betteam = 'u' THEN b.hdp1 - QXHome
										ELSE -1
									END
						WHEN 616 THEN CASE
										WHEN b.betteam = 'o' THEN QXAway - b.hdp1
										WHEN b.betteam = 'u' THEN b.hdp1 - QXAway
										ELSE -1
									END
						WHEN 617 THEN CASE
										WHEN QXLastBasket = 'N' THEN 0
										WHEN b.betteam = QXLastBasket THEN 1 
										ELSE -1
									END
						END
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
					, WinLost = CASE 
						WHEN @modds > 0.25 THEN actual_stake + stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype = 614 THEN odds - 1 ELSE odds END) END)
						WHEN @modds = 0.25 THEN actual_stake + stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype = 614 THEN odds - 1 ELSE odds END) END) * 0.5
						WHEN @modds = 0 THEN actual_stake
						WHEN @modds = -0.25 THEN actual_stake * 0.5
						WHEN @modds < -0.25 THEN 0
						END
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
			FROM	@currecommend ag
				INNER JOIN dbo.bettrans b WITH (ROWLOCK, UPDLOCK)
					ON ag.recommend = b.recommend
				INNER JOIN @tmpData t
					ON	t.QuarterX LIKE SUBSTRING(CAST(b.betid AS VARCHAR),1,3)
			WHERE	b.matchid = @matchid
					AND b.bettype BETWEEN 609 AND 617
					AND b.statusID NOT IN (101, 102)
			OPTION (FORCE ORDER)	
	
			IF @affectedagents <> 100
				BREAK						
        END
    END
    ELSE
    BEGIN
		CREATE TABLE #tempCust(custid INT PRIMARY KEY)
		
		INSERT INTO #tempCust(custid)
        SELECT	custid
        FROM	dbo.bettrans WITH(NOLOCK) 
        WHERE	matchid = @matchid 
				AND bettype BETWEEN 609 AND 617
				GROUP BY custid
		
		CREATE TABLE #currList (custid INT PRIMARY KEY)
		DECLARE @MinCustId INT
		
		WHILE (1=1)
		BEGIN
			DELETE FROM #currList

            DELETE TOP (1000)
            FROM #tempCust OUTPUT DELETED.custid INTO #currList
            
            IF @@ROWCOUNT = 0 BREAK

			SELECT @MinCustId = MIN(CustId) FROM #currList
			
			UPDATE	b 
				SET @modds = CASE b.bettype
						WHEN 609 THEN CASE 
										WHEN b.betteam = 'h' THEN (QXHome - b.hdp1) - (QXAway - b.hdp2)
										WHEN b.betteam = 'a' THEN (QXAway - b.hdp2) - (QXHome - b.hdp1)
										ELSE - 1
									END
						WHEN 610 THEN CASE 
										WHEN b.betteam = 'o' THEN QXHome + QXAway - b.hdp1
										WHEN b.betteam = 'u' THEN b.hdp1 - (QXHome + QXAway)	
										ELSE -1
									END
						WHEN 611 THEN CASE
										WHEN b.betteam = 'o' AND (QXHome + QXAway) % 2 = 1 THEN 1
										WHEN b.betteam = 'e' AND (QXHome + QXAway) % 2 = 0 THEN 1
										ELSE -1
									END
						WHEN 612 THEN CASE
										WHEN b.betteam = 'h' THEN (QXHome - QXAway)
										WHEN b.betteam = 'a' THEN (QXAway - QXHome)
										ELSE -1
									END
						WHEN 613 THEN CASE
										WHEN b.betid LIKE '___10' AND QXRaceTo10 = 'N' THEN 0
										WHEN b.betid LIKE '___15' AND QXRaceTo15 = 'N' THEN 0
										WHEN b.betid LIKE '___20' AND QXRaceTo20 = 'N' THEN 0
										WHEN b.betid LIKE '___10' AND b.betteam = QXRaceTo10 THEN 1
										WHEN b.betid LIKE '___15' AND b.betteam = QXRaceTo15 THEN 1
										WHEN b.betid LIKE '___20' AND b.betteam = QXRaceTo20 THEN 1
										ELSE -1
									END
						WHEN 614 THEN CASE 
										WHEN b.betteam = 'H1-4' AND (QXHome - QXAway) BETWEEN 1 AND 4 THEN 1
										WHEN b.betteam = 'H5-8' AND (QXHome - QXAway) BETWEEN 5 AND 8 THEN 1
										WHEN b.betteam = 'H9+' AND (QXHome - QXAway) >= 9 THEN 1
										WHEN b.betteam = 'D' AND (QXHome - QXAway) = 0 THEN 1
										WHEN b.betteam = 'A1-4' AND (QXAway - QXHome) BETWEEN 1 AND 4 THEN 1
										WHEN b.betteam = 'A5-8' AND (QXAway - QXHome) BETWEEN 5 AND 8 THEN 1
										WHEN b.betteam = 'A9+' AND (QXAway - QXHome) >= 9 THEN 1
										ELSE -1
									END
						WHEN 615 THEN CASE
										WHEN b.betteam = 'o' THEN QXHome - b.hdp1
										WHEN b.betteam = 'u' THEN b.hdp1 - QXHome
										ELSE -1
									END
						WHEN 616 THEN CASE
										WHEN b.betteam = 'o' THEN QXAway - b.hdp1
										WHEN b.betteam = 'u' THEN b.hdp1 - QXAway
										ELSE -1
									END
						WHEN 617 THEN CASE
										WHEN QXLastBasket = 'N' THEN 0
										WHEN b.betteam = QXLastBasket THEN 1 
										ELSE -1
									END
						END
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
					, WinLost = CASE 
						WHEN @modds > 0.25 THEN actual_stake + stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype = 614 THEN odds - 1 ELSE odds END) END)
						WHEN @modds = 0.25 THEN actual_stake + stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype = 614 THEN odds - 1 ELSE odds END) END) * 0.5
						WHEN @modds = 0 THEN actual_stake
						WHEN @modds = -0.25 THEN actual_stake * 0.5
						WHEN @modds < -0.25 THEN 0
						END
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
			FROM	#currList c
				INNER JOIN dbo.bettrans b WITH (ROWLOCK, UPDLOCK)
					ON c.custid = b.custid
				INNER JOIN @tmpData t
					ON	t.QuarterX LIKE SUBSTRING(CAST(b.betid AS VARCHAR),1,3)
			WHERE	b.matchid = @matchid
					AND b.custid >= @MinCustId
					AND b.bettype BETWEEN 609 AND 617
					AND b.statusID NOT IN (101, 102)
			OPTION (FORCE ORDER)	
		END
    END
	
END
GO