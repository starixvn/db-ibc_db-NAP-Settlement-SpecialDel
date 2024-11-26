/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 2024111@Louisa
	Task: Refund Determined for Baseball [Redmine: #212365]
	DB: DBPRO/bodb02
*/
 
USE bodb02
GO 

--1. Extend [SDTRefund] from TINYINT to  SMALLINT
-----------------------------------------------------------------
 ALTER TABLE dbo.settlementspecialbettypeprofile ALTER COLUMN SDTRefund SMALLINT
 GO

--2. Update setting for SDTRefund
-----------------------------------------------------------------
/*
--Bit4 -> Bit5 -> Bit6 -> Bit7 -> Bit8 -> Bit9 -> Bit10 -> Bit11 -> Bit12 -> Bit13
--Inn1 -> Inn2 -> Inn3 -> Inn4 -> Inn5 -> Inn6 -> Inn7  -> Inn8  -> Inn9  -> EI

*/

	CREATE TABLE #tmp_newSetting ( bettype SMALLINT, SDTRefund INT )
	INSERT INTO #tmp_newSetting ( bettype, SDTRefund )
	--Bit 4~13 for Inn1~Inn9 and EI
	SELECT  8801, 8184 UNION ALL
	SELECT  8802, 8184 UNION ALL
	SELECT  8803, 8184 UNION ALL
	SELECT  8814, 8184 UNION ALL
	SELECT  8825, 8184 UNION ALL
	SELECT  8826, 8184 UNION ALL

	-- Bit 4~11 for Inn1 ~ Inn8
	SELECT  8810, 2040 UNION ALL
	SELECT  8811, 2040 UNION ALL
	SELECT  8812, 2040 UNION ALL
	SELECT  8813, 2040 UNION ALL

	-- Bit 6 and 8 for Inn3 and Inn5
	SELECT  8804, 160 UNION ALL
	SELECT  8819, 160 UNION ALL

	-- bit 6, 8, 10  for Inns 3, 5, 7
	SELECT  8806, 672 UNION ALL

	-- bit4~10 for Inns 1~7
	SELECT  8807, 1016 UNION ALL

	--Bit4~8 for Inns 1~5
	SELECT  8808, 248 UNION ALL
	SELECT  8809, 248 

	UPDATE sp
	SET SDTRefund  = ISNULL(sp.SDTRefund,0) | s.SDTRefund
	FROM SettlementSpecialBettypeProfile sp  WITH (ROWLOCK,UPDLOCK)
	INNER JOIn #tmp_newSetting s ON sp.bettype = s.bettype
	WHERE sp.sporttype = 8
   

	UPDATE sp
	SET sp.SDTResourceId = sp.ResourceId 
	FROM SettlementSpecialBettypeProfile sp  WITH (ROWLOCK,UPDLOCK)
	INNER JOIn #tmp_newSetting s ON sp.bettype = s.bettype
	WHERE SportType = 8  

	UPDATE sp
	SET sp.SDTpfId = sp.pfid 
	FROM SettlementSpecialBettypeProfile sp  WITH (ROWLOCK,UPDLOCK)
	INNER JOIn #tmp_newSetting s ON sp.bettype = s.bettype
	WHERE sp.SportType = 8  
		AND sp.SDTPfid IS NULL

	 

GO

