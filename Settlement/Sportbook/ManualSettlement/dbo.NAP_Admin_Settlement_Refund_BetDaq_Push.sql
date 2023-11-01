/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Refund_BetDaq_Push]
	@MatchId int,
	@AdminId int, 	
	@IP varchar(15) = '',
	@BroadcastSessionId VARCHAR(50)	= NULL,
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
	- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
	- 20230817@Kathy: Write log [Redmine:#192311]

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
	
	SELECT   @ErrCode = 0
			,@ErrMsg = ''
			,@procName = OBJECT_NAME(@@procid)
			,@sqlCommand = 'EXEC [dbo].[NAP_Admin_Settlement_Refund_BetDaq] @matchid = ' + CONVERT(NVARCHAR(50),@MatchId) +
								 ', @creator = ' + CONVERT(NVARCHAR(50),@AdminId) + 
								 ', @IP = ''' + CONVERT(NVARCHAR(50),@IP) + '''' +
								 CASE WHEN @BroadcastSessionId IS NOT NULL 
									THEN ', @BroadcastSessionId = ''' + @BroadcastSessionId + ''''
									ELSE '' END +
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
		INSERT INTO Single_Calculate_Queue(matchid, matchcode, IsCalculating, LeagueID, SportType, AdminId, IP, Action, sqlCommand, BroadcastSessionId)
		SELECT @MatchId, @matchcode, 0, @leagueid, @sporttype, @AdminId, @IP, @Action, @sqlCommand, @BroadcastSessionId
	END
END

GO