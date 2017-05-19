/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
USE [bodb02]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Parlay_Refund] (
	@MatchId 			INT
	, @matchdate		SMALLDATETIME
	, @Mode				VARCHAR(20)
	, @IsRefundHT		BIT
	, @resultDetail_bb	VARCHAR(MAX) = NULL
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

	Param's Explanation:		
		- @Mode: ['REFUND', 'REFUND-HT','REFUND-FT']
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @tempRefundBatch TABLE (refno BIGINT, betcount INT)
	CREATE TABLE #refundBettypes (bettype SMALLINT PRIMARY KEY, groupId SMALLINT, GroupName NVARCHAR(50))
	
	DECLARE @SelectedQuarterREFUND VARCHAR(50) = NULL
			,@xmlbb XML
	
	IF @resultDetail_bb IS NOT NULL
	BEGIN
		SET @xmlbb = CONVERT(XML, @resultDetail_bb)    
		
		SELECT	TOP(1) 
				@SelectedQuarterREFUND = ISNULL(T.C.value('./@SelectedQuarterREFUND[1]', 'varchar(50)'), '')
		FROM	@xmlbb.nodes('/root/r') as [T](C) --T: table, C: column    
		OPTION	( OPTIMIZE FOR ( @xmlbb = NULL ) )  
	END
	
	INSERT INTO #refundBettypes (bettype, groupId, GroupName)
	SELECT f.BetType, f.GroupId, f.GroupName
	FROM dbo.f_Set_GetGroupBettypes() f
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
		AND f.IsAuto = 0 -- Exclude BetRadar, FM
	
	DECLARE @fromTransId	INT
		,@batchNo			INT
		,@batchCount		INT
		,@strTicket			VARCHAR(MAX)

	SELECT @batchNo			= 2000
		, @batchCount		= 0
		, @fromTransId		= 0
		, @ticketCount		= 0
	
	DECLARE @tempRefno TABLE (refno BIGINT)
	
	INSERT INTO @tempRefno (refno)
	SELECT bm.refno
	FROM dbo.bettransm bm WITH(NOLOCK)
		INNER JOIN #refundBettypes t ON bm.bettype = t.bettype
	
	WHERE bm.matchid 	= @matchid
		AND bm.statusID NOT IN (101,102)
		AND 1 = CASE
					WHEN @SelectedQuarterREFUND IS NULL THEN 1
					WHEN @SelectedQuarterREFUND LIKE '%' + t.GroupName + '%' THEN 1
					WHEN t.groupId = 10 AND @SelectedQuarterREFUND LIKE '%' + LEFT(bm.betcheck,3) + '%' THEN 1
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
