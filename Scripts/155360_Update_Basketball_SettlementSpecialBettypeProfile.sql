/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created by: 20210524@Louisa
	Task	  : SOP for Basketball [Redmine:#155360]
	DB		  : DBTXN/bodb02

	Revisions:
		20210524@Louisa: Move bettype 605, 617 from Calculate popup to Early popup   [Redmine:#155360]
*/

USE bodb02
GO

BEGIN

	UPDATE sp
	SET  sp.SettleType = 'EAR'
	FROM dbo.SettlementSpecialBettypeProfile sp WITH(ROWLOCK,UPDLOCK)
	WHERE sp.SportType = 2
	AND sp.BetType IN ( 605, 617 )

END