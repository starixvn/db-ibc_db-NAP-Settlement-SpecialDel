/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_AutoInstantOS_ResultSel
	 @matchID		INT
	,@ResourceIds   VARCHAR(MAX)  = ''
	,@SourceID		TINYINT = 98
AS
/*
	Creator: 20230801@Aries
	Task: Support Instant Settlement for Basketball
	DB: DBPRO/bodb02
	Revisions:	
		- 20230801@Aries: Created [Redmine:#189662]

*/

BEGIN
    SET NOCOUNT ON

	SELECT tbl.HomeValue
		  ,tbl.AwayValue
		  ,tbl.ResourceID
	FROM STRING_SPLIT(@ResourceIds,',') AS fs
		CROSS APPLY(SELECT TOP 1
						   a.HomeValue
						  ,a.AwayValue
						  ,a.ResourceID
					FROM dbo.AutoPayoutResultOS AS a WITH(NOLOCK)
					WHERE a.MatchID = @matchID 
						AND a.SourceID = @SourceID
						AND a.ResourceID = fs.value
						AND a.StatusId = 2 -- Success
						ORDER BY a.AutoPayoutResultId DESC
    ) AS tbl
END
GO