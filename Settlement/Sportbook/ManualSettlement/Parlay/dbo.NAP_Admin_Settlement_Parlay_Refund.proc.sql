/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Parlay_Refund] (
	@MatchId 			INT
	, @matchdate		SMALLDATETIME
	, @Mode				VARCHAR(20)
	, @IsRefundHT		BIT
	, @resultDetail_bb	VARCHAR(MAX) = NULL
	, @resultDetail_ss	VARCHAR(MAX) = NULL
	, @resultDetail		VARCHAR(MAX) = NULL
	, @TicketCount		INT = 0 OUTPUT
	, @ErrCode 			INT = 0 OUTPUT
	, @ErrMsg 			NVARCHAR(200) = '' OUTPUT
)
AS
/*	Creator: 20161206@Bobby
	Task: #61352 - Apply settle determined for parlay bet types
	DB: DBTXN/BODB02
	ORIGINAL: 

	Revisions:		
		- 20170215@Kathy: Basketball All-in-One [Redmine:#71372]
		- 20170613@Kathy: Early Settlement [Redmine:#77835] 
		- 20170901@Kathy: Settle parlay tickets of tennis in case of they have result [Redmine:#82122]
		- 20190715@Helen: Recover/Void tickets in Bet 14 - Update statuswinlost for VOID Tickets [Redmine:115377]
		- 20190813@Helen: Remove vnteam in metadata
		- 20221228@Kathy: Exclude ticket sitedb when settling on central [Redmine:#180639]

	Param's Explanation:		
		- @Mode: ['REFUND', 'REFUND-HT','REFUND-FT']
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @tempRefundBatch TABLE (refno BIGINT, betcount INT)
	DECLARE @tmpResultDetail TABLE (ResourceId VARCHAR(20))
	
	DECLARE @ResourceResult_1_tmp AS TABLE (ResourceId VARCHAR(20),HomeValue VARCHAR(50))		
	DECLARE @GoalBettype_tmp AS TABLE (bettype INT, Voided_cnt INT, ticket_cnt INT)
	
	CREATE TABLE #refundBettypes (bettype SMALLINT PRIMARY KEY, groupId SMALLINT, GroupName NVARCHAR(50), isEarly BIT)
	
	DECLARE @basketball_ResourceIdsREFUND VARCHAR(MAX) = NULL
			,@xmlbb XML
			,@tennis_SelectedSetREFUND VARCHAR(50)
			,@xmlss XML
			,@IsCentral	BIT = 0

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT
	
	IF @resultDetail_bb IS NOT NULL
	BEGIN
		SET @xmlbb = CONVERT(XML, @resultDetail_bb)    
		
		;WITH cteResultDetail
		AS(
			SELECT	T.c.value('./@rid','VARCHAR(20)') AS ResourceId				
					,T.c.value('./@ssId','TINYINT') AS SettlementStatusId
			FROM	@xmlbb.nodes('/root/r') AS T(c)
		)
		INSERT INTO @tmpResultDetail(ResourceId)
		SELECT	ResourceId
		FROM	cteResultDetail r
		WHERE	SettlementStatusId = 1
		OPTION ( OPTIMIZE FOR ( @xmlbb = NULL ) )
		
		SELECT @basketball_ResourceIdsREFUND = COALESCE(@basketball_ResourceIdsREFUND + ',' + r.ResourceId , r.ResourceId)	 
				FROM	@tmpResultDetail t
					CROSS APPLY (
						SELECT CASE
									WHEN t.ResourceId = '00' THEN 'FT'
									WHEN t.ResourceId = '01' THEN '1H'
									WHEN t.ResourceId = '02' THEN '2H'
									ELSE t.ResourceId
								END AS ResourceId
					) r					
	END
	
	IF @resultDetail_ss IS NOT NULL
	BEGIN
		SET @xmlss = CONVERT(XML, @resultDetail_ss)    
                
        SELECT	TOP(1) 
				@tennis_SelectedSetREFUND = ISNULL(T.C.value('./@SelectedSetREFUND[1]', 'varchar(50)'), '')
        FROM	@xmlss.nodes('/root/r') as [T](C) --T: table, C: column    
        OPTION ( OPTIMIZE FOR ( @xmlss = NULL ) )    
	END
	
	IF @resultDetail IS NOT NULL
	BEGIN
		DECLARE @xmlResultDetail XML
		
		SET @xmlResultDetail = CONVERT(XML,@resultDetail)
		
		INSERT INTO @ResourceResult_1_tmp (ResourceId,HomeValue)
		SELECT	T.c.value('./@rid','VARCHAR(20)') AS ResourceId
				,T.c.value('./@home','VARCHAR(50)') AS HomeValue
		FROM	@xmlResultDetail.nodes('/root/r') AS T(c)
		OPTION ( OPTIMIZE FOR ( @xmlResultDetail = NULL ) )
		
		-- check GoalBettype if all tickets have been voided
		INSERT INTO @GoalBettype_tmp (bettype, Voided_cnt,ticket_cnt)
		SELECT b.bettype
			, SUM(CASE WHEN statusID IN (101,102) THEN 1 ELSE 0 END) AS Voided_cnt
			, COUNT(1) AS ticket_cnt
		FROM bettransm b WITH (NOLOCK)
			INNER JOIN dbo.f_Set_GetGroupBettypes() bt ON b.bettype = bt.BetType AND bt.IsUsedGoalRecordValue = 1
		WHERE b.matchid = @matchid 
		GROUP BY b.bettype
	
		DELETE g 
		FROM @GoalBettype_tmp g
			INNER JOIN SettlementSpecialBettypeProfile p WITH (NOLOCK) ON p.bettype = g.bettype
		WHERE g.Voided_cnt = g.ticket_cnt
			AND NOT EXISTS (SELECT 1 FROM @ResourceResult_1_tmp rs WHERE p.ResourceID = rs.ResourceId)
			
	END
	
	INSERT INTO #refundBettypes (bettype, groupId, GroupName, isEarly)
	SELECT f.BetType, f.GroupId, f.GroupName, CASE WHEN e.bettype IS NOT NULL THEN 1 ELSE 0 END AS isEarly
	FROM dbo.f_Set_GetGroupBettypes() f
		LEFT JOIN dbo.f_Set_GetEarlyBettypes() e
			ON f.BetType = e.bettype
		LEFT JOIN @GoalBettype_tmp gbt ON f.BetType = gbt.bettype	
	WHERE 1 = CASE 
				WHEN @Mode = 'REFUND' THEN 1
				WHEN @Mode = 'REFUND-HT' THEN
					CASE 
						WHEN f.Is3x30 = 1 THEN 1
						ELSE 0
					END
				WHEN @Mode = 'REFUND-FT' THEN 
					CASE 
						WHEN @IsRefundHT = 1 THEN 1
						WHEN @IsRefundHT = 0 AND f.GroupId IN (2,4,6) THEN 1
						ELSE 0
					END
				WHEN @Mode = 'ABANDONED-2H' THEN 
					CASE 
						WHEN (@IsRefundHT = 1 AND (f.GroupId IN (1,3,5,7) OR f.Is3x30 = 1)) THEN 1
						ELSE 0
					END
				ELSE 0 
			END
		AND f.GroupId NOT IN (8,9) -- Exclude BetRadar, FM
		AND 1= CASE 
					WHEN f.IsUsedGoalRecordValue = 1 AND gbt.bettype IS NOT NULL THEN 1
					WHEN f.IsUsedGoalRecordValue = 1 AND gbt.bettype IS NULL THEN 0
					ELSE 1
				END	
					
	DECLARE @fromTransId	INT
		,@batchNo			INT
		,@batchCount		INT
		,@strTicket			VARCHAR(MAX)

	SELECT @batchNo			= 2000
		, @batchCount		= 0
		, @fromTransId		= 0
		, @ticketCount		= 0
	
	DECLARE @tempRefno TABLE (refno BIGINT, QuarterX VARCHAR(20))
	
	INSERT INTO @tempRefno (refno, QuarterX)
	SELECT bm.refno, res.QuarterX
	FROM dbo.bettransm bm WITH(NOLOCK)
		INNER JOIN #refundBettypes t ON bm.bettype = t.bettype
		CROSS APPLY (
				SELECT CAST(bm.bettype AS VARCHAR) + ISNULL(SUBSTRING(bm.betcheck, 2, LEN(bm.betcheck)), '') AS ResourceId
		) r
		CROSS APPLY (
			SELECT CASE 
						WHEN t.groupId = 10 
							THEN CASE 
									WHEN bm.betcheck = '801' THEN 'Q1'
									WHEN bm.betcheck = '802' THEN 'Q2'
									WHEN bm.betcheck = '803' THEN 'Q3'
									WHEN bm.betcheck = '804' THEN 'Q4'
									ELSE ''
								END
						ELSE ''
					END AS QuarterX
		) res
	WHERE bm.matchid 	= @matchid
		AND bm.statusID NOT IN (101)
		AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END 
		AND 1 = CASE
					WHEN @resultDetail_bb IS NULL THEN 1
					WHEN t.isEarly = 1 THEN CASE
												WHEN CHARINDEX(',' + r.ResourceId + ',', ',' + @basketball_ResourceIdsREFUND + ',') > 0 THEN 1
												ELSE 0
											END
					WHEN t.groupId = 10 THEN CASE
												WHEN CHARINDEX(',' + res.QuarterX + ',', ',' + @basketball_ResourceIdsREFUND + ',') > 0 THEN 1
												ELSE 0
											END
					WHEN CHARINDEX(',' + t.groupName + ',', ',' + @basketball_ResourceIdsREFUND + ',') > 0 THEN 1
					ELSE 0 
				END
		AND 1 = CASE
					WHEN @resultDetail_ss IS NULL THEN 1
					WHEN @tennis_SelectedSetREFUND LIKE '%1%' AND bm.Bettype IN (154,155,156,1311,1312,1316,1317,1318) AND betcheck LIKE '801%' THEN 1  --Exclude 1324
					WHEN @tennis_SelectedSetREFUND LIKE '%2%' AND bm.Bettype IN (154,155,156,1311,1312,1316,1317,1318) AND betcheck LIKE '802%' THEN 1
					WHEN @tennis_SelectedSetREFUND LIKE '%3%' AND bm.Bettype IN (154,155,156,1311,1312,1316,1317,1318) AND betcheck LIKE '803%' THEN 1
					WHEN @tennis_SelectedSetREFUND LIKE '%4%' AND bm.Bettype IN (154,155,156,1311,1312,1316,1317,1318) AND betcheck LIKE '804%' THEN 1
					WHEN @tennis_SelectedSetREFUND LIKE '%5%' AND bm.Bettype IN (154,155,156,1311,1312,1316,1317,1318) AND betcheck LIKE '805%' THEN 1
					WHEN @tennis_SelectedSetREFUND LIKE '%6%' AND bm.Bettype IN (1,2,3,20,153,1301,1302,1303,1305,1306,1308) THEN 1    
					ELSE 0
				END

	--GROUP BY bm.refno

	--DO REFUND parlay tickets
	WHILE (1 = 1)
	BEGIN
		
		DELETE @tempRefundBatch
		
		DELETE TOP(@batchNo) t
		OUTPUT deleted.refno INTO @tempRefundBatch(refno)
		FROM @tempRefno t	
		
		SELECT @batchCount	= @@ROWCOUNT
			,@ticketCount	+= @batchCount

		SELECT @strTicket = CAST(
		(
			SELECT *
			FROM (
				SELECT TOP(@batchNo)
					b.transid AS t
					,b.refno AS r
					,0 AS m
				FROM @tempRefundBatch ref
					INNER JOIN dbo.bettransm b WITH(NOLOCK) ON b.refno = ref.refno
				WHERE b.matchid 	= @matchid
			) AS b FOR XML AUTO
		) AS VARCHAR(MAX))
		
		IF(@strTicket IS NOT NULL)
		BEGIN
		EXEC dbo.NAP_Admin_Calculate_MP_broker 
			@matchid 		= @matchid
			,@matchdate		= @matchdate
			,@mode 			= 'REFUND'
			,@action 		= 'REFUND'
			,@strTransIds	= @strTicket
		END
		
		--BREAK;

		IF(@batchCount = 0 OR @strTicket IS NULL) BREAK
			
	END
	
	DROP TABLE #refundBettypes
	RETURN
END
GO
