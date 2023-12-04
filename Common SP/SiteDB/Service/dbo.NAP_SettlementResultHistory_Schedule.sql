/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[dbo.NAP_SettlementResultHistory_Schedule]
AS
/*	
	Created by: 20221026@Kathy
	Task: Settlement  
	
	Revisions:
		- 20221026@Kathy: Enhance settlement performance of siteDB on Central/SubDB [178694]

	Param's Explanation:  
		   
*/
BEGIN	
	SET NOCOUNT ON

	CREATE TABLE #tblTrans (transId BIGINT)

	DECLARE  @SessionId			VARCHAR(50)       
			,@matchid			INT
			,@sportType 		INT
			,@batchNo			INT 			= 2000
			

	DECLARE @tmpTransIDBatch TABLE (TransID BIGINT)

	SELECT	 TOP 1
			 @matchid =	matchid
			,@SessionId = SessionID
			,@sportType	= sportType
	FROM SettlementResultHistory AS h WITH(NOLOCK)
	WHERE h.StatusID = 1
		AND NOT EXISTS (SELECT TOP 1 1
						FROM [dbo].[BalanceNegative] AS b WITH(NOLOCK)
						WHERE b.SessionID = h.SessionID
							AND b.statusid = 0)

	IF @SessionId IS NULL 
	BEGIN
		RETURN
	END

	INSERT INTO #tblTrans(TransId)
	SELECT t.t AS TransId
	FROM SiteDB_SettlementService_CalculationLog AS l WITH(NOLOCK)
	    CROSS APPLY OPENJSON( CAST(DECOMPRESS(l.TransInfoJson) AS NVARCHAR(MAX))) WITH (t  BIGINT,w MONEY,bef_winlost  MONEY,ssid VARCHAR(50)) AS t
	WHERE l.matchid = @matchid
		AND t.ssid = @SessionId
		AND t.w != bef_winlost

	WHILE 1=1
	BEGIN
		DELETE @tmpTransIDBatch
		
		DELETE TOP(@batchNo) t
		OUTPUT deleted.transid
		INTO @tmpTransIDBatch(TransID)
		FROM #tmpTransID t 

		SELECT @batchCount 	= @@ROWCOUNT
		IF @batchCount = 0 BREAK


		INSERT INTO SettlementResultHistory_TicketDetails(SessionID,Transid,ResourceID)
		SELECT  @SessionId
			   ,t.transId
			   ,s.ResourceID
		FROM @tmpTransIDBatch AS t
			INNER JOIN bettrans AS b WITH(NOLOCK) ON b.transId = t.transId
			INNER JOIN SettlementSpecialBettypeProfile AS s WITH(NOLOCK) ON s.bettype = t.bettype AND s.betid = t.betid AND s.SportType = @sportType
		WHERE NOT EXISTS (SELECT TOP 1 1 
						  FROM SettlementResultHistory_TicketDetails AS h 
						  WHERE h.transId = t.transId
						  AND h.SessionId = @SessionId)

	END

	UPDATE SettlementResultHistory
	SET StatusID = 2
	WHERE matchid =	@matchid
		AND SessionId = @SessionID
END