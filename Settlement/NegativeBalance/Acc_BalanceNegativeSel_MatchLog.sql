/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_BalanceNegativeSel_MatchLog]
	 @MatchID	INT,
	 @GroupID	INT = 1 
AS
/*
	Created by: Jamie
	Date: 2013-06-26
	Task: Retreive Match Info and Settlement Log 
	DB: DBLOG/bodb_CustomerLog 
	
	Revisions:
		- 20140304@Elodie: Retreive settlement log for outright
		- 20150918@Elodie: Get Log Action Name by Chinese langague [Red:#43705]
		- 20170629@Bobby: 78882 - Add groupid = 7
		- 20180103@Helen: Change Action List on Negative Balance email & Get Mailing List from OIC [Redmine:82430]
		- 20181116@Helen: action=165 Calculate Fast Markets,do NOT get for userid=111  [Redmine:82430]
		- 20190405@Patrick: Support archive date range [Redmine: #111476]
		- 20190103@Vicky: Incorporate BetBuilder  [Redmine:#106903]
		- 20220711@Kathy: Do not use SELECT INTO [Redmine:#175276]
		- 20230213@Aries: Migrate Calculate Outright Function to NAP Settlement Site [Redmine:#163971]
		- 20230621@Kathy: Remove checking event in 14/bk range after reviewing [Redmine:#186616]
		- 20231030@Aries: Enhance negative balance e-mail to remove redundant information [Redmine:#196172]
		
	Param's Explanation: 
		+ @GroupID: 1: Match Single Bet; 2: Match Parlay Bet ; 3: Outright; 7: Vitural Sport

*/
BEGIN 
	SET NOCOUNT ON 

	DECLARE @tmpMatch TABLE (
		 MatchID		INT PRIMARY KEY
		,LeagueID		INT
		,MatchCode		VARCHAR(50)
		,EventDate		DATETIME
		,HomeID			INT
		,AwayID			INT
		,SportType		INT
	)
	
	CREATE TABLE #__tmpData (LogId BIGINT, LogDate DATETIME, finalhomescore INT, finalawayscore INT, hthomescore INT, htawayscore INT, ActionID INT, Remark VARCHAR(MAX), UserID INT)

	IF @GroupID IN (1,2,7)
	BEGIN 
		INSERT INTO @tmpMatch(
				MatchID
			,LeagueID
			,MatchCode
			,EventDate
			,HomeID
			,AwayID
			,SportType
		)
		SELECT	 TOP 1 MatchID
				,LeagueID
				,MatchCode
				,EventDate
				,HomeID
				,AwayID
				,SportType
		FROM	bodb02.dbo.[match]  WITH (NOLOCK)
		WHERE	matchid = @MatchID
	END 
	ELSE IF @GroupID = 3 
	BEGIN	
		INSERT INTO @tmpMatch(
				MatchID
			,LeagueID
			,MatchCode
			,EventDate
			,HomeID
			,AwayID
		)
		SELECT	 orid
				,leagueid
				,matchcode
				,eventdate
				,teamid
				,0
		FROM	bodb02.dbo.[outright] WITH (NOLOCK)	
		WHERE	orid = @MatchID
	END

	SELECT	 MatchID
			,LeagueID
			,MatchCode
			,EventDate
			,HomeID
			,AwayID
			,SportType
	FROM	@tmpMatch

	IF @GroupID IN (1,2,7)
	BEGIN
		
		DECLARE @__archiveDate DATETIME
		SELECT @__archiveDate = DATEADD(DAY, 1, dbo.f_CustomerLog_GetArchiveDate())

		
		INSERT INTO #__tmpData (LogId, LogDate, finalhomescore, finalawayscore, hthomescore, htawayscore, ActionID, Remark, UserID)
		SELECT LogId, LogDate, finalhomescore, finalawayscore, hthomescore, htawayscore, ActionID, Remark, UserID
		FROM (
			SELECT LogID, LogDate, finalhomescore, finalawayscore, hthomescore, htawayscore, ActionID, Remark, UserID
			FROM dbo.UserLog_Settle WITH(NOLOCK)
			WHERE MatchID = @MatchID AND LogDate >= @__archiveDate

			UNION ALL
			SELECT LogID, LogDate, finalhomescore, finalawayscore, hthomescore, htawayscore, ActionID, Remark, UserID
			FROM bodb_CustomerLog_Archive.dbo.UserLog_Settle WITH(NOLOCK)
			WHERE MatchID = @MatchID AND LogDate < @__archiveDate
		)t

		SELECT	  l.logid
				, l.logdate
				, act.ActionNameEN
				, act.ActionNameCS
				, l.finalhomescore
				, l.finalawayscore
				, l.hthomescore
				, l.htawayscore
		FROM	#__tmpData l WITH(NOLOCK)
				LEFT JOIN bodb_CustomerLog.dbo.LogAction la WITH (NOLOCK) ON l.ActionID = la.ActionID
				OUTER APPLY (
					SELECT 
						CASE 
							WHEN l.ActionId IN (187,188) THEN 
								CASE 
									WHEN l.Remark LIKE '%Multiple%' THEN  REPLACE(REPLACE(la.ActionNameEN, 'VS BetRadar', ''), 'All', 'Mix Parlay All') 
									ELSE REPLACE(la.ActionNameEN, 'VS BetRadar', '') --remove product name
								END
							
							WHEN l.ActionID IN (157,158) THEN REPLACE(la.ActionNameEN,'Auto Payout - ','')
							WHEN l.ActionID = 81009 THEN 'Calculate Single Match Parlay'
							WHEN l.ActionID = 81010 THEN 'Undo Single Match Parlay Settlement'
							ELSE la.ActionNameEN 
							
						END AS ActionNameEN
						,CASE 
							WHEN l.ActionId IN (187,188) THEN 
								CASE 
									WHEN l.Remark LIKE '%Multiple%' THEN  
										CASE 
											WHEN l.ActionId = 187 THEN N'计算混合过关' 
											WHEN l.ActionId = 188 THEN N'所有混合过关退款'
										END
									ELSE REPLACE(la.ActionNameCS, 'VS BetRadar', '') --remove product name
								END
							WHEN l.ActionID = 81009 THEN N'结算Single Match Parlay'
							WHEN l.ActionID = 81010 THEN N'撤消Single Match Parlay'
							ELSE la.ActionNameCS 
						END AS ActionNameCS
				) AS act

		WHERE 1 = CASE 
						WHEN @GroupID = 7 THEN 
							CASE 
								WHEN l.Remark NOT LIKE '%Error%' AND l.Remark NOT LIKE '%API%' THEN 1
								ELSE 0
							END
						ELSE 1
					END
			AND 1 = CASE 
						WHEN l.ActionID = 165 AND l.userID IN (111,17649007) THEN 0
						WHEN @GroupID IN (1,2) AND l.ActionID IN (SELECT actionid FROM dbo.f_Set_NegativeBalance_ActionGroup()) THEN 1 
						WHEN @GroupID = 7 THEN 1
						ELSE 0 END
			
		ORDER BY	l.LogID ASC 	
	END
	ELSE IF @GroupID = 3
	BEGIN
		SELECT	  l.logid
				, l.logdate
				, la.ActionNameEN
				, la.ActionNameCS
				, l.Result
				, CASE WHEN  l.ActionID = 137 AND CHARINDEX(',', l.Remark) = 0 AND CAST(l.Remark as INT) > 1 THEN 'DeadHeat(' + l.Remark + ')' 
					   WHEN  l.ActionID = 137 AND CHARINDEX(',', l.Remark) > 0 AND CAST(SUBSTRING(l.Remark, 0, CHARINDEX(',', l.Remark)) AS INT) > 1 THEN 'DeadHeat(' + SUBSTRING(l.Remark, 0, CHARINDEX(',', l.Remark)) + ')' 
					   ELSE '' 
				  END AS Remark
		FROM	bodb_CustomerLog.dbo.UserLog_SettleOutright l WITH(NOLOCK)
				LEFT JOIN bodb_CustomerLog.dbo.LogAction la WITH (NOLOCK) ON l.ActionID = la.ActionID
		WHERE	l.MatchID = @MatchID and l.ActionID IN (137,145,139)
		ORDER BY	l.LogID ASC 	
	END
END 

GO