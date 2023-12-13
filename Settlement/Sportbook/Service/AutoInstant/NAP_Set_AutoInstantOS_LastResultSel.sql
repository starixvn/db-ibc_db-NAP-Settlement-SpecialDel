/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_AutoInstantOS_LastResultSel
	 @matchID			INT
	,@HTHome			INT	OUTPUT
	,@HTAway			INT	OUTPUT
	,@FTHome			INT	OUTPUT
	,@FTAway			INT	OUTPUT
AS
/*
	Creator: 20230801@Aries
	Task: Enhance Recalculation and Instant Settle for Basketball
	DB: DBPRO/bodb02
	Revisions:	
		- 20231213@Aries: Created [Redmine:#198283]

*/

BEGIN
    SET NOCOUNT ON

	SELECT @HTHome = SUM(IIF(rs.ResourceID IN ('Q1' ,'Q2'),tbl.HomeValue,0)) 
		  ,@HTAway = SUM(IIF(rs.ResourceID IN ('Q1' ,'Q2'),tbl.AwayValue,0)) 
		  ,@FTHome = SUM(tbl.HomeValue) 
		  ,@FTAway = SUM(tbl.AwayValue) 
	FROM (VALUES('Q1' ),('Q2'),('Q3'),('Q4'))AS rs(ResourceID)
		CROSS APPLY(SELECT TOP 1
						   (CAST(a.HomeValue  AS INT)) AS HomeValue
						  ,(CAST(a.AwayValue  AS INT)) AS AwayValue
					FROM dbo.AutoPayoutResultOS AS a WITH(NOLOCK)
					WHERE a.MatchID = @matchID 
						AND a.SourceID = 98
						AND a.ResourceID = rs.ResourceID
						AND a.StatusId = 2 
					ORDER BY a.AutoPayoutResultId DESC
		) AS tbl
	WHERE NOT EXISTS (SELECT TOP 1 1 
	                  FROM dbo.ResultDetail AS r WITH(NOLOCK) 
					  WHERE r.ResourceID = rs.ResourceID 
						AND ResultStatusID IN (2, 5)
						AND r.MatchID = @matchID)
END
GO