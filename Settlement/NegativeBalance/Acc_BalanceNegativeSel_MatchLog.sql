/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
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
		- 
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
	
	IF @GroupID IN (1,2,7)
	BEGIN 

		IF EXISTS (SELECT TOP 1 1 FROM bodb02.dbo.[match] WITH (NOLOCK) WHERE matchid = @MatchID)
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
		ELSE IF EXISTS (SELECT TOP 1 1 FROM bodb02.dbo.[match14] WITH (NOLOCK) WHERE matchid = @MatchID) 
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
			FROM	bodb02.dbo.[match14]  WITH (NOLOCK)
			WHERE	matchid = @MatchID
		END
		ELSE 
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
			FROM	DBACC.bodb_archive.dbo.[match_bk]  WITH (NOLOCK)
			WHERE	matchid = @MatchID
		END
	END 
	ELSE IF @GroupID = 3 
	BEGIN
		IF EXISTS (SELECT TOP 1 1 FROM bodb02.dbo.[outright] WITH (NOLOCK) WHERE orid = @MatchID)
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
		ELSE IF EXISTS (SELECT TOP 1 1 FROM bodb02.dbo.[outright14] WITH (NOLOCK) WHERE orid = @MatchID) 
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
			FROM	bodb02.dbo.[outright14] WITH (NOLOCK)	
			WHERE	orid = @MatchID		
		END 
		ELSE 
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
			FROM	DBACC.bodb_Archive.dbo.[outright_bk] WITH (NOLOCK)	
			WHERE	orid = @MatchID			
		END
		
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
		SELECT	  l.logid
				, l.logdate
				, act.ActionNameEN
				, act.ActionNameCS
				, l.finalhomescore
				, l.finalawayscore
				, l.hthomescore
				, l.htawayscore
		FROM	bodb_CustomerLog.dbo.UserLog_Settle l WITH(NOLOCK)
				LEFT JOIN bodb_CustomerLog.dbo.LogAction la WITH (NOLOCK) ON l.ActionID = la.ActionID
				OUTER APPLY (
					SELECT 
						CASE 
							WHEN l.ActionId IN (187,188) THEN 
								CASE 
									WHEN l.Remark LIKE '%Multiple%' THEN  REPLACE(REPLACE(la.ActionNameEN, 'VS BetRadar', ''), 'All', 'Mix Parlay All') 
									ELSE REPLACE(la.ActionNameEN, 'VS BetRadar', '') --remove product name
								END
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
							ELSE la.ActionNameCS 
						END AS ActionNameCS
				) AS act

		WHERE	l.MatchID = @MatchID
			AND 1 = CASE 
						WHEN @GroupID = 7 THEN 
							CASE 
								WHEN l.Remark NOT LIKE '%Error%' AND l.Remark NOT LIKE '%API%' THEN 1
								ELSE 0
							END
						ELSE 1
					END
		ORDER BY	l.LogID ASC 	
	END
	ELSE IF @GroupID = 3
	BEGIN
		SELECT	  l.logid
				, l.logdate
				, la.ActionNameEN
				, la.ActionNameCS
				, l.Result
				, CASE WHEN l.ActionID = 137 AND cast(l.Remark as INT) > 1 THEN 'DeadHeat(' + l.Remark + ')' ELSE '' END AS Remark
		FROM	bodb_CustomerLog.dbo.UserLog_SettleOutright l WITH(NOLOCK)
				LEFT JOIN bodb_CustomerLog.dbo.LogAction la WITH (NOLOCK) ON l.ActionID = la.ActionID
		WHERE	l.MatchID = @MatchID and l.ActionID IN (137,141,139)
		ORDER BY	l.LogID ASC 	
	END
END 
GO 