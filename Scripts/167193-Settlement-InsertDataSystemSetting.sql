/*<info serverAlias="SBSETTLE-bodb02" executers="" viewers="" isFunction="0"></info>*/
USE bodb02
GO

/*  Created: Kathy@20220107
	Task: monitor Settlement log [Redmine:#167193]
	DB: SBSETTLE-bodb02
*/

INSERT INTO dbo.SystemSettings (VName, VValue) VALUES ('CheckCalculationLogs', 5)
