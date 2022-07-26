/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_LogInfo_KO_Select]
(	
	@MatchId              INT = 0
	,@RequestId			  INT = 0
	,@ActionId			  INT = 5
	,@IsShowLogOnly		  BIT = 0
	,@KickOffTime		  DATETIME = NULL
	,@TransInfo		  VARCHAR(MAX) = NULL
)
AS
/*	
	Created by: July
	Date 20220720
	Task: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20220720@July: Create new SP - Refactor code issue type EKO & WKO [Redmine: #175412]

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE  @IsExistedInOtherRequest BIT = 0
			,@IsExistSingle			  BIT = 0
			,@IsExistParlay			  BIT = 0
			,@IsExistFM				  BIT = 0
			,@IsExistFM2			  BIT = 0
			,@MatchProcessXML		  XML = NULL
			,@MatchParlayProcessXML	  XML = NULL
			,@TotalRefnoParlay		  INT = 0
			,@ThreadHold			  INT = 0
			,@TransInfoXML         XML = NULL

	CREATE TABLE #TVSTicketBets (
			transid               BIGINT,
			SubTransid            BIGINT,
			refno                 BIGINT,
			custid                INT,
			transdate             DATETIME,
			bettype               SMALLINT,
			livehomescore         SMALLINT,
			liveawayscore         SMALLINT,
			IsMixParlay           BIT DEFAULT(0),
			matchid               INT,
			WalletType            TINYINT,
			RefCode               BIGINT,
			MainTransId           BIGINT,
			LiveIndicator		  BIT  DEFAULT(0),
			StatusId			  TINYINT
	)

	CREATE TABLE #tmpRefCodeSummary (
			RefCode		BIGINT,
			custid		INT,
			bettype		SMALLINT,
			transid		BIGINT,
			MatchId		INT
	)

	CREATE INDEX IX_TVSTicketBets_RefCode ON #TVSTicketBets(RefCode)
	CREATE INDEX IX_tmpRefCodeSummary_Refcode ON #tmpRefCodeSummary(RefCode)

	CREATE TABLE #TransidInRequest (TransId BIGINT, RequestId INT, MainTransId BIGINT, MatchId INT)

	CREATE TABLE #tmpTransInfo(
	   matchid INT
	  ,transid BIGINT PRIMARY KEY
      ,Subtransid BIGINT
	  ,custid INT	
      ,transdate DATETIME
      ,hdp1 SMALLMONEY
      ,hdp2 SMALLMONEY
      ,livehomescore SMALLINT
      ,liveawayscore SMALLINT
      ,liveindicator BIT
      ,betteam NVARCHAR(10)
      ,creator INT
      ,refno BIGINT
      ,bettype SMALLINT
      ,betfrom NVARCHAR(1)
      ,statusID TINYINT
      ,WalletType TINYINT
	  ,RefCode BIGINT
	  ,Subcustid INT	
	  ,Sublivehomescore SMALLINT
      ,Subliveawayscore SMALLINT
	  ,Subhdp1 SMALLMONEY
      ,Subhdp2 SMALLMONEY
	  ,Subbetfrom NVARCHAR(1)
	  ,Subbettype SMALLINT
	  ,SubstatusID TINYINT
	  ,Subtransdate DATETIME
	  ,Subliveindicator BIT
      ,IsMixParlay BIT
	)

	DECLARE @tblMatchParlay AS TABLE (MatchId INT, RefNo BIGINT)

	SET @TransInfoXML = CONVERT(XML, @TransInfo)
	INSERT INTO #tmpTransInfo( 
		   matchid
		  ,transid 
		  ,Subtransid
		  ,refno
		  ,custid		
		  ,transdate 
		  ,hdp1 
		  ,hdp2 
		  ,livehomescore 
		  ,liveawayscore 
		  ,liveindicator 
		  ,bettype
		  ,betfrom
		  ,statusID
		  ,WalletType 
		  ,RefCode 
		  ,Subcustid
		  ,Sublivehomescore 
		  ,Subliveawayscore 
		  ,Subbetfrom
		  ,Subbettype
		  ,Subtransdate
		  ,Subhdp1
		  ,Subhdp2
		  ,Subliveindicator
		  ,IsMixParlay
		)
	SELECT t.c.value('@matchid','INT') AS matchid
			,t.c.value('@transid','BIGINT') AS transid
			,t.c.value('@Subtransid','BIGINT') AS Subtransid
			,t.c.value('@refno','BIGINT') AS refno
			,t.c.value('@custid','INT') AS custid
			,t.c.value('@transdate','DATETIME') AS transdate
			,t.c.value('@hdp1','SMALLMONEY') AS hdp1
			,t.c.value('@hdp2','SMALLMONEY') AS hdp2
			,t.c.value('@livehomescore','SMALLINT') AS livehomescore
			,t.c.value('@liveawayscore','SMALLINT') AS liveawayscore
			,t.c.value('@liveindicator','BIT') AS liveindicator
			,t.c.value('@bettype','SMALLINT') AS bettype
			,t.c.value('@betfrom','NVARCHAR(1)') AS betfrom
			,t.c.value('@statusID','TINYINT') AS statusID
			,t.c.value('@WalletType','TINYINT') AS WalletType
			,t.c.value('@RefCode','BIGINT') AS RefCode
			,t.c.value('@Subcustid','INT') AS Subcustid
			,t.c.value('@Sublivehomescore','SMALLINT') AS Sublivehomescore
			,t.c.value('@Subliveawayscore','SMALLINT') AS Subliveawayscore
			,t.c.value('@Subbetfrom','NVARCHAR(1)') AS Subbetfrom
			,t.c.value('@Subbettype','SMALLINT') AS Subbettype
			,t.c.value('@Subtransdate','SMALLINT') AS Subtransdate
			,t.c.value('@Subhdp1','SMALLMONEY') AS Subhdp1
			,t.c.value('@Subhdp2','SMALLMONEY') AS Subhdp2
			,t.c.value('@Subliveindicator','BIT') AS Subliveindicator
			,t.c.value('@IsMixParlay','BIT') AS IsMixParlay
	FROM @TransInfoXML.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@TransInfoXML = NULL))

	INSERT INTO #TVSTicketBets(
			transid		
			,SubTransid		
			,refno			
			,custid					
			,transdate		
			,bettype 				
			,livehomescore 	
			,liveawayscore 		
			,WalletType
			,RefCode
			,LiveIndicator
			,matchid
			,StatusId
		)
	SELECT   b.transid
			,b.Subtransid
			,b.refno
			,b.custid
			,b.transdate
			,b.bettype
			,b.livehomescore
			,b.liveawayscore
			,b.WalletType
			,b.RefCode
			,b.liveindicator
			,@MatchId
			,b.statusID
	FROM #tmpTransInfo b
	WHERE	b.matchid = @MatchId AND b.IsMixParlay = 0
			AND b.transdate >= @KickOffTime
			AND 1= CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1
						WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
						ELSE 0 END
			AND b.liveindicator = 0
			AND b.betfrom <> 'P'	
						
	---get sub ticket of a mix parlay	
	IF EXISTS (
			SELECT TOP 1 1
			FROM #tmpTransInfo bm 
			WHERE bm.matchid = @matchid
				AND bm.Subtransdate >= @KickOffTime
				AND 1= CASE WHEN @ActionId <>2 AND bm.SubstatusID NOT IN (101, 102, 103) THEN 1
							WHEN @ActionId = 2 AND bm.SubstatusID NOT IN (101, 103) THEN 1
							ELSE 0 END
				AND bm.Subliveindicator = 0
				AND bm.Subbetfrom <> 'P'
			)
	BEGIN		
		INSERT INTO #TVSTicketBets(
				transid		
				,SubTransid		
				,refno			
				,custid							
				,transdate		
				,bettype					
				,livehomescore	
				,liveawayscore		
				,IsMixParlay
				,LiveIndicator
				,matchid
				,StatusId
			)
		SELECT   b.transid
				,b.Subtransid
				,b.refno
				,b.Subcustid				
				,b.Subtransdate
				,b.bettype
				,b.Sublivehomescore
				,b.Subliveawayscore
				,b.liveawayscore
				,b.IsMixParlay
				,b.Subliveindicator
				,@MatchId
				,b.statusID
		FROM #tmpTransInfo b	
		WHERE	b.matchid = @matchid AND b.IsMixParlay = 1 
		        AND b.Subtransdate >= @KickOffTime
				AND 1= CASE WHEN @ActionId <>2 AND b.SubstatusID NOT IN (101, 102, 103) THEN 1
							WHEN @ActionId = 2 AND b.SubstatusID NOT IN (101, 103) THEN 1
							ELSE 0 END
				AND b.liveindicator = 0 AND b.Subliveindicator = 0
				AND b.Subbetfrom <> 'P'
				AND b.transdate >= @KickOffTime
				AND b.statusID NOT IN (101, 102, 103)
	END 

	-- update MainTransId
	IF EXISTS (SELECT TOP 1 1 FROM #TVSTicketBets WHERE RefCode IS NOT NULL)
	BEGIN
		UPDATE sub
		SET MainTransId = main.transid
		FROM #TVSTicketBets main
				INNER JOIN #TVSTicketBets sub
						ON main.RefCode = sub.RefCode
						AND main.transid <> sub.transid	
						AND main.custid = sub.custid
						AND main.bettype = sub.bettype
		WHERE main.WalletType = 1					
		  
		INSERT INTO #tmpRefCodeSummary(RefCode, custid, bettype, transid, MatchId)
		SELECT RefCode, custid, bettype
				, MAX(transid) AS transid
				, matchid
		FROM #TVSTicketBets
		WHERE	RefCode IS NOT NULL
		GROUP BY RefCode, custid, bettype, matchid
		HAVING COUNT(*) = 1

		IF @@ROWCOUNT > 0
		BEGIN	
			INSERT INTO #TVSTicketBets(
						transid		
						,SubTransid		
						,refno			
						,custid					
						,transdate		
						,bettype 					
						,livehomescore 	
						,liveawayscore 			
						,WalletType
						,RefCode
						,MainTransId
						,LiveIndicator
						,matchid
						,StatusId
					)
				SELECT   b.transid
						,b.SubTransID
						,b.refno
						,b.custid
						,b.transdate
						,b.bettype
						,b.livehomescore
						,b.liveawayscore
						,b.WalletType
						,b.RefCode
						,t.transid AS MainTransId
						,b.liveindicator
						,b.matchid
						,b.statusID
			FROM #tmpRefCodeSummary t
					INNER JOIN #tmpTransInfo b
							ON b.RefCode = t.RefCode
							AND b.transid <> t.transid
							AND b.matchid = t.MatchId
							AND b.custid = t.custid
							AND b.bettype = t.bettype 
			WHERE 1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
							WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
							ELSE 0 END
		END  			    				    					    				    					    	
	END
	
	/*Get Transid in Request of range Transid*/
	IF @ActionId NOT IN (2)
	BEGIN
		INSERT INTO #TransidInRequest (TransId, RequestId, MainTransId, MatchId)
		SELECT tmp.transid, r.RequestId, tmp.MainTransId, @MatchId
		FROM dbo.TicketVoiding_Request r WITH (NOLOCK)
			CROSS APPLY (
						SELECT rs.TransId, rs.TransId AS MainTransId
						FROM dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK)
						WHERE rs.RequestId = r.RequestId AND rs.MatchId = @MatchId
						UNION ALL
						SELECT rp.TransId, rp.MainTransId
						FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rp WITH (NOLOCK)
						WHERE rp.RequestId = r.RequestId AND rp.MatchId = @MatchId
				)tmp
			INNER JOIN #TVSTicketBets t ON tmp.TransId = t.transid
		WHERE r.RequestId <> @RequestId AND r.ActionId NOT IN (2)

		IF @@ROWCOUNT <> 0
		BEGIN
			SELECT @IsExistedInOtherRequest = 1
		END
	END

	IF @IsShowLogOnly = 1 AND @RequestId <> 0
	BEGIN
		SELECT  @IsExistedInOtherRequest AS IsExistedInOtherRequest
				,@IsExistSingle AS IsExistSingle
				,@IsExistParlay AS IsExistParlay
				,@IsExistFM AS IsExistFM
				,@IsExistFM2 AS IsExistFM2
				,@MatchProcessXML AS MatchProcessXML
				,@MatchParlayProcessXML AS MatchParlayProcessXML

		--TransId in request table
		IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
		BEGIN
			SELECT RequestId, MatchId,
				STUFF((
				SELECT ', ' + CAST(MainTransId AS VARCHAR(MAX)) 
				FROM #TransidInRequest
				WHERE (RequestId = r.RequestId AND MatchId = r.MatchId)
				ORDER BY TransId
				FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
				,1,2,'') AS TransIds
			FROM #TransidInRequest r
			GROUP BY r.RequestId, r.MatchId
		END
		ELSE
		BEGIN
			SELECT RequestId, MatchId, CAST(TransId AS VARCHAR(MAX)) AS TransIds 
			FROM #TransidInRequest
		END

		RETURN;
	END
	
	---Prepare for lock match---
	SELECT @IsExistSingle = MAX(CASE WHEN t.Bettype NOT IN (9, 29, 10, 801, 803, 804, 805, 806) AND f.GroupId IS NULL THEN 1 ELSE 0 END)
			,@IsExistParlay = MAX (CASE WHEN t.IsMixParlay = 1 THEN 1 ELSE 0 END)
			,@IsExistFM = MAX(CASE WHEN f.GroupId = 1 THEN 1 ELSE 0 END)
			,@IsExistFM2 = MAX(CASE WHEN f.GroupId = 2 THEN 1 ELSE 0 END)
	FROM #TVSTicketBets AS t
		OUTER APPLY (
				SELECT GroupId
				FROM dbo.f_TVS_CheckingProcessGroupBettypes()
				WHERE Bettype = t.Bettype
		)f
	WHERE NOT EXISTS (SELECT 1 FROM #TransidInRequest r WHERE r.TransId = t.SubTransid)

	SET @MatchProcessXML = (
		SELECT DISTINCT t.matchid "@MatchId"
			,CASE 
				WHEN f.GroupId IS NULL THEN 1 --SB
				WHEN f.GroupId = 1 THEN 6 -- Fast Market
				WHEN f.GroupId = 2 THEN 7 -- Fast market 228
				ELSE 0
				END AS "@KeyID"
		FROM #TVSTicketBets t
			OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = t.Bettype
			)f
		WHERE NOT EXISTS (SELECT 1 FROM #TransidInRequest r WHERE r.TransId = t.SubTransid)
		FOR XML PATH('r'), ROOT('root'))
	
	--Lock Refno process - SportBook
	EXEC dbo.NAP_Set_GlobalSettingSel 
		@LockName = 'ParlayRefno'
		,@ThreadHold = @ThreadHold OUTPUT

	INSERT INTO @tblMatchParlay (MatchId, RefNo)
	SELECT '' AS MatchId, t.Refno --Many matches with same Refno  
	FROM #TVSTicketBets t
	WHERE NOT EXISTS (SELECT 1 FROM #TransidInRequest r WHERE r.TransId = t.SubTransid)
			AND t.IsMixParlay = 1
	GROUP BY t.Refno  
	HAVING COUNT(*) > 1

	SET @TotalRefnoParlay = @@ROWCOUNT
	
	INSERT INTO @tblMatchParlay (MatchId, RefNo)
	SELECT  t.MatchId, t.RefNo
	FROM #TVSTicketBets t
	WHERE NOT EXISTS (SELECT 1 FROM #TransidInRequest r WHERE r.TransId = t.SubTransid)
	  AND NOT EXISTS (SELECT 1 FROM @tblMatchParlay m WHERE m.RefNo = t.refno) 
			AND t.IsMixParlay = 1
	
	SELECT @TotalRefnoParlay = @TotalRefnoParlay + @@ROWCOUNT

	IF @TotalRefnoParlay <= @ThreadHold
	BEGIN
		SET @MatchParlayProcessXML = (
		SELECT  DISTINCT MatchId "@MatchId"
				,refno AS "@RefNo"
		FROM @tblMatchParlay 
		FOR XML PATH('r'), ROOT('root'))
	END	
	ELSE
	BEGIN
		SET @MatchParlayProcessXML = NULL
	END

	--Error Table
	SELECT @IsExistedInOtherRequest AS IsExistedInOtherRequest
		  ,@IsExistSingle AS IsExistSingle
		  ,@IsExistParlay AS IsExistParlay
		  ,@IsExistFM AS IsExistFM
		  ,@IsExistFM2 AS IsExistFM2
		  ,@MatchProcessXML AS MatchProcessXML
		  ,@MatchParlayProcessXML AS MatchParlayProcessXML

	--TransId in request table
	IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
	BEGIN
		SELECT RequestId, MatchId,
			STUFF((
			SELECT ', ' + CAST(MainTransId AS VARCHAR(MAX)) 
			FROM #TransidInRequest
			WHERE (RequestId = r.RequestId AND MatchId = r.MatchId)
			ORDER BY TransId
			FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
			,1,2,'') AS TransIds
			
		FROM #TransidInRequest r
		GROUP BY r.RequestId, r.MatchId
	END
	ELSE
	BEGIN
		SELECT RequestId, MatchId, CAST(TransId AS VARCHAR(MAX)) AS TransIds 
		FROM #TransidInRequest
	END

	DROP TABLE #TVSTicketBets
	DROP TABLE #TransidInRequest
	DROP TABLE #tmpRefCodeSummary
	DROP TABLE #tmpTransInfo

END
GO

