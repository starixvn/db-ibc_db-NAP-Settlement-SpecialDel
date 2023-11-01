/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Refund_BetDaq]
	@matchid int,
	@creator int, 	
	@IP varchar(15) = '',
	@BroadcastSessionId VARCHAR(50)	= NULL,
	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT
AS

/*
	Created: 20140114@Kathy 
	Task : Refund Running BetDaq 
	Original: 
	DB: DBTXN/BODB02

	Revisions: 
		- 20140512@Kathy: Exclude 1H FGLG (127) [Redmine:#14449]
		- 20140909@Kathy: Exclude virtual racing (bettype 1231,1232,1233, 1237, 1238), outright (bettype 10, 31, 32, 33),
						 sportting solution (from 1301 -> 1334), keno (1501 -> 1599)
		- 20141030@Jamie: Sportting Solution Tennis Settlement [Redmine:#23034]
		- 20150206@Jamie: Auto Settlement Betradar phase 2 [Redmine: #27212]
		- 20150807@Kathy: Using new balance table (BalCreditSportsPending,BalDebitSportsPending) [Redmine:#40125]
		- 20171023@Kathy: Include bettype 14, 127 [Redmine:#81308]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
		- 20230214@Aries: Use Service Broker to Write Log to DB Log [Redmine: #187252]
		- 20230523@Kathy: scaleout credit [Redmine:#188452]
		- 20230817@Kathy: Write log [Redmine:#192311]

	Param's Explanation:
	• @matchid: matchid need to refund
	• @IsExcludeBetdaq: Is Exclude betdaq tickets or not
	• @IsSettleAbandonedMatch: Is Settlement for Abandoned/postponed match or not
	BetDaq account: 
				custid	--- username	-	roleid
				50057	---	BQUS888		-	1
				879241	---	BQUSMLB		-	1
				103873	---	BQUSNBA		-	1
				78761	---	ITibc101	-	1
				1688156	---	MTEST0101	-	2
				851668  --- BDUS01      -   1
				878902  --- BDUS016     -   1
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @Remark				VARCHAR(500)
			,@ActionID			INT
			 ,@avaiableProcess	BIT
			 ,@start			DATETIME
			 ,@IsCentral		BIT = 0	
			 ,@SiteDBGroupId	TINYINT
	
	DECLARE @tblDebitPending TVP_BalanceList
	DECLARE @tblCreditPending TVP_BalanceList
	
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	CREATE TABLE #BalanceBefore (custid int PRIMARY KEY, balance money)
	CREATE TABLE #BalanceAfter (custid int PRIMARY KEY, balance money)
	CREATE TABLE #Balance (custid int PRIMARY KEY, balance money, Increased bit)
	
	CREATE INDEX IX_Balance_Increased ON #Balance (Increased)

	SELECT	@start = CURRENT_TIMESTAMP
			,@ActionID = 126

	-- check and not allow attempt to settlement same game while it's still not finish
	INSERT INTO #tblMatchProcess(matchid, KeyID)
	SELECT	@matchid AS matchid
			,1 AS KeyId

	--check settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch		= 1
		, @avaiableProcess 	= @avaiableProcess OUTPUT
		, @ErrCode			= @ErrCode OUTPUT
		, @ErrMsg			= @ErrMsg OUTPUT

	IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
	BEGIN
		SELECT    @ErrCode = 1000000
                ,@ErrMsg    = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'

        RETURN
	END

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	INSERT INTO #BalanceBefore
	SELECT	custid, SUM(winlost-actual_stake+playercomm)
	FROM	dbo.bettrans with (rowlock)
	WHERE 
			(	custid IN (50057, 879241, 103873, 78761, 851668, 878902) 
				OR recommend = 1688156	)
			AND matchid = @matchid
			AND SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE SiteDBGroupID END
			AND bettype NOT IN (10, 31, 32, 33, 1231, 1232, 1233, 1237, 1238) -- Outright, VSRacing
			AND bettype NOT BETWEEN 1301 AND 1399 -- exclude sporting solution product
			AND bettype NOT BETWEEN 153 AND 156   -- New bettype of Tennis
			AND bettype NOT BETWEEN 1501 and 1599 -- Keno
			AND bettype NOT IN (135,160,164,168,169,173,174,175,176,180,192,193,210,211,212,213,214,215,216,217) --Auto bets BetRadar 2 


	GROUP BY custid

	EXEC dbo.NAP_Admin_Calculate_Main 
		 @matchid = @matchid
		,@action = 'REFUND'
		,@mode = 'BetDaq'

	INSERT INTO #BalanceAfter	
	SELECT	custid, SUM(winlost-actual_stake+playercomm)
	FROM	dbo.bettrans with (rowlock)
	WHERE 
			(	custid IN (50057, 879241, 103873, 78761, 851668, 878902) 
				OR recommend = 1688156	)
			AND matchid = @matchid
			AND SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE SiteDBGroupID END
			AND bettype NOT IN (10, 31, 32, 33, 1231, 1232, 1233, 1237, 1238) -- Outright, VSRacing
			AND bettype NOT BETWEEN 1301 AND 1399 -- exclude sporting solution product
			AND bettype NOT BETWEEN 153 AND 156   -- New bettype of Tennis
			AND bettype NOT BETWEEN 1501 and 1599 -- Keno
			AND bettype NOT IN (135,160,164,168,169,173,174,175,176,180,192,193,210,211,212,213,214,215,216,217) --Auto bets BetRadar 2 

	GROUP BY custid


	INSERT INTO #Balance
	SELECT b.custid, a.balance - b.balance, CASE WHEN a.balance > b.balance THEN 1 ELSE 0 END
	FROM #BalanceBefore b
		INNER JOIN #BalanceAfter a ON b.custid = a.custid
	WHERE b.balance <> a.balance

	INSERT INTO @tblDebitPending (custID, balance)
	SELECT	custid, ABS(balance)
	FROM	#Balance
	WHERE	Increased = 0
	
	IF @@rowcount <> 0
		EXEC dbo.Dot_BalancePendingDebitIns 
			@BalancePending = @tblDebitPending
			,@Type			= 1 -- Sports

	INSERT INTO @tblCreditPending (custID, balance)
	SELECT	custid, balance
	FROM	#Balance
	WHERE	Increased = 1
	
	IF @@rowcount <> 0
		EXEC dbo.Dot_BalancePendingCreditIns 
			@BalancePending = @tblCreditPending
			,@Type			= 1 -- Sports
			
	----
	-- Add Negative Balance into BalanceNegative table 
	----
	IF OBJECT_ID('BalanceNegative','U') IS NOT NULL
	BEGIN
		INSERT INTO [dbo].[BalanceNegative]
				   ([ExecDate]
				   ,[MatchID]
				   ,[ActionID]
				   ,[GroupID]
				   ,[CustID]
				   ,[Balance]
				   ,[StatusID]
				   ,[Remark])
		SELECT	 GETDATE()
				,@MatchID
				,@ActionID
				,1			-- Sportsbook Single bet Settlement 
				,CustID
				,Balance
				,0
				,NULL 
		FROM	#Balance WITH (NOLOCK)
		WHERE	Increased = 0
	END		        
	---------------------------------------------------

	DROP TABLE #Balance
	DROP TABLE #BalanceBefore
	DROP TABLE #BalanceAfter

	----------------------------------------------------
	--Write Log Settle
	BEGIN
		DECLARE 
			@finalhomescore INT, @finalawayscore INT,
			@hthomescore INT, @htawayscore INT,
			@goalrecord varchar(50), @betstatus nvarchar(50)
		SELECT 
			@finalhomescore = finalhomescore,
			@finalawayscore = finalawayscore,
			@hthomescore = hthomescore, 
			@htawayscore = htawayscore,
			@goalrecord = goalrecord,
			@betstatus = betstatus
		 FROM dbo.match WITH(NOLOCK) WHERE matchid = @matchid

		SELECT @SiteDBGroupId = (SELECT dbo.f_Get_SiteDBGroupID())
		SELECT @Remark ='<root>'
							+ '<r t="n" n="SiteDB" v="' + CAST(ISNULL(@SiteDBGroupId, 0) AS VARCHAR)  + '"/>'
							+ '<r t="dmin" n="StartTime" v="' + CONVERT(VARCHAR, @start, 120)  + '"/>'			
							+ '<r t="dmax" n="EndTime" v="' + CONVERT(VARCHAR, GETDATE(), 120) + '"/>'							
						+ '</root>'

		EXEC bodb_CustomerLog.dbo.WriteLog_SSB_UserLog_Settle
			@UserID = @creator,
			@Matchid = @matchid,
			@ActionID = @ActionID,
			@finalhomescore = @finalhomescore,
			@finalawayscore = @finalawayscore,  
			@hthomescore = @hthomescore,
			@htawayscore = @htawayscore,
			@GoalRecord =@GoalRecord,
			@betstatus = @betstatus,
			@Remark = @Remark,
			@IP = @IP,
			@BroadcastSessionId = @BroadcastSessionId
		
	 END

	------ releasing Settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch		= 1
		, @IsReleased		= 1
END

GO