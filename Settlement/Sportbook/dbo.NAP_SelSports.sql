/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [NAP_SelSports]
AS
/*
	Created by: 20131223@Kathy
	Task: Get the list of sports for Settlement function
	DB:DB02.BODB02
	Original: Acc_SelSports
	
	Revisions:
		- 20190903@Sol: Multi Sports on One Page - Changed column list return - [Redmind: #118379]
		- 20191213@Sol: Hide inactive sport types in dropdown box "Sports" - [Redmind: #125412]
		- 20230109@Aries: Migrate Calculate Outright Function to NAP Settlement Site [Redmine:#163971]

	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	SELECT SportType
		  ,SportName
	FROM Sports WITH (NOLOCK)
	WHERE SportType <= 99 
		AND SportType NOT IN (27, 46)
END


GO


