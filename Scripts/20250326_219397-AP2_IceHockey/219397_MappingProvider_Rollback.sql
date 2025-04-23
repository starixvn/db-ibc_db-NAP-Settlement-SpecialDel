/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20250326@Aries
	Task: Support AutoPayout2 for Ice Hockey [Redmine:#219397]
	DB: DBPRO/bodb02
*/

USE bodb02
GO

--Ice-Hockey 
UPDATE ProviderGameTypeMapping
SET isActive = 0
WHERE sporttype = 4  

--Handball
UPDATE ProviderGameTypeMapping
SET isActive = 0
WHERE sporttype = 24
