/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20230207@Aries
	Task: Apply Settlement by Profile for Remaining Sports [Redmine: #182677]
	DB: DBPRO/bodb02
*/


USE bodb02
GO

UPDATE dbo.SettlementResultTableSetting  WITH (ROWLOCK, UPDLOCK) 
SET  IsSettleByProfile = 1
    ,IsMergedParlay = 1   
WHERE SportType IN (3,4,7,8,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,44,46,47,48,49,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,68,69,98,99)

GO
