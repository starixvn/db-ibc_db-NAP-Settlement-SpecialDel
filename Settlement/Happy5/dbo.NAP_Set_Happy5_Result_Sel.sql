/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.[NAP_Set_Happy5_Result_Sel]
	 @MatchID				INT
	,@Action				VARCHAR(20)		=  'CAL'
	
AS
/*
	Created by: 20240520@Aries
	Task: Transfer the logic business from the DB layer to the Application layer for Happy5 [Redmine:#202389]
	DB: DBPRO/bodb02

	Revisions:
		- 20240520@Aries: Created  [Redmine:#202389]

	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @tmpBingoBall TABLE (Seq TINYINT, Number TINYINT)
	DECLARE @tmpResult TABLE (ResourceID VARCHAR(20), Result1 VARCHAR(50), Result2 VARCHAR(50))
	
	INSERT INTO @tmpBingoBall(Seq, Number)
	SELECT  Seq, Number
	FROM	dbo.BingoBall b WITH (NOLOCK)
	WHERE matchid = @matchid

	IF @Action LIKE 'CAL%'
	BEGIN
		INSERT INTO @tmpResult(ResourceID, Result1, Result2)
		SELECT '00'
			  ,SUM(CAST(Number AS INT)), '0'
		FROM @tmpBingoBall
		UNION ALL
		SELECT '8104' AS ResourceID
			  ,SUM(CASE WHEN CAST(Number AS INT) % 2 = 1 THEN 1 ELSE 0 END) AS Result1
			  ,SUM(CASE WHEN CAST(Number AS INT) % 2 = 0 THEN 1 ELSE 0 END) AS Result2
		FROM @tmpBingoBall
	END

	IF @Action LIKE 'REFUND%'
	BEGIN
		INSERT INTO @tmpResult(ResourceID, Result1, Result2)
		SELECT '00', NULL, NULL
		UNION ALL
		SELECT '8104', NULL, NULL
	END

	SELECT p.pfID AS ProfileId, r.ResourceID,  r.Result1, r.Result2, p.OddsType
	FROM @tmpResult AS r
		INNER JOIN SettlementSpecialBettypeProfile p WITH(NOLOCK) ON r.ResourceID = p.ResourceID AND p.sporttype = 164


	SELECT Seq
		  ,Number
	FROM @tmpBingoBall
	ORDER BY Seq ASC
END
GO