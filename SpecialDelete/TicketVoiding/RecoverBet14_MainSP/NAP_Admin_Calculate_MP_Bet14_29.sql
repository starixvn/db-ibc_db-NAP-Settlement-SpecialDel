/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_MP_Bet14_29]
	@strXML	VARCHAR(MAX)
AS
/*
	Created by: 20190715@Helen
	Task: Settlement  
	DB: DBTRANS/BODB02
	
	Revisions:
		- 20190715@Helen: Recover/Void tickets in Bet 14 - [Redmine:115377]
		
	Param's Explanation:  
		
*/
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #Refno (refno BIGINT  PRIMARY KEY, transid BIGINT)
	DECLARE @minRefno BIGINT	
			
	DECLARE @xml XML
			,@statusId TINYINT
			,@winlost MONEY
			,@winlostdate SMALLDATETIME
			,@currentDate SMALLDATETIME
			
	SET @currentDate =  CONVERT(VARCHAR(10),GETDATE(),102)
	
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
	
	CREATE TABLE #temp_source (transid BIGINT,winlostdate SMALLDATETIME,totalStake MONEY,winlost MONEY,awinlost MONEY,mwinlost MONEY,swinlost MONEY
								,playercomm MONEY,comm MONEY,acomm MONEY,scomm MONEY,ruben TINYINT)
	
	INSERT INTO #temp_source (transid,winlostdate, totalStake, winlost, awinlost,mwinlost,swinlost,playercomm, comm, acomm, scomm, ruben)
	SELECT transid = b.transid
		,winlostdate = MAX(winlostdate)
		,totalStake = SUM(stake)
		,winlost = SUM(winlost) 
		,awinlost = SUM(awinlost) 
		,mwinlost = SUM(mwinlost) 
		,swinlost = SUM(swinlost) 
		,playercomm = SUM(playercomm) 
		,comm = SUM(comm) 
		,acomm = SUM(acomm) 
		,scomm = SUM(scomm) 			
		,ruben = CASE WHEN SUM(CASE statusID WHEN 0 THEN stake ELSE 0 END) > 0 THEN 0 ELSE 1 END -- in case got sub running, then ruben=0, otherwise set ruben=1
	FROM #Refno b 
		INNER JOIN dbo.BetParlayResult pr WITH(NOLOCK) ON pr.refno = b.refno
	WHERE pr.RefNo >= @minRefno
	GROUP BY b.refno, b.transid
	
	UPDATE b WITH(ROWLOCK, UPDLOCK)
	SET @statusId = CASE 
						WHEN s.ruben = 0 THEN 0 
						WHEN s.winlost = s.totalStake THEN 111 -- winlost = stake, member DRAW
						WHEN s.winlost > s.totalStake THEN 112 -- winlost > stake, member WIN
						WHEN s.winlost < s.totalStake THEN 113 -- winlost < stake, member LOSE
						ELSE b.statusID -- uncontrollale situation, hope it's not happen in real life
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
		,winlostdate = CASE WHEN @statusId = 113 AND b.winlostdate > @currentDate THEN @currentDate ELSE b.winlostdate END
		,actual_stake = s.totalStake
		,betdaqid = s.totalStake							
		,ruben = s.ruben
		,winlost = @winlost
		,awinlost = s.awinlost * s.ruben
		,mwinlost = s.mwinlost * s.ruben
		,swinlost = s.swinlost * s.ruben
		,playercomm = s.playercomm * s.ruben
		,comm = s.comm * s.ruben
		,acomm = s.acomm * s.ruben
		,scomm = s.scomm * s.ruben
	FROM dbo.bettrans b
		INNER JOIN #temp_source s ON b.transid = s.transid
	
	UPDATE b WITH(ROWLOCK, UPDLOCK)
		SET @statusId = CASE 
						WHEN s.ruben = 0 THEN 0 
						WHEN s.winlost = s.totalStake THEN 111 -- winlost = stake, member DRAW
						WHEN s.winlost > s.totalStake THEN 112 -- winlost > stake, member WIN
						WHEN s.winlost < s.totalStake THEN 113 -- winlost < stake, member LOSE
						ELSE b.statusID -- uncontrollale situation, hope it's not happen in real life
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
		,actual_stake = s.totalStake
		,betdaqid = s.totalStake							
		,ruben = s.ruben
		,winlost = @winlost
		,awinlost = s.awinlost * s.ruben
		,mwinlost = s.mwinlost * s.ruben
		,swinlost = s.swinlost * s.ruben
		,playercomm = s.playercomm * s.ruben
		,comm = s.comm * s.ruben
		,acomm = s.acomm * s.ruben
		,scomm = s.scomm * s.ruben
	FROM dbo.bettrans14 b
		INNER JOIN #temp_source s ON b.transid = s.transid
	
	DROP TABLE #temp_source
	DROP TABLE #Refno
					
END
GO
