/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchSelDetail_ReCal]
(
	@matchid	INT
)
AS
/*
    Created by: 20201211@Max
    Task: Support to Re-calculate Settled Tickets
    DB: DBPRO/BODB02 
    
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
		,CASE WHEN mr.IsHTCal = 1 THEN 'Calculated' 
			WHEN match.sporttype = 1 AND rsHT.SettlementStatusID <> 0 AND mr.calrefund = 1 THEN 'Calculated'
			WHEN match.sporttype <> 1 AND mr.calrefund = 1 THEN 'Calculated'
			ELSE NULL END AS HTStatus
        ,CASE WHEN mr.calculate = 1 THEN 'Calculated' 
			WHEN match.sporttype = 1 AND rsFT.SettlementStatusID <> 0 AND mr.calrefund = 1 THEN 'Calculated' 
			WHEN match.sporttype <> 1 AND mr.calrefund = 1 THEN 'Calculated' 
			ELSE NULL END AS FTStatus
     FROM dbo.match WITH (NOLOCK)
        LEFT OUTER JOIN dbo.match_remark mr WITH (NOLOCK) ON match.matchid = mr.matchid
		OUTER  APPLY(
		  		SELECT ResultStatusID, 
		    		SettlementStatusID
		  		FROM dbo.ResultDetail rd WITH (NOLOCK) 
		  		WHERE  rd.matchid = @matchid
					AND rd.ResourceId = '01'
		  	) AS rsHT
		OUTER  APPLY(
		  		SELECT ResultStatusID, 
		    		SettlementStatusID
		  		FROM dbo.ResultDetail rd WITH (NOLOCK) 
		  		WHERE  rd.matchid = @matchid
					AND rd.ResourceId = '00'
		  	) AS rsFT
    WHERE match.matchid = @matchid
	
END
GO