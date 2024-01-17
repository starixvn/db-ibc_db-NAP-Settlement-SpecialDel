/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_zzzBettrans_Delete]
(
	 @TransIds		VARCHAR(MAX) = ''
	,@Type			TINYINT = 0
)
AS
/*	
	Created by:20231227@Max
	Task: [TVS] Recover Ticket issue type [Redmine: #196020]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20231227@Max: Create new SP [Redmine: #196020]

	Param's explanation:
		@Type: 
			0: Single + Main Parlay
			1: Sub Parlay
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @SiteDBGroupID     SMALLINT = 0
			,@TransInfo			VARBINARY(MAX)
			,@TransInfo3rd		VARBINARY(MAX)
			,@MatchId			INT

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	DECLARE @tmpTransInfo TABLE(
			  matchid INT, transid BIGINT, status NVARCHAR(10), winlost MONEY, ruben TINYINT, statuswinlost TINYINT, stake MONEY
			, statusID TINYINT, creator INT, actual_stake MONEY, odds SMALLMONEY, oddsspread MONEY, transdesc NVARCHAR(2000), ExtraInfo VARCHAR(1000), FcUpdateTime DATETIME2
			, aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
			, PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
			, transdate DATETIME, comstatus NVARCHAR(40)
			, bettype SMALLINT
			)

	DECLARE @tmp_TransId AS TABLE (transid BIGINT)
	DECLARE @tmpMatchidInfo TABLE (MatchId INT, IsFinish BIT)

	INSERT INTO @tmp_TransId (transid)
	SELECT value
	FROM string_split(@TransIds, ',')
	WHERE value <> ''

	IF @Type = 0
	BEGIN
		-- delete normal ticket
		DELETE main
			OUTPUT deleted.matchid, deleted.transid, deleted.transdate, deleted.comstatus, deleted.bettype
			INTO @tmpTransInfo (matchid, transid, transdate, comstatus, bettype)
		FROM zzzbettrans main WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tmp_TransId t 
				ON	main.transid = t.transid
					AND ISNULL(main.comstatus,'') <> 'CO'
					AND main.SiteDBGroupID = @SiteDBGroupID

		IF @SiteDBGroupID <> 0 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)
		BEGIN
			INSERT INTO @tmpMatchidInfo (MatchId)
			SELECT DISTINCT MatchId FROM @tmpTransInfo

			WHILE (1=1)
			BEGIN
				UPDATE TOP(1)m
				SET IsFinish = 1, @matchid = MatchId 
				FROM @tmpMatchidInfo m
				WHERE IsFinish IS NULL

				IF @@ROWCOUNT = 0 BREAK;
				SET @TransInfo = COMPRESS((
				SELECT	matchid AS 'mid'
						, transId AS 't'
						, transdate AS 'td'
						, comstatus AS 'cst'
				FROM	@tmpTransInfo 
				WHERE matchid = @MatchId AND bettype NOT IN (10, 38)
				FOR JSON PATH))

				IF @TransInfo IS NOT NULL
				BEGIN
					INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType)
					SELECT 'TVS'
						, CASE WHEN @MatchId NOT IN (9,29,2799) THEN 'RecoverSingleBet' ELSE 'RecoverMainParlayBet' END
						, 'zzzbettrans', 'D', @matchid, @TransInfo, 's'
				END

				--For match table; EventTable = 1
				SET @TransInfo3rd= COMPRESS((
				SELECT	matchid AS 'mid'
						, transId AS 't'
						, transdate AS 'td'
						, comstatus AS 'cst'
				FROM	@tmpTransInfo 
				WHERE matchid = @MatchId AND bettype IN (38)
				FOR JSON PATH))
			
				IF @TransInfo3rd IS NOT NULL
				BEGIN
					INSERT INTO dbo.SiteDB_SettlementService_CalculationLog_3rd (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType, EventTable)
					SELECT 'TVS', 'RecoverSingleBet', 'zzzbettrans', 'D', @matchid, @TransInfo3rd, 's', 1
				END

				SET @TransInfo3rd = NULL
				--For ouright table; EventTable = 2
				SET @TransInfo3rd= COMPRESS((
				SELECT	matchid AS 'mid'
						, transId AS 't'
						, transdate AS 'td'
						, comstatus AS 'cst'
				FROM	@tmpTransInfo 
				WHERE matchid = @MatchId AND bettype IN (10)
				FOR JSON PATH))
			
				IF @TransInfo3rd IS NOT NULL
				BEGIN
					INSERT INTO dbo.SiteDB_SettlementService_CalculationLog_3rd (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType, EventTable)
					SELECT 'TVS', 'RecoverSingleBet', 'zzzbettrans', 'D', @matchid, @TransInfo3rd, 's', 2
				END
			END

			DELETE FROM @tmpTransInfo
			DELETE FROM @tmpMatchidInfo
			SET @TransInfo = NULL
			SET @TransInfo3rd = NULL
		END
	END
	ELSE IF @Type = 1
	BEGIN
		RETURN;
	END
END		
GO


