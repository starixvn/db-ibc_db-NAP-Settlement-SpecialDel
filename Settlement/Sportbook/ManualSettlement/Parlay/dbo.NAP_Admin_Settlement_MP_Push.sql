/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_MP_Push] (
	@MatchIds 	VARCHAR(4000)
	,@AdminId 	INT
	,@Action 	VARCHAR(20) = 'CAL'
	,@IP 		VARCHAR(15) = ''
	,@ErrCode 	INT = 0 OUTPUT
	,@ErrMsg 	NVARCHAR(200) = '' OUTPUT
	)
AS
/*	Creator: 20140213@Kathy
	Task: Main SP for Mix parly settlement
	DB: DBTXN/BODB02
	ORIGINAL: Admin_Settlement_MP

	Revisions:		
		- 20140506@Kathy: Don't allow to calculate exists matches in queue
		- 20140512@Kathy: allow to execute undo action without score [Redmine:#14449]
		- 20141117@Jamie: Change ErrCode [Redmine:#23034]		
		- 20150401@Kathy: Add checking ticket status before performing settlement [Redmine:#33493]		
		- 20150922@Johnson: check result status from ResultDetail [Redmine: #43806]
		- 20151002@Kathy: add more UAT version for testing (UAT1,UAT2,UAT3,UAT4)
		- 20160429@Kathy: Enhance performance [Redmine:#52426]
		- 20160714@Kathy: Add checking SystemSettings before doing Parlay Settlement on UAT
		- 20160801@Patrick: Auto Payout - User can cal MP before calculating FT FGLG [Redmine: #61767]
		- 20161125@Bobby: #67822 - check single and parlay ticket for AUTO bet types
		- 20170313@Kathy: Check betstatus result for bettype 14,127 to notify user do CAL FGLG [Redmine:#73218]
		- 20170215@Kathy: Basketball All-in-One [Redmine:#71372]
		- 20170609@Kathy: Early settlement for BAIO [Redmine:#77835]
		- 20170815@Kathy: Using table ResultDetail to store FGLG result instead of betstatus [Redmine:#81308]
		- 20171204@Kathy: Allow to settle parlay in case Early Settled bettypes have only Single tickets [Redmine:#87544]
		- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
		- 20180801@Vicky: Incorporate eSports 2.0 [Redmine #95874]
		- 20190218@Kathy: Do not allow to settle match which has eventdate = movebet day [Redmine:#108768]
		- 20190517@Sol: Tuning performance [Redmine:#112904]
		- 20190620@Kathy: Remove auto betradar bettypes [Redmine:#109584]
		- 20190725@Sol: Incorporate PHAIO 4b - Implement [ResourceID] = '09' to Settle PH4B Bet Types [Redmine:#115232]
		- 20190924@Sol: Incorporate BMAIO - modified sp to support ResultDetailOS [Redmine:#120324]
		- 20200115@Max: Enhance SPs [Redmine: #127031]
		- 20200318@Sol: Settlement with Ticket Exclusion for Other Sports - Tennis - [Redmine:#129316]
		- 20200515@Kathy: Settlement Exclusion for Parlay [Redmine:#134103]
		- 20200703@Kathy: Incorporate New Bet Types of Basketball - Phase 2 [Redmine:#135846]
		- 20201111@Louisa: Prevent process if SettlementStatus turn on bit 1,2,3,5,7 [Redmine:#143441]
		- 20210203@Louisa: Cricket AIO [Redmine:#148870]
		- 20210524@Louisa: SOP for Badminton, Basketball [Redmine:#155361,#155360]
		- 20210611@Louisa: Beach Volleyball [Redmine:#156541]
		- 20210729@Louisa: Auto Settle Cricket [Redmine:#154586]
		- 20210514@Kathy: settle parlay ticket [Redmine:#154737]
		- 20211022@Kathy: Support Settlement Exclusion for Parlay Sub Tickets [Redmine:#163172]
		- 20220315@Kathy: Change to use STRING_SPLIT [Redmine:#166454]
		- 20220509@Kathy: Change to use STRING_SPLIT on DBPRO [Redmine:#172461]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
		
	Param's Explanation:		
		
*/
SET NOCOUNT ON

