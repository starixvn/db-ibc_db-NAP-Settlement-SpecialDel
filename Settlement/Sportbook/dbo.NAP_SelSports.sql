/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [NAP_SelSports] @isGetAll BIT = 0
AS
/*
	Created by: 20131223@Kathy
	Task: Get the list of sports for Settlement function
	DB:DB02.BODB02
	Original: Acc_SelSports
	
	Revisions:
		- 20190903@Sol: Multi Sports on One Page - Changed column list return - [Redmind: #118379]
		- 20191213@Sol: Hide inactive sport types in dropdown box "Sports" - [Redmind: #125412]

	Param's Explanation:
		@isGetAll: 1 - get all sports for view result, 0- get only sportbook
		
*/
BEGIN
	SET NOCOUNT ON

	SELECT SportType, SportName
	FROM Sports WITH (NOLOCK)
	WHERE (SportType <= 99 AND SportType NOT IN (27, 46)) OR (@isGetAll = 1 AND SportType IN (151, 152, 153))
END


GO


