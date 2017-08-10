/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet,Dot_Casino" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Admin_Settlement_s160
	@MatchId		INT
	,@Action		VARCHAR(20)		= 'CAL'
	,@IsAuto		BIT				= 1
	,@FirstBall		TINYINT			= NULL
	,@SecondBall	TINYINT			= NULL
	,@ThirdBall		TINYINT			= NULL
	,@AdminId		INT
	,@IP			VARCHAR(50)		= ''
	
	,@ErrCode		INT				= 0		OUTPUT
	,@ErrMsg		VARCHAR(200)	= ''	OUTPUT
AS
/*
	Created by: Kathy
	Date: 20170426
	Task: Lucky 3 - Settlement 
	DB: DBTXN/BODB02
	
	Revisions:
		- 20170426@Kathy: Lucky 3 - Settlement  [Redmine:#77170]
		
	Param's Explanation:	
		@Action: CAL, REFUND
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @StartTime				DATETIME
			,@EndTime				DATETIME
			,@Remark				VARCHAR(200)
			,@avaiableProcess		BIT
			,@ActionId				TINYINT
			,@FirstPrizeMaxCount	TINYINT
			,@PrizeSettingId		INT
			,@strMatchInfo			VARCHAR(MAX) = ''
			,@strCustId				VARCHAR(8000) = ''
			,@strCustSetting		VARCHAR(MAX) = ''
			,@batchCount			INT = 2000
			,@xml					VARCHAR(MAX) = ''
			,@balanceUpd			VARCHAR(MAX) = ''
			,@balanceAcc			VARCHAR(MAX) = ''
			
			,@oldFirstBall 			TINYINT
			,@oldSecondBall			TINYINT
			,@oldThirdBall			TINYINT
	
	DECLARE @BeforeUpd 	TVP_BalanceChange
	DECLARE @AfterUpd 	TVP_BalanceChange	
	
	CREATE TABLE #tmpTicketResults (
		TransId			BIGINT PRIMARY KEY
		,CustId			INT
		,Recommend		INT
		,Winlost		MONEY
		,aWinlost		MONEY
		,mWinlost		MONEY
		,sWinlost		MONEY
		,sComm			MONEY
		,aComm			MONEY
		,Comm			MONEY
		,PlayerComm		MONEY
		,StatusId		TINYINT
		,modds			SMALLMONEY
	)
	DECLARE @tmpBetTickets TVP_Settlement_BetTicket
	
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	
	IF @Action = 'CAL' AND @IsAuto = 1
	BEGIN
		SELECT	@FirstBall = Number
		FROM	DBPRO.bodb02.dbo.BingoBall WITH (ROWLOCK)
		WHERE	matchid = @MatchId
				AND seq = 1
		
		SELECT	@SecondBall = Number
		FROM	DBPRO.bodb02.dbo.BingoBall WITH (ROWLOCK)
		WHERE	matchid = @MatchId
				AND seq = 2
				
		SELECT	@ThirdBall = Number
		FROM	DBPRO.bodb02.dbo.BingoBall WITH (ROWLOCK)
		WHERE	matchid = @MatchId
				AND seq = 3
	END
	
	IF @Action = 'CAL'
	BEGIN
		IF @FirstBall IS NULL OR @SecondBall IS NULL OR @ThirdBall IS NULL
		BEGIN
			SELECT   @ErrCode = 1000001
					,@ErrMsg    = 'All ball values are required'

			RETURN
		END
		
		IF @FirstBall > 75 OR  @SecondBall > 75  OR @ThirdBall > 75 
		BEGIN
			SELECT   @ErrCode = 1000001
					,@ErrMsg    = CASE
									WHEN @FirstBall > 75 THEN 'First ball'
									WHEN @SecondBall > 75 THEN 'Second ball'
									WHEN @ThirdBall > 75 THEN 'Third ball'
								END + ' value is invalid'

			RETURN
		END
		
		SELECT	@PrizeSettingId = m.homeid
				,@FirstPrizeMaxCount = m.awayid
		FROM	DBPRO.bodb02.dbo.match m WITH(NOLOCK)
		WHERE	m.matchid = @MatchId
		
		IF EXISTS (SELECT	TOP 1 1 
				FROM	dbo.bettrans b WITH(NOLOCK) 
				WHERE	b.matchid = @MatchId 
						AND b.bettype = 1600 
						AND b.statusID NOT IN (101, 102) 
						AND NOT EXISTS (SELECT TOP 1 1 FROM dbo.Lucky3PrizeSettingDetail WITH(NOLOCK) WHERE PrizeSettingID = @PrizeSettingId AND ExchangeID = b.currency)
				)
		BEGIN
			SELECT   @ErrCode = 1000002
					,@ErrMsg    = 'There is missing setting in some currencies, please contact admin for more details'

			RETURN
		END
	END
	
	INSERT INTO #tblMatchProcess (matchid, KeyID)
	SELECT	@matchid AS matchid
			,1 	AS KeyID
		
	--check settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch = 1
		,@avaiableProcess = @avaiableProcess OUTPUT
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT
		
	IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
	BEGIN
		SELECT   @ErrCode = 1000000
                ,@ErrMsg    = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'

        RETURN
	END
	
	SELECT	@StartTime = GETDATE()
			,@ActionId = CASE @Action 
							WHEN 'CAL' THEN 192
							WHEN 'REFUND' THEN 193
							WHEN 'UNDO' THEN 194
						END
	
	SELECT 	@oldFirstBall = FirstBall
			,@oldSecondBall = SecondBall
			,@oldThirdBall = ThirdBall
	FROM (
		SELECT	b.Matchid
				,CASE WHEN b.Seq = 1 THEN 'FirstBall'
					WHEN b.Seq = 2 THEN 'SecondBall'
					when b.Seq = 3 THEN 'ThirdBall'
				END AS seq 
				,Number
		FROM	DBPRO.bodb02.dbo.bingoBall b WITH(NOLOCK)
		WHERE	matchId = @MatchId
	)AS s
	PIVOT (
		MAX(s.Number)
		FOR seq IN (FirstBall, SecondBall, ThirdBall)
	) AS pvt
			
	EXEC dbo.NAP_Admin_PreCalculate_s160
		@MatchId = @MatchId
		,@Mode = 'preCAL'
		,@Action = @Action
		,@FirstBall = @FirstBall
		,@SecondBall = @SecondBall
		,@ThirdBall = @ThirdBall
	
	SET @strMatchInfo = CAST((SELECT	t.Matchid AS '@m'
										,t.fb '@fb'
										,t.sb '@sb'
										,t.tb  AS '@tb'
										,ISNULL(r.fn,0) AS '@fn'
										,ISNULL(r.sn,0) AS '@sn'
										,ISNULL(r.tn,0) AS '@tn'
								FROM	(VALUES (@MatchId, @FirstBall, @SecondBall, @ThirdBall)) t(Matchid, fb, sb, tb) 
									LEFT JOIN (
										SELECT	MatchId
												,CAST(SUM(CASE WHEN Prize = 1 THEN Odds * Hits ELSE 0 END) AS INT) AS fn
												,CAST(SUM(CASE WHEN Prize = 2 THEN Odds * Hits ELSE 0 END) AS INT) AS sn
												,CAST(SUM(CASE WHEN Prize = 3 THEN Odds * Hits ELSE 0 END) AS INT) AS tn
										FROM	dbo.BetLucky3Result WITH(NOLOCK)
										WHERE	MatchId = @MatchId
										GROUP BY MatchId
									)r
										ON	t.Matchid = r.MatchId
								FOR XML PATH ('r'), ROOT('root'), TYPE
								) AS VARCHAR(MAX)
							)
							
	EXEC DBPRO.bodb02.dbo.NAP_Admin_Match_Update_s160 
		@Action = @Action
		,@IsAuto = @IsAuto
		,@strMatchInfo = @strMatchInfo	
	
	IF @Action = 'CAL'
	BEGIN
		IF EXISTS (SELECT TOP 1 1 FROM dbo.BetLucky3Result WITH(NOLOCK) WHERE MatchId = @MatchId AND Prize = 1)
		BEGIN
			CREATE TABLE #tmpSMAWinningShare (
				CustId				INT
				,WinningShareCom	DECIMAL(9,8)
				,WinningShareSuper	DECIMAL(9,8)
				,WinningShareMaster	DECIMAL(9,8)
				,WinningShareAgent	DECIMAL(9,8)
			)
			
			CREATE TABLE #tmpCustId (
				Id 		INT IDENTITY(1,1)
				,CustId INT
			)
			
			DECLARE @Id INT = 1
			
			INSERT INTO #tmpCustId (CustId)
			SELECT	CustId
			FROM	dbo.BetLucky3Result WITH(NOLOCK)
			WHERE	MatchId = @MatchId
					AND bettype = 1602
			GROUP BY custid
			
			WHILE (1 = 1)
			BEGIN
				SET @strCustId = ''
				
				SELECT	@strCustId = @strCustId + CAST(CustId AS VARCHAR) + ','
				FROM	#tmpCustId
				WHERE	Id BETWEEN @Id AND @Id + 4000
				
				IF @@rowcount = 0 
					BREAK
					
				INSERT INTO #tmpSMAWinningShare (CustId, WinningShareCom, WinningShareSuper, WinningShareMaster, WinningShareAgent)
				EXEC DBCUST.CustDB.dbo.NAP_Set_WinningShareSel @strCustId = @strCustId, @VendorID = 16
				
				SET @Id = @Id + 4000
			END
			
			SET @strCustSetting = CAST((SELECT	CustId '@id'
												,WinningShareCom '@c'
												,WinningShareSuper '@s'
												,WinningShareMaster '@m'
												,WinningShareAgent '@a'
										FROM	#tmpSMAWinningShare
										FOR XML PATH('r'), ROOT('root'), TYPE
								) AS VARCHAR(MAX))
		END
	
		EXEC dbo.NAP_Admin_PreCalculate_s160
			@MatchId = @MatchId
			,@Mode = 'CAL'
			,@strCustSetting = @strCustSetting
			,@FirstPrizeMaxCount = @FirstPrizeMaxCount
			,@PrizeSettingId = @PrizeSettingId
			
		;WITH cteResult 
		AS
		(
			SELECT	TransId
					,SUM(r.Winlost) AS Winlost
					,SUM(r.aWinlost) AS aWinlost
					,SUM(r.mWinlost) AS mWinlost
					,SUM(r.sWinlost) AS sWinlost
					,SUM(r.sComm) AS sComm
					,SUM(r.aComm) AS aComm
					,SUM(r.Comm) AS Comm
					,SUM(r.PlayerComm) AS PlayerComm
			FROM	dbo.BetLucky3Result r WITH(ROWLOCK)
			WHERE	MatchId = @MatchId
			GROUP BY TransId
		)
		INSERT INTO #tmpTicketResults (TransId, CustId, Recommend, Winlost, aWinlost, mWinlost, sWinlost, sComm, aComm, Comm, PlayerComm, StatusId, modds)	
		SELECT	c.TransId 
				,b.custid
				,b.recommend
				,c.Winlost
				,c.aWinlost
				,c.mWinlost
				,c.sWinlost
				,c.sComm
				,c.aComm
				,c.Comm
				,c.PlayerComm
				,CASE
					WHEN c.Winlost > b.stake THEN 112
					WHEN c.Winlost = b.stake THEN 111
					ELSE 113
				END AS StatusId	
				,CASE
					WHEN c.Winlost > b.stake THEN 1
					WHEN c.Winlost = b.stake THEN 0
					ELSE -1
				END AS mOdds		
		FROM	cteResult c
			INNER JOIN dbo.bettrans b WITH (ROWLOCK)
				ON	c.TransId = b.TransId
					AND b.MatchId = @MatchId
					AND b.bettype = 1600		
	END
	ELSE IF @Action IN ('UNDO', 'REFUND')
	BEGIN
		INSERT INTO #tmpTicketResults(Transid, CustId, Recommend, Winlost, aWinlost, mWinlost, sWinlost, sComm, aComm, Comm, PlayerComm, StatusId, modds)
		SELECT	TransId
				,custid
				,recommend
				,CASE WHEN @Action = 'REFUND' THEN actual_stake ELSE 0 END AS Winlost
				,0 AS aWinlost
				,0 AS mWinlost
				,0 AS sWinlost
				,0 AS sComm
				,0 AS aComm
				,0 AS Comm
				,0 AS PlayerComm
				,CASE WHEN @Action = 'REFUND' THEN 103 ELSE 0 END AS StatusId
				,0 AS modds
		FROM	dbo.bettrans WITH(ROWLOCK)
		WHERE	MatchId = @MatchId
	END
	
	BEGIN TRY
		WHILE (1 = 1)
		BEGIN	
			SET @balanceUpd = NULL
			DELETE FROM @tmpBetTickets
			
			DELETE TOP (@batchCount) #tmpTicketResults
			OUTPUT	@MatchId
					,DELETED.TransId, DELETED.CustId, DELETED.recommend, 1600 -- bettype
					,DELETED.Winlost, DELETED.aWinlost, DELETED.mWinlost, DELETED.sWinlost
					,DELETED.sComm, DELETED.aComm, DELETED.Comm, DELETED.PlayerComm
					,DELETED.StatusId, DELETED.modds
			INTO @tmpBetTickets(matchid
					,TransId, CustId, recommend, bettype
					,Winlost, aWinlost, mWinlost, sWinlost
					,sComm, aComm, Comm, PlayerComm
					,StatusId, modds)
			
			IF @@rowcount = 0
				BREAK
			
			EXEC dbo.NAP_Admin_Calculate_Bettrans
					@BetTickets		= @tmpBetTickets	
					,@CWLBettype	= 1600
					,@balanceUpd 	= @balanceUpd OUTPUT
					,@ErrCode 		= @ErrCode OUTPUT
					,@ErrMsg 		= @ErrMsg OUTPUT
					
			IF(@balanceUpd IS NOT NULL)
			BEGIN
				SET @balanceAcc += @balanceUpd
			END		
			
			IF @ErrCode	> 0 
				BREAK
		END
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = ERROR_NUMBER()
				,@ErrMsg = ERROR_MESSAGE()
	END CATCH
	
	-- Settlement balance process
	EXEC dbo.NAP_Admin_Settlement_BalanceProcess
		@BalanceAcc				= @balanceAcc
		,@BalanceType			= 4
		,@actionId				= @ActionId
		,@MatchID				= @MatchID
		,@GroupID				= 0 -- No adding into Balance Negative		
		
	-- Releasing settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch		= 1
		,@IsReleased		= 1

	SET @EndTime = GETDATE()
	
	SELECT @Remark = 'IsAuto: ' + CAST(@IsAuto AS VARCHAR) + '</br>'
					+ CASE 
						WHEN @Action = 'CAL' THEN '1st: ' + CAST(@FirstBall AS VARCHAR) + '; '
													+ '2nd: ' + CAST(@SecondBall AS VARCHAR)  + '; '
													+ '3rd: ' + CAST(@ThirdBall AS VARCHAR) + '</br>'
						ELSE ''
					END
					+ CASE 
						WHEN @IsAuto = 0 THEN '(Old result - 1st: ' + ISNULL(CAST(@oldFirstBall AS VARCHAR),'N/A') + '; '
													+ '2nd: ' + ISNULL(CAST(@oldSecondBall AS VARCHAR),'N/A') + '; '
													+ '3rd: ' + ISNULL(CAST(@oldThirdBall AS VARCHAR),'N/A') + ')</br>'
						ELSE ''
					END
					+ 'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS NVARCHAR(50)) + ' ms'
	
	DECLARE @doing NVARCHAR(300) = 'Settlement for matchid: ' + CAST(@MatchId AS VARCHAR) + ', ' + @Remark
	EXEC dbo.WriteLog_UserLog 
		@UserID = @AdminId
		,@Doing = @doing
		
	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle @UserID = @AdminId
			,@Matchid = @matchid
			,@ActionID = @ActionID
			,@finalhomescore = NULL
			,@finalawayscore = NULL
			,@hthomescore = NULL
			,@htawayscore = NULL
			,@GoalRecord = NULL
			,@betstatus = NULL
			,@Remark = @Remark
			,@IP = @IP
	END TRY

	BEGIN CATCH
		SELECT @Remark = @Remark + ' ErrMsg=' + LEFT(ERROR_MESSAGE(), 200)

		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle @UserID = @AdminId
			,@Matchid = @matchid
			,@ActionID = @ActionID
			,@finalhomescore = NULL
			,@finalawayscore = NULL
			,@hthomescore = NULL
			,@htawayscore = NULL
			,@GoalRecord = NULL
			,@betstatus = NULL
			,@Remark = @Remark
			,@IP = @IP
	END CATCH
END
GO