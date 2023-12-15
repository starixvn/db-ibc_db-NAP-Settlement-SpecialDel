/*<info serverAlias="DBSIG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SettlementResultHistory_Schedule]
AS
/*	
	Created by: 20231214@Aries
	Task: Settlement  
	DB: DBCTG-bodb02
	
	Revisions:
		- 20231214@Aries: Result Amendment [Redmine: #196401]

	Param's Explanation:  
		- @WrongResult: '<root><r Id="96801004" Home="20" Away="" RefBettypeID ="9680" G="1" OtherInfo="16776" Action="CAL" LogDate="2023-11-24 03:25:22.243" /></root>'	 
		- @ActualResult: '<root><r Id="96801004" Home="20" Away="" RefBettypeID ="9680" G="1" OtherInfo="16776"/></root>'
*/
BEGIN	
	SET NOCOUNT ON

	CREATE TABLE #tblTrans (transId BIGINT  PRIMARY KEY WITH (IGNORE_DUP_KEY = ON),TicketType VARCHAR(1))
	CREATE TABLE #tblTransParlay (transId BIGINT  PRIMARY KEY WITH (IGNORE_DUP_KEY = ON))

	DECLARE  @SessionId			VARCHAR(50)       
			,@matchid			INT
			,@sportType 		INT
			,@batchNo			INT 			= 2000
			,@batchCount		INT 			= 0
			,@isPass			BIT				= 0
			,@CreatedDate		DATETIME
			,@DateCheck			DATETIME 		= DATEADD(MINUTE,-30 ,GETDATE())
			
	DECLARE @tmpTransIDBatch TABLE (TransID BIGINT,TicketType VARCHAR(1))
	CREATE TABLE #Resource(ResourceID VARCHAR(20), SeqNo INT,PRIMARY KEY(ResourceID))

	IF OBJECT_ID('BalanceNegative','U') IS NOT NULL 
	BEGIN
		SELECT	 TOP 1
				 @matchid =	matchid
				,@SessionId = SessionID
				,@sportType	= sportType
				,@CreatedDate = CreatedDate
				,@isPass = IIF(b.StatusID IS NULL,1,0)
		FROM SettlementResultHistory AS h WITH(NOLOCK)
			OUTER APPLY (SELECT TOP 1 statusid
						 FROM [dbo].[BalanceNegative] AS b WITH(NOLOCK)
						 WHERE b.matchid = h.matchid
							AND b.SessionID = h.SessionID
							AND b.statusid = 0
			) AS b
		WHERE h.StatusID = 1
			AND (b.StatusID IS NULL OR h.CreatedDate <= @DateCheck)

		IF @SessionId IS NULL
		BEGIN
			SELECT	 TOP 1
				 @matchid =	h.matchid
				,@SessionId = h.SessionID
				,@sportType	= h.sportType
				,@isPass = IIF((s.IsCalculating IS NOT NULL AND s.IsCalculating > 1 AND (p.IsCalculating IS NULL OR p.IsCalculating > 1) AND b.StatusID IS NULL),1,0)
			FROM SettlementResultHistory AS h WITH(NOLOCK)
				CROSS APPLY (SELECT TOP 1 MIN(IsCalculating) AS  IsCalculating
							 FROM Single_Calculate_Queue AS q WITH(NOLOCK) 
							 WHERE q.matchid = h.matchid
								AND q.BroadcastSessionId = h.SessionID
				) AS s
				OUTER APPLY (SELECT TOP 1 MIN(IsCalculating) AS  IsCalculating
							 FROM Parlay_Calculate_Queue AS q WITH(NOLOCK) 
							 WHERE q.matchid = h.matchid
								AND q.BroadcastSessionId = h.SessionID
								AND q.IsCalculating IN (0,1)
				) AS p
				OUTER APPLY (SELECT TOP 1 statusid
						 FROM [dbo].[BalanceNegative] AS b WITH(NOLOCK)
						 WHERE b.matchid = h.matchid
							AND b.SessionID = h.SessionID
							AND b.statusid = 0
				) AS b
			WHERE h.StatusID = 0 
				AND (
				    (s.IsCalculating IS NOT NULL AND s.IsCalculating > 1 AND (p.IsCalculating IS NULL OR p.IsCalculating > 1) AND b.StatusID IS NULL)
					OR 
					h.CreatedDate <= @DateCheck
				)
		END
	END
	ELSE
	BEGIN
		SELECT	 TOP 1
				 @matchid =	matchid
				,@SessionId = SessionID
				,@sportType	= sportType
				,@CreatedDate = CreatedDate
				,@isPass = 1
		FROM SettlementResultHistory AS h WITH(NOLOCK)
		WHERE h.StatusID = 1

		IF @SessionId IS NULL
		BEGIN
			SELECT	 TOP 1
				 @matchid =	h.matchid
				,@SessionId = h.SessionID
				,@sportType	= h.sportType
				,@isPass = IIF(s.IsCalculating IS NOT NULL AND s.IsCalculating > 1 AND (p.IsCalculating IS NULL OR p.IsCalculating > 1),1,0)
			FROM SettlementResultHistory AS h WITH(NOLOCK)
				CROSS APPLY (SELECT TOP 1 MIN(IsCalculating) AS  IsCalculating
							 FROM Single_Calculate_Queue AS q WITH(NOLOCK) 
							 WHERE q.matchid = h.matchid
								AND q.BroadcastSessionId = h.SessionID
				) AS s
				OUTER APPLY (SELECT TOP 1 MIN(IsCalculating) AS  IsCalculating
							 FROM Parlay_Calculate_Queue AS q WITH(NOLOCK) 
							 WHERE q.matchid = h.matchid
								AND q.BroadcastSessionId = h.SessionID
								AND q.IsCalculating IN (0,1)
				) AS p
			WHERE h.StatusID = 0 
				AND (
				    (s.IsCalculating IS NOT NULL AND s.IsCalculating > 1 AND (p.IsCalculating IS NULL OR p.IsCalculating > 1))
					OR 
					h.CreatedDate <= @DateCheck
				)
		END
	END

	IF @CreatedDate <= @DateCheck AND @isPass = 0
	BEGIN
		UPDATE SettlementResultHistory
		SET StatusID = 3
		WHERE matchid =	@matchid
			AND SessionId = @SessionID
	
		RETURN
	END

	IF @SessionId IS NULL 
	BEGIN
		RETURN
	END

	INSERT INTO #tblTrans(TransId,TicketType)
	SELECT t.t AS TransId
		  ,l.TicketType
	FROM SiteDB_SettlementService_CalculationLog AS l WITH(NOLOCK)
	    CROSS APPLY OPENJSON(CAST(DECOMPRESS(l.TransInfoJson) AS NVARCHAR(MAX))) WITH (t  BIGINT,[sid] TINYINT,bef_sid TINYINT,ssid VARCHAR(50)) AS t
	WHERE l.matchid = @matchid
		AND t.ssid = @SessionId
		AND t.[sid] != t.bef_sid
		AND t.bef_sid != 0
	
	INSERT INTO #tblTransParlay(TransId)
	SELECT t.t AS TransId
	FROM SiteDB_SettlementService_CalculationLog AS l WITH(NOLOCK)
	    CROSS APPLY OPENJSON(CAST(DECOMPRESS(l.TransInfoJson) AS NVARCHAR(MAX))) WITH (t  BIGINT,[sid] TINYINT,bef_sid TINYINT,ssid VARCHAR(50)) AS t
	WHERE l.matchid = 29
		AND t.ssid = @SessionId
		AND t.[sid] != t.bef_sid
		AND t.bef_sid != 0
		AND t.[sid] != 0
		AND l.LogDate >= DATEADD(MINUTE,-30 ,@CreatedDate) 

	;WITH CTE_ResourceID AS (
		SELECT  CAST(h.[ActualResult] AS XML)  AS ActualResult
			   ,SeqNo
		FROM SettlementResultHistory AS h WITH(NOLOCK) 
		WHERE matchid =	@matchid
			AND SessionId = @SessionID
	)
	INSERT INTO #Resource(ResourceID,SeqNo)
	SELECT ResourceID  = x.r.value('(@Id)[1]','NVARCHAR(50)')
	   ,   SeqNo
	FROM CTE_ResourceID
		CROSS APPLY ActualResult.nodes('/root/r') x(r) 

	WHILE 1=1
	BEGIN
		DELETE @tmpTransIDBatch
		
		DELETE TOP(@batchNo) t
		OUTPUT deleted.transid,deleted.TicketType
		INTO @tmpTransIDBatch(TransID,TicketType)
		FROM #tblTrans t 

		SELECT @batchCount 	= @@ROWCOUNT
		IF @batchCount = 0 BREAK

		INSERT INTO SettlementResultHistory_TicketDetails(SessionID,Transid,SeqNo)
		SELECT  @SessionId
			   ,t.transId
			   ,r.SeqNo
		FROM @tmpTransIDBatch AS t
			INNER JOIN bettrans AS b WITH(NOLOCK) ON b.transId = t.transId
			INNER JOIN SettlementSpecialBettypeProfile AS s WITH(NOLOCK) ON s.bettype = b.bettype AND  (s.BetID = 0 OR b.BetID = s.BetID)AND s.SportType = @sportType
			INNER JOIN #Resource AS r ON  s.ResourceID = r.ResourceID 
		WHERE t.TicketType = 's'
			AND NOT EXISTS (SELECT TOP 1 1 
						    FROM SettlementResultHistory_TicketDetails AS h 
						    WHERE h.transId = t.transId
								AND h.SessionId = @SessionId)

		INSERT INTO SettlementResultHistory_TicketDetails(SessionID,Transid,SeqNo)
		SELECT  @SessionId
			   ,tp.transid
			   ,tbl.SeqNo
		FROM @tmpTransIDBatch AS t
			INNER JOIN bettransm AS p WITH(NOLOCK) ON p.transId = t.transId
			CROSS APPLY(SELECT TOP 1 bt.transid
			            FROM bettrans AS bt WITH(NOLOCK) 					
						WHERE bt.refno = p.refno
							AND bt.matchid  = 29							
			) AS b
			CROSS APPLY(SELECT TOP 1 r.SeqNo
			            FROM SettlementSpecialBettypeProfile AS s WITH(NOLOCK) 
							INNER JOIN #Resource AS r ON  s.ResourceID = r.ResourceID 
						WHERE s.bettype = p.bettype
							AND s.SportType = @sportType
			) AS tbl
			INNER JOIN #tblTransParlay AS tp ON tp.transid = b.transid
		WHERE t.TicketType = 'p'
			AND NOT EXISTS (SELECT TOP 1 1 
						    FROM SettlementResultHistory_TicketDetails AS h 
						    WHERE h.transId = tp.transid
								AND h.SessionId = @SessionId)
	END

	UPDATE SettlementResultHistory
	SET StatusID = 2
	WHERE matchid =	@matchid
		AND SessionId = @SessionID
END