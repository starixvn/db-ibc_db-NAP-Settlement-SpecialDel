/*<info serverAlias="DBCTG-bodb02, DBSIC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_NetPosition]
    @MatchId INT
    ,@Bettype SMALLINT
	,@Action VARCHAR(20)
AS
/*	Creator: 20230616@Kathy
	Task: Net postion

	Revisions:
		- 20230616@Kathy: Migrate NetPosition API & Services to NAP Settlement System [Redmine:#187311]
*/
BEGIN

    SET NOCOUNT ON;
	
	DECLARE @CustId	INT
			,@IsCentral BIT

	DECLARE @tmpCustIds TABLE (CustId INT)
	DECLARE @tmpTransIds TABLE (TransId BIGINT PRIMARY KEY, CustId INT)

	SET @IsCentral = 0

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	INSERT INTO @tmpTransIds(TransId, CustId)
	SELECT	b.TransId, b.CustId
	FROM	dbo.bettrans b WITH(NOLOCK)
	WHERE	b.matchid = @MatchId
			AND b.bettype = @Bettype
			AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END

	IF @Action IN ('CAL', 'REFUND')
	BEGIN
		UPDATE	np 
			SET	SyncStatus=1
				,IsSettled=1
				,ModifiedDate=CURRENT_TIMESTAMP 
		OUTPUT DELETED.CustID INTO @tmpCustIds(CustId)
		FROM	dbo.NetPositionTrans np WITH (ROWLOCK, UPDLOCK)
			INNER JOIN @tmpTransIds t
				ON np.TransID = t.TransId

		UPDATE bnp
			SET Debit=0
				,Credit=0
				,ModifiedDate=CURRENT_TIMESTAMP 
		FROM	dbo.BalNetPosition bnp WITH (ROWLOCK, UPDLOCK) 
		WHERE	Matchid=@Matchid 
				AND Bettype=@bettype
				AND EXISTS (SELECT TOP 1 1 FROM @tmpCustIds c WHERE c.CustId = bnp.CustID)
	END
	ELSE IF @Action = 'UNDO'
	BEGIN
		UPDATE	np
			SET	IsSettled=0
				,ModifiedDate=CURRENT_TIMESTAMP
		OUTPUT DELETED.CustID INTO @tmpCustIds(CustId)
		FROM	dbo.NetPositionTrans np WITH (ROWLOCK, UPDLOCK) 
			INNER JOIN @tmpTransIds t
				ON np.TransID = t.TransId
		
		IF @@ROWCOUNT > 0
		BEGIN
			WHILE(1=1)
			BEGIN
				SELECT TOP (1)	@CustId = CustId
				FROM	@tmpCustIds
		
				IF @@ROWCOUNT = 0
					BREAK

				EXEC dbo.NAP_Admin_Calculation_NetPosition
					@MatchId	= @MatchId
					,@CustId	= @CustId
					,@Bettype	= @Bettype
					,@Action	= @Action

				DELETE @tmpCustIds
				WHERE	CustId = @CustId
			END
		END
	END
END

