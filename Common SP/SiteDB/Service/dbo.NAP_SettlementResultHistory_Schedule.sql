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

	CREATE TABLE #tblTrans (transId BIGINT  PRIMARY KEY WITH (IGNORE_DUP_KEY = ON),TicketType VARCHAR(1),bettype SMALLINT,betid BIGINT,refno BIGINT,winlost MONEY,bef_winlost MONEY,statusid TINYINT,bef_statusid TINYINT)
	CREATE TABLE #tblTransParlay (transId BIGINT  PRIMARY KEY WITH (IGNORE_DUP_KEY = ON),bettype SMALLINT,betid BIGINT,refno BIGINT,winlost MONEY,bef_winlost MONEY,statusid TINYINT,bef_statusid TINYINT)

	DECLARE  @SessionId			VARCHAR(50)       
			,@matchid			INT
			,@sportType 		INT
			,@ActionType		TINYINT
			,@StatusID			SMALLINT	
			,@batchNo			INT 			= 2000
			,@batchCount		INT 			= 0
			,@isPass			BIT				= 0
			,@CreatedDate		DATETIME
			,@DateCheck			DATETIME 		= DATEADD(MINUTE,-5 ,GETDATE())
			
	DECLARE @tmpTransIDBatch TABLE (TransID BIGINT,TicketType VARCHAR(1),bettype SMALLINT,betid BIGINT,refno BIGINT,winlost MONEY,bef_winlost MONEY,statusid TINYINT,bef_statusid TINYINT)
	CREATE TABLE #Resource(ResourceID VARCHAR(20), SeqNo INT,PRIMARY KEY(ResourceID))

	/* #1: Get match is caculated */
	IF OBJECT_ID('BalanceNegative','U') IS NOT NULL 
	BEGIN
		SELECT	 TOP 1
				 @matchid =	h.matchid
				,@SessionId = h.SessionID
				,@sportType	= h.sportType
				,@ActionType = h.ActionType
				,@StatusID =  h.StatusID
				,@CreatedDate = h.CreatedDate
				,@isPass = CASE WHEN h.StatusID = 0 AND b.StatusID IS NULL  THEN 1
								WHEN h.StatusID = 1 AND s.IsCalculating IS NOT NULL AND s.IsCalculating > 1 AND (p.IsCalculating IS NULL OR p.IsCalculating > 1) AND b.StatusID IS NULL THEN 1
							    ELSE 0
							END
		FROM SettlementResultHistory AS h WITH(NOLOCK)
			OUTER APPLY (SELECT TOP 1 MIN(IsCalculating) AS  IsCalculating
						 FROM Single_Calculate_Queue AS q WITH(NOLOCK) 
						 WHERE q.matchid = h.matchid
							AND q.BroadcastSessionId = h.SessionID
			) AS s
			OUTER APPLY (SELECT TOP 1 MIN(IsCalculating) AS  IsCalculating
						 FROM Parlay_Calculate_Queue AS q WITH(NOLOCK) 
						 WHERE q.matchid = h.matchid
							AND q.BroadcastSessionId = h.SessionID
			) AS p
			OUTER APPLY (SELECT TOP 1 statusid
					 FROM [dbo].[BalanceNegative] AS b WITH(NOLOCK)
					 WHERE b.matchid = h.matchid
						AND b.SessionID = h.SessionID
						AND b.statusid = 0
			) AS b
		WHERE h.StatusID IN (0,1)	
			AND 1 = CASE WHEN h.StatusID = 0 AND b.StatusID IS NULL  THEN 1
						 WHEN h.StatusID = 1 AND s.IsCalculating IS NOT NULL AND s.IsCalculating > 1 AND (p.IsCalculating IS NULL OR p.IsCalculating > 1) AND b.StatusID IS NULL THEN 1
						 WHEN h.CreatedDate <= @DateCheck THEN 1
						 ELSE 0
					 END
	END
	ELSE
	BEGIN
		SELECT	 TOP 1
				 @matchid =	h.matchid
				,@SessionId = h.SessionID
				,@sportType	= h.sportType
				,@ActionType = h.ActionType
				,@StatusID =  h.StatusID
				,@CreatedDate = h.CreatedDate
				,@isPass = CASE WHEN h.StatusID = 0 THEN 1
								WHEN h.StatusID = 1 AND s.IsCalculating IS NOT NULL AND s.IsCalculating > 1 AND (p.IsCalculating IS NULL OR p.IsCalculating > 1) THEN 1
							    ELSE 0
							END
		FROM SettlementResultHistory AS h WITH(NOLOCK)
			OUTER APPLY (SELECT TOP 1 MIN(IsCalculating) AS  IsCalculating
						 FROM Single_Calculate_Queue AS q WITH(NOLOCK) 
						 WHERE q.matchid = h.matchid
							AND q.BroadcastSessionId = h.SessionID
			) AS s
			OUTER APPLY (SELECT TOP 1 MIN(IsCalculating) AS  IsCalculating
						 FROM Parlay_Calculate_Queue AS q WITH(NOLOCK) 
						 WHERE q.matchid = h.matchid
							AND q.BroadcastSessionId = h.SessionID
			) AS p
		WHERE h.StatusID IN (0,1)
			AND 1 = CASE WHEN h.StatusID = 0 THEN 1
						 WHEN h.StatusID = 1 AND  s.IsCalculating IS NOT NULL AND s.IsCalculating > 1 AND (p.IsCalculating IS NULL OR p.IsCalculating > 1) THEN 1
						 WHEN h.CreatedDate <= @DateCheck THEN 1
						 ELSE 0
					END
	END

	/* #2: Check negative balance and queue processes hasn't completed and Update fail status*/
	IF @CreatedDate <= @DateCheck AND @isPass = 0
	BEGIN
		UPDATE SettlementResultHistory
		SET  StatusID = 3
			,ModifiedDate = GETDATE()
		WHERE matchid =	@matchid
			AND SessionId = @SessionID
		
		SELECT @matchid AS matchId,@SessionId AS SessionId, @ActionType AS ActionType, @CreatedDate AS CreatedDate,  @StatusID AS Status

		RETURN
	END

	IF @SessionId IS NULL 
	BEGIN
		RETURN
	END

	/* #3: Get changed ticket from calculation log (sync serivce)*/
	INSERT INTO #tblTrans(TransId,TicketType,bettype,betid,refno,winlost,bef_winlost,statusid,bef_statusid)
	SELECT t.t AS TransId
		  ,l.TicketType
		  ,t.bt AS bettype
		  ,t.bi AS betid
		  ,t.rf AS refno
		  ,t.w AS winlost
		  ,t.bef_w AS bef_winlost
		  ,t.[sid] AS statusid
		  ,t.bef_sid AS bef_statusid
	FROM SiteDB_SettlementService_CalculationLog AS l WITH(NOLOCK)
	    CROSS APPLY OPENJSON(CAST(DECOMPRESS(l.TransInfoJson) AS NVARCHAR(MAX))) WITH (t  BIGINT,w MONEY,bef_w MONEY,[sid] TINYINT,bef_sid TINYINT,bt SMALLINT,bi BIGINT,rf BIGINT) AS t
	WHERE l.matchid = @matchid
		AND l.BroadcastSessionId  = @SessionId
		AND (t.[sid] != t.bef_sid OR t.bef_w != t.w OR l.TicketType = 'p')
		AND t.bef_sid != 0
	
	INSERT INTO #tblTransParlay(TransId,bettype,betid,refno,winlost,bef_winlost,statusid,bef_statusid)
	SELECT t.t AS TransId
		  ,t.bt AS bettype
		  ,t.bi AS betid
		  ,t.rf AS refno
		  ,t.w AS winlost
		  ,t.bef_w AS bef_winlost
		  ,t.[sid] AS statusid
		  ,t.bef_sid AS bef_statusid
	FROM SiteDB_SettlementService_CalculationLog AS l WITH(NOLOCK)
	    CROSS APPLY OPENJSON(CAST(DECOMPRESS(l.TransInfoJson) AS NVARCHAR(MAX))) WITH (t  BIGINT,w MONEY,bef_w MONEY,[sid] TINYINT,bef_sid TINYINT,bt SMALLINT,bi BIGINT,rf BIGINT) AS t
	WHERE l.matchid = 29
		AND l.BroadcastSessionId  = @SessionId
		AND (t.[sid] != t.bef_sid OR t.bef_w != t.w)
		AND t.bef_sid != 0
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

	/* #4: Insert ticket*/
	WHILE 1=1
	BEGIN
		DELETE @tmpTransIDBatch
		
		DELETE TOP(@batchNo) t
		OUTPUT deleted.transid,deleted.TicketType,deleted.bettype,deleted.betid,deleted.refno,deleted.winlost,deleted.bef_winlost,deleted.statusid,deleted.bef_statusid
		INTO @tmpTransIDBatch(TransID,TicketType,bettype,betid,refno,winlost,bef_winlost,statusid,bef_statusid)
		FROM #tblTrans t 

		SELECT @batchCount 	= @@ROWCOUNT
		IF @batchCount = 0 BREAK
		
		INSERT INTO SettlementResultHistory_TicketDetails(SessionID,Transid,SeqNo,ExtraInfo_Before,ExtraInfo_After)
		SELECT  @SessionId
			   ,t.transId
			   ,r.SeqNo
			   ,CONCAT('<root><r status="',	 CASE WHEN bef_statusid = 1	  THEN 'WAITING' 
											 	  WHEN bef_statusid = 0	  THEN 'RUNNING' 
											 	  WHEN bef_statusid = 101 THEN 'REJECT' 
											 	  WHEN bef_statusid = 102 THEN 'VOID' 
											 	  WHEN bef_statusid = 103 THEN 'REFUND' 
											 	  WHEN bef_statusid = 111 THEN 'DRAW' 
											 	  WHEN bef_statusid = 112 THEN 'WON' 
											 	  WHEN bef_statusid = 113 THEN 'LOSE' 
											 	  ELSE 'None'
											 END
						,'"winlost="',IIF(bef_winlost IS NOT NULL, CONVERT(VARCHAR(50),bef_winlost,2),'0')
						,'" /></root>') AS ExtraInfo_Before
			   ,CONCAT('<root><r status="',  CASE WHEN statusid = 1	 THEN 'WAITING' 
											 	  WHEN statusid = 0	 THEN 'RUNNING' 
											 	  WHEN statusid = 101 THEN 'REJECT' 
											 	  WHEN statusid = 102 THEN 'VOID' 
											 	  WHEN statusid = 103 THEN 'REFUND' 
											 	  WHEN statusid = 111 THEN 'DRAW' 
											 	  WHEN statusid = 112 THEN 'WON' 
											 	  WHEN statusid = 113 THEN 'LOSE' 
											 	  ELSE 'None'
											 END
						,'"winlost="',IIF(bef_winlost IS NOT NULL, CONVERT(VARCHAR(50),winlost,2),'0')
						,'" /></root>') AS ExtraInfo_After
		FROM @tmpTransIDBatch AS t
			INNER JOIN SettlementSpecialBettypeProfile AS s WITH(NOLOCK) ON s.bettype = t.bettype AND  (s.BetID = 0 OR t.BetID = s.BetID)AND s.SportType = @sportType
			INNER JOIN #Resource AS r ON  s.ResourceID = r.ResourceID 
		WHERE t.TicketType = 's'
			AND NOT EXISTS (SELECT TOP 1 1 
						    FROM SettlementResultHistory_TicketDetails AS h WITH(NOLOCK)  
						    WHERE h.transId = t.transId
								AND h.SessionId = @SessionId)

		INSERT INTO SettlementResultHistory_TicketDetails(SessionID,Transid,SeqNo,ExtraInfo_Before,ExtraInfo_After)
		SELECT  @SessionId
			   ,tp.transid
			   ,tbl.SeqNo
			   ,CONCAT('<root><r status="',	 CASE WHEN tp.bef_statusid = 1	 THEN 'WAITING' 
											 	  WHEN tp.bef_statusid = 0	 THEN 'RUNNING' 
											 	  WHEN tp.bef_statusid = 101 THEN 'REJECT' 
											 	  WHEN tp.bef_statusid = 102 THEN 'VOID' 
											 	  WHEN tp.bef_statusid = 103 THEN 'REFUND' 
											 	  WHEN tp.bef_statusid = 111 THEN 'DRAW' 
											 	  WHEN tp.bef_statusid = 112 THEN 'WON' 
											 	  WHEN tp.bef_statusid = 113 THEN 'LOSE' 
											 	  ELSE 'None'
											 END
						,'"winlost="',IIF(tp.bef_winlost IS NOT NULL, CONVERT(VARCHAR(50),tp.bef_winlost,2),'0')
						,'" /></root>') AS ExtraInfo_Before
			   ,CONCAT('<root><r status="',  CASE WHEN tp.statusid = 1	 THEN 'WAITING' 
											 	  WHEN tp.statusid = 0	 THEN 'RUNNING' 
											 	  WHEN tp.statusid = 101 THEN 'REJECT' 
											 	  WHEN tp.statusid = 102 THEN 'VOID' 
											 	  WHEN tp.statusid = 103 THEN 'REFUND' 
											 	  WHEN tp.statusid = 111 THEN 'DRAW' 
											 	  WHEN tp.statusid = 112 THEN 'WON' 
											 	  WHEN tp.statusid = 113 THEN 'LOSE' 
											 	  ELSE 'None'
											 END
						,'"winlost="',IIF(tp.bef_winlost IS NOT NULL, CONVERT(VARCHAR(50),tp.winlost,2),'0')
						,'" /></root>') AS ExtraInfo_After
		FROM @tmpTransIDBatch AS t
			CROSS APPLY(SELECT TOP 1 r.SeqNo
			            FROM SettlementSpecialBettypeProfile AS s WITH(NOLOCK) 
							INNER JOIN #Resource AS r ON  s.ResourceID = r.ResourceID 
						WHERE s.bettype = t.bettype
							AND s.SportType = @sportType
			) AS tbl
			INNER JOIN #tblTransParlay AS tp ON tp.refno = t.refno 
		WHERE t.TicketType = 'p'
			AND NOT EXISTS (SELECT TOP 1 1 
						    FROM SettlementResultHistory_TicketDetails AS h WITH(NOLOCK) 
						    WHERE h.transId = tp.transid
								AND h.SessionId = @SessionId)
	END

	/* #5: Update success status*/
	UPDATE SettlementResultHistory
	SET  StatusID = 2
		,ModifiedDate = GETDATE()
	WHERE matchid =	@matchid
		AND SessionId = @SessionID
END