BEGIN
	DECLARE  @procName nvarchar(50)	
			,@matchid int
			,@matchcode nvarchar(50)
			,@ParentIds VARCHAR(MAX) = ''
			
	DECLARE @subErrCode		INT
			,@subErrMsg		NVARCHAR(200)
		
	DECLARE @tblBettype TABLE ( matchid INT
						  ,Sporttype SMALLINT
						  ,Bettype SMALLINT
						  ,Betcheck NVARCHAR(50)
						  ,ResourceID VARCHAR(20)
						 )
						 
	Create table #Match (matchid INT
						  ,matchcode NVARCHAR(50)
						  ,fth SMALLINT
						  ,fta SMALLINT
						  ,hth SMALLINT
						  ,hta SMALLINT
						  ,sporttype SMALLINT
						  ,SettlementStatus	TINYINT
						  ,ParentId INT )
	
	SELECT	 @ErrCode = 0
			,@ErrMsg = ''
			,@procName = OBJECT_NAME(@@procid)
			,@subErrCode = 0
			,@subErrMsg = ''
	
	INSERT INTO #Match ( matchid, sporttype)
	SELECT matchid
		,sporttype
	FROM DBPRO.bodb02.dbo.Match m WITH (NOLOCK)
		INNER JOIN (SELECT value FROM STRING_SPLIT(@matchids , ',')) tm
			ON m.matchid = tm.value		

	IF EXISTS (	SELECT TOP 1 1	FROM #Match	)
	BEGIN
		IF @procName LIKE '%_xtest' or @procName LIKE '%_xpre' OR @procName LIKE '%_UAT_' -- UAT1 -->UAT9
		BEGIN

			WHILE(1 = 1)
			BEGIN
				SELECT TOP 1 @matchid = matchid
						,@matchcode = matchcode
				FROM #Match

				IF @@ROWCOUNT = 0
					BREAK
				
				IF EXISTS (SELECT TOP 1 1 FROM dbo.SystemSettings WHERE VName = 'isCalculatingParlay' AND VValue = '0')
					AND NOT EXISTS (SELECT TOP 1 1 FROM dbo.ParlayLocking)
				BEGIN
					UPDATE dbo.SystemSettings WITH (ROWLOCK, UPDLOCK)
							SET VValue = 1
					WHERE VName = 'isCalculatingParlay'
					
				END
				ELSE
				BEGIN
					SELECT	@ErrCode = 1000000
						,@ErrMsg = 'Another parlay settlement is in progress or some parlay tickets are being deleted, please wait a few seconds until the on-going process has finished and try again.'
					RETURN	
				END
				
				BEGIN TRY
					EXEC [NAP_Admin_Settlement_MP] @matchid = @matchid
						,@creator = @AdminId
						,@action  = @action
						,@IP      = @IP
						,@ErrCode = @subErrCode 	OUTPUT
						,@ErrMsg  = @subErrMsg   	OUTPUT
				END TRY
				BEGIN CATCH			
					UPDATE dbo.SystemSettings WITH (ROWLOCK, UPDLOCK)
						SET VValue = 0
					WHERE VName = 'isCalculatingParlay'
				
					SELECT @ErrMsg  = @matchcode + ': ' + ISNULL(ERROR_MESSAGE(),'')
						  ,@ErrCode = @@error
					
					RETURN
				END CATCH
				
				IF @subErrCode > 0
					SELECT @ErrMsg = @ErrMsg + ' ' + @matchcode + ':' + @subErrMsg + ', '
				
				UPDATE dbo.SystemSettings WITH (ROWLOCK, UPDLOCK)
						SET VValue = 0
				WHERE VName = 'isCalculatingParlay'

				DELETE 
				FROM #Match
				WHERE matchid = @matchid
			END
			
		END
		ELSE
		BEGIN		
			INSERT INTO dbo.Parlay_Calculate_Queue (matchid, isCalculating, creator, ip, starttime, action, Sporttype)
			SELECT matchid, 0, @AdminId, @IP, CURRENT_TIMESTAMP, @action, sporttype
			FROM #Match
		END
	END
END
GO

