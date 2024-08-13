/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20240608@Aries
	    - 20240604@Aries: Transfer the logic business from the DB layer to the Application layer for Happy5 [Redmine:#202389]
	DB: DBPRO/bodb02
*/
USE bodb02


UPDATE bingoBall
SET Number = 1
WHERE  matchid = 90252737
    AND Seq = 1

UPDATE bingoBall
SET Number = 2
WHERE  matchid = 90252737
    AND Seq = 2


UPDATE bingoBall
SET Number = 3
WHERE  matchid = 90252737
    AND Seq = 3

UPDATE bingoBall
SET Number = 4
WHERE  matchid = 90252737
    AND Seq = 4

UPDATE bingoBall
SET Number = 5
WHERE  matchid = 90252737
    AND Seq = 5