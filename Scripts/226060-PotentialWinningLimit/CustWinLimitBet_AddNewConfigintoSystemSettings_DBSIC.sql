/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0" isNested="0"></info>*/
/*
	Created: 20250602@July
	Task: [Synergy] - Integration - Potential Winning Limit/Threshold - [Redmine: #226514]
	DB: DBSIC-bodb02

	Note: Only sitedb3
*/

USE bodb02
GO

DECLARE @LastTransId BIGINT
      , @LastRepUpdateTime DATETIME2(7)

SELECT @LastTransId = MAX(TransId) FROM dbo.bettrans WITH (NOLOCK)
SELECT @LastRepUpdateTime = MAX(RepUpdateTime) FROM dbo.CustWinLimitBet_History WITH (NOLOCK)

INSERT INTO systemsettings (VName, VValue) VALUES ('CustWinLimitBet_LastTransId', @LastTransId)
															   
INSERT INTO systemsettings (VName, VValue) VALUES ('CustWinLimitBet_LastRepUpdateTime ', CONVERT(VARCHAR(50), @LastRepUpdateTime, 21) )
															   
SELECT * FROM systemsettings WITH (NOLOCK) WHERE vname LIKE '%CustWinLimitBet%'
