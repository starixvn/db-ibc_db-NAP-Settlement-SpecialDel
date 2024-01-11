/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet,dot_admin" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [NAP_Set_SettlementStatusUpd_Louisa]
	@MatchId	INT
	,@Type		TINYINT
	,@IsEnabled BIT
	,@AdminId	INT
	,@IP		VARCHAR(20)	= ''
	,@HoldInfo	VARCHAR(MAX) = ''

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
			+ 5: IsMTDHold
			+ 6: IsRefund

	 @HoldInfo = '<root>
					<r t="1" s="0" child="0"/>
					<r t="2" s="0" child="1"/>
				</root>'
	
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @SettlementStatus	TINYINT
			,@AutoSetting		TINYINT

			--write log
			,@Starttime			DATETIME
			,@ActionId			INT
			,@Remark			VARCHAR(500)
	
	IF ISNULL(@HoldInfo,'') = ''
	BEGIN
		SELECT	@Starttime = GETDATE()
				,@ActionId = CASE
								WHEN @Type = 5 THEN 81005 --MTD Hold
								WHEN @Type = 6 THEN 81018 --refund All
								ELSE 81049
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
	
			END
	END
	ELSE 
	BEGIN
		 SELECT @HoldInfo

			;WITH recursion AS (
		SELECT  m.matchid, m.sporttype, m.ParentID, m.ChildMatchType, 0 AS level
		FROM match m WITH(NOLOCK)
		where matchid = 78631441
		
		UNION ALL 
		SELECT  m.matchid, m.sporttype, m.ParentID, m.ChildMatchType,
				level + 1
		FROM match m WITH(NOLOCK)
			INNER JOIN recursion d
			ON m.ParentID = d.matchid	 
	)
 
	SELECT   d.matchid AS descendant_id 
			,m.matchid AS ancestor_id 
			,m.sporttype,d.ParentID, d.ChildMatchType
			,d.level
	FROM recursion d
		INNER JOIN match m WITH(NOLOCK)
	ON d.ParentID = m.matchid
	ORDER BY level, ancestor_id;

	END
END
GO
