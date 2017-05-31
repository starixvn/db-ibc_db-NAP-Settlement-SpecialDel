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
			,@strBettypes VARCHAR(MAX)
			
	EXEC dbo.Nap_Admin_Settlement_2 @mode = 'basketball'
		,@matchid = @matchid
		,@str_resultDetail = @xmlResultDetail OUTPUT
		
	SET @xml = CONVERT(XML, @xmlResultDetail)
	
	SELECT	@fth = ISNULL(T.C.value('./@FTHome[1]', 'INT'), 0)
			,@fta = ISNULL(T.C.value('./@FTAway[1]', 'INT'), 0)
			,@hth = ISNULL(T.C.value('./@HTHome[1]', 'INT'), 0)
			,@hta = ISNULL(T.C.value('./@HTAway[1]', 'INT'), 0)
	FROM	@xml.nodes('/root/r') AS T(c) -- Table/Column
	OPTION ( OPTIMIZE FOR ( @xml = NULL ) ) 
	
	SELECT @totalgoal	=  @fth + @fta
		,@totalht		= @hth + @hta
		, @FTScoreDiff	= @fth - @fta
		,@HTScoreDiff	= @hth - @hta
		,@oddeven		= (@fth + @fta) % 2
		,@oddevenht		= (@hth + @hta) % 2
		
	DECLARE @tblBettypes TABLE (bettype SMALLINT)

	INSERT INTO @tblBettypes (BetType)	
	SELECT	b.bettype
	FROM	dbo.bettrans b WITH(NOLOCK)
	WHERE	b.matchid = @matchid
	GROUP BY b.bettype
	

	SELECT @strBettypes = COALESCE(@strBettypes + ',' + CAST(b.bettype AS VARCHAR(10)), CAST(b.bettype AS VARCHAR(10))) 
	FROM	dbo.f_Set_GetGroupBettypes() c
		INNER JOIN @tblBettypes b
			ON b.bettype = c.bettype
	WHERE	(GroupId = 10 AND @SelectedQuarter LIKE '%80[1-4]%')
			OR @SelectedQuarter LIKE '%' + GroupName + '%' -- 1H, 2H, FT	
				
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
		,@SelectedQuarter = @SelectedQuarter
		,@sporttype = 2
		,@CalledByBrokerService = 0 
		,@strBettypes = @strBettypes
END
GO
