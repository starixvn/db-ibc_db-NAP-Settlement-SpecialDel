/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_AutoUnmark_Update]
(
	@Matchid		 INT,
	@Bettype		 SMALLINT,
	@MarkedBy		 INT,
	@Betid			 BIGINT = NULL,
	@UserId          INT           = 0,
    @Username        NVARCHAR(100) = '',
    @IP              VARCHAR(15)   = NULL,
    @ErrMsg          NVARCHAR(200) = '' OUTPUT,
    @ErrCode         INT           = 0 OUTPUT,
	@FailedTransIds	VARCHAR(MAX)	= NULL	OUTPUT,
	@NegativeBalanceUsers VARCHAR(MAX) = ''	OUTPUT
)
AS
/*	Created by: Max
	Date 20200212
	Task: Abnormal Void Bets Automation [Redmine: #128359]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20200212@Max: Create new SP [Redmine: #128359]
		- 20200221@Max: HotFix [Redmine: #128924]
		- 20200226@Max: Confirm Auto Unmark Group By User [Redmine: #129219]
		- 20200226@Max: Auto Void Winning Bets - [Redmine: #129184]
		- 20200312@Max: Hotfix - Confirm Auto Unmark not work for Early Settlement Bettype - [Redmine: #130279]
		- 20200313@Max: Support Quarter X, Y, Z on Auto Unmark Page - [Redmine: #130322]
		
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @UnmarkTransids VARCHAR(MAX)  = ''

	DECLARE @query NVARCHAR(MAX) = ''
	, @ExecuteSQL NVARCHAR(MAX) = ''
	, @IsActiveVoidWinning BIT = 0

	DECLARE @avaiableProcess BIT
			,@isExistMatch BIT

			,@IsBettypeHT	BIT = 0
			,@IsBettypeFT	BIT = 0
			,@IsBettypeEAR	BIT = 0
			
			,@IsCalHTQueue		BIT = 0
			,@IsCalFTQueue		BIT = 0
			,@IsCalAllQueue		BIT = 0
			,@IsCalEarlyQueue	BIT = 0
			
	DECLARE @tmpMarkedTransIDBatch TABLE (transid BIGINT)

	CREATE TABLE #tmpTransid_unmark (transid BIGINT, isFinish INT)
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	
	--Step 1: Insert table TicketVoiding_AutoUnmarkSetting
	INSERT INTO dbo.TicketVoiding_AutoUnmarkSetting (Matchid, Bettype, IsConfirm, CreatedDate, UserId, MarkedBy, betid)
	VALUES(@Matchid, @Bettype, 1, GETDATE(), @UserId, @MarkedBy, @Betid)

	--Step 2: Get tranid to unmark
	CREATE TABLE #inputRequestTransId (TransId BIGINT)
	CREATE TABLE #ValidRequestTransId (TransId BIGINT)
	CREATE TABLE #ProblemAccount_tmp (CustID INT)
	
	INSERT INTO #inputRequestTransId (TransId)
	SELECT  tmp.transid
	FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) 
		INNER JOIN dbo.TicketVoiding_Request req WITH (NOLOCK) ON req.RequestId = rd.RequestId 
		CROSS APPLY (SELECT val AS transid
					 FROM dbo.f_SplitString(rd.TransIds, ',')
					) AS tmp
	WHERE req.IssueTypeId = 11 AND rd.MatchId = @MatchId
	OPTION (maxrecursion 0)
	
	INSERT INTO #ValidRequestTransId (TransId)	
	SELECT t.TransId
	FROM #inputRequestTransId t
		INNER JOIN dbo.bettrans b WITH (NOLOCK) ON t.TransId = b.transid
	WHERE b.bettype = @Bettype

	-- get all transid that not belong to any abnormal request
	SELECT  @query = N''		
	SELECT	@query = @query + N'SELECT Custid 
								FROM dbo.ProblemAccount WITH (NOLOCK)	
								WHERE Actionid = 2 and SubIssueTypeId = 38'
	SELECT	@ExecuteSQL = N'EXECUTE DBCUST.CUSTDB.dbo.sp_executesql @query'

	INSERT INTO #ProblemAccount_tmp (CustID)
	EXECUTE	sys.sp_executesql @ExecuteSQL, N'@query NVARCHAR(MAX)', @query

	INSERT INTO #tmpTransid_unmark (transid)
	SELECT mt.TransId
	FROM dbo.MarkedTransaction mt WITH (NOLOCK)
		INNER JOIN dbo.bettrans b WITH (NOLOCK) 
			ON b.transid = mt.TransId
		OUTER APPLY (SELECT TOP 1 custid
					 FROM #ProblemAccount_tmp t
					 WHERE t.custid = b.custid
					 ) AS tmp
	WHERE mt.MatchId = @Matchid
		AND mt.bettype = @Bettype
		AND mt.TransId NOT IN (SELECT transid FROM #ValidRequestTransId)
		AND b.statusID IN (0, 1)
		AND mt.UserId = @MarkedBy
		AND mt.MarkType <> 2
		AND tmp.CustID IS NULL
	
	IF NOT EXISTS (SELECT TOP (1) 1 FROM #tmpTransid_unmark)
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = 'The confirmation is updated successfully. But there is no ticket affected by this action as the remaining marked tickets have to wait for the event result.'
		RETURN
	END
	
	INSERT INTO #tblMatchProcess(matchid, KeyID)
	SELECT	@matchid AS matchid
			,1 AS KeyId
	
	SELECT	@isExistMatch = CASE WHEN KeyID = 1 THEN 1 ELSE 0 END
	FROM	#tblMatchProcess
			
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch = 1
		, @avaiableProcess = @avaiableProcess OUTPUT
		, @ErrCode = @ErrCode OUTPUT
		, @ErrMsg = @ErrMsg OUTPUT
		
	IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
	BEGIN		
		RETURN
	END

	WHILE (1 = 1)
	BEGIN
		BEGIN TRY
			DELETE @tmpMarkedTransIDBatch
		
			UPDATE TOP(3000) t
				SET isFinish = 1
			OUTPUT deleted.transid
			INTO @tmpMarkedTransIDBatch(transid)
			FROM #tmpTransid_unmark t 
			WHERE isFinish IS NULL
		
			IF @@ROWCOUNT = 0 BREAK
			SET @UnmarkTransids = ''
			SELECT @UnmarkTransids = STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
											FROM @tmpMarkedTransIDBatch
											FOR XML PATH('')
								), 1,1,'')
		
			--Step 3: Unmark
			EXEC [dbo].[Nap_SpecialDelete_MarkedTickets_Update] @TransIds = @UnmarkTransids
				,@UserId = @UserId
				,@Username = @Username
				,@IP = @IP
				,@ErrMsg = @ErrMsg OUTPUT
				,@ErrCode = @ErrCode OUTPUT;

			--Step 4: resettle ticket
			IF EXISTS (
					SELECT TOP (1) 1 
					FROM @tmpMarkedTransIDBatch taq
						INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = taq.transid
					WHERE b.statuswinlost IS NOT NULL
				)
			BEGIN
				
				SELECT @IsCalHTQueue = MAX(CASE WHEN Action = 'CAL-HT' THEN 1 ELSE 0 END)
						, @IsCalFTQueue =MAX( CASE WHEN Action = 'CAL-FT' THEN 1 ELSE 0 END)
						, @IsCalAllQueue = MAX(CASE WHEN Action = 'CAL' THEN 1 ELSE 0 END)
						, @IsCalEarlyQueue = MAX(CASE WHEN Action IN ('CAL_EAR', 'CAL-EARLY') THEN 1 ELSE 0 END)
				FROM dbo.TicketVoiding_AutoVoidRequest_Queue WITH (NOLOCK)
				WHERE StatusId IN (1,2,4) AND matchid = @MatchId AND RequestId = 0

				IF EXISTS (SELECT TOP (1) 1 FROM dbo.f_Set_GetGroupBettypes() WHERE groupid IN (1,3) AND bettype = @Bettype)
					SET @IsBettypeHT = 1

				IF EXISTS (SELECT TOP (1) 1 FROM dbo.f_Set_GetGroupBettypes() WHERE groupid IN (2,4) AND bettype = @Bettype)
					SET @IsBettypeFT = 1
				
				IF EXISTS (SELECT TOP (1) 1 FROM dbo.f_Set_GetEarlyBettypes() WHERE bettype = @Bettype)
					SET @IsBettypeEAR = 1

				IF (
						(@IsCalHTQueue = 1 AND  @IsBettypeHT = 1)
					OR  (@IsCalFTQueue = 1 AND  (@IsBettypeFT = 1 OR @IsBettypeHT = 1))
					OR	(@IsCalAllQueue = 1 AND (@IsBettypeFT = 1 OR @IsBettypeHT = 1))
					OR	(@IsCalEarlyQueue = 1 AND (@IsBettypeEAR = 1))
					)
				BEGIN
			
				EXEC [dbo].[TicketVoiding_ReCalculate_Single_PreUpdate]
						@Matchid = @Matchid	,
						@TransIds = @UnmarkTransids,
						@UserId  = @UserId,
						@IP = @IP,
						@FailedTransIds = @FailedTransIds OUTPUT,
						@ErrMsg = @ErrMsg OUTPUT,
						@ErrCode = @ErrCode OUTPUT,
						@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT
				END
			END	
			
			SET @UnmarkTransids = ''
		END TRY
		BEGIN CATCH
			SELECT @ErrCode = ERROR_NUMBER()
				, @ErrMsg = ERROR_MESSAGE()
		END CATCH
	END

	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch = 1
		,@IsReleased = 1

	DROP TABLE #ValidRequestTransId
	DROP TABLE #inputRequestTransId
	DROP TABLE #tblMatchProcess
	DROP TABLE #tmpTransid_unmark
	DROP TABLE #ProblemAccount_tmp
	
END