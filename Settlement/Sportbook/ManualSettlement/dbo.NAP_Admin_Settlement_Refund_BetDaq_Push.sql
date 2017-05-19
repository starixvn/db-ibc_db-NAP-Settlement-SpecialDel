
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.NAP_Admin_Settlement_Refund_BetDaq_Push    Script Date: 06/10/2015 11:21:40 AM ******/
/****** Object:  Stored Procedure dbo.NAP_Admin_Settlement_Refund_BetDaq_Push    Script Date: 4/8/2015 1:48:15 AM ******/
/****** Object:  Stored Procedure dbo.NAP_Admin_Settlement_Refund_BetDaq_Push    Script Date: 06/04/2015 1:01:55 PM ******/
CREATE PROCEDURE [dbo].[NAP_Admin_Settlement_Refund_BetDaq_Push]
	@MatchId int,
	@AdminId int, 	
	@IP varchar(15) = '',
	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT
AS

	/*
	Created: 20140218@Kathy 
	Task : Refund Running BetDaq 
	Original: 
	DB: DBTXN/BODB02

	Revisions: 
	- 20140506@Kathy: Don't allow to calculate exists matches in queue
	- 20141030@Jamie: Sporting Solution for Tennis [Redmine:#23034]
	- 20150401@Kathy: Add checking ticket status before performing settlement [Redmine:#33493]
	- 20151005@Kathy: add more UAT version for testing (UAT1,UAT2,UAT3,UAT4)
	

	Param's Explanation:
	• @matchid: matchid need to refund
	• @IsExcludeBetdaq: Is Exclude betdaq tickets or not
	• @IsSettleAbandonedMatch: Is Settlement for Abandoned/postponed match or not
	BetDaq account: 
				custid	--- username	-	roleid
				50057	---	BQUS888		-	1
				879241	---	BQUSMLB		-	1
				103873	---	BQUSNBA		-	1
				78761	---	ITibc101	-	1
				1688156	---	MTEST0101	-	2
				851668  --- BDUS01      -   1
				878902  --- BDUS016     -   1
	*/
BEGIN
	SET NOCOUNT ON
	DECLARE  @matchcode nvarchar(50)
			,@sporttype int
			,@leagueid int
			,@sqlCommand NVARCHAR(500)
			,@procName nvarchar(50)	
			,@Action VARCHAR(10)

	SELECT   @matchcode = m.matchcode
			,@sporttype = m.sporttype
			,@leagueid = m.leagueid
			,@Action = 'BetDaq'
	FROM match m with(NOLOCK)
	where m.matchid = @MatchId

	IF @@ROWCOUNT = 0 
	BEGIN
		SELECT	 @ErrCode	= 1001001
				,@ErrMsg	= 'Match does not exist!'	
		RETURN
	END 

	IF EXISTS (SELECT 1 from Single_Calculate_Queue with(NOLOCK) WHERE matchid = @matchid AND IsCalculating IN (0,1) )
		OR EXISTS (SELECT 1 from Parlay_Calculate_Queue with(NOLOCK) WHERE matchid = @matchid AND IsCalculating IN (0,1))
	BEGIN 
		SELECT	 @ErrCode	= 1001003
				,@ErrMsg	= 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'	
		RETURN
	END 
	
	-- check waiting ticket
				EXEC NAP_Admin_Settlement_Checking
		@MatchId = @MatchId
		,@Action = @Action
		,@Mode = 'REFUND'
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT
	IF @ErrCode <> 0
	BEGIN
		SELECT @ErrCode
			,@ErrMsg
		
		RETURN
	END
	
	SELECT   @ErrCode = 0
			,@ErrMsg = ''
			,@procName = OBJECT_NAME(@@procid)
			,@sqlCommand = 'EXEC [dbo].[NAP_Admin_Settlement_Refund_BetDaq] @matchid = ' + CONVERT(NVARCHAR(50),@MatchId) +
								 ', @creator = ' + CONVERT(NVARCHAR(50),@AdminId) + 
								 ', @IP = ''' + CONVERT(NVARCHAR(50),@IP) + '''' +
								 ', @ErrCode = @ErrCode OUTPUT' +
								 ', @ErrMsg = @ErrMsg OUTPUT' 

	IF (@procName LIKE '%_xtest' OR @procName LIKE '%_xpre' OR @procName LIKE '%_UAT_') -- UAT1 -->UAT9
	BEGIN
		BEGIN TRY
			EXEC sys.sp_executesql @sqlCommand
				,N'@ErrMsg VARCHAR(400) OUTPUT, @ErrCode int OUTPUT'
				,@ErrMsg = @ErrMsg OUTPUT
				,@ErrCode = @ErrCode OUTPUT
		END TRY

		BEGIN CATCH
			SELECT   @ErrMsg = @ErrMsg + ISNULL(ERROR_MESSAGE(),'')
					,@ErrCode = @ErrCode
			RETURN
		END CATCH
	END 
	ELSE
	BEGIN
		INSERT INTO Single_Calculate_Queue(matchid, matchcode, IsCalculating, LeagueID, SportType, AdminId, IP, Action, sqlCommand)
		SELECT @MatchId, @matchcode, 0, @leagueid, @sporttype, @AdminId, @IP, @Action, @sqlCommand
	END
END


GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT VIEW DEFINITION ON [dbo].[NAP_Admin_Settlement_Refund_BetDaq_Push] TO [vnteam]
GO 
 GRANT EXECUTE ON [dbo].[NAP_Admin_Settlement_Refund_BetDaq_Push] TO [bodbAdminNet]
GO 
