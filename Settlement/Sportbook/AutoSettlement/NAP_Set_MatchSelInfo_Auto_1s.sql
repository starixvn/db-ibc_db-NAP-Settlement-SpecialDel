/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchSelInfo_Auto_1s]
	@MatchID		INT
AS
/*	Creator: 20160516@Patrick
	Task: Auto Settlement - Select match info
	DB: DBPRO/BODB02
	Original: 
	
	Revisions:
		- 20170123@Kathy:  Allow user to Enable/Disable Auto Settlement of Fast Market [Redmine:#69949]
		- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
		- 20200311@Sol: PH5 Enhancement - Early popyp auto fill [Redmine:#128076]
		
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON 
	
	DECLARE @IsExistFGLG 		BIT = 0
			,@IsExistHTFGLG  	BIT = 0
			,@IsCalRefund		BIT = 0
	
	CREATE TABLE #BettypeFGLG  (bettype SMALLINT, GroupID SMALLINT)
	INSERT INTO #BettypeFGLG (bettype,GroupID)
	SELECT BetType,GroupID
	FROM dbo.f_Set_GetGroupBettypes()
	WHERE IsFGLG = 1
	
	IF EXISTS (SELECT TOP 1 1 
				FROM DBTXN.bodb02.dbo.bettrans b WITH (NOLOCK) 
				WHERE matchid = @matchId AND StatusId NOT IN (101, 102) 
					AND EXISTS (SELECT 1 FROM #BettypeFGLG fglg WITH (NOLOCK) WHERE fglg.bettype = b.bettype AND fglg.GroupID IN (2,4))
			)
		SET @IsExistFGLG = 1
	ELSE IF EXISTS (SELECT TOP 1 1 
					FROM DBTXN.bodb02.dbo.bettransm bm WITH (NOLOCK) 
					WHERE matchid = @matchId AND StatusId NOT IN (101, 102) 
							AND EXISTS (SELECT 1 FROM #BettypeFGLG fglg WITH (NOLOCK) WHERE fglg.bettype = bm.bettype AND fglg.GroupID IN (2,4))
					)
		SET @IsExistFGLG = 1
		
	IF EXISTS (SELECT TOP 1 1 
				FROM DBTXN.bodb02.dbo.bettrans b WITH (NOLOCK) 
				WHERE matchid = @matchId AND StatusId NOT IN (101, 102) 
					AND EXISTS (SELECT 1 FROM #BettypeFGLG fglg WITH (NOLOCK) WHERE fglg.bettype = b.bettype AND fglg.GroupID IN (1,3))
				)
		SET @IsExistHTFGLG = 1
	ELSE IF EXISTS (SELECT TOP 1 1 
					FROM DBTXN.bodb02.dbo.bettransm bm WITH (NOLOCK) 
					WHERE matchid = @matchId AND StatusId NOT IN (101, 102) 
						AND EXISTS (SELECT 1 FROM #BettypeFGLG fglg WITH (NOLOCK) WHERE fglg.bettype = bm.bettype AND fglg.GroupID IN (1,3))
					)
		SET @IsExistHTFGLG = 1
	
	SELECT	@IsCalRefund = calrefund
	FROM	dbo.match_remark WITH(NOLOCK)
	WHERE	matchid = @matchId
	
	-- Match Info 
	SELECT	m.LeagueID
			,m.MatchID
			,m.matchcode
			,m.kickofftime
			,playTime = datediff(minute, m.kickofftime, CURRENT_TIMESTAMP) 
			,m.homeid
			,m.awayid
			,m.betstatus
			,m.GoalRecord
			,m.hthomescore AS HalfTimeHomeScore
			,m.htawayscore AS HalfTimeAwayScore
			,m.finalhomescore
			,m.finalawayscore
			,@IsExistFgLg AS IsExistFgLg
            ,@IsExistHtFgLg AS IsExistHtFgLg
            ,@IsCalRefund AS IsCalRefund
            ,m.AutoSetting
            ,(SELECT AutoSetting FROM dbo.League WITH(NOLOCK) WHERE leagueid = m.leagueid) AS AutoSettingForLeague
			,m.ChildMatchType
	FROM	dbo.Match m WITH (NOLOCK)
	WHERE	MatchID = @MatchID
	
	DROP TABLE #BettypeFGLG

END
GO