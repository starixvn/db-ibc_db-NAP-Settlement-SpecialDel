/*<info serverAlias="DBTP-bodb02" executers="" isFunction="0"></info>*/
/*
	Created: 20241017@July 
	Task: Support script to handle the issue: tickets moved to 14 but event still be in active table for VS2 - [Redmine: #212251]
	DB: DBTP-bodb02
*/

USE bodb02
GO

--CASE 1: scan ticket của 2 sports issue ở 14 => lấy ra danh sách các ticket vs matchid của nó => Move
SELECT DISTINCT matchid, winlostdate --108 matches
FROM dbo.bettrans14 b WITH(NOLOCK)
	INNER JOIN dbo.VSRaceInfo vs WITH(NOLOCK) ON b.matchid = vs.EventID
WHERE vs.SportType IN (198,177)

	
--CASE 2: những thằng nào đã settled rồi mà chưa update eventstatus thì mình update cho nó
SELECT DISTINCT matchid, winlostdate --90 matches
--vo.EventStatus, * 
FROM dbo.bettrans b WITH(NOLOCK)
	INNER JOIN dbo.VSRaceInfo vs WITH(NOLOCK) ON b.matchid = vs.EventID
	CROSS APPLY (SELECT DISTINCT vo.EventID, vo.EventStatus
                FROM dbo.VSOutright vo WITH(NOLOCK) 
				WHERE b.matchid = vo.EventID
			)vo
WHERE vs.EventStatus = 'completed'
	AND vo.EventStatus <> 'completed'