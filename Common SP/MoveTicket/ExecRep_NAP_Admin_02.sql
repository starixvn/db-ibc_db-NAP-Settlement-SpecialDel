/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.ExecRep_NAP_Admin_02
	@MatchId INT
	,@Mode VARCHAR(15)
	,@strTransIds VARCHAR(MAX)
AS
/*	Creator: Kathy
	Date: 20210218
	Task: Move ticket of cricket
	DB: DBTXN/BODB02

	Revisions:
		- 20210218@Kathy: Move Tickets of Settled Results Functions [Redmine:#148870]

	Param's Explanation:
		@matchid: child matchid
		@Mode: single
				subparlay
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @xml XML

	DECLARE @tmpTrans TABLE (TransID BIGINT PRIMARY KEY)
	
	SET @xml = CAST(@strTransIds AS XML)

	INSERT INTO @tmpTrans (TransID)
	SELECT T.C.value('./@t', 'bigint') AS transid
	FROM @xml.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@xml = NULL ))

	IF @Mode = 'Single'
	BEGIN
		-- bettrans
		UPDATE b WITH(ROWLOCK, UPDLOCK)
			SET matchid = @MatchId
		FROM	@tmpTrans t
			INNER JOIN dbo.bettrans b
				ON t.TransID = b.transid
	END
	ELSE IF @Mode = 'subParlay'
	BEGIN
		-- bettransM
		UPDATE bm WITH(UPDLOCK, ROWLOCK)
			SET matchid = @MatchId
		FROM	@tmpTrans t
			INNER JOIN dbo.bettransm bm 
				ON bm.transid = t.transid

		-- BetParlayDetail
		UPDATE d  WITH(ROWLOCK, UPDLOCK)
			SET matchid = @MatchId
		FROM	@tmpTrans t
			INNER JOIN dbo.BetParlayDetail d
				ON d.transid = t.TransId
		WHERE	matchid = @MatchId
	END
END