/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Parlay_Calculate_3]
	@matchid 		INT
	,@matchdate		SMALLDATETIME
    ,@Action		VARCHAR(10)
	,@strTransIds 	VARCHAR(MAX) = NULL
AS
/*    
	Creator: 20161205@Bobby
    Task: #61352 - Apply settle determined for parlay bet types
    DB: DBTXN.bodb02
	Original:

    Revisions:        
		- 20170609@Kathy: Early Settlement - BAIO [Redmine:#77835]
		
    Param's Explanation:
        
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @xmlParlayTicket 	XML
		
	CREATE TABLE #parlayTicket (transid BIGINT, refno BIGINT, statusId TINYINT, modds SMALLMONEY, IsRefundGame BIT)		
	CREATE TABLE #parlayOutput (transid BIGINT, refno BIGINT, statusId TINYINT, statuswinlost TINYINT)		
	
	SET @xmlParlayTicket = CONVERT(XML, @strTransIds)
	
	INSERT INTO #parlayTicket (transid, refno, statusId, modds, IsRefundGame)
	SELECT T.C.value('./@t', 'BIGINT') 			AS transid
			,T.C.value('./@r', 'BIGINT') 		AS refno
			,T.C.value('./@s', 'TINYINT') 		AS statusId
			,T.C.value('./@m', 'SMALLMONEY') 	AS modds
			,T.C.value('./@i', 'BIT') 			AS IsRefundGame
	FROM @xmlParlayTicket.nodes('/b') AS T(C)
	OPTION (OPTIMIZE FOR (@xmlParlayTicket = NULL ))
	
	IF(@@ROWCOUNT = 0) RETURN
	
	--CALCULATE PROCESS
	IF (@action IN ('ABANDONED', 'REFUND'))
	BEGIN
		--UPDATE bettransm
		UPDATE bm
		SET winlostdate 	= @matchdate
			/*,[status] 		= CASE 
				WHEN t.statusID = 113 THEN N'LOSE'
				WHEN t.statusID = 112 THEN N'WON'
				WHEN t.statusID = 103 THEN N'Refund'
				ELSE bm.[status]
			END*/
			,[status] 	= CASE 
				WHEN t.modds = 0 THEN 'Refund'
				WHEN t.modds < 0 THEN 'LOSE'
				WHEN t.modds > 0 THEN 'WON'
				ELSE bm.[status]
			END
			--,statusID 	= t.statusID
			,statusID = CASE 
				WHEN t.modds = 0 THEN 103 
				WHEN t.modds < 0 THEN 113
				WHEN t.modds > 0 THEN 112
				ELSE bm.statusID
			END
			/*,statuswinlost = CASE 
				WHEN t.statusID = 113 THEN 4 -- LOSE
				WHEN t.statusID = 112 THEN 2 -- WON
				WHEN t.statusID = 103 THEN 0 -- REFUND
				ELSE bm.statuswinlost
			END*/
			,statuswinlost = CASE 
				WHEN t.modds > 0.25 THEN 2 -- WON
				WHEN t.modds = 0.25 THEN 1 -- Half WON
				WHEN t.modds = - 0.25 THEN 3 -- Half LOSE
				WHEN t.modds < - 0.25 THEN 4 -- LOSE
				ELSE bm.statuswinlost
			END
			,ruben 		= 1
			
		OUTPUT INSERTED.transid
				,INSERTED.refno
				,INSERTED.statusID
				,INSERTED.statuswinlost
		INTO #parlayOutput(transid, refno, statusID, statuswinlost)
		FROM dbo.bettransm bm WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #parlayTicket t
			ON bm.refno = t.refno AND bm.transid = t.transid
		
		--UPDATE BetParlayDetail
		UPDATE pd 
		SET winlostdate 	= @matchdate
			,statusid 		= r.statusId
			,statuswinlost 	= r.statuswinlost
		FROM dbo.BetParlayDetail pd WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #parlayOutput r
			ON pd.transid 	= r.transid
			AND pd.RefNo 	= r.refno
	END
	
	IF (@action IN ('CAL'))
	BEGIN
		--UPDATE bettransm
		UPDATE bm
		SET ruben = CASE 
				WHEN t.modds IS NULL THEN 0
				ELSE 1
            END
			,winlostdate 	= @matchdate
			,[status] = CASE 
					WHEN t.modds IS NULL THEN N'running'
					WHEN t.modds = 0 AND t.IsRefundGame = 0 THEN N'DRAW'
					WHEN t.modds = 0 AND t.IsRefundGame = 1 THEN N'Refund'
					WHEN t.modds < 0 THEN N'LOSE'
					WHEN t.modds > 0 THEN N'WON'
					END
			,statusID = CASE 
				WHEN t.modds IS NULL THEN 0
				WHEN t.modds = 0 AND t.IsRefundGame = 0 THEN 111
				WHEN t.modds = 0 AND t.IsRefundGame = 1 THEN 103 
				WHEN t.modds < 0 THEN 113
				WHEN t.modds > 0 THEN 112
			END
			,statuswinlost = CASE 
				WHEN t.modds > 0.25 THEN 2 -- WON
				WHEN t.modds = 0.25 THEN 1 -- Half WON
				WHEN t.modds = - 0.25 THEN 3 -- Half LOSE
				WHEN t.modds < - 0.25 THEN 4 -- LOSE
				ELSE 0 -- DRAW
			END
		OUTPUT INSERTED.transid
				,INSERTED.refno
				,INSERTED.statusID
				,INSERTED.statuswinlost
		INTO #parlayOutput(transid, refno, statusID, statuswinlost)
		FROM dbo.bettransm bm WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #parlayTicket t
			ON bm.refno = t.refno AND bm.transid = t.transid
		
		--UPDATE BetParlayDetail
		UPDATE pd 
		SET winlostdate 	= @matchdate
			,statusid 		= r.statusId
			,statuswinlost 	= r.statuswinlost
		FROM dbo.BetParlayDetail pd WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #parlayOutput r
			ON pd.transid 	= r.transid
			AND pd.RefNo 	= r.refno
	END
	
	DROP TABLE #parlayTicket;
	DROP TABLE #parlayOutput
	RETURN;
END

GO