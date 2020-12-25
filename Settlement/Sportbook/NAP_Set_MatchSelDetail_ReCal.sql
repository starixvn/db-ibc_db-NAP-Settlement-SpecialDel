/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Set_MatchSelDetail_ReCal]
(
	@matchid	INT
)
AS
/*
    Created by: 20201211@Max
    Task: Support to Re-calculate Settled Tickets
    DB: DBTXN/BODB02 
    
    Revisions:            
		- 20201211@Max: Support to Re-calculate Settled Tickets [Redmine: #145669]
		
*/
BEGIN
    SET NOCOUNT ON

    SELECT match.sporttype
        ,match.betstatus
        ,hthomescore AS HalfTimeHomeScore
        ,htawayscore AS HalfTimeAwayScore
        ,match.finalhomescore
        ,match.finalawayscore
		,match.GoalRecord
		,CASE WHEN mr.IsHTCal = 1 THEN 'Calculated' ELSE NULL END AS HTStatus
        ,CASE WHEN mr.calculate = 1 OR (mr.calculate = 0 AND mr.calrefund  = 1) THEN 'Calculated' ELSE NULL END AS FTStatus
     FROM DBPRO.bodb02.dbo.match WITH (NOLOCK)
        LEFT OUTER JOIN DBPRO.bodb02.dbo.match_remark mr WITH (NOLOCK) ON match.matchid = mr.matchid
    WHERE match.matchid = @matchid
	
END
GO