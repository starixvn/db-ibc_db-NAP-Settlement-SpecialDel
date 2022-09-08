/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_AutoUnmark_Update]
(
	@Matchid		 INT,
	@TransIds		 VARCHAR(MAX) ='',
	@Bettype		 SMALLINT,
	@MarkedBy		 INT,
	@Betid			 BIGINT = NULL,
	@UserId          INT           = 0,
    @IP              VARCHAR(15)   = NULL
)
AS
/*	Created by: Max
	Date 20200212
	Task: Abnormal Void Bets Automation [Redmine: #128359]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20200212@Max: Create new SP [Redmine: #128359]
		- 20200221@Max: HotFix [Redmine: #128924]
		- 20200226@Max: Confirm Auto Unmark Group By User [Redmine: #129219]
		- 20200226@Max: Auto Void Winning Bets - [Redmine: #129184]
		- 20200312@Max: Hotfix - Confirm Auto Unmark not work for Early Settlement Bettype - [Redmine: #130279]
		- 20200313@Max: Support Quarter X, Y, Z on Auto Unmark Page - [Redmine: #130322]
		- 20200403@Raymond: Auto void for Tennis [Redmind: #131516]	
		- 20200406@Helen:[TVS] Auto Void winning bet  for Tennis + hotfix [Redmine:#131516]
		- 20200415@Raymond: Mark/Unmark Parlay Tickets and remaing sports [Redmine: #131670]
		- 20200615@Max: HotFix - Do not settle after confirm auto unmark - Remove check StatusId in Queue - [Redmine: #135864]
		- 20200727@Max: [TVS] Danger Accept Bets Issue Type [Redmine: #135947]
		- 20201007@Max: Integrate new bet type Time Machine OU [Redmine: #143032]
		- 20210329@Max: TVS - Correct Ticket on DBTP [Redmine: #151954]
		- 20210420@July: Integrate new bettype Time Machine HDP  [Redmine:#153433]
		- 20220628@Max: Confirm Auto Unmark - Auto unmark select Error converting data type nvarchar to bigint [Redmine: #172277]
		- 20220829@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]

	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @UnmarkTransids		VARCHAR(MAX)  = ''
	      , @ResettleTransids	VARCHAR(MAX) = '' 
		  , @ErrMsg				NVARCHAR(200) = ''
          , @ErrCode			INT   = 0
	      , @NegativeBalanceUsers VARCHAR(MAX) = ''	

	DECLARE @avaiableProcess BIT
		   ,@isExistMatch BIT
		   ,@IsCalQueue	BIT = 0
		   ,@isExistFM2	BIT = 0
		   ,@spName VARCHAR(500) = OBJECT_NAME(@@PROCID)
		   ,@SiteDBGroupID	SMALLINT = 0
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	DECLARE @tmpMarkedTransIDBatch TABLE (transid BIGINT,statuswinlost TINYINT,IsMixParlay BIT)

	CREATE TABLE #tmpTransid_unmark (transid BIGINT,statuswinlost TINYINT, isFinish INT, IsMixParlay BIT DEFAULT(0))
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	
	--Step 2: Get tranid to unmark
	CREATE TABLE #inputRequestTransId (TransId BIGINT)
	IF @TransIds <> ''
	BEGIN
		INSERT INTO #inputRequestTransId (TransId)
		SELECT value
		FROM STRING_SPLIT(@TransIds, ',')
	END

	-- get list transid to unmark
	INSERT INTO #tmpTransid_unmark (
		transid
		,statuswinlost
		,IsMixParlay
		)
	SELECT mt.TransId
		,b.statuswinlost
		,0
	FROM dbo.MarkedTransaction AS mt WITH (NOLOCK)
		INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = mt.TransId AND b.matchid = mt.MatchId AND b.SiteDBGroupID = @SiteDBGroupID
	WHERE mt.MatchId = @Matchid
		AND mt.bettype = @Bettype
		AND mt.UserId = @MarkedBy
		AND mt.MarkType <> 2
		AND mt.TransId NOT IN (SELECT transid FROM #inputRequestTransId)
		AND b.statusID IN (0, 1)
		AND (
			@Betid IS NULL
			OR (
				@Betid IS NOT NULL
				AND b.betid = @Betid
				)
			)
	UNION
	SELECT bm.TransId
		,NULL
		,1
	FROM dbo.MarkedTransaction AS mt WITH (NOLOCK)
		INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = mt.TransId AND b.matchid = 29 AND b.SiteDBGroupID = @SiteDBGroupID
		INNER JOIN dbo.bettransm AS bm WITH (NOLOCK) ON bm.refno = b.refno AND bm.matchid = mt.MatchId AND bm.SiteDBGroupID = b.SiteDBGroupID
	WHERE mt.MatchId = @Matchid
		AND mt.bettype = @Bettype
		AND mt.UserId = @MarkedBy
		AND mt.MarkType <> 2
		AND bm.statusID IN (0, 1)
		AND (
			@Betid IS NULL
			OR (
				@Betid IS NOT NULL
				AND bm.betcheck = CONVERT(NVARCHAR(100), @Betid)
				)
			)
	
	IF NOT EXISTS (SELECT TOP (1) 1 FROM #tmpTransid_unmark)
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = 'The confirmation is updated successfully. But there is no ticket affected by this action as the remaining marked tickets have to wait for the event result.'
		
		SELECT @ErrCode AS ErrorCode, @ErrMsg AS ErrorMsg
		RETURN
	END
	
	SET @IsCalQueue = ( SELECT TOP (1) 1
							FROM dbo.TicketVoiding_AutoVoidRequest_Queue WITH (NOLOCK)
							WHERE matchid = @MatchId AND RequestId = 0
						)
	WHILE (1 = 1)
	BEGIN
		BEGIN TRY
			
			DELETE @tmpMarkedTransIDBatch
			
			SET @UnmarkTransids = ''
			SET @ResettleTransids = ''
			
			UPDATE TOP(3000) t
				SET isFinish = 1
			OUTPUT deleted.transid, deleted.statuswinlost, deleted.IsMixParlay
			INTO @tmpMarkedTransIDBatch(transid, statuswinlost, IsMixParlay)
			FROM #tmpTransid_unmark t 
			WHERE isFinish IS NULL
		
			IF @@ROWCOUNT = 0 BREAK
			
			SELECT @UnmarkTransids = STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
											FROM @tmpMarkedTransIDBatch
											FOR XML PATH('')
								), 1,1,'')
		
			SELECT @ResettleTransids = STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
											FROM @tmpMarkedTransIDBatch
											WHERE IsMixParlay = 0
											AND statuswinlost IS NOT NULL
											FOR XML PATH('')
								), 1,1,'')
								
			--Step 3: Unmark
			EXEC dbo.Nap_SpecialDelete_MarkedTickets_Update 
				 @TransIds = @UnmarkTransids
				,@UserId = @UserId
				,@IP = @IP

			--Step 4: resettle ticket
			IF @ResettleTransids <> '' AND @IsCalQueue = 1 
			BEGIN
				EXEC [dbo].[TicketVoiding_ReCalculate_Single_PreUpdate]
							@Matchid = @Matchid	,
							@TransIds = @ResettleTransids,
							@UserId  = @UserId,
							@IP = @IP,
							@ErrMsg = @ErrMsg OUTPUT,
							@ErrCode = @ErrCode OUTPUT,
							@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT
			END	
			
		END TRY
		BEGIN CATCH
			SELECT @ErrCode = ERROR_NUMBER(), @ErrMsg = ERROR_MESSAGE()
		END CATCH
	END

	------------------------------------------------------------------------------
	--1. Table error code/msg transid
	SELECT @ErrCode AS ErrorCode
	      ,@ErrMsg AS ErrorMsg			
	      ,@NegativeBalanceUsers AS NegativeBalanceUsers

	DROP TABLE #inputRequestTransId
	DROP TABLE #tblMatchProcess
	DROP TABLE #tmpTransid_unmark
END