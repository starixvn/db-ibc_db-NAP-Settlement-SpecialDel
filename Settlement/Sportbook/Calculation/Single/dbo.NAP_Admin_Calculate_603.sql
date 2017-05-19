/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_603] 
	@matchid 			INT
	,@bettype			SMALLINT
	,@result			VARCHAR(MAX)
AS
/*
    Created: 20170220@Kathy
    Task: Basketball - Calculate [Redmine:#71372]
    DB: DBTXN/BODB02
    Original:

    Revisions:

    Param's Explanation:

*/
BEGIN
    SET NOCOUNT ON
	
	IF @@SERVERNAME IN ('DB04', 'DB042', 'DB043', 'DB044') RETURN
	
	DECLARE @modds				MONEY
			,@commWinRate		SMALLMONEY
			,@commLostRate		SMALLMONEY
			,@xml				XML
		
	DECLARE @fth				INT
			,@fta 				INT			
			,@FTHighestQuarter	VARCHAR(10)
			,@FTFirstBasket		VARCHAR(10)
			,@FTLastBasket		VARCHAR(10)		
			
			,@SecondRaceTo20	VARCHAR(10)
			,@SecondRaceTo25	VARCHAR(10)
			,@SecondRaceTo30	VARCHAR(10)
			
			,@HTRaceTo20		VARCHAR(10)
			,@HTRaceTo25		VARCHAR(10)
			,@HTRaceTo30		VARCHAR(10)			
			
			,@Q1H 				INT
			,@Q2H 				INT
			,@Q3H 				INT
			,@Q4H 				INT
			,@Q1A 				INT
			,@Q2A 				INT
			,@Q3A 				INT
			,@Q4A 				INT
	
	SET @xml = CONVERT(XML, @result)
	
	IF @bettype = 603
	BEGIN
		SELECT	@Q1H = ISNULL(T.C.value('./@Q1Home[1]', 'INT'), 0) 
				,@Q2H = ISNULL(T.C.value('./@Q2Home[1]', 'INT'), 0)
				,@Q3H = ISNULL(T.C.value('./@Q3Home[1]', 'INT'), 0)
				,@Q4H = ISNULL(T.C.value('./@Q4Home[1]', 'INT'), 0)
				,@Q1A = ISNULL(T.C.value('./@Q1Away[1]', 'INT'), 0) 
				,@Q2A = ISNULL(T.C.value('./@Q2Away[1]', 'INT'), 0)
				,@Q3A = ISNULL(T.C.value('./@Q3Away[1]', 'INT'), 0)
				,@Q4A = ISNULL(T.C.value('./@Q4Away[1]', 'INT'), 0)
		FROM	@xml.nodes('/root/r') AS T(c) -- Table/Column
		OPTION ( OPTIMIZE FOR ( @xml = NULL ) ) 
		
		SELECT	@FTHighestQuarter = CASE 
							WHEN MAX(t.scoreH) > MAX(t.scoreA) THEN 'H'
							WHEN MAX(t.scoreH) < MAX(t.scoreA) THEN 'A'
							ELSE ''
						END	
		FROM	(VALUES(@Q1H,@Q1A),(@Q2H,@Q2A),(@Q3H,@Q3A),(@Q4H,@Q4A)) AS t(scoreH,scoreA)
	END	
	ELSE IF @bettype = 604
	BEGIN
		SELECT	@FTFirstBasket = ISNULL(T.C.value('./@FTFirstBasket[1]', 'VARCHAR(10)'), '')
		FROM	@xml.nodes('/root/r') AS T(c) -- Table/Column
		OPTION ( OPTIMIZE FOR ( @xml = NULL ) ) 
	END
	ELSE IF @bettype = 605
	BEGIN
		SELECT	@FTLastBasket = ISNULL(T.C.value('./@FTLastBasket[1]', 'VARCHAR(10)'), '')
		FROM	@xml.nodes('/root/r') AS T(c) -- Table/Column
		OPTION ( OPTIMIZE FOR ( @xml = NULL ) )
	END
	ELSE IF @bettype = 606
	BEGIN
		SELECT	@HTRaceTo20 = ISNULL(T.C.value('./@HTRaceTo20[1]', 'VARCHAR(10)'), '')
				,@HTRaceTo25 = ISNULL(T.C.value('./@HTRaceTo25[1]', 'VARCHAR(10)'), '')
				,@HTRaceTo30 = ISNULL(T.C.value('./@HTRaceTo30[1]', 'VARCHAR(10)'), '')
		FROM	@xml.nodes('/root/r') AS T(c) -- Table/Column
		OPTION ( OPTIMIZE FOR ( @xml = NULL ) )
	END
	ELSE IF @bettype = 607
	BEGIN
		SELECT	@SecondRaceTo20 = ISNULL(T.C.value('./@SecondRaceTo20[1]', 'VARCHAR(10)'), '')
				,@SecondRaceTo25 = ISNULL(T.C.value('./@SecondRaceTo25[1]', 'VARCHAR(10)'), '')
				,@SecondRaceTo30 = ISNULL(T.C.value('./@SecondRaceTo30[1]', 'VARCHAR(10)'), '')
		FROM	@xml.nodes('/root/r') AS T(c) -- Table/Column
		OPTION ( OPTIMIZE FOR ( @xml = NULL ) )
	END
	
	IF @@SERVERNAME IN ('DB052', 'DB053', 'DB054','DB231','DB215')
    BEGIN
		DECLARE @affectedagents INT

        CREATE TABLE #tmpRecommend(recommend INT  PRIMARY KEY)

        INSERT INTO #tmpRecommend(recommend)
        SELECT	DISTINCT recommend
        FROM	dbo.bettrans WITH(NOLOCK) 
        WHERE	matchid = @matchid
				AND bettype = @bettype

        DECLARE @currecommend TABLE(recommend int PRIMARY KEY)
        
        WHILE(1=1)
        BEGIN
			DELETE 
            FROM @currecommend

            DELETE TOP (100)
            FROM #tmpRecommend OUTPUT DELETED.recommend INTO @currecommend

            SET @affectedagents = @@rowcount
            
			UPDATE	b 
				SET @modds = CASE b.bettype
						WHEN 603 THEN CASE 
										WHEN @FTHighestQuarter = '' THEN 0
										WHEN b.betteam = @FTHighestQuarter THEN 1 
										ELSE -1 
										END
						WHEN 604 THEN CASE WHEN b.betteam = @FTFirstBasket THEN 1 ELSE -1 END
						WHEN 605 THEN CASE WHEN b.betteam = @FTLastBasket THEN 1 ELSE -1 END
						WHEN 606 THEN CASE 
										WHEN b.betid = 820 AND @HTRaceTo20 = 'N' THEN 0
										WHEN b.betid = 825 AND @HTRaceTo25 = 'N' THEN 0
										WHEN b.betid = 830 AND @HTRaceTo30 = 'N' THEN 0
										WHEN b.betid = 820 AND b.betteam = @HTRaceTo20 THEN 1 
										WHEN b.betid = 825 AND b.betteam = @HTRaceTo25 THEN 1
										WHEN b.betid = 830 AND b.betteam = @HTRaceTo30 THEN 1
										ELSE -1 
										END
						WHEN 607 THEN CASE 
										WHEN b.betid = 820 AND @SecondRaceTo20 = 'N' THEN 0
										WHEN b.betid = 825 AND @SecondRaceTo25 = 'N' THEN 0
										WHEN b.betid = 830 AND @SecondRaceTo30 = 'N' THEN 0
										WHEN b.betid = 820 AND b.betteam = @SecondRaceTo20 THEN 1 
										WHEN b.betid = 825 AND b.betteam = @SecondRaceTo25 THEN 1
										WHEN b.betid = 830 AND b.betteam = @SecondRaceTo30 THEN 1
										ELSE -1 
										END
						ELSE -1
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
						WHEN @modds > 0.25 THEN actual_stake + stake * (CASE WHEN odds < 0 THEN 1 ELSE odds END)
						WHEN @modds = 0.25 THEN actual_stake + stake * (CASE WHEN odds < 0 THEN 1 ELSE odds END) * 0.5
						WHEN @modds = 0 THEN actual_stake
						WHEN @modds = -0.25 THEN actual_stake * 0.5
						WHEN @modds < -0.25 THEN 0
						END
					, aWinLost = CASE 
						WHEN @modds > 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE odds END) * -apositiontaking
						WHEN @modds = 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE odds END) * -apositiontaking * 0.5
						WHEN @modds = 0 THEN 0
						WHEN @modds = -0.25 THEN actual_stake * apositiontaking * 0.5
						WHEN @modds < -0.25 THEN actual_stake * apositiontaking
						END
					, mWinLost = CASE
						WHEN @modds > 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE odds END) * -mpositiontaking
						WHEN @modds = 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE odds END) * -mpositiontaking * 0.5
						WHEN @modds = 0 THEN 0
						WHEN @modds = -0.25 THEN actual_stake * mpositiontaking * 0.5
						WHEN @modds < -0.25 THEN actual_stake * mpositiontaking
						END
					, sWinLost = CASE
						WHEN @modds > 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE odds END) * -spositiontaking
						WHEN @modds = 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE odds END) * -spositiontaking * 0.5
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
			WHERE	b.matchid = @matchid
					AND b.bettype = @bettype
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
				AND bettype = @bettype
		GROUP BY custid
        
        --PRINT @@ROWCOUNT

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
						WHEN 603 THEN CASE 
										WHEN @FTHighestQuarter = '' THEN 0
										WHEN b.betteam = @FTHighestQuarter THEN 1 
										ELSE -1 
										END
						WHEN 604 THEN CASE WHEN b.betteam = @FTFirstBasket THEN 1 ELSE -1 END
						WHEN 605 THEN CASE WHEN b.betteam = @FTLastBasket THEN 1 ELSE -1 END
						WHEN 606 THEN CASE 
										WHEN b.betid = 820 AND @HTRaceTo20 = 'N' THEN 0
										WHEN b.betid = 825 AND @HTRaceTo25 = 'N' THEN 0
										WHEN b.betid = 830 AND @HTRaceTo30 = 'N' THEN 0
										WHEN b.betid = 820 AND b.betteam = @HTRaceTo20 THEN 1 
										WHEN b.betid = 825 AND b.betteam = @HTRaceTo25 THEN 1
										WHEN b.betid = 830 AND b.betteam = @HTRaceTo30 THEN 1
										ELSE -1 
										END
						WHEN 607 THEN CASE 
										WHEN b.betid = 820 AND @SecondRaceTo20 = 'N' THEN 0
										WHEN b.betid = 825 AND @SecondRaceTo25 = 'N' THEN 0
										WHEN b.betid = 830 AND @SecondRaceTo30 = 'N' THEN 0
										WHEN b.betid = 820 AND b.betteam = @SecondRaceTo20 THEN 1 
										WHEN b.betid = 825 AND b.betteam = @SecondRaceTo25 THEN 1
										WHEN b.betid = 830 AND b.betteam = @SecondRaceTo30 THEN 1
										ELSE -1 
										END
						ELSE -1
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
						WHEN @modds > 0.25 THEN actual_stake + stake * (CASE WHEN odds < 0 THEN 1 ELSE odds END)
						WHEN @modds = 0.25 THEN actual_stake + stake * (CASE WHEN odds < 0 THEN 1 ELSE odds END) * 0.5
						WHEN @modds = 0 THEN actual_stake
						WHEN @modds = -0.25 THEN actual_stake * 0.5
						WHEN @modds < -0.25 THEN 0
						END
					, aWinLost = CASE 
						WHEN @modds > 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE odds END) * -apositiontaking
						WHEN @modds = 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE odds END) * -apositiontaking * 0.5
						WHEN @modds = 0 THEN 0
						WHEN @modds = -0.25 THEN actual_stake * apositiontaking * 0.5
						WHEN @modds < -0.25 THEN actual_stake * apositiontaking
						END
					, mWinLost = CASE
						WHEN @modds > 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE odds END) * -mpositiontaking
						WHEN @modds = 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE odds END) * -mpositiontaking * 0.5
						WHEN @modds = 0 THEN 0
						WHEN @modds = -0.25 THEN actual_stake * mpositiontaking * 0.5
						WHEN @modds < -0.25 THEN actual_stake * mpositiontaking
						END
					, sWinLost = CASE
						WHEN @modds > 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE odds END) * -spositiontaking
						WHEN @modds = 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE odds END) * -spositiontaking * 0.5
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
			WHERE	b.matchid = @matchid
					AND b.custid >= @MinCustId
					AND b.bettype = @bettype
					AND b.statusID NOT IN (101, 102)
			OPTION (FORCE ORDER)
		END
	END
END
GO
