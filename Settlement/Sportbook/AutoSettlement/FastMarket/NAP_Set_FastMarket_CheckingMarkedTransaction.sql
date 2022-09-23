/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_FastMarket_CheckingMarkedTransaction]
    @MatchID        INT
	,@Results		VARCHAR(MAX)
AS
/*   
	Creator: Kathy
    Date: 20190320
    Task: Check marked ticket [Redmine:#106823]
    DB: DBTXN/BODB02
    Original: 
    
    Revisions:
		- 20190320@Kathy: Settlement with Tickets Exclusion [Redmine:#106823]
		- 20200928@Kathy: Implement New Bettype 228 Time Machine Over/Under [Redmine:#142001]
		- 20210406@Kathy: New bettype 229 [Readmine:#152748]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
		
    Param's Explanation:
		@Results
			<BetTypes>
				<BetType Id="">
					<Item Position="" />
					<Item Position="" />
				</BetType>	
			</BetTypes>
*/ 
BEGIN
	SET NOCOUNT ON
	
	DECLARE @isExistMarkedTicket	BIT
			,@xml					XML
			,@IsCentral				BIT
		
	DECLARE @tmpBettype TABLE (bettype SMALLINT, Position TINYINT)

	SET @isExistMarkedTicket = 0
	SET @xml = CONVERT(XML, @Results)

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	INSERT INTO @tmpBettype(bettype, Position)
	SELECT T.C.value('@Id', 'SMALLINT') AS Bettype
		,X.C.value('@Position','TINYINT') as Position
	FROM @xml.nodes('/BetTypes/BetType') AS T(C)
		CROSS APPLY
			C.nodes('Item') AS X(C)
	OPTION ( OPTIMIZE FOR ( @xml = NULL ) )

	IF EXISTS (
		SELECT	TOP 1 1
		FROM	dbo.bettrans b WITH(NOLOCK)
			INNER JOIN dbo.MarkedTransaction mt WITH(NOLOCK)
				ON	b.transid = mt.TransId
			INNER JOIN @tmpBettype bt
				ON	b.bettype = bt.bettype
		WHERE	b.matchid = @MatchID
				AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
				AND b.statusID = 0	
				AND 1 = CASE
							WHEN b.bettype NOT IN (228, 229)
								THEN CASE 
										WHEN b.hdp1 = bt.Position THEN 1
										ELSE 0
									END
							ELSE CASE
									WHEN bt.Position < 45 AND b.hdp1 = bt.Position THEN 1
									WHEN bt.Position > 45 AND b.hdp1 = bt.Position - 1 THEN 1
									ELSE 0
								END
						END
				AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
		)
	BEGIN
		SET @isExistMarkedTicket = 1
	END
	
	SELECT @isExistMarkedTicket AS isExistMarkedTicket
END
GO
