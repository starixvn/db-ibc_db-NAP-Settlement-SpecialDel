/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_MP_29]
	@matchdate	SMALLDATETIME
	,@strXML	VARCHAR(MAX)
AS
/*
	Created: Kathy
	Date: 20160419
	Task : Settle bettrans (for system parlay)
	DB: DBTXN.bodb02
	
	Original: 

	Revisions:
		- 20160728@Kathy: Using non clustered index PK_bettrans to settle [Redmine:#61193]
		- 20161114@Kathy: Wrongly update winlostdate of parlay running ticket [Redmine#67084]
		- 20190409@Sol: Settlement Time [Redmine:#99638]
		- 20201126@Louisa: God Of Fortune for Parlay [Redmine:#145774]

	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #Refno (refno BIGINT  PRIMARY KEY, transid BIGINT)
	DECLARE @minRefno BIGINT	
			
	DECLARE @xml XML
			,@statusId TINYINT
			,@winlost MONEY
			
	SET @xml = CONVERT(XML, N'<root><r rn="' + REPLACE(REPLACE(@strXML, '|', '" t="'), ',', '"/><r rn="') + '"/></root>')
	
	INSERT INTO #Refno (refno, transid)
	SELECT T.C.value('./@rn', 'bigint')
			,T.C.value('./@t', 'bigint')
	FROM @xml.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@xml = NULL ))
	
	SELECT @minRefno = MIN(refno)
	FROM #Refno
	DECLARE @settlementTime DATETIME
	SET @settlementTime = GETDATE();

	;WITH _source AS (
	SELECT transid = b.transid
		,winlostdate = MAX(pr.winlostdate)
		,totalStake = SUM(pr.stake)
		--,modds = SUM(modds) 
		,winlost = SUM(pr.winlost) 
		,awinlost = SUM(pr.awinlost) 
		,mwinlost = SUM(pr.mwinlost) 
		,swinlost = SUM(pr.swinlost) 
		,playercomm = SUM(pr.playercomm) 
		,comm = SUM(pr.comm) 
		,acomm = SUM(pr.acomm) 
		,scomm = SUM(pr.scomm) 			
		,ruben = CASE WHEN SUM(CASE pr.statusID WHEN 0 THEN pr.stake ELSE 0 END) > 0 THEN 0 ELSE 1 END -- in case got sub running, then ruben=0, otherwise set ruben=1
	FROM #Refno b 
		INNER JOIN dbo.BetParlayResult pr WITH(NOLOCK)
			ON pr.refno = b.refno
	WHERE pr.RefNo >= @minRefno
	GROUP BY b.refno, b.transid
	)
	UPDATE b WITH(ROWLOCK, UPDLOCK)
	SET @statusId = CASE
					WHEN s.ruben = 0 THEN 0
					WHEN ISNULL(b.oddsspread,0) = 1 THEN	CASE ---GoF
															WHEN s.winlost = b.actual_Stake THEN 111
															WHEN s.winlost > b.actual_Stake THEN 112
															WHEN s.winlost < b.actual_stake THEN 113 
															END
					ELSE	CASE				
							WHEN s.winlost = s.totalStake THEN 111 -- winlost = stake, member DRAW
							WHEN s.winlost > s.totalStake THEN 112 -- winlost > stake, member WIN
							WHEN s.winlost < s.totalStake THEN 113 -- winlost < stake, member LOSE
							ELSE b.statusID -- uncontrollale situation, hope it's not happen in real life
							END
					END
		,@winlost = s.winlost * s.ruben
		,SettlementTime = CASE WHEN @statusId <> 0 AND (b.winlost <> @winlost OR statusID <> @statusId) THEN @settlementTime ELSE SettlementTime END
		,statusID = @statusId
		,[status] = CASE 
						WHEN @statusId = 0 THEN 'running' 
						WHEN @statusId = 111 THEN 'DRAW' -- winlost = stake, member DRAW
						WHEN @statusId = 112 THEN 'WON' -- winlost > stake, member WIN
						WHEN @statusId = 113 THEN 'LOSE' -- winlost < stake, member LOSE
						ELSE b.[status] -- uncontrollale situation, hope it's not happen in real life
					END
		,winlostdate = CASE WHEN @statusId <> b.statusID THEN s.winlostdate ELSE b.winlostdate END
		--,modds = s.modds
		---,actual_stake = s.totalStake
		,betdaqid = s.totalStake							
		,ruben = s.ruben
		,winlost =  @winlost
		,awinlost = s.awinlost * s.ruben
		,mwinlost = s.mwinlost * s.ruben
		,swinlost = s.swinlost * s.ruben
		,playercomm = s.playercomm * s.ruben
		,comm = s.comm * s.ruben
		,acomm = s.acomm * s.ruben
		,scomm = s.scomm * s.ruben
	FROM dbo.bettrans b
		INNER JOIN _source s
			ON b.transid = s.transid
END


GO
