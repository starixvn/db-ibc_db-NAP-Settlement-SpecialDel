/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="vnteam" isFunction="0"></info>*/
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
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
		- 20241223@Aries: Support Auto Refund for Soccer's Early Results [Redmine:#214410]

		
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON 
	
	DECLARE @IsCalRefund		BIT = 0
	
	SELECT	@IsCalRefund = calrefund
	FROM	dbo.match_remark WITH(NOLOCK)
	WHERE	matchid = @matchId
	
	-- Match Info 
	SELECT	m.LeagueID
			,m.MatchID
			,m.sporttype
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
            ,@IsCalRefund AS IsCalRefund
            ,m.AutoSetting
            ,(SELECT AutoSetting FROM dbo.League WITH(NOLOCK) WHERE leagueid = m.leagueid) AS AutoSettingForLeague
			,m.ChildMatchType
	FROM	dbo.Match m WITH (NOLOCK)
	WHERE	MatchID = @MatchID

END
GO