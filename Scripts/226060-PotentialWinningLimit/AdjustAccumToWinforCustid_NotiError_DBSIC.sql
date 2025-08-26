/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0" isNested="0"></info>*/
/*
	Created: 20250826@July
	Task: [Synergy] - Adjust wrong data for CustID - 94447317 in CustWinLimitBet.AccumToWin - [Redmine: #237077]
	DB: DBSIC-bodb02

	Note: Only sitedb3
*/
USE bodb02
GO
DECLARE @CustID		INT = 94447317

UPDATE c
		SET AccumToWin =  AccumToWin - 3094 
		  , RepUpdateTime = [dbo].[f_GetDateTime2]()
FROM CustWinLimitBet c WITH (ROWLOCK, UPDLOCK)
WHERE c.CustID = @CustID