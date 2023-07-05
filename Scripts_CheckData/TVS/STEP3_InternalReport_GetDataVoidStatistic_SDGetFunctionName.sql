/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/

USE bodb_CustomerLog
GO
SELECT a.ActionNameEN AS Function_SDName ,ActionID,l.*
FROM dbo.TicketVoiding_Log l WITH(NOLOCK) 
	INNER JOIN dbo.LogAction a WITH(NOLOCK)  ON l.LogActionId = a.ActionID
WHERE LogActionid IN (90512,90513,90514,90515,90516,90517,90518)
	AND (
		MatchID IN (69666733)
		OR 
		LogData LIKE '%137052032753205253%'
	)
