/*<info serverAlias="DBTXN-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by: 20220303@Louisa
    Task: 20220303@Louisa: ESports Phase 4 [Redmine:#166330]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20220303@Louisa: Update fomular for bettype 9090 due to betoption has changed
*/

USE bodb02
GO

	UPDATE dbo.SettlementSpecialBettypeProfile WITH(ROWLOCK, UPDLOCK)
	SET pfid = 9090
	WHERE SportType = 43
		AND bettype = 9090
		AND pfid = 101

GO
