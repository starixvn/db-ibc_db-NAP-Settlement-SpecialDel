/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Admin_VS_Betradar_HorseDog_Result_Sel
	 @EventID		INT
AS
/*
	Created by: 20240918@Aries
	Task: Betradar VS - Integrate 2 new sports Virtual Horse Racing & Virtual Dog Racing [Redmine:#210875]
	DB: DBPRO/bodb02

	Revisions:
		- 20240918@Aries: Created  [Redmine:#210875]

	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @SportType TINYINT
	
	SELECT @SportType = SportType FROM VSRaceInfo WITH(NOLOCK) WHERE EventID = @EventID

	SELECT EventID
		  ,EventStatus
		  ,EventTime
		  ,SportType
		  ,LeagueID
		  ,Racers
		  ,VendorMatchId
		  ,Distance
	FROM VSRaceInfo WITH(NOLOCK)
	WHERE EventID = @EventID

	SELECT Orid
		  ,Placing
		  ,RacerID
	FROM VSOutright WITH(NOLOCK)
	WHERE EventID = @EventID
	ORDER BY Placing ASC

	SELECT pfID AS ProfileId
		  ,ResourceID  
		  ,OddsType  
	FROM SettlementSpecialBettypeProfile WITH(NOLOCK) 
	WHERE SportType = @SportType
END
GO