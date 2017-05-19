 ALTER PROCEDURE [dbo].[Nap_Set_MatchMetricGamingStatusSel]	
 AS
	/*
		Created: Johnson
		Date: 2015-06-29
		Task: Get match status of Metric Gaming
		DB: DBPRO/bodb02
	*/
BEGIN
	SET NOCOUNT ON
	DECLARE @isExistRunningMG BIT
	IF EXISTS(
		SELECT TOP 1 1
		FROM match m WITH(NOLOCK)
			INNER JOIN ResultDetail3rd rs WITH(NOLOCK) ON m.matchid = rs.matchid
			INNER JOIN VendorStatus vs WITH(NOLOCK) ON m.matchid = vs.matchid 
		WHERE m.eventstatus = 'completed'
			AND sporttype = 1
			AND rs.SettlementStatusID = 0--MG is running
			AND vs.opened = 1--match offer MG			
			AND vs.VendorID = 5
	)
	BEGIN
		SELECT @isExistRunningMG = 1
	END		
	ELSE SELECT @isExistRunningMG = 0
	
	SELECT @isExistRunningMG as isExistRunningMG
		
END
GO
GRANT EXECUTE ON [dbo].[Nap_Set_MatchMetricGamingStatusSel] TO [bodbAdminNet]