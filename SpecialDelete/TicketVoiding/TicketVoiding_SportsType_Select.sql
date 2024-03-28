/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_SportsType_Select]	
AS
/*	Created by: Alan
	Date 20181212
	Task: get league info [Redmine:#90155]
	DB: DBPRO/bodb02
	
	Revisions: 
		- 20181219@Alan: Create new SP [Redmine:#90155]
	
	Param's explanation:		
*/
BEGIN
	SET NOCOUNT ON

	SELECT s.SportType
			,s.SportName
	FROM	dbo.Sports s WITH(NOLOCK)
	WHERE	(s.SportType BETWEEN 1 AND 99 
			OR s.SportType = 154)
			AND s.SportType <> 27 -- old cricket

END
GO