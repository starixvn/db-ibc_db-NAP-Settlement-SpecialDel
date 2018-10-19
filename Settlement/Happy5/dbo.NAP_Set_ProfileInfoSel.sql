/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet,Dot_Casino" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE dbo.[NAP_Set_ProfileInfoSel]
	@Sporttype				TINYINT
	,@MatchID				INT
	,@Action				VARCHAR(20)		=  'CAL'
	
AS
/*
	Created by: Vicky.phan
	Date: 20181015
	Task: Happy 5 - Settlement 
	DB: DBTXN/BODB02
	 
	Revisions:
		- 20181015@Vicky: Happy 5 - Settlement  [Redmine:#102844]
		
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @xmlResourceResult XML
	DECLARE @tmpResultDetail TABLE (ResourceID VARCHAR(20), Result1 VARCHAR(50), Result2 VARCHAR(50))
	-------------------------------------------------------------------------------------
	
	IF @Action LIKE 'CAL%'
	BEGIN
		
		INSERT INTO @tmpResultDetail(ResourceID, Result1)
		SELECT  Seq, Number
		FROM    dbo.BingoBall b WITH (NOLOCK)
		WHERE matchid = @matchid
	END
	
	
	IF @Sporttype = 164
	BEGIN
		IF @Action LIKE 'CAL%' AND EXISTS (SELECT TOP 1 1 FROM @tmpResultDetail)
		BEGIN
			INSERT INTO @tmpResultDetail(ResourceID, Result1, Result2)
			SELECT '00', SUM(CAST(Result1 AS INT)), '0'
			FROM @tmpResultDetail
			UNION ALL
			SELECT '8104' AS ResourceID
					,SUM(CASE WHEN CAST(Result1 AS INT) % 2 = 1 THEN 1 ELSE 0 END) AS Result1
					,SUM(CASE WHEN CAST(Result1 AS INT) % 2 = 0 THEN 1 ELSE 0 END) AS Result2
			FROM @tmpResultDetail
		END
		
		IF @Action LIKE 'REFUND%'
		BEGIN
			INSERT INTO @tmpResultDetail(ResourceID, Result1, Result2)
			SELECT '00', NULL, NULL
			UNION ALL
			SELECT '8104', NULL, NULL
		END
	END 
	 
	SELECT p.pfID, r.ResourceID, p.Bettype, r.Result1, r.Result2, p.OddsType
	FROM @tmpResultDetail r
		INNER JOIN SettlementSpecialBettypeProfile p ON r.ResourceID = p.ResourceID 
	AND p.sporttype = @sporttype
END
GO