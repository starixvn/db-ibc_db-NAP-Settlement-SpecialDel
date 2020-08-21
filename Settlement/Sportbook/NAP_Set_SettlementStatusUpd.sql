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
		
	Parameters Explanation:    
		@Type: TINYINT
			+ 1: IsPending
			+ 2: IsUndecided
			+ 3: IsUnderSettlement	
			+ 4: IsSystemSettlement
			+ 5: IsMTDHold
			+ 6: IsRefund
	
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @SettlementStatus	TINYINT

			--write log
			,@Starttime			DATETIME
			,@ActionId			INT
			,@LogData			NVARCHAR(200) 
			,@Remark			VARCHAR(500)
	
	SELECT	@Starttime = GETDATE()
			,@ActionId = CASE
							WHEN @Type = 1 THEN 81002
							WHEN @Type = 2 THEN 81003
							WHEN @Type = 3 THEN 81004
							WHEN @Type = 5 THEN 81005
							WHEN @Type = 6 THEN 81018
							ELSE NULL
						END

	UPDATE m 
		SET @SettlementStatus = ISNULL(SettlementStatus, 0)
			,SettlementStatus = CASE 
									WHEN @IsEnabled = 1 THEN @SettlementStatus | POWER(2, @Type - 1)
									ELSE @SettlementStatus & (~POWER(2, @Type - 1))
								END
	FROM	dbo.match m WITH(ROWLOCK, UPDLOCK)
	WHERE	m.matchid = @MatchId

	IF @Type BETWEEN 1 AND 2
	BEGIN
		UPDATE	mr 
			SET isPending = CASE WHEN @Type = 1 THEN @IsEnabled ELSE mr.isPending END
				,isUndecided = CASE WHEN @Type = 2 THEN @IsEnabled ELSE mr.isUndecided END
		FROM	dbo.match_remark mr WITH(ROWLOCK, UPDLOCK)
		WHERE	mr.matchid = @MatchId
	END
			
	SELECT @LogData = 'Update settlement status of MatchID = ' + CAST(@MatchId AS VARCHAR(20)) + ' with Type = ' + CAST(@Type AS VARCHAR(2))

	EXEC dbo.WriteLog_UserLog @UserID = @AdminId, @Doing = @LogData

	IF @Type IN (1,2,3,5,6)
	BEGIN
		SELECT @Remark = 'Turn ' + CASE WHEN @IsEnabled = 1 THEN 'on ' ELSE 'off ' END
						 + CASE
								WHEN @Type = 1 THEN 'Pending '
								WHEN @Type = 2 THEN 'Undecided '
								WHEN @Type = 3 THEN 'Under Settlement '
								WHEN @Type = 5 THEN 'MTD Hold '
								WHEN @Type = 6 THEN 'Refund '
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
