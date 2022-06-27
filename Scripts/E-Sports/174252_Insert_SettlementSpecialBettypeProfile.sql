/*<info serverAlias="DBTXN-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by: 20220620@Louisa
    Task: Extend Best Of Map Esports from up to M30 [Redmine:#174252]
    DB: DBTXN/bodb02
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @tbl_newBOM TABLE (pfID SMALLINT, BetType SMALLINT, BetID BIGINT, ResourceID VARCHAR(20), RoundID VARCHAR(10) , OrdNo SMALLINT)
	
	INSERT INTO @tbl_newBOM (pfID, BetType, BetID, ResourceID, RoundID, OrdNo)
	VALUeS (20,	9001, 810, 'M10', '810' , 10)
		  ,(20,	9001, 811, 'M11', '811' , 11)
		  ,(20,	9001, 812, 'M12', '812' , 12)
		  ,(20,	9001, 813, 'M13', '813' , 13)
		  ,(20,	9001, 814, 'M14', '814' , 14)
		  ,(20,	9001, 815, 'M15', '815' , 15)
		  ,(20,	9001, 816, 'M16', '816' , 16)
		  ,(20,	9001, 817, 'M17', '817' , 17)
		  ,(20,	9001, 818, 'M18', '818' , 18)
		  ,(20,	9001, 819, 'M19', '819' , 19)
		  ,(20,	9001, 820, 'M20', '820' , 20)	 
		  ,(20,	9001, 821, 'M21', '821' , 21)
		  ,(20,	9001, 822, 'M22', '822' , 22)
		  ,(20,	9001, 823, 'M23', '823' , 23)
		  ,(20,	9001, 824, 'M24', '824' , 24)
		  ,(20,	9001, 825, 'M25', '825' , 25)
		  ,(20,	9001, 826, 'M26', '826' , 26)
		  ,(20,	9001, 827, 'M27', '827' , 27)
		  ,(20,	9001, 828, 'M28', '828' , 28)
		  ,(20,	9001, 829, 'M29', '829' , 29)
		  ,(20,	9001, 830, 'M30', '830' , 30)

 	INSERT INTO dbo.SettlementSpecialBettypeProfile (pfID, BetType, SportType, BetID, ResourceID, SettleType, GroupType, RoundID, OddsType, OrdNo)
	SELECT t.pfID, t.BetType, 43 AS SportType, t.BetID, t.ResourceID, 'MNL' AS SettleType, 'HT' AS GroupType, t.RoundID, NULL AS OddsType, t.OrdNo
	FROM @tbl_newBOM t
	OUTER APPLY ( SELECT TOP 1 bettype FROM dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK)
		WHERE t.BetType = sp.BetType AND t.BetID = sp.BetID
		AND sp.SportType = 43 ) sp
	WHERE sp.BetType IS NULL

END
GO