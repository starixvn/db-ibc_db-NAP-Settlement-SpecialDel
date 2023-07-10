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




--------------------------------------------------------------------------------------
/* Check function void of SD - Check on Central and SiteDB*/
/*
--DBTRANS/SITEDB

USE bodb02

SELECT *
FROM DBO.TVS_UserActionLog (NOLOCK) --keep 14 day
WHERE (
	SPNAME LIKE '%NAP_SpecialDelete_VoidParlayBet_Update%'
OR SPNAME LIKE '%NAP_SpecialDelete_VoidSingleBet_Update%'
OR SPNAME LIKE '%NAP_SpecialDelete_VoidByCurrency_Update%'
OR SPNAME LIKE '%NAP_SpecialDelete_VoidBetIdList_Upd%'
OR SPNAME LIKE '%NAP_BettransDelSpecialDel_EarlyKO%'
OR SPNAME LIKE '%NAP_SpecialDelete_VoidParlaySubVSBetRadar_Upd%'
OR SPNAME LIKE '%NAP_BettransDelSpecial_NumberGame%' 
)
AND 
(MATCHID IN (69675879,69683206,69695637)
OR SQLCOMMAND LIKE '%%'
)
*/

