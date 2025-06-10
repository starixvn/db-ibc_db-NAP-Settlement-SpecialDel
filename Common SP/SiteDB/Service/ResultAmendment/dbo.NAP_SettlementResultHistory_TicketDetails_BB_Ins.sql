/*<info serverAlias="DBSIG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_SettlementResultHistory_TicketDetails_BB_Ins]
	 @MatchId					INT	
	,@sportType					INT
	,@SessionId				    VARCHAR(50)		
	,@ErrorSessionIds			VARCHAR(MAX)	= NULL
AS
/*	
	Created by: 20250418@Hughie
	Task: Settlement  
	DB: DBSIG-bodb02
	
	Revisions:
		- 20250418@Hughie: Settle - Integrate - Result Amendment -Betbuilder [Redmine:#224372]
*/
BEGIN	
	SET NOCOUNT ON
	
	CREATE TABLE #tblTrans (transId BIGINT  PRIMARY KEY WITH (IGNORE_DUP_KEY = ON),bettype SMALLINT,winlost MONEY,bef_winlost MONEY,statusid TINYINT,bef_statusid TINYINT, betcheck NVARCHAR(50))

	DECLARE @Resource TABLE(MarketId VARCHAR(50), SeqNo INT,SelectionType INT, PRIMARY KEY(SelectionType,MarketId))
	DECLARE @tmpTransIDBatch TABLE (TransID BIGINT,bettype SMALLINT,winlost MONEY,bef_winlost MONEY,statusid TINYINT,bef_statusid TINYINT,betcheck NVARCHAR(50))

	DECLARE  @batchNo			INT 			= 2000
			,@batchCount		INT 			= 0

	INSERT INTO #tblTrans(TransId,bettype,winlost,bef_winlost,statusid,bef_statusid,betcheck)
	SELECT t.t AS TransId
		  ,t.bt AS bettype
		  ,t.w AS winlost
		  ,t.bef_w AS bef_winlost
		  ,t.[sid] AS statusid
		  ,t.bef_sid AS bef_statusid
		  ,t.bc AS betcheck
	FROM SiteDB_SettlementService_CalculationLog_3rd AS l WITH(NOLOCK)
	    CROSS APPLY OPENJSON(CAST(DECOMPRESS(l.TransInfoJson) AS NVARCHAR(MAX))) WITH (t  BIGINT,w MONEY,bef_w MONEY,[sid] TINYINT,bef_sid TINYINT,bt SMALLINT,bc NVARCHAR(50)) AS t
	WHERE l.BroadcastSessionId  = @SessionId
		AND t.bef_w != t.w
		AND t.bef_sid != 0
		AND t.sid != 0

	;WITH CTE_MarketId AS (
		SELECT  CAST(h.[ActualResult] AS XML)  AS ActualResult
			   ,SeqNo
		FROM SettlementResultHistory AS h WITH(NOLOCK) 
		WHERE matchid =	@matchid
			AND SessionId = @SessionID
	)
	INSERT INTO @Resource(MarketId,SeqNo,SelectionType)
	SELECT	rNode.value('(@MarketId)[1]', 'VARCHAR(50)') AS MarketId,
			SeqNo,
			rNode.value('(@Id)[1]', 'INT') AS SelectionType
	FROM CTE_MarketId
		CROSS APPLY ActualResult.nodes('/root/r') AS x(rNode)

	/* #4: Insert ticket*/
	WHILE 1=1
	BEGIN
		DELETE @tmpTransIDBatch
		
		DELETE TOP(@batchNo) t
		OUTPUT deleted.transid,deleted.bettype,deleted.winlost,deleted.bef_winlost,deleted.statusid,deleted.bef_statusid,deleted.betcheck
		INTO @tmpTransIDBatch(TransID,bettype,winlost,bef_winlost,statusid,bef_statusid,betcheck)
		FROM #tblTrans AS t 

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
						,'" winlost="',IIF(bef_winlost IS NOT NULL, CONVERT(VARCHAR(50),bef_winlost,2),'0')
						,'" MarketId="',ISNULL(r.MarketId,'')
						,'" Id="',ISNULL(r1.SelectionType,r.SelectionType)  
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
						,'" winlost="',IIF(bef_winlost IS NOT NULL, CONVERT(VARCHAR(50),winlost,2),'0')
						,'" MarketId="',ISNULL(r.MarketId,'')
						,'" Id="',ISNULL(r1.SelectionType,r.SelectionType)
						,'" /></root>') AS ExtraInfo_After
		FROM @tmpTransIDBatch AS t
			OUTER APPLY (
                SELECT TOP 1 mre.SeqNo, mre.MarketId, CONVERT(VARCHAR(50),mre.SelectionType,2) AS SelectionType
                FROM  @Resource AS mre
                WHERE mre.MarketId = t.betcheck
			) AS r	
			OUTER APPLY(
				SELECT mre.MarketId
                	  ,STRING_AGG(CONVERT(VARCHAR(50),mre.SelectionType,2),',') AS SelectionType
                	  ,MAX(mre.SeqNo) AS SeqNo
                FROM  @Resource AS mre
                WHERE mre.MarketId = t.betcheck
                GROUP BY mre.MarketId
			) AS r1
		WHERE NOT EXISTS (SELECT TOP 1 1 
						    FROM SettlementResultHistory_TicketDetails AS h WITH(NOLOCK)  
						    WHERE h.transId = t.transId
								AND h.SessionId = @SessionId)
	END

	IF @ErrorSessionIds IS NULL OR  @ErrorSessionIds = ''
	BEGIN
		RETURN
	END

	CREATE TABLE #tblTicketDetail(transId BIGINT  PRIMARY KEY WITH (IGNORE_DUP_KEY = ON),SeqNo SMALLINT, ExtraInfo_Before VARCHAR(MAX), ExtraInfo_After VARCHAR(MAX))

	DECLARE @tmlSession99 TABLE(SessionID VARCHAR(50))
	DECLARE @tmpTicketDetailBatch TABLE (TransID BIGINT,SeqNo SMALLINT, ExtraInfo_Before VARCHAR(MAX), ExtraInfo_After VARCHAR(MAX))

	INSERT INTO @tmlSession99(SessionID)
	SELECT f.value
	FROM STRING_SPLIT(@ErrorSessionIds, ',') f

	INSERT INTO #tblTicketDetail(transId,SeqNo,ExtraInfo_Before,ExtraInfo_After)
	SELECT t.transId,t.SeqNo,t.ExtraInfo_Before,t.ExtraInfo_After
	FROM SettlementResultHistory_TicketDetails AS t WITH(NOLOCK) 
		INNER JOIN @tmlSession99 AS s ON t.SessionID = s.SessionID

	WHILE 1=1
	BEGIN
		DELETE @tmpTicketDetailBatch

		DELETE TOP(@batchNo) t
		OUTPUT deleted.transid,deleted.SeqNo,deleted.ExtraInfo_Before,deleted.ExtraInfo_After
		INTO @tmpTicketDetailBatch(TransID,SeqNo,ExtraInfo_Before,ExtraInfo_After)
		FROM #tblTicketDetail AS t 

		SELECT @batchCount 	= @@ROWCOUNT
		IF @batchCount = 0 BREAK

		INSERT INTO SettlementResultHistory_TicketDetails(SessionID,Transid,SeqNo,ExtraInfo_Before,ExtraInfo_After)
		SELECT @SessionID,t.transId,t.SeqNo,t.ExtraInfo_Before,t.ExtraInfo_After
		FROM @tmpTicketDetailBatch AS t
		WHERE NOT EXISTS (SELECT TOP 1 1 
						  FROM SettlementResultHistory_TicketDetails AS h WITH(NOLOCK) 
						  WHERE h.transId = t.transid
							AND h.SessionId = @SessionId)
	END
END


