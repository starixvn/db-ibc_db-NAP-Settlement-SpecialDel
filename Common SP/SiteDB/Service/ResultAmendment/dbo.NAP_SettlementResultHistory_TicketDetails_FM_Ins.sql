/*<info serverAlias="DBSIG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_SettlementResultHistory_TicketDetails_FM_Ins]
	 @MatchId					INT		
	,@sportType					INT	
	,@SessionId				    VARCHAR(50)		
	,@ErrorSessionIds			VARCHAR(MAX)	= NULL	
AS
/*	
	Created by: 20250415@Aries
	Task: Settlement  
	DB: DBSIG-bodb02
	
	Revisions:
		- 20250415@Aries: Settle - Integrate - Result Amendment - Fast Markets, Time Machine, ＆ Bet Builder [Redmine:#223456]
*/
BEGIN	
	SET NOCOUNT ON
	
	CREATE TABLE #tblTrans (transId BIGINT  PRIMARY KEY WITH (IGNORE_DUP_KEY = ON),bettype SMALLINT,hdp1 SMALLMONEY,winlost MONEY,bef_winlost MONEY,statusid TINYINT,bef_statusid TINYINT)

	DECLARE @Resource TABLE(ResourceID VARCHAR(20), SeqNo INT,Position INT, PRIMARY KEY(ResourceID,Position))
	DECLARE @tmpTransIDBatch TABLE (TransID BIGINT,bettype SMALLINT,hdp1 SMALLMONEY,winlost MONEY,bef_winlost MONEY,statusid TINYINT,bef_statusid TINYINT)
	
	DECLARE  @batchNo			INT 			= 2000
			,@batchCount		INT 			= 0

	INSERT INTO #tblTrans(TransId,bettype,hdp1,winlost,bef_winlost,statusid,bef_statusid)
	SELECT t.t AS TransId
		  ,t.bt AS bettype
		  ,t.hdp1
		  ,t.w AS winlost
		  ,t.bef_w AS bef_winlost
		  ,t.[sid] AS statusid
		  ,t.bef_sid AS bef_statusid
	FROM SiteDB_SettlementService_CalculationLog AS l WITH(NOLOCK)
	    CROSS APPLY OPENJSON(CAST(DECOMPRESS(l.TransInfoJson) AS NVARCHAR(MAX))) WITH (t  BIGINT,w MONEY,bef_w MONEY,[sid] TINYINT,bef_sid TINYINT,bt SMALLINT,hdp1 SMALLMONEY) AS t
	WHERE l.BroadcastSessionId  = @SessionId
		AND t.bef_w != t.w
		AND t.bef_sid != 0
		AND t.sid != 0


	;WITH CTE_ResourceID AS (
		SELECT  CAST(h.[ActualResult] AS XML)  AS ActualResult
			   ,SeqNo
		FROM SettlementResultHistory AS h WITH(NOLOCK) 
		WHERE matchid =	@matchid
			AND SessionId = @SessionID
	)
	INSERT INTO @Resource(ResourceID,SeqNo,Position)
	SELECT	rNode.value('(@Id)[1]', 'VARCHAR(50)') AS ResourceID,
			SeqNo,
			rNode.value('(@Pos)[1]', 'INT') AS Position
	FROM CTE_ResourceID
		CROSS APPLY ActualResult.nodes('/root/r') AS x(rNode)

	/* #4: Insert ticket*/
	WHILE 1=1
	BEGIN
		DELETE @tmpTransIDBatch
		
		DELETE TOP(@batchNo) t
		OUTPUT deleted.transid,deleted.bettype,deleted.hdp1,deleted.winlost,deleted.bef_winlost,deleted.statusid,deleted.bef_statusid
		INTO @tmpTransIDBatch(TransID,bettype,hdp1,winlost,bef_winlost,statusid,bef_statusid)
		FROM #tblTrans AS t 

		SELECT @batchCount 	= @@ROWCOUNT
		IF @batchCount = 0 BREAK
		
		INSERT INTO SettlementResultHistory_TicketDetails(SessionID,Transid,SeqNo,ExtraInfo_Before,ExtraInfo_After)
		SELECT  @SessionId
			   ,t.transId
			   ,ISNULL(r.SeqNo,r1.SeqNo) AS SeqNo
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
						,'" Id="',COALESCE(r.ResourceID,r1.ResourceID,'')
						,'" Pos="',ISNULL(r.Position,r1.Position)
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
						,'" Id="',COALESCE(r.ResourceID,r1.ResourceID,'')
						,'" Pos="',ISNULL(r.Position,r1.Position)
						,'" /></root>') AS ExtraInfo_After
		FROM @tmpTransIDBatch AS t
			OUTER APPLY (
                SELECT TOP 1 
					 mre.ResourceID
					,CONVERT(VARCHAR(50),mre.Position,2) AS Position
					,mre.SeqNo
                FROM  @Resource AS mre
                WHERE mre.ResourceID = t.bettype
					AND 1 = CASE WHEN mre.ResourceID IN ('228','229') AND mre.Position  < 45 AND mre.Position = t.hdp1 THEN 1
								 WHEN mre.ResourceID IN ('228','229') AND mre.Position  > 45 AND mre.Position - 1 = t.hdp1 THEN 1
								 WHEN mre.ResourceID  NOT IN ('228','229') AND  mre.Position  = t.hdp1 THEN 1
								 ELSE 0
							END
			) AS r	
			OUTER APPLY(
				SELECT mre.ResourceID
                	  ,STRING_AGG(CONVERT(VARCHAR(50),mre.Position,2),',') AS Position
                	  ,MAX(mre.SeqNo) AS SeqNo
                FROM  @Resource AS mre
                WHERE mre.ResourceID = t.bettype
                    AND mre.ResourceID = '228'
					AND mre.Position <= t.hdp1
                GROUP BY mre.ResourceID
			) AS r1	
		WHERE  NOT EXISTS (SELECT TOP 1 1 
						    FROM SettlementResultHistory_TicketDetails AS h WITH(NOLOCK)  
						    WHERE h.transId = t.transId
								AND h.SessionId = @SessionId)
			AND ISNULL(r.SeqNo,r1.SeqNo) IS NOT NULL

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