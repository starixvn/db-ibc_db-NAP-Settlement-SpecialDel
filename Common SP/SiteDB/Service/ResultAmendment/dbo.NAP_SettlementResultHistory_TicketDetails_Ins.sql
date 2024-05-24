/*<info serverAlias="DBSIG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_SettlementResultHistory_TicketDetails_Ins]
	 @MatchId					INT		
	,@sportType					INT	
	,@SessionId				    VARCHAR(50)		
	,@ErrorSessionIds			VARCHAR(MAX)	= NULL	
AS
/*	
	Created by: 20231214@Aries
	Task: Settlement  
	DB: DBSIG-bodb02
	
	Revisions:
		- 20231214@Aries: Result Amendment [Redmine: #196401]
*/
BEGIN	
	SET NOCOUNT ON
	CREATE TABLE #Resource(ResourceID VARCHAR(20), SeqNo INT,PRIMARY KEY(ResourceID))
	CREATE TABLE #tblTrans (transId BIGINT  PRIMARY KEY WITH (IGNORE_DUP_KEY = ON),TicketType VARCHAR(1),bettype SMALLINT,betid BIGINT,refno BIGINT,winlost MONEY,bef_winlost MONEY,statusid TINYINT,bef_statusid TINYINT)
	CREATE NONCLUSTERED INDEX IDX_refno ON #tblTrans (refno)

	DECLARE @tmpTransIDBatch TABLE (TransID BIGINT,TicketType VARCHAR(1),bettype SMALLINT,betid BIGINT,refno BIGINT,winlost MONEY,bef_winlost MONEY,statusid TINYINT,bef_statusid TINYINT)
	DECLARE  @batchNo			INT 			= 2000
			,@batchCount		INT 			= 0

	INSERT INTO #tblTrans(TransId,TicketType,bettype,betid,refno,winlost,bef_winlost,statusid,bef_statusid)
	SELECT t.t AS TransId
		  ,IIF(l.matchid = 29,'m',l.TicketType)
		  ,t.bt AS bettype
		  ,t.bi AS betid
		  ,t.rf AS refno
		  ,t.w AS winlost
		  ,t.bef_w AS bef_winlost
		  ,t.[sid] AS statusid
		  ,t.bef_sid AS bef_statusid
	FROM SiteDB_SettlementService_CalculationLog AS l WITH(NOLOCK)
	    CROSS APPLY OPENJSON(CAST(DECOMPRESS(l.TransInfoJson) AS NVARCHAR(MAX))) WITH (t  BIGINT,w MONEY,bef_w MONEY,[sid] TINYINT,bef_sid TINYINT,bt SMALLINT,bi BIGINT,rf BIGINT) AS t
	WHERE l.BroadcastSessionId  = @SessionId
		AND (t.bef_w != t.w OR (l.TicketType = 'p' AND l.matchid != 29))
		AND t.bef_sid != 0

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
		FROM #tblTrans AS t 
		WHERE t.TicketType != 'm'

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
						,'" Id="',ISNULL(s.ResourceID,'')
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
						,'" Id="',ISNULL(s.ResourceID,'')
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
						,'" winlost="',IIF(tp.bef_winlost IS NOT NULL, CONVERT(VARCHAR(50),tp.bef_winlost,2),'0')
						,'" Id="',ISNULL(tbl.ResourceID,'')
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
						,'" winlost="',IIF(tp.bef_winlost IS NOT NULL, CONVERT(VARCHAR(50),tp.winlost,2),'0')
						,'" Id="',ISNULL(tbl.ResourceID,'')
						,'" /></root>') AS ExtraInfo_After
		FROM @tmpTransIDBatch AS t
			CROSS APPLY(SELECT TOP 1 r.SeqNo, r.ResourceID 
			            FROM SettlementSpecialBettypeProfile AS s WITH(NOLOCK) 
							INNER JOIN #Resource AS r ON  s.ResourceID = r.ResourceID 
						WHERE s.bettype = t.bettype
							AND s.SportType = @sportType
			) AS tbl
			INNER JOIN #tblTrans AS tp ON tp.refno = t.refno AND tp.TicketType = 'm'
		WHERE t.TicketType = 'p'
			AND NOT EXISTS (SELECT TOP 1 1 
						    FROM SettlementResultHistory_TicketDetails AS h WITH(NOLOCK) 
						    WHERE h.transId = tp.transid
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