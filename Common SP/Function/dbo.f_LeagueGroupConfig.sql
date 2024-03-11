/*<info serverAlias="DBTXN-bodb02,DBACC-bodb02,DBAGE-bodb02" executers="" viewers="" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_LeagueGroupConfig] ()
RETURNS TABLE
WITH SCHEMABINDING
AS
/*
	Created date: 20240311@Max
	DB: DBTXN-bodb02,DBACC-bodb02,DBAGE-bodb02
	TASK: Message Notifications for Voiding Tickets of Special Sites (ChinaView, JollySports) [Redmine: #198905]
	
	Revision
		- 20240311@Max: Inittial

	Parameters Explanation:				
		- LeagueGroupType:				
		+ 1: SABA				
		+ 2:...	
	
*/
RETURN
	(
	--SABA				
	SELECT	CONVERT(SMALLINT, 42) AS LeagueGroupID			
		,CONVERT(TINYINT, 1) AS LeagueGroupType		
	UNION ALL SELECT 74		,1	
	UNION ALL SELECT 108	,1		
	UNION ALL SELECT 113	,1		
	UNION ALL SELECT 122	,1		
	UNION ALL SELECT 151	,1		

	)
GO