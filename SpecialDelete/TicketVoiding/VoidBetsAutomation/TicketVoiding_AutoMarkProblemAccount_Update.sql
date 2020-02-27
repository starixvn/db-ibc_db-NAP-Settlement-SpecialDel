/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_AutoMarkProblemAccount_Update]
(
	@UserId		INT = 10278938
	,@UserName		VARCHAR(100) = 'starixIT'
	,@IP			VARCHAR(50)		= '125.227.140.97'
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			VARCHAR(300)	= ''	OUTPUT
)
AS
/*
	Created by: Helen
	Date 20200225
	Task: [TVS] Abnormal Void Bets Automation
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20200225@Helen:[TVS] Auto Void winning bet [Redmine:#128836]
	
	Param's explanation:	
*/
BEGIN
	DECLARE @query NVARCHAR(MAX) = ''
		, @ExecuteSQL NVARCHAR(MAX) = ''
		, @IsActiveVoidWinning BIT = 0
		, @TransIds_tmp VARCHAR(MAX) = ''
		, @start INT  = 1
		, @end INT = 0
		, @matchid INT
		, @Mark_cnt INT
		, @Unmark_cnt INT
		
	SET @IsActiveVoidWinning = (SELECT TOP (1) IsActive 
								FROM DBCUST.CUSTDB.dbo.ProblemAccountAction WITH (NOLOCK) 
								WHERE ActionID = 2)
								
	IF ISNULL(@IsActiveVoidWinning,0) = 0
		RETURN

	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)
	DECLARE @Matchid_Final AS TABLE (Matchid INT, ID INT IDENTITY(1,1))
	
	DECLARE @tmpAutoTransIDBatch TABLE (TransId	BIGINT)
	CREATE TABLE #Transid_Mark (Matchid INT, Transid BIGINT,custID INT, IsFinish BIT)
	CREATE TABLE #Transid_UnMark (Matchid INT, Transid BIGINT,custID INT, IsFinish BIT)
	CREATE TABLE #ProblemAccount_tmp (CustID INT)
	CREATE TABLE #MatchRunning_tmp (Matchid INT)
		
	INSERT INTO @bettype_tmp (bettype)
	SELECT pt.bettype
	FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
	WHERE pt.ProductID = 1 -- Sportsbook
		AND pt.bettype NOT IN (10, 9, 29) -- outright, parlay
		AND pt.bettype NOT BETWEEN 221 AND 227 -- Fast Market
		AND pt.SubProduct NOT IN ('Bet Builder', 'MG-SuperLive', 'BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet Builder, Metric Gaming, Bet trade (BT-)
		AND pt.SportType IN (1, 2, 9, 43)
	
	SELECT  @query = N''		
	SELECT	@query = @query + N'SELECT Custid 
								FROM dbo.ProblemAccount WITH (NOLOCK)	
								WHERE Reasonid = 109 AND Actionid = 2 '
	SELECT	@ExecuteSQL = N'EXECUTE DBCUST.CUSTDB.dbo.sp_executesql @query'

	INSERT INTO #ProblemAccount_tmp (CustID)
	EXECUTE	sys.sp_executesql @ExecuteSQL, N'@query NVARCHAR(MAX)', @query

	IF EXISTS (SELECT TOP (1) 1 FROM #ProblemAccount_tmp)
	BEGIN
		-- get running match
		INSERT INTO #MatchRunning_tmp (Matchid)
		SELECT matchid
		FROM match m WITH (NOLOCK)
		WHERE eventstatus <> 'complete'
			AND m.sporttype IN (1, 2, 9, 43)
		
	END
	
	INSERT INTO #Transid_Mark (transid, Matchid,custID)
	SELECT b.transid, b.matchid,b.custid
	FROM #MatchRunning_tmp m
		INNER LOOP JOIN dbo.bettrans b WITH (NOLOCK) ON m.Matchid = b.matchid 
		CROSS APPLY (SELECT TOP 1 custid
					 FROM #ProblemAccount_tmp t
					 WHERE t.custid IN (b.custid, b.srecommend, b.mrecommend, b.recommend)
					 ) AS tmp
		OUTER APPLY (SELECT TOP 1 transid
					 FROM  dbo.MarkedTransaction mt WITH (NOLOCK)
					 WHERE mt.transid = b.transid
					 ) AS mt_tmp
	WHERE b.statusID = 0 AND mt_tmp.TransId IS NULL
		AND EXISTS (SELECT TOP 1 1 FROM @bettype_tmp bt WHERE bt.bettype = b.bettype)
	
	SET @Mark_cnt = @@ROWCOUNT
	
	INSERT INTO @Matchid_Final (Matchid)
	SELECT DISTINCT matchid
	FROM #Transid_Mark
	
	--Step 1: Mark Ticket Problem Account
	SET @end = (SELECT MAX(ID) FROM @Matchid_Final )
	
	IF @Mark_cnt > 0
	BEGIN
		WHILE @start <= @end
		BEGIN
			SET @matchid = (SELECT matchid FROM @Matchid_Final WHERE ID = @start)
			
			WHILE (1=1)
			BEGIN
				DELETE @tmpAutoTransIDBatch
					
				UPDATE TOP(2000) t
					SET isFinish = 1
				OUTPUT DELETED.TransId
						
				INTO @tmpAutoTransIDBatch(TransId)
				FROM #Transid_Mark t 
				WHERE isFinish IS NULL
					AND t.Matchid = @matchid
				
				IF @@ROWCOUNT = 0 BREAK
				
				SELECT @TransIds_tmp = STUFF((SELECT ',' + CONVERT(VARCHAR(50), tp.transid)
												FROM @tmpAutoTransIDBatch tp
												GROUP BY TransId for XML PATH('')), 1, 1, '')
					
				EXEC dbo.Nap_SpecialDelete_UnMarkedTickets_Update @TransIds = @TransIds_tmp, @UserId = @UserId
																, @Username = @UserName, @IP = @IP
																, @MarkType = 2
																,@ErrMsg = @ErrMsg OUTPUT
																,@ErrCode = @ErrCode OUTPUT;
																
				
				SET @TransIds_tmp = ''	 
				
			END
			
			SET @start = @start + 1
			
		END	
	END
	--Step 2: Unmark ticket not belong problem account, status running only, mark by auto system
	INSERT INTO #Transid_UnMark (transid, Matchid,custID)
	SELECT b.transid, b.matchid,b.custid
	FROM #MatchRunning_tmp m
		INNER JOIN dbo.MarkedTransaction mt WITH (NOLOCK) ON m.Matchid = mt.MatchId
		INNER JOIN dbo.bettrans b WITH (NOLOCK) ON mt.TransId = b.transid
		OUTER APPLY (SELECT TOP 1 custid
					 FROM #ProblemAccount_tmp t
					 WHERE t.custid IN (b.custid, b.srecommend, b.mrecommend, b.recommend)
					 ) AS tmp
	WHERE b.statusID = 0 AND tmp.CustID IS NULL
		AND mt.MarkType = 2
	
	SET @Unmark_cnt = @@ROWCOUNT	
	
	IF @Unmark_cnt > 0
	BEGIN	
		WHILE (1=1)
		BEGIN
			
			DELETE @tmpAutoTransIDBatch
				
			UPDATE TOP(2000) t
				SET isFinish = 1
			OUTPUT DELETED.TransId
					
			INTO @tmpAutoTransIDBatch(TransId)
			FROM #Transid_UnMark t 
			WHERE isFinish IS NULL
			
			IF @@ROWCOUNT = 0 BREAK
			
			SELECT @TransIds_tmp = STUFF((SELECT ',' + CONVERT(VARCHAR(50), tp.transid)
											FROM @tmpAutoTransIDBatch tp
											GROUP BY TransId for XML PATH('')), 1, 1, '')
				
			EXEC [dbo].[Nap_SpecialDelete_MarkedTickets_Update] @TransIds = @TransIds_tmp
				,@UserId = @UserId
				,@Username = @UserName
				,@IP = @IP
				,@ErrMsg = @ErrMsg OUTPUT
				,@ErrCode = @ErrCode OUTPUT;
				
			SET @TransIds_tmp = ''	 
			
		END
	END
	
	DROP TABLE #MatchRunning_tmp
	DROP TABLE #ProblemAccount_tmp
	DROP TABLE #Transid_Mark
	DROP TABLE #Transid_UnMark
END		
GO		
					


