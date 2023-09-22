/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_WaitingOtherSportSel_MatchInfo] 
	@MatchIds	VARCHAR(MAX)
AS
/*
	Created: 20230920@Aries
	Task: Remove remote query [Redmine:#194359] 
	DB: DBTXN/BODB02
	
	Revision:
		- 20230920@Aries: Remove remote query [Redmine:#194359]

	Param's explanation:  
		
*/
BEGIN
	SET NOCOUNT ON

	SELECT r.MatchId
		  ,MAX(r.StatusId) AS StatusId
	FROM STRING_SPLIT(@MatchIds, ',') AS f
		INNER JOIN dbo.AutoPayoutResultOS AS r WITH (NOLOCK)  ON f.[value] = r.MatchId AND ISNULL(r.SourceID,0) = 0
    GROUP BY r.MatchId
END
GO