/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
/*	
	Creator by: 20230705@July
	Task: [SD] Enhance void log to detect more information
	DB: DBLOG/bodb_CustomerLog

	Revisions:
		- 20230705@July: Insert new LogAction  [Redmine:#190590]

*/

USE bodb_CustomerLog
GO
INSERT INTO dbo.LogAction (ActionID, SPName, ActionNameEN, ActionNameCH, ActionNameCS, ActionNameJP, ActionNameTH, ActionNameKO, ActionNameVI,IsInternal) 
VALUES (90512, 
		'NAP_SpecialDelete_VoidSingleBet_Update', 
		'Void Single Bet',
		'Void Single Bet',
		'Void Single Bet',
		'Void Single Bet',
		'Void Single Bet',
		'Void Single Bet',
		'Void Single Bet',
		0
		),
	(90513, 
		'NAP_SpecialDelete_VoidBetIdList_Upd', 
		'Void By BetId',
		'Void By BetId',
		'Void By BetId',
		'Void By BetId',
		'Void By BetId',
		'Void By BetId',
		'Void By BetId',
		0
		),
	(90514, 
		'NAP_SpecialDelete_VoidByCurrency_Update', 
		'Void By Currency',
		'Void By Currency',
		'Void By Currency',
		'Void By Currency',
		'Void By Currency',
		'Void By Currency',
		'Void By Currency',
		0
		),
	(90515, 
		'NAP_SpecialDelete_VoidParlayBet_Update', 
		'Void Parlay Bet',
		'Void Parlay Bet',
		'Void Parlay Bet',
		'Void Parlay Bet',
		'Void Parlay Bet',
		'Void Parlay Bet',
		'Void Parlay Bet',
		0
		),
	(90516, 
		'NAP_SpecialDelete_VoidParlaySubVSBetRadar_Upd', 
		'Void Parlay Sub Virtual Sports Bet',
		'Void Parlay Sub Virtual Sports Bet',
		'Void Parlay Sub Virtual Sports Bet',
		'Void Parlay Sub Virtual Sports Bet',
		'Void Parlay Sub Virtual Sports Bet',
		'Void Parlay Sub Virtual Sports Bet',
		'Void Parlay Sub Virtual Sports Bet',
		0
		),
	(90517, 
		'NAP_BettransDelSpecialDel_EarlyKO', 
		'Void Early KO Bet',
		'Void Early KO Bet',
		'Void Early KO Bet',
		'Void Early KO Bet',
		'Void Early KO Bet',
		'Void Early KO Bet',
		'Void Early KO Bet',
		0
		),
	(90518, 
		'NAP_BettransDelSpecial_NumberGame', 
		'Void Number Game Bet',
		'Void Number Game Bet',
		'Void Number Game Bet',
		'Void Number Game Bet',
		'Void Number Game Bet',
		'Void Number Game Bet',
		'Void Number Game Bet',
		0
		)
select * from dbo.LogAction where ActionID >= 90512 and ActionID<=91000