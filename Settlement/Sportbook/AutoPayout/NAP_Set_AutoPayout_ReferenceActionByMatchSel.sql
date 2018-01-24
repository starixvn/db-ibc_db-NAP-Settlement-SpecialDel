/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_AutoPayout_ReferenceActionByMatchSel @MatchIds VARCHAR(MAX)
	, @ActionIds VARCHAR(1024)
AS

/*	Creator: 20160311@Patrick
	Task: Auto Payout - Get reference action
	DB: DB052/bodb_CustomerLog
	
	Revision:	
		- 20160930@Bobby: #65002 - Add HomeScore & AwayScore info
		- 20161221@Bobby: #69159 - Correct HomeScore & AwayScore info		
		- 20180123@Benjamin: ActionID: 195-HT 196-FT for Auto Instant [Redmine:#86964]
      
	Param's Explanation:
		
		
*/
BEGIN
	SET NOCOUNT ON

	;WITH MatchTmp AS (
		SELECT CAST(val AS INT) AS MatchId
		FROM bodb02.dbo.Lrf_f_StringSplit(@MatchIds, ',')
	), ActionLogTmp AS (
		SELECT CAST(val AS INT) AS ActionId
		FROM bodb02.dbo.strSplit(@ActionIds, ',')
	)

	SELECT LogId, MatchID, ActionID, CASE WHEN Remark LIKE 'Failed%' THEN 1 ELSE 0 END AS IsFailed
		, CASE 	WHEN ActionID IN (178, 102, 195) THEN hthomescore 
				WHEN ActionID IN (179, 101, 100, 196) THEN finalhomescore 
				ELSE 0 
		END AS HomeScore
		, CASE 	WHEN ActionID IN (178, 102, 195) THEN htawayscore 
				WHEN ActionID IN (179, 101, 100, 196) THEN finalawayscore 
				ELSE 0 
		END AS AwayScore
		
	FROM dbo.UserLog_Settle l WITH(NOLOCK)
	WHERE EXISTS (SELECT TOP 1 1 FROM MatchTmp f WHERE f.MatchId = l.MatchID)
		AND EXISTS (SELECT TOP 1 1 FROM ActionLogTmp f WHERE f.ActionId = l.ActionID)
	ORDER BY LogId

END

