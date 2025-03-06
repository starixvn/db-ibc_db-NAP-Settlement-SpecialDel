/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_MatchLockingTicketSel
	@MatchId INT 
	,@KeyId INT
	,@Action VARCHAR(20) = ''
	,@MarketId VARCHAR(20) = ''
AS
/*
	Created by: 20210506@Kathy
	Task: Get number of ticket of locked match [Redmine:#151475]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20210506@Kathy: Get number of ticket of locked  [Redmine:#151475]
		- 20220913@Louisa: Support delete locking at SiteDB after release Scale out DBTrans [RedmineId:#177711]
		- 20230208@Louisa: remove block code check by [f_Set_SettingByProfile] [RedmineId:#179505]
		- 20250305@Lani: Change alias server [Redmine: #217848]

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @SportType SMALLINT
			,@TicketCount INT
			,@IsCentral BIT = 0

	DECLARE @tmpBettype TABLE (bettype SMALLINT)
	
	SELECT	@SportType = m.sporttype
	FROM	dbo.match m WITH(NOLOCK)
	WHERE	m.matchid = @MatchId

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	IF @KeyId = 5 -- Bet Builder
	BEGIN
		SELECT	@TicketCount = COUNT(1)
		FROM	dbo.bettrans b WITH(NOLOCK)
		WHERE	b.matchid = @MatchId
				AND b.bettype = 38
				AND b.statusID IN (0,1)
				AND b.betcheck = @MarketId
				AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
	END
	ELSE
	BEGIN
		INSERT INTO @tmpBettype(bettype)
		SELECT	bt.typeid
		FROM	dbo.bettype bt WITH(NOLOCK)
		WHERE	1 = CASE
						WHEN @KeyId = 2 AND bt.typeid = 10 THEN 1 -- outright
						WHEN @KeyId = 3 AND bt.typeid BETWEEN 801 AND 806 THEN 1 -- metric gaming
						WHEN @KeyId = 4 AND bt.typeid BETWEEN 1231 AND 1233 THEN 1 -- VS racing
						WHEN @KeyId = 6 AND bt.typeid BETWEEN 221 AND 227 THEN 1 -- FM
						WHEN @KeyId = 7 AND bt.typeid BETWEEN 228 AND 229 THEN 1 -- SABA FM
						ELSE 0
					END

		IF @Action <> '' --settlement
		BEGIN
			;WITH cteProfile
			AS(
				SELECT	DISTINCT bettype, SettleType
				FROM	dbo.SettlementSpecialBettypeProfile s WITH(NOLOCK)
				WHERE	s.SettleType = CASE 
											WHEN @Action LIKE '%EAR' THEN 'EAR'
											ELSE 'MNL'
										END
						AND s.SportType = @SportType
			)
			, cteInstant
			AS(
				SELECT	i.bettype
				FROM	dbo.f_Set_Instant_GetBettypes () i
				WHERE	1 = CASE
								WHEN @Action = 'INST-HT' AND i.InstantType & 1 = 1 THEN 1
								WHEN @Action = 'INST-FT' AND i.InstantType & 2 = 2 THEN 1 
								WHEN @Action = 'INST-UNDO' THEN 1
								ELSE 0
							END
			)
			INSERT INTO @tmpBettype (bettype)
			SELECT	f.bettype
			FROM	dbo.f_Set_GetGroupBettypes() f
				OUTER APPLY (
					SELECT p.BetType
					FROM	cteProfile p
					WHERE	p.BetType = f.BetType
				)p
				OUTER APPLY (
					SELECT	i.bettype
					FROM	cteInstant i
					WHERE	i.bettype = f.BetType
				)i
			WHERE	1 = CASE 
							WHEN @Action LIKE '%EARLY' THEN CASE WHEN f.GroupId = 8 THEN 1 ELSE 0 END -- auto soccer
							WHEN @Action = 'CAL-HT' THEN CASE WHEN f.GroupId IN (1,3,5) THEN 1 ELSE 0 END -- ht
							WHEN @Action = 'REFUND-HT' THEN CASE WHEN f.Is3x30 = 1 THEN 1 ELSE 0 END -- refund
							WHEN @Action IN ('CAL-FT', 'REFUND-FT') THEN CASE WHEN f.GroupId IN (2,4,6) THEN 1 ELSE 0 END -- ft
							WHEN p.BetType IS NOT NULL THEN CASE WHEN f.BetType = p.BetType THEN 1 ELSE 0 END -- profile
							WHEN i.bettype IS NOT NULL THEN CASE WHEN f.BetType = i.BetType THEN 1 ELSE 0 END -- inst
							WHEN f.GroupId NOT IN (8,9) THEN 1 -- all
							ELSE 0
						END

			SELECT	@TicketCount = COUNT(1)
			FROM	dbo.bettrans b WITH(NOLOCK)
				INNER JOIN @tmpBettype t
					ON b.bettype = t.bettype
			WHERE	b.matchid = @MatchId
					AND b.statusID IN (0,1)
					AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
		END
		ELSE
		BEGIN
			SELECT	@TicketCount = COUNT(1)
			FROM	dbo.bettrans b WITH(NOLOCK)
				LEFT JOIN @tmpBettype t
					ON b.bettype = t.bettype
			WHERE	b.matchid = @MatchId
					AND b.statusID IN (0,1)
					AND (@KeyId = 1 OR t.bettype IS NOT NULL)
					AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
		END
		
	END

	SELECT @TicketCount AS TicketCount
END
GO
