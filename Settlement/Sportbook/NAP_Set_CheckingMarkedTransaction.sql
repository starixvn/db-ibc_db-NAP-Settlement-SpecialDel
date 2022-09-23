/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_CheckingMarkedTransaction]
    @MatchID				INT
	,@Action				VARCHAR(20)
	,@IsExistMarkedTicket  	BIT = 0 			OUTPUT
	,@ErrCode				INT = 0 			OUTPUT
	,@ErrMsg				VARCHAR(MAX) = '' 	OUTPUT
AS
/*    
	Creator: Kathy
    Date: 20190320
    Task: Check marked ticket [Redmine:#106823]
    DB: DBTXN/BODB02
    Original: 
    
    Revisions:
		- 20190320@Kathy: Settlement with Tickets Exclusion [Redmine:#106823]
		- 20190620@Kathy: Remove betradar corner bettypes [Redmine:#109584]
		- 20200515@Kathy: Settlement Exclusion for Parlay [Redmine:#134103]
		- 20211215@Kathy: Soccer - Include calculate parlay into calculate single tickets process [Redmine:#166072]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]

    Param's Explanation:
		@Action: single ticket: REFUND, REFUND-HT, REFUND-FT
				 parlay ticket: MP-REFUND, MP-REFUND-HT, MP-REFUND-FT, MP

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @IsMergedParlay	BIT = 0
			,@IsCentral	BIT = 0
	DECLARE @tmpBettype TABLE (bettype SMALLINT)	

	SELECT	@IsMergedParlay = IsMergedParlay
	FROM	dbo.SettlementResultTableSetting WITH(NOLOCK)
	WHERE	Sporttype IN (SELECT Sporttype FROM dbo.match WITH(NOLOCK) WHERE matchid = @MatchID)

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	INSERT INTO @tmpBettype(bettype)
	SELECT	BetType
	FROM	dbo.f_Set_GetGroupBettypes()
	WHERE	1 = CASE 
					WHEN Is3x30 = 1  AND @Action = 'REFUND-HT' THEN 1
					WHEN GroupId IN(2,4) AND @Action = 'REFUND-FT' THEN 1
					WHEN @Action = 'REFUND' THEN 1
				END
			AND IsAuto = 0

	IF @Action IN ('REFUND', 'REFUND-HT', 'REFUND-FT')
	BEGIN
		IF EXISTS (SELECT TOP 1 1
					FROM	dbo.bettrans b WITH(NOLOCK)
						INNER JOIN dbo.MarkedTransaction mt WITH(NOLOCK)
							ON b.transid = mt.TransId
						INNER JOIN @tmpBettype bt
							ON b.bettype = bt.bettype
					WHERE	b.matchid = @MatchID
							AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
							AND b.statusID NOT IN (101, 102)
			)
		BEGIN
			SET @IsExistMarkedTicket = 1
		END
		ELSE IF @IsMergedParlay = 1
		BEGIN
			IF EXISTS (SELECT TOP 1 1
					FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
						CROSS APPLY (
							SELECT TOP 1 b.refno
									,b.statusID
									,b.matchid
									,b.SiteDBGroupID
							FROM	dbo.bettrans b WITH(NOLOCK)
							WHERE	b.transid = mt.TransId
									AND b.matchid = 29
						) b							
						CROSS APPLY (
							SELECT TOP 1 bm.transid
							FROM	dbo.bettransm bm WITH(NOLOCK)
							WHERE	bm.matchid = mt.matchid
									AND bm.refno = b.refno
									AND bm.statusID = 0
									AND EXISTS (SELECT TOP 1 1 FROM @tmpBettype t WHERE t.bettype = bm.bettype)
						)bm
					WHERE	mt.MatchId = @MatchID
							AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
		)
			SET @isExistMarkedTicket = 1
		END
	END
	ELSE IF @Action LIKE 'MP%'
	BEGIN
		IF EXISTS (SELECT TOP 1 1
					FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
						CROSS APPLY (
							SELECT TOP 1 b.refno
									,b.statusID
									,b.matchid
									,b.SiteDBGroupID
							FROM	dbo.bettrans b WITH(NOLOCK)
							WHERE	b.transid = mt.TransId
									AND b.matchid = 29
						) b							
						CROSS APPLY (
							SELECT TOP 1 bm.transid
							FROM	dbo.bettransm bm WITH(NOLOCK)
							WHERE	bm.matchid = mt.matchid
									AND bm.refno = b.refno
									AND bm.statusID = 0
						)bm
					WHERE	mt.MatchId = @MatchID
							AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
		)
		BEGIN
			SET @IsExistMarkedTicket = 1
		END
	END
	
	IF @IsExistMarkedTicket = 1
		SELECT 	@ErrCode = 1001032
				,@ErrMsg = 'ERROR! Cannot proceed due to marked tickets. Please unmark them and try again.'
END
GO