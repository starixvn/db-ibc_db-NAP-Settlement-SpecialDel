/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_BetDaq_Move]
	@MatchID		INT,
	@NewMatchID		INT,
	@AdminId		INT,
	@BroadcastSessionId VARCHAR(50)	= NULL,
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(100)='' OUTPUT,  
	@NewMatchcode	NVARCHAR(20) ='' OUTPUT,
	@IP varchar(15) = ''
AS
/*
	Created: Kathy
	Date: 20140114
	Task: Move BetDaq to new match 
	DB: DBTXN/BODB02 

	Revisions: 
			- 20140512@Kathy: Add more log to distinguish between NAP and old settlement system
			- 20141024@Jamie: Sportting Solution Tennis Settlement [Redmine:#23034]
			- 20150418@Jamie: Betradar phase II [Readmine:#27212]
			- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
			- 20230214@Aries: Use Service Broker to Write Log to DB Log [Redmine: #187252]
			- 20230921@Kathy: change the way to write log for single ticket [Redmine:#193125]

	Note: For settlement SPs should hardcode the custid of betdaq customer to avoid replication problem


	Param's Explanation: 
		@MatchID: current match 

*/
BEGIN
	SET NOCOUNT ON
	DECLARE	@awayID			INT,
			@homeID			INT,
			@leagueID		INT,
			@eventdate		DATETIME,			
			@newEventdate	DATETIME,
			@matchcode		VARCHAR(20),
			@sporttype		INT ,
			@transinfo		XML,
			@IsSiteDB		BIT = 0,
			@SiteDBGroupId	TINYINT,
			@StartTime		DATETIME
	
	SET @StartTime = GETDATE()
	IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL 
	SET @IsSiteDB = 1

	DECLARE @finalhomescore INT, @finalawayscore INT,
			@hthomescore INT, @htawayscore INT,
			@betstatus nvarchar(50), @goalrecord varchar(50), @Remark varchar(MAX)

	DECLARE @finalhomescore1 INT, @finalawayscore1 INT,
			@hthomescore1 INT, @htawayscore1 INT,
			@betstatus1 nvarchar(50), @goalrecord1 varchar(50), @Remark1 varchar(MAX)

	DECLARE @tmpOdds TABLE (
		bettype		INT,
		oddsid		INT
	)
	
	DECLARE @tmpTransInfo TABLE 
	(	transid			BIGINT
		,matchid		INT
		,oddsid			INT
		,winlostdate	SMALLDATETIME
	)

	SELECT	@awayID		= awayID,
			@homeID		= homeID,
			@leagueID	= leagueID,
			@eventdate	= eventdate,
			@finalhomescore = finalhomescore,
			@finalawayscore = finalawayscore,
			@hthomescore = hthomescore, 
			@htawayscore = htawayscore,
			@goalrecord = goalrecord,
			@betstatus = betstatus,
			@matchcode = matchcode,
			@sporttype = sporttype
	FROM	DBPRO.BODB02.dbo.Match WITH (NOLOCK)
	WHERE	matchid = @MatchID 

	SELECT	@NewMatchcode	= matchcode, 
			@newEventdate	= eventdate,
			@finalhomescore1 = finalhomescore,
			@finalawayscore1 = finalawayscore,
			@hthomescore1 = hthomescore, 
			@htawayscore1 = htawayscore,
			@goalrecord1 = goalrecord,
			@betstatus1 = betstatus   
	FROM	DBPRO.BODB02.dbo.match WITH (NOLOCK) 
	WHERE	matchid = @NewMatchID
	
	INSERT INTO @tmpOdds ( bettype, oddsid)
	SELECT	bettype, max(oddsid)
	FROM	DBPRO.BODB02.dbo.odds WITH (NOLOCK)
	WHERE	matchid = @NewMatchID
			AND liveindicator = 0 
	GROUP BY bettype 

	UPDATE	bettrans WITH (ROWLOCK,UPDLOCK)
	SET		matchid		= @NewMatchID, 
			oddsid		= o.oddsid, 
			winlostdate = @newEventdate 
	OUTPUT inserted.TransId
			,inserted.matchid 
			,inserted.oddsid
			,inserted.winlostdate
	INTO @tmpTransInfo (transid, matchid, oddsid, winlostdate)
	FROM	bettrans b
			INNER JOIN @tmpOdds o ON b.bettype = o.bettype 
	WHERE	b.matchid = @MatchID 
			AND b.bettype NOT IN (135,160,164,168,169,173,174,175,176,180,192,193,210,211,212,213,214,215,216,217)
			AND (b.custid IN (50057, 879241, 103873, 78761, 851668, 878902) or b.recommend = 1688156)
			AND b.ruben = 0
			AND 1 = CASE WHEN @Sporttype = 5 AND b.bettype NOT IN (1,2,3,20) THEN 0 
						 ELSE 1 END 
			AND b.SiteDBGroupID = CASE WHEN @IsSiteDB = 1 THEN b.SiteDBGroupID ELSE 0 END
			/*
			AND (
				b.custid IN (Select CustID from  [f_GetBetDaqCustomer] (1)) 
				or b.recommend IN (Select CustID from  [f_GetBetDaqCustomer] (2))
				)
			*/	
	
	IF @@ERROR = 0 AND @IsSiteDB = 1 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)
	BEGIN
			SET @transInfo = (
				SELECT transId AS '@t'	
						,matchid AS '@mid'
						,oddsid AS '@oid'
						,winlostdate AS '@wld'
				FROM	@tmpTransInfo
				FOR XML PATH('r'),ROOT('root'), TYPE
			)
			INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo, SettlementAction, TicketType)
			VALUES ('Settlement', 'MoveBetdaq', 'bettrans', @MatchId, @transInfo, 'MoveBetdaq', 's')
	END
	ELSE IF @@ERROR <> 0
	BEGIN
		SELECT	@ErrCode = 103,
				@ErrMsg  =  'Moving match is not successful!'
		RETURN
	END

	-- write log
	BEGIN
		SELECT @SiteDBGroupId = (SELECT dbo.f_Get_SiteDBGroupID())
		SELECT @Remark ='<distinct>'
							+ '<r n="To match" v="' + CONVERT(VARCHAR(10),@NewMatchid) + '"/>'
							+ '<r n="MatchCode" v="' +@newMatchcode + '"/>'
						+'</distinct>'
						+ '<root>'
							+ '<r t="n" n="SiteDB" v="' + CAST(ISNULL(@SiteDBGroupId, 0) AS VARCHAR)  + '"/>'
							+ '<r t="dmin" n="StartTime" v="' + CONVERT(VARCHAR, @StartTime, 120)  + '"/>'			
							+ '<r t="dmax" n="EndTime" v="' + CONVERT(VARCHAR, GETDATE(), 120) + '"/>'							
						+ '</root>'

		SELECT @Remark1 ='<distinct>'
							+ '<r n="From match" v="' + CONVERT(VARCHAR(10),@Matchid) + '"/>'
							+ '<r n="MatchCode" v="' + @matchcode + '"/>'
						+'</distinct>'
						+ '<root>'
							+ '<r t="n" n="SiteDB" v="' + CAST(ISNULL(@SiteDBGroupId, 0) AS VARCHAR)  + '"/>'
							+ '<r t="dmin" n="StartTime" v="' + CONVERT(VARCHAR, @StartTime, 120)  + '"/>'			
							+ '<r t="dmax" n="EndTime" v="' + CONVERT(VARCHAR, GETDATE(), 120) + '"/>'							
						+ '</root>'

		EXEC bodb_CustomerLog.dbo.WriteLog_SSB_UserLog_Settle
			@UserID = @AdminId,
			@Matchid = @MatchID,
			@ActionID = 113,
			@finalhomescore = @finalhomescore,
			@finalawayscore = @finalawayscore,  
			@hthomescore = @hthomescore,
			@htawayscore = @htawayscore,
			@GoalRecord = @goalrecord,
			@betstatus = @betstatus,
			@Remark = @Remark,
			@IP = @IP,
			@BroadcastSessionId = @BroadcastSessionId

		EXEC bodb_CustomerLog.dbo.WriteLog_SSB_UserLog_Settle
			@UserID = @AdminId,
			@Matchid = @NewMatchID,
			@ActionID = 114,
			@finalhomescore = @finalhomescore1,
			@finalawayscore = @finalawayscore1,  
			@hthomescore = @hthomescore1,
			@htawayscore = @htawayscore1,
			@GoalRecord = @goalrecord1,
			@betstatus = @betstatus1,
			@Remark = @Remark1,
			@IP = @IP,
			@BroadcastSessionId = @BroadcastSessionId
	END

END
GO
