 /*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
 ALTER PROCEDURE [dbo].[Nap_Set_LeagueSel_by_Vendor]
	@FromDate		DATETIME
	,@ToDate		DATETIME
	,@vendorId		INT			= 34
 AS
	/*
		Created by: 20190103@Vicky
		Task: Incorporate BetBuilder 
		DB: DBPRO.BODB02
		
		Revisions:
		- 20190103@Vicky: Incorporate BetBuilder  [Redmine:#106903]
	*/
BEGIN
	SET NOCOUNT ON
	
	SELECT DISTINCT l.leagueid, l.leaguename
	FROM match m WITH (NOLOCK)
		INNER JOIN VendorStatus vs WITH (NOLOCK) ON m.matchid = vs.matchid
		INNER JOIN league l WITH (NOLOCK) ON m.leagueid = l.leagueid
	WHERE m.eventdate BETWEEN @fromdate AND @todate
		AND vs.opened = 1		
		AND vs.VendorID = @vendorId
	ORDER BY leaguename
END
GO
