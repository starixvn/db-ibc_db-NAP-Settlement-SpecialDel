/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_SB_ErrorHandling @Action VARCHAR(20)
	, @MatchId INT
	, @sqlCommand VARCHAR(MAX)	
	, @ErrMsg VARCHAR(500)
	, @AdminId INT
	, @IP VARCHAR(20)
	, @ActionIDInput INT				= 0
AS
/*
	Created: 20160325@Patrick
	Task: Handle the error when exec sql command
	DB: DBTXN/bodb02
	
	Revisions:
		-20161013@Bobby: #65178 - Implement Instant calculation process
		-20180124@Benjamin: Add @IsAutoInst variable for Auto Instant [Redmine:#86964]
		-20190103@Vicky: Incorporate BetBuilder  [Redmine:#106903]
		-20200108@Max: Instant Settlement for Corner Bettype [Redmine:#124951]
		-20200401@Sol: HotFix - Don't write error message on Userlog table when the match is being locked by other actions - [Redmine:#129165]
		-20200720@Kathy: Extend datatype of @sqlCommand to VARCHAR(MAX) [Redmine:#135846]
*/
BEGIN
	SET NOCOUNT ON
	DECLARE 
		@TypeId	    TINYINT
		, @Remark	    VARCHAR(500)
		, @Mode	    TINYINT
		, @ActionId   INT
		, @fth	    INT
		, @fta	    INT
		, @hth	    INT
		, @hta	    INT
		, @goalrecord NVARCHAR(50)
		, @betstatus  NVARCHAR(50)
		, @IsAutoInst INT
		, @SourceId   TINYINT
		, @ChildMatchType		TINYINT
		 
	SELECT @IsAutoInst = CASE WHEN CHARINDEX('@IsAutoInst = ''1''', @sqlCommand) > 0 THEN 1 ELSE 0 END  --#86964

	IF @ActionIDInput <> 0
	BEGIN
		SELECT @ActionId = @ActionIdInput
	END
	ELSE
	BEGIN
		SELECT @Mode = CASE 
							WHEN CHARINDEX('NAP_Admin_Settlement_1_InstantCalculation_Undo', @sqlCommand) > 0 THEN 7
							WHEN (
								CHARINDEX('NAP_Admin_Settlement_1_InstantCalculation', @sqlCommand) > 0 
								AND 
								CHARINDEX('NAP_Admin_Settlement_1_InstantCalculation_Undo', @sqlCommand) = 0 -- dont count undo-instant process
							) THEN 6
							WHEN CHARINDEX('NAP_Admin_Settlement_1_AutoPayout', @sqlCommand) > 0 THEN 5
							WHEN CHARINDEX('NAP_Admin_Settlement_FGLG', @sqlCommand) > 0
								OR CHARINDEX('NAP_Admin_Settlement_Refund_FGLG', @sqlCommand) > 0 THEN 2
							WHEN CHARINDEX('NAP_Admin_Settlement_Corner', @sqlCommand) > 0 THEN 3
							WHEN CHARINDEX('NAP_Admin_Settlement_Parlay', @sqlCommand) > 0 THEN 4
							WHEN CHARINDEX('NAP_Admin_Settlement_1', @sqlCommand) > 0
								OR CHARINDEX('NAP_Admin_Settlement_RefundHT', @sqlCommand) > 0
								OR CHARINDEX('NAP_Admin_Settlement_RefundFT', @sqlCommand) > 0 
								OR CHARINDEX('NAP_Admin_Settlement_Refund_All', @sqlCommand) > 0 THEN 1
							WHEN CHARINDEX('NAP_Admin_Settlement_Profile', @sqlCommand) > 0 THEN 8
						ELSE NULL END
		IF @Mode IS NULL
			RETURN
	
		SELECT @ActionId = ActionId 
		FROM dbo.f_Set_GetListAction() 
		WHERE Mode = @Mode AND ActionName = @Action
		
		IF @ActionId IS NULL
		RETURN
	END
	
	SELECT @Remark = 'Failed: ' + @ErrMsg
		, @fth = m.finalhomescore
		, @fta = m.finalawayscore
		, @hth = m.hthomescore
		, @hta = m.htawayscore
		, @GoalRecord = m.GoalRecord
		, @BetStatus = m.betstatus
		, @ChildMatchType = m.ChildMatchType
	FROM DBPRO.BODB02.dbo.match m WITH (NOLOCK)
	WHERE m.matchid = @MatchId
	
	--Auto payout
	IF @Mode IN (5,6)
	BEGIN
		SELECT @TypeId = CASE    WHEN @Action = 'CAL-HT' THEN 1
							WHEN @Action = 'CAL-FT' THEN 2
							WHEN @Action = 'INST-HT' THEN 101
							WHEN @Action = 'INST-FT' THEN 102
							ELSE -1 
					  END
			, @SourceId = CASE WHEN @ChildMatchType = 204 THEN 100
								WHEN @IsAutoInst = 1 THEN 5 
								ELSE 100 END

		--update status for autopayout result
		EXEC DBPRO.bodb02.dbo.NAP_Set_AutoPayoutResultUpd @MatchId = @MatchId
			, @TypeId = @TypeId
			, @StatusId = 3 --failed
			, @IsIncludedUpdateMatch = 0
			, @SourceId = @SourceId
	END
	
	--Instant Calculation
	IF @Mode = 6
	BEGIN	
		-- Re-update confirmed instant score
		SELECT TOP(1)
			@fth = CASE WHEN @TypeId = 102 THEN HomeValue ELSE @fth END
			, @fta = CASE WHEN @TypeId = 102 THEN AwayValue ELSE @fta END
			, @hth = CASE WHEN @TypeId = 101 THEN HomeValue ELSE @hth END
			, @hta = CASE WHEN @TypeId = 101 THEN AwayValue ELSE @hta END
		FROM DBPRO.BODB02.dbo.AutoPayoutResult WITH (NOLOCK)
		WHERE matchid = @MatchId
			AND CalculationType = @TypeId
		ORDER BY AutoPayoutResultId DESC
	
	END
	
	--Begin: #86964
	SELECT @actionid = CASE WHEN (@IsAutoInst = 1 AND @Action = 'INST-HT') THEN 197 	
							WHEN (@IsAutoInst = 1 AND @Action = 'INST-FT') THEN 198
							ELSE @actionid END
    --End: #86964								

	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle @userid = @AdminId
			, @matchid = @matchid
			, @actionid = @actionid
			, @finalhomescore = @fth
			, @finalawayscore = @fta
			, @hthomescore = @hth
			, @htawayscore = @hta
			, @GoalRecord = @goalrecord
			, @betstatus = @betstatus
			, @remark = @Remark
			, @ip = @IP
	END TRY
	BEGIN CATCH 
		SELECT @remark = @remark + ' ErMsg=' + LEFT(ERROR_MESSAGE(), 300)
		
		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle @UserID = @AdminId
			, @MatchID = @matchid
			, @actionid = @actionid
			, @finalhomescore = @fth
			, @finalawayscore = @fta
			, @hthomescore = @hth
			, @htawayscore = @hta
			, @GoalRecord = @goalrecord
			, @betstatus = @betstatus
			, @remark = @Remark
			, @IP = @IP
	END CATCH
END
GO
