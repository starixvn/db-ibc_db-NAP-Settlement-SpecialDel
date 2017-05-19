USE [bodb02]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_Set_MatchSelInfo_Auto_1s]
	@MatchID		INT

AS
/*	Creator: 20160516@Patrick
	Task: Auto Settlement - Select match info
	DB: DBPRO/BODB02
	Original: 
	
	Revisions:
		- 20170123@Kathy:  Allow user to Enable/Disable Auto Settlement of Fast Market [Redmine:#69949]
		
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON 
	
	DECLARE @IsExistFGLG 		BIT = 0
			,@IsExistHTFGLG  	BIT = 0
			,@IsCalRefund		BIT = 0
	
	IF EXISTS (SELECT TOP 1 1 FROM DBTXN.bodb02.dbo.bettrans b WITH (NOLOCK) WHERE matchid = @matchId AND StatusId NOT IN (101, 102) AND Bettype = 14)
		SET @IsExistFGLG = 1
	ELSE IF EXISTS (SELECT TOP 1 1 FROM DBTXN.bodb02.dbo.bettransm bm WITH (NOLOCK) WHERE matchid = @matchId AND StatusId NOT IN (101, 102) AND Bettype = 14)
		SET @IsExistFGLG = 1
		
	IF EXISTS (SELECT TOP 1 1 FROM DBTXN.bodb02.dbo.bettrans b WITH (NOLOCK) WHERE matchid = @matchId AND StatusId NOT IN (101, 102) AND Bettype = 127)
		SET @IsExistHTFGLG = 1
	ELSE IF EXISTS (SELECT TOP 1 1 FROM DBTXN.bodb02.dbo.bettransm bm WITH (NOLOCK) WHERE matchid = @matchId AND StatusId NOT IN (101, 102) AND Bettype = 127)
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
	FROM	dbo.Match m WITH (NOLOCK)
	WHERE	MatchID = @MatchID

END
GO
GRANT EXECUTE ON [dbo].[NAP_Set_MatchSelInfo_Auto_1s] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Set_MatchSelInfo_Auto_1s] TO [vnteam] AS [dbo]