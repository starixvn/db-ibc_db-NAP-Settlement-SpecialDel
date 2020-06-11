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

    Param's Explanation:
		@Action: single ticket: REFUND, REFUND-HT, REFUND-FT
				 parlay ticket: MP-REFUND, MP-REFUND-HT, MP-REFUND-FT, MP

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @tmpBettype TABLE (bettype SMALLINT)	

	INSERT INTO @tmpBettype(bettype)
	SELECT	BetType
	FROM	dbo.f_Set_GetGroupBettypes()
	WHERE	1 = CASE 
					WHEN GroupId IN(1,3) AND @Action = 'REFUND-HT' THEN 1
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
							AND b.statusID NOT IN (101, 102)
			)
		BEGIN
			SET @IsExistMarkedTicket = 1
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
