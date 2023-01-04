/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_LogInfo_KO_Select]
(	
	 @RequestId			  INT = 0
	,@ActionId			  INT = 5
	,@IsShowLogOnly		  BIT = 0
	,@KickOffInfo		  VARCHAR(MAX) = NULL
	,@TransInfoJson			VARCHAR(MAX) = NULL
)
AS
/*	
	Created by: 20220808@July
	Task: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20220808@July: Create new SP - Refactor code issue type EKO & WKO [Redmine: #175412]
		- 20221124@July: [TVS] Increase data size when sending data between web and DB [Redmine: #180863]
		- 20230103@Max: Change JSON input [Redmine: #180625]

	Param's explanation:
	+ @KickOffInfo: 
			<root><r MatchId="0" KickOffTime=""/></root>
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE  @IsExistedInOtherRequest BIT = 0
			,@KickOffInfoXML		  XML = NULL	
			,@MatchId			      INT
			,@KickOffTime		      DATETIME = NULL
			,@MarkTransIds		      VARCHAR(MAX) =''
			,@UnmarkTransIds		  VARCHAR(MAX) =''
			,@OldActionId			  TINYINT

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
			LiveIndicator		  BIT DEFAULT(0),
			StatusId			  TINYINT,
			SubStatusId			  TINYINT,
			SiteDBGroupID		  SMALLINT,
	)

	CREATE TABLE #TransidInRequest (TransId BIGINT, RequestId INT, MainTransId BIGINT, MatchId INT)
	CREATE TABLE #tmpTransInfo(
	   matchid INT
	  ,transid BIGINT
	  ,Subtransid BIGINT
	  ,refno BIGINT
	  ,custid INT	
      ,hdp1 SMALLMONEY
      ,hdp2 SMALLMONEY
      ,livehomescore SMALLINT
      ,liveawayscore SMALLINT
      ,liveindicator BIT
	  ,odds SMALLMONEY
	  ,oddsspread MONEY
      ,betfrom NVARCHAR(3)
      ,bettype SMALLINT
      ,betteam NVARCHAR(10)
	  ,betcheck NVARCHAR(50)
	  ,Status NVARCHAR(10)
      ,transdate DATETIME
	  ,checktime DATETIME
	  ,betid BIGINT
	  ,Transdesc NVARCHAR(1000)
	  ,statusID TINYINT
	  ,Subcustid INT
	  ,Subhdp1 SMALLMONEY
      ,Subhdp2 SMALLMONEY
	  ,Sublivehomescore SMALLINT
      ,Subliveawayscore SMALLINT
	  ,Subliveindicator BIT
	  ,Subodds SMALLMONEY
	  ,Suboddsspread MONEY
	  ,Subbetfrom NVARCHAR(3)
	  ,Subbettype SMALLINT
	  ,Subbetteam  NVARCHAR(10)
	  ,Subbetcheck NVARCHAR(50)
	  ,SubStatus NVARCHAR(10)
	  ,Subtransdate DATETIME
	  ,Subchecktime DATETIME
	  ,SubTransdesc  NVARCHAR(1000)
	  ,SubstatusID TINYINT
	  ,srecommend INT
	  ,mrecommend INT
	  ,recommend INT
      ,creator INT
	  ,stake MONEY
	  ,oddstype TINYINT
	  ,CurrencyName NVARCHAR(50)
	  ,betdaqid BIGINT
	  ,ExtraInfo VARCHAR(1000)
	  ,BonusID INT
	  ,winlost	MONEY
	  ,actual_stake MONEY
	  ,winlostdate SMALLDATETIME
	  ,modds SMALLMONEY
	  ,statuswinlost TINYINT
      ,IsMixParlay BIT
	  ,SiteDBGroupID SMALLINT
	  ,WalletType TINYINT
	  ,RefCode BIGINT
	)

	INSERT INTO #tmpTransInfo( 
		    matchid 
	       ,transid 
		   ,Subtransid 
	       ,refno 
	       ,custid 	
           ,hdp1 
           ,hdp2 
           ,livehomescore 
           ,liveawayscore 
           ,liveindicator 
	       ,odds 
	       ,oddsspread 
           ,betfrom 
           ,bettype 
           ,betteam 
	       ,betcheck 
	       ,Status 
           ,transdate 
	       ,checktime 
	       ,betid 
	       ,Transdesc 
	       ,statusID 
	       ,Subcustid 
	       ,Subhdp1 
           ,Subhdp2 
	       ,Sublivehomescore 
           ,Subliveawayscore 
	       ,Subliveindicator 
	       ,Subodds 
	       ,Suboddsspread 
	       ,Subbetfrom 
	       ,Subbettype 
	       ,Subbetteam  
	       ,Subbetcheck 
	       ,SubStatus 
	       ,Subtransdate 
	       ,Subchecktime 
	       ,SubTransdesc  
	       ,SubstatusID 
	       ,srecommend 
	       ,mrecommend 
	       ,recommend 
           ,creator 
		   ,stake 
	       ,oddstype 
	       ,CurrencyName 
	       ,betdaqid 
	       ,ExtraInfo 
	       ,BonusID 
	       ,winlost	
	       ,actual_stake 
	       ,winlostdate 
	       ,modds 
	       ,statuswinlost 
           ,IsMixParlay 
	       ,SiteDBGroupID 
		   ,WalletType 
		   ,RefCode
	)
	SELECT mid ,t ,s_t ,ref ,c ,hdp1 ,hdp2 ,lh ,la ,li
		,o ,os ,bfr ,btype ,bteam ,bcheck ,s ,tdate ,checkt ,bid
		,tdes ,sid ,s_c ,s_hdp1 ,s_hdp2 ,s_lh ,s_la ,s_li ,s_o ,s_os
		,s_bfr ,s_btype ,s_bteam ,s_bcheck ,s_s ,s_tdate ,s_checkt ,s_tdes ,s_sid ,sre
		,mre ,re ,cr ,stake ,ost ,curr ,bdaq ,ex ,bo ,w
		,acstake ,wld ,m ,statuswl ,isP ,sitedb
		,wt ,refc
	FROM string_split(@TransInfoJson, ',') f
		CROSS APPLY (SELECT CAST(DECOMPRESS(CONVERT(VARBINARY(MAX), f.value, 1)) AS NVARCHAR(MAX)) AS Decompress_TransInfoJson) t
		CROSS APPLY (
				SELECT mid ,t ,s_t ,ref ,c ,hdp1 ,hdp2 ,lh ,la ,li
					  ,o ,os ,bfr ,btype ,bteam ,bcheck ,s ,tdate ,CASE WHEN checkt = '1900-01-01 00:00:00.000' THEN NULL ELSE checkt END AS checkt ,bid
					  ,tdes ,sid ,s_c ,s_hdp1 ,s_hdp2 ,s_lh ,s_la ,s_li ,s_o ,s_os
					  ,s_bfr ,s_btype ,s_bteam ,s_bcheck ,s_s ,s_tdate ,CASE WHEN s_checkt = '1900-01-01 00:00:00.000' THEN NULL ELSE s_checkt END AS s_checkt ,s_tdes ,s_sid ,sre
					  ,mre ,re ,cr ,stake ,ost ,curr ,bdaq ,ex ,bo ,w
					  ,acstake ,CASE WHEN wld = '1900-01-01 00:00:00.000' THEN NULL ELSE wld END AS wld ,m ,statuswl ,isP ,sitedb
					  ,wt ,refc
				FROM OPENJSON(@Decompress_TransInfoJson0) 
				WITH( mid INT, t BIGINT, s_t BIGINT, ref BIGINT, c INT, hdp1 SMALLMONEY, hdp2 SMALLMONEY, lh SMALLINT, la SMALLINT ,li BIT 
					 ,o SMALLMONEY ,os MONEY ,bfr NVARCHAR(3) ,btype SMALLINT ,bteam NVARCHAR(10) ,bcheck NVARCHAR(50) ,s NVARCHAR(10) ,tdate DATETIME ,checkt DATETIME ,bid BIGINT
					 ,tdes NVARCHAR(1000) ,sid TINYINT ,s_c INT ,s_hdp1 SMALLMONEY ,s_hdp2 SMALLMONEY ,s_lh SMALLINT ,s_la SMALLINT ,s_li BIT ,s_o SMALLMONEY ,s_os MONEY 
					 ,s_bfr NVARCHAR(3) ,s_btype SMALLINT ,s_bteam NVARCHAR(10) ,s_bcheck NVARCHAR(50) ,s_s NVARCHAR(10) ,s_tdate DATETIME ,s_checkt DATETIME ,s_tdes NVARCHAR(1000) ,s_sid  TINYINT ,sre INT
					 ,mre INT ,re INT ,cr INT ,stake MONEY ,ost TINYINT ,curr NVARCHAR(50) ,bdaq BIGINT ,ex VARCHAR(1000) ,bo INT ,w MONEY
					 ,acstake MONEY ,wld SMALLDATETIME ,m SMALLMONEY ,statuswl TINYINT ,isP BIT ,sitedb SMALLINT
					 ,wt TINYINT ,refc BIGINT
				)
		) tbl

	INSERT INTO #TVSTicketBets(
			transid		
			,SubTransid		
			,refno			
			,custid					
			,transdate		
			,bettype 				
			,livehomescore 	
			,liveawayscore 		
			,LiveIndicator
			,matchid
			,StatusId
			,SubStatusId
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
			,b.liveindicator
			,@MatchId
			,b.statusID
			,b.SubstatusID
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
	IF EXISTS ( SELECT TOP 1 1 FROM #tmpTransInfo bm  WHERE bm.IsMixParlay = 1)
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
				,SubStatusId
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
				,b.IsMixParlay
				,b.Subliveindicator
				,@MatchId
				,b.statusID
				,b.SubstatusID
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
		WHERE r.RequestId <> @RequestId AND r.ActionId NOT IN (2)

		IF @@ROWCOUNT <> 0
		BEGIN
			SELECT @IsExistedInOtherRequest = 1
		END
	END

	IF @IsShowLogOnly = 1 AND @RequestId <> 0
	BEGIN
		-- 1. Validate table
		SELECT  @IsExistedInOtherRequest AS IsExistedInOtherRequest

		-- 2. TransId in request table
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

		-- 3. Loginto table ( NO-use)
		SELECT NULL AS MatchId

		-- 4. Unmark table
		SELECT NULL AS UnmarkTransIds
		
		-- 5. Transinfo table (No need return data)
		SELECT @TransInfoJson AS TransInfoJson

		RETURN;
	END
	
	IF @RequestId = 0 AND @ActionId <> 2
	BEGIN
		--Mark ticket when add request
		SELECT @MarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(tp.transid AS VARCHAR(50)) 
											FROM #TVSTicketBets tp   
											WHERE tp.IsMixParlay = 0 AND tp.StatusId IN (0,1)
											AND NOT EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = tp.TransId)-- exist in # request
											FOR XML PATH('')), 1,1,'')
										,'')

		IF @MarkTransIds <> ''
				SET @MarkTransIds = @MarkTransIds + ','

		SELECT @MarkTransIds += ISNULL(STUFF((SELECT ',' + CAST(tp.SubTransid AS VARCHAR(50)) 
											FROM #TVSTicketBets tp   
											WHERE tp.IsMixParlay = 1 AND tp.SubStatusId IN (0,1)
											AND NOT EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = tp.SubTransid)-- exist in # request
											FOR XML PATH('')), 1,1,'')
										,'')
	END
	ELSE IF @IsShowLogOnly = 0 AND @RequestId <> 0 
	BEGIN
		SELECT @OldActionId = ISNULL(ActionId,0) FROM dbo.TicketVoiding_Request WITH(NOLOCK) WHERE RequestId = @RequestId
		
		IF @ActionId  <> 2 AND @OldActionId <> 2
		BEGIN
			--Edit request filter on UI -> unmark ticket 
			SELECT @UnmarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(rdt.transid AS VARCHAR(50)) 
											FROM dbo.TicketVoiding_RequestDetailTicket_Single rdt WITH(NOLOCK)
												LEFT JOIN #TVSTicketBets tp ON rdt.TransId=tp.transid AND tp.IsMixParlay = 0
												LEFT JOIN #TransidInRequest tr on tr.TransId = rdt.TransId
											WHERE tp.TransId IS NULL AND tr.TransId is NULL
												AND rdt.RequestId = @RequestId
											FOR XML PATH('')), 1,1,'')
										,'')

			IF @UnmarkTransIds <> ''
				SET @UnmarkTransIds = @UnmarkTransIds + ','

			SELECT @UnmarkTransIds += ISNULL(STUFF((SELECT ',' + CAST(rdt.transid AS VARCHAR(50)) 
											 FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rdt WITH(NOLOCK)
													LEFT JOIN #TVSTicketBets tp ON rdt.TransId=tp.SubTransid AND tp.IsMixParlay = 1
													LEFT JOIN #TransidInRequest tr on tr.TransId = rdt.TransId
											  WHERE tp.SubTransid IS NULL AND tr.TransId IS NULL
													  AND rdt.RequestId=@RequestId
											  FOR XML PATH('')
											), 1,1,'')
										,'')

	
			--Add mark ticket when edit request (mark all again -> support case unmark by function SD)
			SELECT @MarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(tp.transid AS VARCHAR(50))
											FROM #TVSTicketBets tp
												LEFT JOIN #TransidInRequest tr on tr.TransId = tp.transid
											WHERE tp.IsMixParlay = 0 AND tr.TransId IS NULL AND tp.StatusId IN (0,1)
											FOR XML PATH('')), 1, 1, '')
									, '')

			IF @MarkTransIds <> ''
				SET @MarkTransIds = @MarkTransIds + ','

			SELECT @MarkTransIds += ISNULL(STUFF((SELECT ',' + CAST(tp.SubTransid AS VARCHAR(50))
											FROM #TVSTicketBets tp
												LEFT JOIN #TransidInRequest tr on tr.TransId = tp.SubTransid
											WHERE tp.IsMixParlay = 1 AND tr.TransId IS NULL AND tp.SubStatusId IN (0,1)
											FOR XML PATH('')), 1, 1, '')
									, '')
		END
		ELSE IF @ActionId  <> 2 AND @OldActionId = 2
		BEGIN
			--Mark ticket when add request
			SELECT @MarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(tp.transid AS VARCHAR(50)) 
												FROM #TVSTicketBets tp   
												WHERE tp.IsMixParlay = 0 AND tp.StatusId IN (0,1)
												AND NOT EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = tp.TransId)-- exist in # request
												FOR XML PATH('')), 1,1,'')
											,'')

			IF @MarkTransIds <> ''
					SET @MarkTransIds = @MarkTransIds + ','

			SELECT @MarkTransIds += ISNULL(STUFF((SELECT ',' + CAST(tp.SubTransid AS VARCHAR(50)) 
												FROM #TVSTicketBets tp   
												WHERE tp.IsMixParlay = 1 AND tp.SubStatusId IN (0,1)
												AND NOT EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = tp.SubTransid)-- exist in # request
												FOR XML PATH('')), 1,1,'')
											,'')
		END
		ELSE IF @ActionId = 2 AND @ActionId <> @OldActionId -- Take note
		BEGIN
			SELECT @UnmarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(rdt.transid AS VARCHAR(50)) 
											FROM dbo.TicketVoiding_RequestDetailTicket_Single rdt WITH(NOLOCK)
											WHERE rdt.RequestId = @RequestId
											FOR XML PATH('')), 1,1,'')
										,'')
			IF @UnmarkTransIds <> ''
				SET @UnmarkTransIds = @UnmarkTransIds + ','
			
			SELECT @UnmarkTransIds += ISNULL(STUFF((SELECT ',' + CAST(rdt.transid AS VARCHAR(50)) 
											 FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rdt WITH(NOLOCK)
											  WHERE rdt.RequestId=@RequestId
											  FOR XML PATH('')
											), 1,1,'')
										,'')
		END

	END
	/*****************Return table **************************/
	-- 1. Validate table
	SELECT @IsExistedInOtherRequest AS IsExistedInOtherRequest
		  
	-- 2. TransId exists in other request table
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

	-- 3. Loginto table (no-need but must return)
	SELECT NULL MatchId

	-- 4. List ticket unmark/mark   (if any)
	SELECT @UnmarkTransIds AS UnmarkTransIds
	      ,@MarkTransIds AS MarkTransIds

	-- 5. Transinfo table
	SET @TransInfoJson = COMPRESS((SELECT t.matchid AS 'mid'
		    ,t.transid AS 't'
			,t.Subtransid AS 's_t'
			,t.refno AS 'ref'
			,b.custid AS  'c' 
			,b.hdp1 AS 'hdp1' 
		    ,b.hdp2 AS 'hdp2' 
		    ,b.livehomescore AS 'lh'  
		    ,b.liveawayscore AS 'la' 
		    ,b.liveindicator AS 'li' 
			,b.odds AS 'o' 
		    ,b.oddsspread AS 'os'
		    ,b.betfrom AS 'bfr'
		    ,b.betteam AS 'bteam'
			,b.bettype AS 'btype'
		    ,b.betcheck AS 'bcheck' 
		    ,b.Status AS 's'  
			,b.transdate AS 'tdate' 
			,b.betid AS 'bid'
		    ,b.Transdesc AS 'tdes' 
		    ,b.statusID AS 'sid'
		    ,b.Subcustid AS 's_c'
		    ,b.Subhdp1 AS 's_hdp1'
		    ,b.Subhdp2 AS 's_hdp2' 
			,b.Sublivehomescore AS 's_lh'  
		    ,b.Subliveawayscore AS 's_la'  
		    ,b.Subliveindicator AS 's_li' 
		    ,b.Subodds AS 's_o' 
		    ,b.Suboddsspread AS 's_os' 
		    ,b.Subbetfrom AS 's_bfr' 
		    ,b.Subbetteam AS 's_bteam' 
		    ,b.Subbettype AS 's_btype'  
		    ,b.Subbetcheck AS 's_bcheck' 
		    ,b.SubStatus AS 's_s' 
		    ,b.Subtransdate AS 's_tdate' 
		    ,b.SubTransdesc  AS 's_tdes' 
			,b.SubstatusID AS 's_sid' 
		    ,b.srecommend AS 'sre' 
		    ,b.mrecommend AS 'mre' 
		    ,b.recommend AS 're' 
		    ,b.creator AS 'cr' 
		    ,b.WalletType AS 'wt' 
		    ,b.RefCode AS 'refc' 
			,b.stake AS 'stake'
		    ,b.oddstype AS 'ost'
		    ,b.CurrencyName AS 'curr'
		    ,b.betdaqid AS 'bdaq'   
		    ,b.ExtraInfo AS 'ex'
		    ,b.BonusID AS 'bo' 
		    ,b.winlost AS 'w'     
		    ,b.actual_stake AS 'acstake'
			,b.modds AS 'm'
			,b.IsMixParlay AS 'isP'
			,b.SiteDBGroupID AS 'sitedb'
	FROM #TVSTicketBets t
			INNER JOIN #tmpTransInfo b ON t.matchid = b.matchid AND t.transid = b.transid
		WHERE NOT EXISTS (SELECT 1 FROM #TransidInRequest r WHERE r.TransId = t.SubTransid)
	FOR JSON PATH))

	SELECT @TransInfoJson AS TransInfoJson

	DROP TABLE #TVSTicketBets
	DROP TABLE #TransidInRequest
	DROP TABLE #tmpTransInfo

END
GO

