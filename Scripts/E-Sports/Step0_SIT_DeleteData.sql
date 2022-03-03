/*<info serverAlias="DBTXN-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by: 20220224@Louisa
    Task: 20220224@Louisa: Support Test SIT : ESports Phase 4 [Redmine:#166330]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20220224@Louisa: Delete 54 new bettype ( run SIT only ) [Redmine:#166330]
*/

USE bodb02
GO


DELETE FROM dbo.SettlementSpecialBettypeProfile
WHERE SportType = 43
	AND SettleType = 'EAR'
	AND bettype IN (
9089,9090,9091,9092,9093,9094,9095,9096,9097,9098,9099,9100,9101,9102,9103,9104,9105
,9106,9107,9108,9109,9110,9111,9112,9113,9114,9115,9116,9117,9118,9119,9120,9121,9122
,9123,9124,9125,9126,9127,9128,9129,9130,9131,9132,9133,9134,9135,9136,9137,9138,9139,9140,9141,9142)

GO