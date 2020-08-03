 /*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_SportsSel_by_Vendor]
	 @FromDate		DATETIME
	,@ToDate		DATETIME
	,@vendorId		INT			= 34
AS

/*  
	 Created by: 20200730@July
	 Date: 20200730
	 Task: Get sporttype according to eventdate for BetBuilder [Redmine:#138475] 
	 DB: DBPRO/bodb02
	 
	 Revisions:  
			- 20200730@July: Get sporttype according to eventdate for BetBuilder [Redmine:#138475] 
      
	 Param explanation:  

*/
BEGIN
	SET NOCOUNT ON 

	SELECT	DISTINCT m.sporttype
	FROM	dbo.match m WITH(NOLOCK)
		INNER JOIN VendorStatus vs WITH (NOLOCK) ON m.matchid = vs.matchid
	WHERE m.eventdate BETWEEN @FromDate AND @ToDate
		AND vs.opened = 1		
		AND vs.VendorID = @vendorId
		AND m.sporttype IN (1,2)
END

GO


