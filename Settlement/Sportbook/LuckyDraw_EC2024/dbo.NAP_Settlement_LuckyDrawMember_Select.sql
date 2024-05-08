/*<info serverAlias="DBSIC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Settlement_LuckyDrawMember_Select]
	  @MatchID		INT
	 ,@MinBet		DECIMAL(12,4)
	 ,@IsTest		BIT	= 0
AS
/*
	Created by: 20240401@Aries
	Task: Settlement  
	DB: DBSIC-bodb02
	
	Revisions:
		- 20240401@Aries: EC 2024-Correct Score Sharing and Lucky Draw-(Pool prize) [Redmine:#202309]

	Param's Explanation:  	   
*/
BEGIN	
	SET NOCOUNT ON

	SELECT	 b.transId
			,b.custId
			,b.statusID
	FROM bettrans AS b WITH(NOLOCK)
		INNER JOIN CustDB.dbo.Customer AS c  WITH(NOLOCK) ON b.custId = c.custId
		INNER JOIN CustDB.dbo.Site s WITH(NOLOCK) ON c.Site = s.Site
	WHERE b.matchid = @MatchID
		AND b.bettype = 413
		AND b.status = 'WON'
		AND ISNULL(s.SiteLabel,'') NOT IN ('789y') 
		AND s.site NOT IN ('Special','Hedging')
		AND s.isDeposit = 0
		AND 1 = CASE WHEN @IsTest = 1 AND b.currency = 20 AND 1*stake >= @Minbet THEN 1 
		             WHEN actualrate*stake >= @Minbet THEN 1 
					 ELSE 0
				END	
		AND 1 = CASE WHEN @IsTest = 1 THEN 1
					 WHEN @IsTest = 0 AND b.currency NOT IN (20,27,28,72,213) THEN 1				 
					 ELSE 0
				END
		AND b.liveindicator = 0
		AND b.betfrom != 'p'
END