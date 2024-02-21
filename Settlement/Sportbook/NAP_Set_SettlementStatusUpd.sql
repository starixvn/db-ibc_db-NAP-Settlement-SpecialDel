/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet,dot_admin" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Set_SettlementStatusUpd
	@MatchId	INT
	,@Type		TINYINT = 0
	,@IsEnabled BIT		= 0
	,@AdminId	INT
	,@IP		VARCHAR(20)	= ''
	,@HoldInfo	VARCHAR(MAX) = ''
	,@ChildMatchList VARCHAR(500)	= '' OUTPUT  --use for write log
	,@ErrCode	INT					= 0	OUTPUT
	,@ErrMsg 	NVARCHAR(200)		= '' OUTPUT
AS
/*
	Created: Kathy
	Date: 20180926
	Task : Update settlement status
	DB: DBPRO/bodb02

	Revisions:
		- 20180926@Kathy: Add New Status "Result Pending" and "Under Settlement"  [Redmine:#102028]
		- 20181127@Vicky: Add MTD Hold status [Redmine: #104948]
		- 20200821@Kathy: Add log for refund flag"  [Redmine:#140092]
		- 20201027@Louisa: Add new settlement status - Hold Key bit[7] - [Redmine:#143441]
		- 20220531@Louisa: Turn off Auto Instant Setting if MTD Hold bit[5] is on [Redmine:#173360]
		- 20230915@Louisa: Remove code WriteLog_UserLog [Redmine:#193920]
		- 20240110@Louisa: Support hold child match [Redmine:#198710]

	Parameters Explanation:    
		@Type: TINYINT
			+ 4: IsSystemSettlement
			+ 6: IsRefund
			+ 7: Hold Key

	@HoldInfo = '<root>
					<r t="1" s="true" />			--Turn on Pending bit[1]
					<r t="2" s="true" child="true"/> --Turn on Undecided, also apply to Child Match bit[2]
					<r t="4" s="false" />			--Turn off UnderSettlement  bit[3]
					<r t="16" s="false" />			--Turn off MTD Hold bit[5]
				</root>'
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @SettlementStatus	TINYINT
			,@AutoSetting		TINYINT
			,@Starttime		DATETIME = GETDATE()
			,@Remark		VARCHAR(500)
			,@handle		INT
			,@ActionID		INT

	DECLARE @tmpHoldSetting TABLE (MatchID INT, ParentID INT, TurnOn TINYINT, TurnOff TINYINT, LV TINYINT)

	IF @Type IN (4, 6, 7 )
	BEGIN	
		UPDATE m 
			SET @SettlementStatus = ISNULL(SettlementStatus, 0)
				,SettlementStatus = CASE 
										WHEN @IsEnabled = 1 THEN @SettlementStatus | POWER(2, @Type - 1)
										ELSE @SettlementStatus & (~POWER(2, @Type - 1))
									END
		FROM	dbo.match m WITH(ROWLOCK, UPDLOCK)
			INNER JOIN dbo.League l WITH(NOLOCK) ON m.leagueId = l.leagueid
		WHERE	m.matchid = @MatchId

		IF @Type IN ( 6,7)
		BEGIN
			SELECT @ActionID =  CASE @Type WHEN 6 THEN 81018
											WHEN 7 THEN 81019
								END

			SELECT @Remark = 'Turn ' + CASE WHEN @IsEnabled = 1 THEN 'on ' ELSE 'off ' END
							 + CASE WHEN @Type = 6 THEN 'Refund '
									WHEN @Type = 7 THEN 'Hold Key '
									END
							 + 'on match: '
							 + CAST(@MatchId AS VARCHAR) + '<br/> '
							 + 'Duration: ' + CAST(DATEDIFF(MILLISECOND,@Starttime, GETDATE()) AS VARCHAR) + ' ms'
	
			BEGIN TRY
				EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle
					@UserID             = @AdminId
					,@Matchid           = @matchid
					,@ActionID			= @ActionID
					,@Remark            = @Remark
					,@IP                = @IP
			END TRY
			BEGIN CATCH
				SELECT @Remark = @Remark + ' ErrMsg=' + left(error_message(), 250)

				EXEC DBTXN.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle
					@UserID             = @AdminId
					,@Matchid           = @matchid
					,@ActionID          = @ActionID
					,@Remark            = @Remark
					,@IP                = @IP
			END CATCH
		END

	END
	ELSE 
	BEGIN TRY
		EXEC sp_xml_preparedocument @handle OUTPUT, @HoldInfo

		; WITH cte_recursion AS 
		(
			SELECT  m.matchid, m.ParentID, 0 AS LV
			FROM dbo.match m WITH(NOLOCK)
			WHERE matchid = @MatchId
		
			UNION ALL 
			SELECT  m.matchid, m.ParentID, LV+1
			FROM dbo.match m WITH(NOLOCK)
				INNER JOIN cte_recursion d
				ON m.ParentID = d.matchid	 
		)
		---get all related matches
		, cte_AllMatch ( MatchID, ParentID, LV) AS 
		(
			SELECT m.MatchID, ParentID, LV
			FROM cte_recursion m
		)
		,cte_WebResources (MatchID, ParentID, HoldType, IsEnable, IsApplyChildMatch, LV) 
		AS 
		(
			SELECT   d.matchid
					,d.ParentID
					,setting.t as HoldType
					,setting.s as IsEnable
					,setting.child as IsApplyChildMatch
					,d.LV
			FROM cte_AllMatch d
				CROSS APPLY (	SELECT t, s, isnull(child,0) as child
								FROM OPENXML(@handle,'root/r',1) WITH(	t INT ,s BIT ,child	BIT	) AS tbl --- will parse value "true"/"false" to 1/0 with datatype is BIT
							) setting
		)

		INSERT INTO @tmpHoldSetting (MatchID, ParentID, TurnOn, TurnOff, LV)
		SELECT   w.matchid
				,w.ParentID
				,SUM(CASE WHEN (w.LV =0 OR w.IsApplyChildMatch = 1) AND IsEnable = 1 THEN HoldType ELSE 0 END) as TurnOn
				,SUM(CASE WHEN (w.LV =0 OR w.IsApplyChildMatch = 1) AND IsEnable = 0 THEN HoldType ELSE 0 END) as TurnOff 
				,w.LV
		FROM cte_WebResources w
		WHERE w.LV = 0 OR IsApplyChildMatch = 1
		GROUP BY w.matchid, w.ParentID, LV

		EXEC sp_xml_removedocument @handle

		UPDATE m 
			SET @SettlementStatus = ISNULL(SettlementStatus, 0)
				,@AutoSetting	  = ISNULL(m.AutoSetting, l.AutoSetting)
				,SettlementStatus =  @SettlementStatus &(~TurnOff) | TurnOn 
				,AutoSetting = CASE WHEN TurnOn & 16 > 0 AND ISNULL(@AutoSetting,0) & 2 = 2 THEN  @AutoSetting ^ (POWER(2,1)) --Turn off Auto Instant if MTD Hold is on
									ELSE m.AutoSetting
									END
		FROM	dbo.match m WITH(ROWLOCK, UPDLOCK)
			INNER JOIN dbo.League l WITH(NOLOCK) 
				ON m.leagueId = l.leagueid
			INNER JOIN @tmpHoldSetting h
				ON m.matchid = h.MatchID
		
		UPDATE	mr 
			SET isPending = CASE WHEN 1 & h.TurnOn = 1 THEN 1
								 WHEN 1 & h.TurnOff = 1 THEN 0
								 ELSE mr.isPending
								 END
				,isUndecided = CASE WHEN 2 & h.TurnOn = 2 THEN 1
									WHEN 2 & h.TurnOff = 2 THEN 0
									ELSE mr.isUndecided
									END
		FROM	dbo.match_remark mr WITH(ROWLOCK, UPDLOCK)
		INNER JOIN @tmpHoldSetting h
				ON mr.matchid = h.MatchID

		SELECT @ChildMatchList = ( SELECT MatchID AS 'm', ParentID AS 'p' FROM @tmpHoldSetting WHERE LV > 0 FOR JSON AUTO )

	END TRY
	BEGIN CATCH
		SELECT	 @ErrMsg  = ERROR_MESSAGE()
				,@ErrCode = @@ERROR

		RETURN
	END CATCH
	
END
GO
