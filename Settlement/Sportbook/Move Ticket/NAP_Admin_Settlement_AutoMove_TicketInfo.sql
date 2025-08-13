/*<info serverAlias="DBCTG-bodb02,DBSIG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE NAP_Admin_Settlement_AutoMove_TicketInfo
(
	@ResourceInfo	NVARCHAR(MAX) = ''
)
/*	
	Created: 20250721@Louisa
	Task: Auto move ticket of Cricket [Redmine:#227191]
	DB: DBPRO/bodb02
	
	Revisions:
		- 20250721@Louisa: Created [Redmine:#227191] 


	@ResourceInfo =  [{"m":83796855,"r":"94101005","s":50},{"m":83796855,"r":"94101010","s":50}, {"m":83775762,"r":"A1","s":50}, {"m":83765457,"r":"01","s":8}]
*/
AS
BEGIN
	SET NOCOUNT ON
	
	DECLARE @tmpMatchid TABLE (Matchid INT, IsExistsTicket BIT DEFAULT(0) )
	DECLARE @tmpBettype TABLE (Matchid INT, Bettype SMALLINT, BetId BIGINT  )
	DECLARE @IsCentral	BIT = 0

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	IF ISNULL(@ResourceInfo,'') =  ''
	BEGIN
		INSERT INTO @tmpBettype(MatchID, Bettype, BetId )
		SELECT	js.m, s.BetType, s.BetID 
		FROM OPENJSON(@ResourceInfo)  WITH (m  INT, r  VARCHAR(20), s SMALLINT ) js 
			CROSS APPLY (
				SELECT	s.BetType, s.BetID
				FROM	dbo.SettlementSpecialBettypeProfile s WITH(NOLOCK)
				WHERE	s.Sporttype = js.s
						AND (s.ResourceID = js.r OR s.RefResourceId = js.r)
			)s

		INSERT INTO @tmpMatchid (Matchid)
		SELECT DISTINCT matchid FROM @tmpBettype

		UPDATE m
			SET IsExistsTicket = 1
		FROM @tmpMatchid m
			CROSS APPLY (
				SELECT TOP 1 b.matchid
				FROM @tmpBettype t
					INNER JOIN dbo.bettrans b WITH(NOLOCK) 
						ON t.Matchid = b.matchid
							AND t.Bettype = b.bettype
							AND (t.BetId = 0 OR t.BetId = b.betid)
							AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
				WHERE m.Matchid = b.matchid
				)b
		
		IF EXISTS (SELECT TOP 1 1 FROM @tmpMatchid WHERE IsExistsTicket = 0)
		BEGIN
			UPDATE m
				SET IsExistsTicket = 1
			FROM @tmpMatchid m
				CROSS APPLY (
					SELECT TOP 1 b.matchid
					FROM @tmpBettype t
						INNER JOIN dbo.bettransm b WITH(NOLOCK) 
							ON t.Matchid = b.matchid
								AND t.Bettype = b.bettype
								AND (t.BetId = 0 OR t.BetId = b.betcheck)
								AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
					WHERE m.Matchid = b.matchid
					)b
			WHERE m.IsExistsTicket = 0
		END
	END

	SELECT MatchID, IsExistsTicket
	FROM @tmpMatchid

END
GO