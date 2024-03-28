/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_League_Select]
	@EventDate	DATETIME
	,@Sporttype	SMALLINT	
AS
/*	Created by: Kathy
	Date 20181212
	Task: get league info [Redmine:#90155]
	DB: DBPRO/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
	
	Param's explanation:		
*/
BEGIN
	SET NOCOUNT ON

	SELECT	m.leagueid
	FROM	dbo.match m WITH(NOLOCK)
	WHERE	m.sporttype = @Sporttype
			AND m.eventdate = @EventDate
	GROUP BY m.leagueid
END


