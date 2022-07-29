/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_LogInfo_KO_Select]
(	
	 @RequestId			  INT = 0
	,@ActionId			  INT = 5
	,@IsShowLogOnly		  BIT = 0
	,@KickOffInfo		  VARCHAR(MAX) = NULL
	,@TransInfo		      VARCHAR(MAX) = NULL
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
			,@TransInfoXML         XML = NULL
			,@KickOffInfoXML	   XML = NULL	
			,@MatchId			   INT
			,@KickOffTime		   DATETIME = NULL

	SET @KickOffInfoXML = CONVERT(XML, @KickOffInfo)
	SELECT @MatchId = t.c.value('@MatchId','INT') 
		  ,@KickOffTime = t.c.value('@KickOffTime','DATETIME')
	FROM @KickOffInfoXML.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@KickOffInfoXML = NULL))

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
			LiveIndicator		  BIT DEFAULT(0),
			StatusId			  TINYINT,
			SiteDBGroupID		  SMALLINT,
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
	  ,betid BIGINT
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
	  ,SiteDBGroupID SMALLINT
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
		  ,betid
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
		  ,SiteDBGroupID
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
			,t.c.value('@betid','BIGINT') AS betid
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
			,t.c.value('@SiteDBGroupID','SMALLINT') AS SiteDBGroupID
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
			,SiteDBGroupID
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
			,b.SiteDBGroupID
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
				,SiteDBGroupID
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
				,SiteDBGroupID
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
	
	--Error Table
	SELECT @IsExistedInOtherRequest AS IsExistedInOtherRequest

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


	SET @TransInfoXML = (
	SELECT DISTINCT 
			t.matchid AS "@matchid"
		    ,t.transid AS "@transid"
			,t.Subtransid AS "@Subtransid"
			,t.custid AS "@custid"
			,t.refno AS "@refno"
			,b.bettype AS "@bettype"
			,b.betid AS "@betid"
			,b.IsMixParlay AS "@IsMixParlay"
			,b.SiteDBGroupID AS "@SiteDBGroupID"
		FROM #TVSTicketBets t
			INNER JOIN #tmpTransInfo b ON t.matchid = b.matchid AND t.transid = b.transid
		WHERE NOT EXISTS (SELECT 1 FROM #TransidInRequest r WHERE r.TransId = t.SubTransid)
		FOR XML PATH('r'), ROOT('root')
		)

	SELECT @TransInfoXML AS TransInfo

	DROP TABLE #TVSTicketBets
	DROP TABLE #TransidInRequest
	DROP TABLE #tmpRefCodeSummary
	DROP TABLE #tmpTransInfo

END
GO

