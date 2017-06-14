/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Admin_Settlement_3_Basketball
	@matchId			INT
	,@Mode				VARCHAR(10) = 'CAL'
	,@SelectedQuarter	VARCHAR(50)
AS
/*
    Created: 20170220@Kathy
    Task : Settlement Basketball bets [Redmine:#71372]
    DB: DBTXN/bodb02

    Revisions:
		- 20170609@Kathy: Remove some "early settlement" bettypes [Redmine:#77835]
       
    Param's Explanation:
    • @Mode: CAL
       
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @fth					INT
			,@fta 					INT	
			,@hth					INT
			,@hta 					INT			
			,@FTScoreDiff			INT
			,@HTScoreDiff			INT
			,@totalgoal				INT
			,@totalht				INT
			,@oddeven				SMALLMONEY
			,@oddevenht				SMALLMONEY
			
			,@xmlResultDetail		VARCHAR(MAX)
			,@xml					XML
			,@strBettypes			VARCHAR(MAX)
			,@strResourceIds		VARCHAR(MAX) = ''
			
	DECLARE @tmpResult TABLE(ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50))
	
	EXEC dbo.Nap_Admin_Settlement_2 @mode = 'basketball'
		,@matchid = @matchid
		,@str_resultDetail = @xmlResultDetail OUTPUT
		
	SET @xml = CONVERT(XML, @xmlResultDetail)
	
	;WITH cteResult
	AS(
		SELECT	T.c.value('./@rid','VARCHAR(20)') AS ResourceId
				,T.c.value('./@home','VARCHAR(50)') AS HomeValue
				,T.c.value('./@away','VARCHAR(50)') AS AwayValue
		FROM	@xml.nodes('/root/r') AS T(c)
	)
	INSERT INTO @tmpResult(ResourceId, HomeValue, AwayValue)
	SELECT	ResourceId, HomeValue, AwayValue
	FROM	cteResult r
	OPTION ( OPTIMIZE FOR ( @xml = NULL ) )
	
	SELECT	@fth = HomeValue
			,@fta = AwayValue
	FROM	@tmpResult
	WHERE	ResourceId = '00'
	
	SELECT	@hth = HomeValue
			,@hta = AwayValue
	FROM	@tmpResult
	WHERE	ResourceId = '01'
	
	SELECT @totalgoal	=  @fth + @fta
		,@totalht		= @hth + @hta
		, @FTScoreDiff	= @fth - @fta
		,@HTScoreDiff	= @hth - @hta
		,@oddeven		= (@fth + @fta) % 2
		,@oddevenht		= (@hth + @hta) % 2
		
	DECLARE @tmpBettypes TABLE (bettype SMALLINT, ResourceIds VARCHAR(MAX))

	;WITH cteBettypeResourceIds
	AS(
		SELECT	b.bettype, r.ResourceId		
		FROM	dbo.bettrans b WITH(NOLOCK)
			CROSS APPLY (
				SELECT CAST(CAST(b.bettype AS VARCHAR) + ISNULL(SUBSTRING(CAST(b.betid AS VARCHAR), 2, LEN(b.betid)),'') AS VARCHAR(20)) AS ResourceId
			) r
		WHERE	b.matchid = @matchid
		GROUP BY b.bettype, r.ResourceId
	)
	,cteBettypes
	AS
	(
		SELECT c.bettype, t.ResourceId
		FROM cteBettypeResourceIds c
			LEFT JOIN @tmpResult t
				ON c.ResourceId = t.ResourceId
	)
	INSERT INTO @tmpBettypes (BetType, ResourceIds)	
	SELECT	c.bettype, STUFF((SELECT ',' + CAST(ResourceId AS VARCHAR) FROM cteBettypes WHERE bettype = c.bettype FOR XML PATH('')),1,1,'') AS ResourceIds
	FROM	cteBettypes c
	GROUP BY c.bettype
	
	SELECT	@strBettypes = COALESCE(@strBettypes + ',' + CAST(b.bettype AS VARCHAR(10)), CAST(b.bettype AS VARCHAR(10))) 
			,@strResourceIds = REPLACE(COALESCE(@strResourceIds + ',' + ISNULL(b.ResourceIds,''), ISNULL(b.ResourceIds,'')) ,',,',',')
	FROM	dbo.f_Set_GetGroupBettypes() f
		INNER JOIN @tmpBettypes b
			ON b.bettype = f.bettype
	WHERE	f.IsAuto = 0
			AND 1 = CASE 
						WHEN @SelectedQuarter LIKE '%' + f.GroupName + '%' THEN 1 -- 1H, FT	
						WHEN GroupId = 10 AND @SelectedQuarter LIKE '%80[1-4]%' THEN 1
						ELSE 0
					END
	
	EXEC dbo.NAP_Admin_Calculate_Main @matchid = @matchid
        ,@mode = @mode
        ,@fth = @fth
        ,@fta = @fta
        ,@hth = @hth
        ,@hta = @hta
		,@totalgoal = @totalgoal
		,@totalht = @totalht
		,@totalhome = @fth
        ,@totalaway = @fta
        ,@oddeven = @oddeven
        ,@oddevenht = @oddevenht
        ,@scorediff = @FTScoreDiff
        ,@scorediff_ht = @HTScoreDiff
		,@xmlData = @xmlResultDetail		
		,@ResourceIds = @strResourceIds
		,@sporttype = 2
		,@CalledByBrokerService = 0 
		,@strBettypes = @strBettypes
END
GO
