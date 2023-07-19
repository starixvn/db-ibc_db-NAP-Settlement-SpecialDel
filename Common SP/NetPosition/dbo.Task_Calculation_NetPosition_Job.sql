/*<info serverAlias="DBSIC-bodb02,DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Task_Calculation_NetPosition_Job]
AS
/*
	Created: 220230628@Kathy
	TASk : Calculate NetPosition
	
	RevisiON:
		- 20230628@Kathy: Calculate NetPosition [RedmINe:#187311]
*/
BEGIN
	SET NOCOUNT ON

	DECLARE	@Id			INT 
			,@CustId	INT
			,@MatchId	INT
			,@Bettype	SMALLINT
			,@IsCentral BIT

	SET @IsCentral = 0
	
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT
	
	DECLARE @tmpNetPositionTrans TABLE (Id INT IDENTITY(1,1), Custid INT, Matchid INT, bettype SMALLINT)
	
	INSERT INTO @tmpNetPositionTrans(CustId, MatchId, bettype)
	SELECT TOP (100) t.CustID, t.MatchId, t.bettype 
	FROM (
		SELECT np.CustId, np.MatchId, np.bettype, MIN(np.ModifiedDate) as minModifiedDate
		FROM	dbo.NetPositionTrans np WITH(NOLOCK)
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON b.TransId = np.TransID
		WHERE	np.SyncStatus = 0
				AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
		GROUP BY np.CustId, np.MatchId, np.bettype
	)t
	ORDER BY minModifiedDate

	IF @@ROWCOUNT > 0
	BEGIN
		SET @Id = 1
		WHILE(1 = 1)
		BEGIN
			SELECT	@CustId = Custid
					,@MatchId = Matchid
					,@Bettype = bettype
			FROM	@tmpNetPositionTrans
			WHERE	Id = @Id

			IF @@ROWCOUNT = 0
				BREAK

			EXEC dbo.NAP_Admin_Calculation_NetPosition
				@MatchId = @MatchId
				,@CustId = @CustId
				,@bettype = @bettype

			SET @Id = @Id + 1
		END
	END
END
