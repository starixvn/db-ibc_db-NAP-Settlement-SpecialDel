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
			+ 6: IsRefund

	@HoldInfo = '<root>
					<r t="1" s="true" />			--Turn on Pending bit[1]
					<r t="2" s="true" child="true"/>	--Turn on Undecided, also apply to Child Match bit[2]
					<r t="4" s="false" />			--Turn off UnderSettlement  bit[3]
					<r t="16" s="false" />			--Turn off MTD Hold bit[5]
					<r t="64" s="false" />			--Turn off Hold Key bit[7]
				</root>'
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @SettlementStatus	TINYINT
			,@AutoSetting		TINYINT
			,@Starttime		DATETIME = GETDATE()
			,@Remark		VARCHAR(500)
			,@handle		INT

	DECLARE @tmpHoldSetting TABLE (MatchID INT, ParentID INT, TurnOn TINYINT, TurnOff TINYINT)

	IF @Type IN (4, 6 )
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

		IF @Type = 6
		BEGIN
			SELECT @Remark = 'Turn ' + CASE WHEN @IsEnabled = 1 THEN 'on ' ELSE 'off ' END
							 + 'Refund on match: ' 
							 + CAST(@MatchId AS VARCHAR) + '<br/> '
							 + 'Duration: ' + CAST(DATEDIFF(MILLISECOND,@Starttime, GETDATE()) AS VARCHAR) + ' ms'
	
			BEGIN TRY
				EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle 
					@UserID             = @AdminId
					,@Matchid           = @matchid
					,@ActionID			= 81018
					,@Remark            = @Remark
					,@IP                = @IP
			END TRY
			BEGIN CATCH
				SELECT @Remark = @Remark + ' ErrMsg=' + left(error_message(), 250)

				EXEC DBTXN.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle 
					@UserID             = @AdminId
					,@Matchid           = @matchid
					,@ActionID          = 81018
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
			SELECT  m.matchid, m.ParentID, m.leagueid
			FROM dbo.match m WITH(NOLOCK)
			WHERE matchid = @MatchId
		
			UNION ALL 
			SELECT  m.matchid, m.ParentID, m.leagueid
			FROM dbo.match m WITH(NOLOCK)
				INNER JOIN cte_recursion d
				ON m.ParentID = d.matchid	 
		)
		---get all related matches
		, cte_AllMatch ( MatchID, ParentID) AS 
		(
			SELECT m.MatchID, m.ParentID
			FROM cte_recursion m
		)
		,cte_WebResources (MatchID, ParentID, HoldType, IsEnable, IsApplyChildMatch) 
		AS 
		(
			SELECT   d.matchid
					,d.ParentID
					,setting.t as HoldType
					,setting.s as IsEnable
					,setting.child as IsApplyChildMatch
			FROM cte_AllMatch d
				CROSS APPLY (	SELECT t, s, isnull(child,0) as child
								FROM OPENXML(@handle,'root/r',1) WITH(	t INT ,s BIT ,child	BIT	) AS tbl --- will parse value "true"/"false" to 1/0 with datatype is BIT
							) setting
		)

		INSERT INTO @tmpHoldSetting (MatchID, ParentID, TurnOn, TurnOff)
		SELECT   w.matchid
				,w.ParentID
				,SUM(CASE WHEN (ISNULL(ParentID,0)=0 OR IsApplyChildMatch = 1) AND IsEnable = 1 THEN HoldType ELSE 0 END) as TurnOn
				,SUM(CASE WHEN (ISNULL(ParentID,0)=0 OR IsApplyChildMatch = 1) AND IsEnable = 0 THEN HoldType ELSE 0 END) as TurnOff 
		FROM cte_WebResources w
		WHERE ISNULL(w.ParentID,0) = 0 OR IsApplyChildMatch = 1
		GROUP BY w.matchid, w.ParentID

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

		SELECT @ChildMatchList = ( SELECT STRING_AGG(MatchID,',') FROM @tmpHoldSetting WHERE ISNULL(ParentID,0) > 0 )

	END TRY
	BEGIN CATCH
		SELECT	 @ErrMsg  = ERROR_MESSAGE()
				,@ErrCode = @@ERROR

		RETURN
	END CATCH
	
END
GO
