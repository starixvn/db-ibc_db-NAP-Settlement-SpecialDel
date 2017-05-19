CREATE PROCEDURE [NAP_Get_LiveCasinoGameDetail]
	@matchid int
AS

/*
	Created by: 20140121@Kathy
	Task: get gamehand to settle
	DB: DB02.BODB02 
	Orifgial SP: Acc_Get_LiveCasinoGameResult

	Revisions:
	
		
*/
BEGIN

	SET NOCOUNT ON 

	SELECT 
		matchid
		,matchcode
		,eventdate
		,kickofftime
		,showtime AS GameEvent
		,finalhomescore
		,finalawayscore
		,betstatus
		,eventstatus
		,leagueid
		,CASE WHEN eventstatus = 'completed' THEN 1 ELSE 0 END IsSettled
		, 'Full Time' AS FTStatus
	FROM match WITH(NOLOCK)
	WHERE sporttype = 162 
		AND matchid = @matchid
END



GO

GRANT EXECUTE ON [NAP_Get_LiveCasinoGameDetail] TO [bodbAdminNet] AS [dbo]
GO

GRANT VIEW DEFINITION ON [NAP_Get_LiveCasinoGameDetail] TO [vnteam] AS [dbo]
GO


