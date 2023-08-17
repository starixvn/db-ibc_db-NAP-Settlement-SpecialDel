/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20230817@Max
	Task: Support delete duplicate data on zzzbettrans & zzzbettransM [Redmine: #00000]
	DB: DBCTG-bodb02
*/

USE bodb02
GO

--zzzbettrans
DELETE z
FROM dbo.zzzbettrans z
WHERE z.TransId = 152151780556275728
AND z.source_keyid = 0

--zzzbettransm
DELETE zm
FROM dbo.zzzbettransm zm
WHERE zm.TransId = 152120272676192268
AND zm.source_keyid = 0
	

