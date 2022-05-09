 /*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Nap_Set_LeagueSel_by_Vendor]
	 @SportTypes	VARCHAR(MAX)
	,@FromDate		DATETIME
	,@ToDate		DATETIME
	,@vendorId		INT			= 34
AS

/*
		Created by: 20190103@Vicky
		Task: Incorporate BetBuilder 
		DB: DBPRO.BODB02
		
		Revisions:
		- 20190103@Vicky: Incorporate BetBuilder  [Redmine:#106903]
		- 20200730@July	:  Get league belong to sport for BetBuilder [Redmine:#138475] 
		- 20220509@Kathy: Change to use STRING_SPLIT [Redmine:#172461]
	*/
BEGIN
	SET NOCOUNT ON

	DECLARE @tmpSports TABLE (SportType SMALLINT);
	
	INSERT INTO @tmpSports (SportType)
	SELECT f.value
	FROM STRING_SPLIT(@SportTypes,',')f

	SELECT s.SportType,m.leagueid
	FROM dbo.match m WITH (NOLOCK)
		INNER JOIN @tmpSports s ON m.sporttype=s.SportType 
		INNER JOIN VendorStatus vs WITH (NOLOCK) ON m.matchid = vs.matchid
	WHERE m.eventdate BETWEEN @FromDate AND @ToDate
		  AND vs.opened = 1		
		  AND vs.VendorID = @vendorId
	GROUP BY s.SportType, m.leagueid;

END
GO
