/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20220928@July
	Task: Migrate data column winlost bettransm14 - [Redmine:#175412]  
	DB: DBCTG-bodb02
*/

USE bodb02
GO

UPDATE b 
SET b.winlost = CASE WHEN odds > 0 THEN stake ELSE stake * ABS(odds) END
FROM dbo.bettransm14 b WITH(ROWLOCK, UPDLOCK)
WHERE b.transid IN (
		30868428176752642
		,30868479716360193
		,30871610747518977
		,30930829756596226
		,30930872706269186
		,30930894181105670
		,31226250492116997
		,31226250492117000
		)




