/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE NAP_Set_AutoRefundResultOS_Ins
  @MatchId		 INT
AS
/*
	Creator: 20230808@Aries
	Task: Enhance Auto Refund for Tennis Matches [Redmine:#189433]
	DB: DBPRO/bodb02

	Revisions:
		- 20230808@Aries: Created [Redmine: #189433]

	Param's explaination:

*/
BEGIN
	SET NOCOUNT ON

	DECLARE  @ChildMatch TABLE (MatchId INT)

	IF NOT EXISTS(SELECT 1 FROM ResultDetail WITH(NOLOCK) WHERE matchID = @MatchId AND ResourceID = '00' AND ResultStatusID IN (2,5)) OR
	   EXISTS(SELECT 1 FROM dbo.match WITH(NOLOCK) WHERE matchID = @MatchId AND ISNULL(ParentID,0) != 0)
	BEGIN
		RETURN
	END

	INSERT INTO @ChildMatch(MatchId)
	SELECT m.MatchId
	FROM dbo.match AS m WITH(NOLOCK)
		INNER JOIN dbo.Match_Remark AS mr WITH(NOLOCK) on mr.matchid = m.matchid
		CROSS APPLY (
			SELECT  TOP 1 
					rd.HomeValue + ':' + rd.AwayValue  AS result
				   ,CAST(rd.ResourceID  AS INT) * 100 AS RoundNo
				   ,CASE WHEN rd.ResultStatusID IN (2,5) AND rd.SettlementStatusID = 4 THEN 1 
						 WHEN rd.ResultStatusID IN (2,5) AND rd.SettlementStatusID IN (1,7) THEN 2 
						 ELSE 0
					END AS Cal 
			FROM ResultDetail AS rd WITH(NOLOCK) 
			WHERE rd.MatchId = @MatchId
				AND rd.ResourceID IN ('01','02','03','04','05')
				AND 1 = CASE WHEN rd.ResourceID = '01' AND  m.ChildMatchType = 12 THEN 1
							 WHEN rd.ResourceID = '02' AND  m.ChildMatchType = 14 THEN 1
							 WHEN rd.ResourceID = '03' AND  m.ChildMatchType = 15 THEN 1
							 WHEN rd.ResourceID = '04' AND  m.ChildMatchType = 16 THEN 1
							 WHEN rd.ResourceID = '05' AND  m.ChildMatchType = 17 THEN 1
							 ELSE 0
						END 
		) AS rs
		OUTER APPLY (
			SELECT TOP 1 1 AS IsExistAR
			FROM dbo.AutoRefundResultOS AS arr WITH(NOLOCK) 
			WHERE arr.MatchId = m.matchid 
		) AS ar
	WHERE m.ParentID = @MatchId 
		AND  m.eventstatus = 'running'
		AND  m.ChildMatchType in (12,14,15,16,17)
		AND ISNULL(m.SettlementStatus,0) & 87 = 0
		AND  ar.IsExistAR IS NULL
		AND  1 = CASE WHEN Cal = 1 AND rs.result IN ('6:0','0:6') AND (mr.SubType BETWEEN rs.RoundNo + 7  AND rs.RoundNo + 12 OR mr.SubType = 1000 + rs.RoundNo)  THEN 1
					  WHEN Cal = 1 AND rs.result IN ('6:1','1:6') AND (mr.SubType BETWEEN rs.RoundNo + 8  AND rs.RoundNo + 12 OR mr.SubType = 1000 + rs.RoundNo)  THEN 1
					  WHEN Cal = 1 AND rs.result IN ('6:2','2:6') AND (mr.SubType BETWEEN rs.RoundNo + 9  AND rs.RoundNo + 12 OR mr.SubType = 1000 + rs.RoundNo)  THEN 1
					  WHEN Cal = 1 AND rs.result IN ('6:3','3:6') AND (mr.SubType BETWEEN rs.RoundNo + 10 AND rs.RoundNo + 12 OR mr.SubType = 1000 + rs.RoundNo)  THEN 1
					  WHEN Cal = 1 AND rs.result IN ('6:4','4:6') AND (mr.SubType BETWEEN rs.RoundNo + 11 AND rs.RoundNo + 12 OR mr.SubType = 1000 + rs.RoundNo)  THEN 1
					  WHEN Cal = 1 AND rs.result IN ('7:5','5:7') AND  mr.SubType = 1000 +  rs.RoundNo  THEN 1
					  WHEN Cal = 2 AND (mr.SubType BETWEEN rs.RoundNo + 1  AND rs.RoundNo + 12 OR mr.SubType = 1000 + rs.RoundNo) THEN 1
					  ELSE 0
				  END

	INSERT INTO AutoRefundResultOS(MatchId, SourceId, TypeId, ResourceID)
	SELECT MatchId, 100, 1, '00'
	FROM @ChildMatch

END

