/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.[NAP_Set_Resource_Parsing]
	@Sporttype				TINYINT
	,@MatchID				INT
	,@Action				VARCHAR(20)		=  'CAL'
	,@ErrCode				INT				= 0		OUTPUT
	,@ErrMsg				VARCHAR(200)	= ''	OUTPUT
	
AS
/*
	Created by: 20220719@Louisa
	Task: Scale Out BetTrans [Redmine:#175251]
	DB: DBPRO/bodb02

	Revisions:
		- 20220719@Louisa: Move SP from DBTrans to DBPRO [Redmine:#175251]

	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @xmlResourceResult XML
	DECLARE @tmpResultDetail TABLE (ResourceID VARCHAR(20), Result1 VARCHAR(50), Result2 VARCHAR(50), isSourceFromDB BIT)
	-------------------------------------------------------------------------------------
	
	IF @Action LIKE 'CAL%'
	BEGIN
		
		INSERT INTO @tmpResultDetail(ResourceID, Result1, isSourceFromDB)
		SELECT  Seq, Number, 1
		FROM	dbo.BingoBall b WITH (NOLOCK)
		WHERE matchid = @matchid
	END
	
	
	IF @Sporttype = 164
	BEGIN
		
	
		IF @Action LIKE 'CAL%'
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
	 
	SELECT p.pfID, r.ResourceID, p.Bettype, r.Result1, r.Result2, p.OddsType, r.isSourceFromDB
	FROM @tmpResultDetail r
		LEFT JOIN SettlementSpecialBettypeProfile p WITH(NOLOCK) ON r.ResourceID = p.ResourceID AND p.sporttype = @sporttype

END
GO