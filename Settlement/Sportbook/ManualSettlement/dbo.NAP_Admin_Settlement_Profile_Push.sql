/*<info serverAlias="DBCTG-bodb02,DBSID-bodb02,DBSIC-bodb02" executers="wsv_nap,Dot_Casino" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Profile_Push]
	 @AdminId			INT				
	,@MatchId			INT
	,@SelectedResources	VARCHAR(MAX)	 
	,@Action			VARCHAR(10)		= 'CAL'
	,@IP				VARCHAR(15)		= ''
	,@IsReSettledTickets BIT			= 1
	,@BetStatus			NVARCHAR(50)	= NULL
	,@IsLeader			BIT				= 0
	,@IsAuto			BIT				= 0
	,@IsDirectly		BIT				= 0
	,@ChildMatchIds		VARCHAR(200)	= NULL
	,@RefResultStatus	TINYINT			= 0
	,@BroadcastSessionId	VARCHAR(50)		= NULL
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			NVARCHAR(200)	= ''	OUTPUT
	,@AutoType			TINYINT			= 0
	,@DeterminedType	BIGINT			= 0
	,@AutoSourceInfo	VARCHAR(MAX)	= NULL
	,@IsPingoal			BIT				= 0
	,@IsSettleRelated	BIT				= 0
	,@RemarkInfo		VARCHAR(MAX)	= NULL
AS
/*	Creator: 20180821@Vicky
	Task: Settlement for sport in profile
	DB: DBTXN/BODB02
	
	Revisions:
		- 20180801@Vicky: Incorporate eSports 2.0 [Redmine #95874]
		- 20200210@Sol: Settlement with Ticket Exclusion for Other Sports - Add new param @IsReSettledTickets - [Redmine:#127698]
		- 20200320@Sol: Settlement with Ticket Exclusion for Other Sports - Tennis - Added new param @Betstatus - [Redmine:#129316]
		- 20200401@Sol: HotFix - Don't write error message on Userlog table when the match is being locked by other actions - [Redmine:#129165]
		- 20200804@Kathy: Add new param to indicate calculation action by leader or not for Esport [Redmine:#136931]
		- 20201111@Louisa: Prevent process if SettlementStatus turn on bit 1,2,3,5,7 [Redmine:#143441]
		- 20201113@Louisa: Check Hold Result [Redmine:#135097]
		- 20210121@Kathy: Cricket AIO [Redmine:#148870]
		- 20210514@Kathy: Incorporate Saba Soccer PinGoal [Redmine:#155052]
		- 20210611@Louisa: Beach Volleyball [Redmine:#156541]
		- 20210729@Louisa: Auto Settle Cricket [Redmine:#154586]
		- 20210811@Louisa: SOP Refund for Tennis, E-Sports [Redmine:#159270]
		- 20210514@Kathy: settle parlay ticket [Redmine:#154737]
		- 20210906@Louisa: Settle by profile for Volleyball [Redmine:#160478]
		- 20211025@Louisa: SOP Refund for Badminton, Basketball, Cricket [Redmine:#163574]
		- 20211120@Helen: Pingoal issue - get match from dbpro [Redmine:#164940]
		- 20220126@Kathy: Settlement - Incorporate Saba Basketball PinGoal [Redmine:#167926]
		- 20220224@Kathy: Settle Saba Basketball PinGoal directly [Redmine:#169042]
		- 20220309@Louisa: Auto settle Volleyball [Redmine:#168346]
		- 20220414@Louisa: write log for @RefResultStatus [Redmine:#169958]
		- 20220512@Louisa: Auto settle and Auto refund Badminton [Redmine:#171676]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
		- 20221201@Louisa: PinGoal Esports[Redmine:#180808]
		- 20230328@Aries: Support Auto Payout for Main Tennis Matches [Redmine: #182329]
		- 20230616@Kathy: Migrate NetPosition API & Services to NAP Settlement System [Redmine:#187311]
		- 20230719@Kathy: Remove unused param [Redmine:#187311]
		- 20230515@Aries: Apply Settle Determined for Basketball [Redmine:#175202]
		- 20230808@Aries: Enhance Auto Refund for Tennis Matches [Redmine:#189433]
		- 20231002@Aries: Apply Auto Payout for Cricket by using TheSports Provider  [Redmine: #195768]
		- 20231214@Aries: Result Amendment [Redmine: #196401]
		- 20240328@Louisa: fix issue Auto ES cannot pass data into queue single [Redmine: #203079]
		- 20240305@Aries: Direct Payout for the Fantasy Match of Basketball [Redmine:#199768]
		- 20240409@Aries: Enhance Refund Game Winner matches for Tennis [Redmine: #203638]
		- 20240604@Aries: Support calculate interval child-matches for Table Tennis (SOP) [Redmine:#202100] 
		- 20240718@Kathy: Implement AiO for Baseball [Redmine:#206154]

	Param's Explanation:
		  @SelectedResources: <Resources>
						    	<Resource Id="M1" Home="1" Away="3" />
						    	<Resource Id="M2" Home="2" Away="4" />
						      </Resources>
		 @RefResultStatus ( detect by Web )
				 1: no reference result exist (result not yet confirmed or not exists Provider score)
				 2: values inconsistency
		@AutoType:
				0: None
				1: Auto Payout
				2: Direct Payout
				3: Refund Tennis GW
				4: Others
		@DeterminedType: Convert from bit to decimal, the main resources mapping with: 
				Bit1: HT
				Bit2: HTdone 
				Bit3: FT
				Bit4 -> BitN: Interval (Ex: Basketball Bit4-Q1,Bit5-Q2,....  OR  Tennis Bit4-1S,Bit5-1S,..)
*/		
BEGIN
	SET NOCOUNT ON 

	DECLARE	 @matchcode				NVARCHAR(50)
			,@sporttype				INT
			,@leagueid				INT
			,@LeagueGroupId			INT
			,@sqlCommand			NVARCHAR(MAX)
			,@procName				SYSNAME	= OBJECT_NAME(@@procid)
								  
	SELECT	 @matchcode		= m.matchcode
			,@sporttype		= m.sporttype
			,@leagueid		= m.leagueid
			,@LeagueGroupId	= l.LeagueGroupID
	FROM	DBPRO.bodb02.dbo.match m WITH(NOLOCK)
		INNER JOIN dbo.League l WITH(NOLOCK)
			ON m.leagueid = l.leagueid
	WHERE	m.matchid = @MatchId

	SELECT	 @ErrCode		= 0
			,@ErrMsg		= ''
			,@sqlCommand	= 'EXEC [dbo].[NAP_Admin_Settlement_Profile] @Matchid = ' + CONVERT(NVARCHAR(50), @MatchId) 
															+ ', @creator = ' + CONVERT(NVARCHAR(50), @AdminId) 
															+ ', @SelectedResources = ''' + CONVERT(VARCHAR(MAX), @SelectedResources) + ''''
															+ ', @Action = ''' + CONVERT(NVARCHAR(50), @Action) + ''''
															+ ', @IP = ''' + CONVERT(VARCHAR(15), @IP) + '''' 
															+ ', @IsReSettledTickets = ' + CONVERT(NVARCHAR(1), @IsReSettledTickets)
															+ ', @IsAuto = ' + CONVERT(NVARCHAR(1), @IsAuto)
															+ ', @betstatus = ' + CASE WHEN @BetStatus IS NULL THEN 'NULL' 
                                                                                     ELSE 'N''' + CONVERT(NVARCHAR(50), @BetStatus) + '''' END 
															+  CASE 
																	WHEN @IsLeader = 1 THEN ', @IsLeader = ' + CONVERT(NVARCHAR(50), @IsLeader) 
																ELSE '' 
															END
															+ CASE 
																	WHEN @IsDirectly = 1 THEN ', @IsDirectly = ' + CONVERT(NVARCHAR(1), @IsDirectly)
																ELSE ''
															END
															+ CASE 
																	WHEN @ChildMatchIds IS NOT NULL THEN ', @ChildMatchIds = ''' + CONVERT(NVARCHAR(200),@ChildMatchIds ) + ''''
																	ELSE ''
															END
															+ CASE WHEN @RefResultStatus > 0 THEN ', @RefResultStatus  = ' + CONVERT(NVARCHAR(1), @RefResultStatus) ELSE '' END   
															+ CASE WHEN @DeterminedType > 0 THEN  ', @DeterminedType  = '  + CONVERT(NVARCHAR(50), @DeterminedType) ELSE '' END   
															+ CASE WHEN @BroadcastSessionId IS NOT NULL 
																	THEN ', @BroadcastSessionId = ''' + @BroadcastSessionId + ''''
																	ELSE '' END
															+ ', @AutoType = ' + CONVERT(VARCHAR(5), @AutoType) 
															+ IIF(@AutoSourceInfo IS NOT NULL,', @AutoSourceInfo =  ''' + @AutoSourceInfo + '''','') 
															+ ', @IsPingoal = ' + CONVERT(NVARCHAR(1), @IsPingoal)
															+ ', @IsSettleRelated = ' + CONVERT(NVARCHAR(1), @IsSettleRelated)
															+ IIF(@RemarkInfo IS NOT NULL,', @RemarkInfo =  ''' + @RemarkInfo + '''','') 
															+ ', @ErrCode = @ErrCode OUTPUT' 
															+ ', @ErrMsg = @ErrMsg OUTPUT'
		

	IF (@procName LIKE '%_xtest' OR @procName LIKE '%_xpre' OR @procName LIKE '%_UAT_') -- For testing on UAT -- UAT1 -->UAT9
		OR @IsPingoal = 1 -- Soccer ,Esport RedCat, Basketball   PinGoal
	BEGIN
		BEGIN TRY
			EXEC sys.sp_executesql @sqlCommand
				,N'@ErrMsg VARCHAR(400) OUTPUT, @ErrCode int OUTPUT'
				,@ErrMsg	= @ErrMsg OUTPUT
				,@ErrCode	= @ErrCode OUTPUT
		END TRY

		BEGIN CATCH
			SELECT  @ErrMsg	= @ErrMsg + ISNULL(ERROR_MESSAGE(),'')
				   ,@ErrCode= @ErrCode
			RETURN
		END CATCH
	END
	ELSE
	BEGIN
		INSERT INTO Single_Calculate_Queue (
			matchid
			,matchcode
			,IsCalculating
			,LeagueID
			,SportType
			,AdminId
			,IP
			,Action
			,sqlCommand
			,BroadcastSessionId
			)
		SELECT @MatchId
			,@matchcode
			,0 AS IsCalculating
			,@leagueid
			,@sporttype
			,@AdminId
			,@IP
			,@Action
			,@sqlCommand
			,@BroadcastSessionId

		IF @sportType = 50 
		BEGIN
			UPDATE SettlementResultHistory  WITH(UPDLOCK, ROWLOCK)
			SET  StatusID = 100
				,RepUpdateTime = SYSDATETIME()
			WHERE Matchid = @MatchId
				AND SessionId = @BroadcastSessionId
				AND StatusID IS NULL
		END
	END

END

GO 
