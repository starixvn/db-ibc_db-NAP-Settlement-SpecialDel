/*<info serverAlias="DBTP-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_EventStatusChange_Sel]
(
	@FromDate DATETIME
	,@ToDate DATETIME
	,@IsTest BIT = 0
)
AS
/*	
	Created: 20250908@Max
    Task: Settlement - Integration - Support providing an API when results are changed for the Licensee - [Redmine: #236783]
    DB: DBTP-bodb02
    Revisions:
		- 20250908@Max: Create SP - [Redmine: #236783]
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #ResultData (
        MatchId INT,
		PreviousStatus NVARCHAR(100),
        FinalStatusInRange NVARCHAR(100),     
        NextStatus NVARCHAR(100)
    )

    --Get EventStatus lastest in range time
   ;WITH LastestStatusInTime AS (
        SELECT 
            mt.matchid,
            CASE WHEN mt.betstatus LIKE 'Refund%' THEN 'Refund' ELSE mt.eventstatus END AS FinalStatusInRange,
            mt.UpdateTime AS LastUpdateTimeInRange,
			MatchStatus,
            ROW_NUMBER() OVER(PARTITION BY mt.matchid ORDER BY mt.UpdateTime DESC, CASE WHEN mt.betstatus LIKE 'Refund%' THEN 'Refund' ELSE mt.eventstatus END DESC) as rn
        FROM [dbo].[Match_Tracking] mt WITH (NOLOCK)
			 CROSS APPLY (
				SELECT TOP 1 l.leagueid AS leagueid, eventstatus AS MatchStatus 
				FROM bodb02.dbo.match m WITH (NOLOCK)	
				INNER JOIN bodb02.dbo.League l WITH (NOLOCK) ON l.leagueid = m.leagueid
				WHERE m.matchid = mt.MatchID
				  AND m.sporttype <= 99
				  AND l.isTest = @IsTest
			) m
        WHERE mt.UpdateTime BETWEEN @FromDate AND @ToDate
    ),   
    --Get prev & next status
    AllEventStatus AS (
        SELECT 
            mt.matchid,
            CASE WHEN mt.betstatus LIKE 'Refund%' THEN 'Refund' ELSE mt.eventstatus END AS eventstatus,
            mt.UpdateTime,
            es1.FinalStatusInRange,
            es1.LastUpdateTimeInRange,
            CASE WHEN mt.UpdateTime <= es1.LastUpdateTimeInRange THEN
                ROW_NUMBER() OVER(PARTITION BY mt.matchid ORDER BY mt.UpdateTime DESC, CASE WHEN mt.betstatus LIKE 'Refund%' THEN 'Refund' ELSE mt.eventstatus END DESC)
            END AS rn_before,
            CASE WHEN mt.UpdateTime > es1.LastUpdateTimeInRange THEN
                ROW_NUMBER() OVER(PARTITION BY mt.matchid ORDER BY mt.UpdateTime ASC, CASE WHEN mt.betstatus LIKE 'Refund%' THEN 'Refund' ELSE mt.eventstatus END ASC)
            END AS rn_after
        FROM [dbo].[Match_Tracking] mt WITH (NOLOCK)
			INNER JOIN LastestStatusInTime es1 ON mt.matchid = es1.matchid AND es1.rn = 1
        WHERE CASE WHEN mt.betstatus LIKE 'Refund%' THEN 'Refund' ELSE mt.eventstatus END != es1.FinalStatusInRange
    ),   
    EventStatusPivot AS (
        SELECT 
            es1.matchid,
			es1.MatchStatus,
            es1.FinalStatusInRange,
            MAX(CASE WHEN aes.rn_before = 1 THEN aes.eventstatus END) AS PreviousStatus,
            MAX(CASE WHEN aes.rn_after = 1 THEN aes.eventstatus END) AS NextStatus
        FROM LastestStatusInTime es1
			LEFT JOIN AllEventStatus aes ON es1.matchid = aes.matchid
        WHERE es1.rn = 1
        GROUP BY es1.matchid, es1.FinalStatusInRange, es1.MatchStatus
    )
    --Insert #ResultData
    INSERT INTO #ResultData (MatchId, PreviousStatus, FinalStatusInRange, NextStatus)
    SELECT 
        esp.matchid,
		ISNULL(esp.PreviousStatus, ''),
        esp.FinalStatusInRange,       
        CASE 
            WHEN esp.NextStatus IS NOT NULL THEN esp.NextStatus
            ELSE esp.MatchStatus
        END
    FROM EventStatusPivot esp

    --Return data
    SELECT MatchId
    FROM #ResultData
    WHERE (NextStatus = 'running' AND FinalStatusInRange IN ('completed','Refund'))
       OR (NextStatus IN ('completed','Refund') AND FinalStatusInRange = 'running' AND PreviousStatus IN ('completed','Refund'))
       OR (NextStatus = 'completed' AND FinalStatusInRange = 'Refund')
       OR (NextStatus = 'Refund' AND FinalStatusInRange = 'completed')

    DROP TABLE #ResultData
END
GO
	