/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_3_Basketball]
	@matchId			INT
	,@Mode				VARCHAR(10) = 'CAL'
	,@SelectedQuarter	VARCHAR(50)
	,@IsReSettledTickets BIT = 1
AS
/*
    Created: 20170220@Kathy
    Task : Settlement Basketball bets [Redmine:#71372]
    DB: DBTXN/bodb02

    Revisions:
		- 20170609@Kathy: Remove some "early settlement" bettypes [Redmine:#77835]
		- 20200120@Sol:	Settlement with Ticket Exclusion for Other Sports - [Redmine:#126963]
       
    Param's Explanation:
    @Mode: CAL
       
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
			,@strResourceIds		VARCHAR(MAX) 
			
	DECLARE @tmpResult TABLE(ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50))
	
	EXEC dbo.NAP_Admin_Settlement_2 @mode = 'basketball'
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
	
	DECLARE @tmpBettypeResourceId TABLE (bettype SMALLINT, ResourceId VARCHAR(20))
	;WITH cteBettypes
	AS(
		SELECT	b.bettype, b.betid
		FROM	dbo.bettrans b WITH(NOLOCK)
		WHERE	b.matchid = @matchid
				AND 1 = CASE WHEN @IsReSettledTickets = 0 AND statusID IN (0,102) THEN 1
							 WHEN @IsReSettledTickets = 1 THEN 1
							 ELSE 0
						END
		GROUP BY b.bettype, b.betid
	)
	INSERT INTO @tmpBettypeResourceId(bettype, ResourceId)
	SELECT	c.bettype
			,CASE
				WHEN c.BetType = 605 THEN q.ResourceId
				WHEN CHARINDEX(',' + q.QuarterX + ',', ',' + @SelectedQuarter + ',') > 0 
					THEN CASE 
							WHEN c.bettype = 617 THEN q.ResourceId
							WHEN f.GroupId = 10 THEN q.QuarterX
							ELSE NULL
							END
				ELSE NULL
				END 
	FROM	cteBettypes c
		INNER JOIN dbo.f_Set_GetGroupBettypes() f
			ON c.bettype = f.BetType
		CROSS APPLY (
			SELECT CASE
						WHEN f.groupId = 10 THEN ISNULL(LEFT(CAST(c.betid AS VARCHAR),3),'')
						ELSE NULL
						END AS QuarterX
					,CAST(c.bettype AS VARCHAR) + ISNULL(SUBSTRING(CAST(c.betid AS VARCHAR), 2, LEN(c.betid)), '') AS ResourceId
		) q
			
	WHERE	f.IsAuto = 0
			AND 1 = CASE 
						WHEN @SelectedQuarter LIKE '%' + f.GroupName + '%' THEN 1 -- 1H, FT	
						WHEN f.GroupId = 10 AND @SelectedQuarter LIKE '%80[1-4]%' THEN 1
						ELSE 0
					END
						
	SELECT @strBettypes = COALESCE(@strBettypes + ',' + CAST(bettype AS VARCHAR(10)), CAST(bettype AS VARCHAR(10))) 
	FROM	@tmpBettypeResourceId
	GROUP BY bettype
	
	SELECT @strResourceIds = COALESCE(@strResourceIds + ',' + ResourceId, ResourceId) 
	FROM	@tmpBettypeResourceId
	WHERE	ResourceId IS NOT NULL
	GROUP BY ResourceId
	
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
		,@IsReSettledTickets = @IsReSettledTickets
END

GO
