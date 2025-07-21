/*<info serverAlias="DBCTG-bodb02,DBSIG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE NAP_Admin_Settlement_AutoMove_TicketInfo
(
	@ListMatchIds VARCHAR(500)
)
/*	
	Created: 20250721@Louisa
	Task: Auto move ticket of Cricket [Redmine:#227191]
	DB: DBPRO/bodb02
	
	Revisions:
		- 20250721@Louisa: Created [Redmine:#227191] 
*/
AS
BEGIN
	SET NOCOUNT ON
	
	DECLARE @tmpMatchId TABLE (Matchid INT, IsExistsSettledTicket BIT )
	
	INSERT INTO @tmpMatchId (Matchid, IsExistsSettledTicket)
	SELECT v.value, 0 FROM string_split(@ListMatchIds, ',' ) v

	UPDATE m
	SET m.IsExistsSettledTicket = 1
	FROM @tmpMatchId m
		INNER JOIN bettrans b WITH(NOLOCK)
			ON m.Matchid = b.matchid

	UPDATE m
	SET m.IsExistsSettledTicket = 1
	FROM @tmpMatchId m
		INNER JOIN bettransm b WITH(NOLOCK)
			ON m.Matchid = b.matchid
	WHERE m.IsExistsSettledTicket = 0

	SELECT Matchid, IsExistsSettledTicket
	FROM @tmpMatchId

END
GO