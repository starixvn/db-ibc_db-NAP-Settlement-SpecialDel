/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Admin_VS_Betradar_HorseDog_Result_Upd
	 @EventID		INT
	,@EventStatus	NVARCHAR(100)
	,@BetStatus		VARCHAR(10) = NULL
	
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

	UPDATE VSRaceInfo
	SET  BetStatus = @BetStatus
		,EventStatus = @EventStatus
		,Calculate = 1
		,ChangeTime = GETDATE()
	WHERE EventID = @EventID

	UPDATE VSOutright
	SET  EventStatus = @EventStatus
		,ChangeTime = GETDATE()
	WHERE EventID = @EventID
END
GO