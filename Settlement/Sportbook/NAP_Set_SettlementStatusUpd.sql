/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet,dot_admin" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [NAP_Set_SettlementStatusUpd]
	@MatchId	INT
	,@Type		TINYINT
	,@IsEnabled BIT
	,@AdminId	INT
	,@IP		VARCHAR(20)	= ''

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
		- 20240221@Louisa: Revert Code [Redmine:#198710]

	Parameters Explanation:    
		@Type: TINYINT
			+ 1: IsPending
			+ 2: IsUndecided
			+ 3: IsUnderSettlement	
			+ 4: IsSystemSettlement
			+ 5: IsMTDHold
			+ 6: IsRefund
			+ 7: Hold Key
	
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @SettlementStatus	TINYINT
			,@AutoSetting		TINYINT

			--write log
			,@Starttime			DATETIME
			,@ActionId			INT
			,@Remark			VARCHAR(500)
	
	SELECT	@Starttime = GETDATE()
			,@ActionId = CASE
							WHEN @Type = 1 THEN 81002
							WHEN @Type = 2 THEN 81003
							WHEN @Type = 3 THEN 81004
							WHEN @Type = 5 THEN 81005
							WHEN @Type = 6 THEN 81018
							WHEN @Type = 7 THEN 81019
							ELSE NULL
						END

	UPDATE m 
		SET @SettlementStatus = ISNULL(SettlementStatus, 0)
			,@AutoSetting	  = ISNULL(m.AutoSetting, l.AutoSetting)
			,SettlementStatus = CASE 
									WHEN @IsEnabled = 1 THEN @SettlementStatus | POWER(2, @Type - 1)
									ELSE @SettlementStatus & (~POWER(2, @Type - 1))
								END
			, AutoSetting = CASE WHEN @Type = 5 AND @IsEnabled = 1 AND ISNULL(@AutoSetting,0) & 2 = 2 THEN  @AutoSetting ^ (POWER(2,1)) --Turn off Auto Instant if MTD Hold is on
								 ELSE m.AutoSetting
							END
	FROM	dbo.match m WITH(ROWLOCK, UPDLOCK)
		INNER JOIN dbo.League l WITH(NOLOCK) ON m.leagueId = l.leagueid
	WHERE	m.matchid = @MatchId

	IF @Type BETWEEN 1 AND 2
	BEGIN
		UPDATE	mr 
			SET isPending = CASE WHEN @Type = 1 THEN @IsEnabled ELSE mr.isPending END
				,isUndecided = CASE WHEN @Type = 2 THEN @IsEnabled ELSE mr.isUndecided END
		FROM	dbo.match_remark mr WITH(ROWLOCK, UPDLOCK)
		WHERE	mr.matchid = @MatchId
	END

	IF @Type IN (1,2,3,5,6,7)
	BEGIN
		SELECT @Remark = 'Turn ' + CASE WHEN @IsEnabled = 1 THEN 'on ' ELSE 'off ' END
						 + CASE
								WHEN @Type = 1 THEN 'Pending '
								WHEN @Type = 2 THEN 'Undecided '
								WHEN @Type = 3 THEN 'Under Settlement '
								WHEN @Type = 5 THEN 'MTD Hold '
								WHEN @Type = 6 THEN 'Refund '
								WHEN @Type = 7 THEN 'Hold Key '
								ELSE ''
							END
						+ 'on match: ' + CAST(@MatchId AS VARCHAR) + '<br/> '
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
GO
