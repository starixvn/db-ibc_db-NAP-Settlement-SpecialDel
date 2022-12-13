/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_Refund_BetFair] 
	@matchid int
AS
/*	Created by: Kathy
	Date: 20140218
	Task: Refund Running BetFair
	DB: DBTXN/BODB02
	
	Revisions:
		- 20140512@Kathy: Exclude bettype 1H FGLG (127) [Redmine:#14718]
		- 20140729@Kathy: Add one more account(BF3) into BetFair's group [Redmine:#19665]		
		- 20140909@Kathy: Exclude virtual racing (bettype 1237, 1238), outright (bettype 10, 31, 32, 33), keno (1501 -> 1599)
		- 20141030@Jamie: Sportting Solution Tennis Settlement [Redmine:#23034]
		- 20150422@Jamie: Settlement Betradar phase 2 [Redmine: #27212]
		- 20171023@Kathy: Include bettype 14, 127 [Redmine:#81308]
		- 20181129@Kathy: Do not settle ticket on DB04x [Redmine:#105327]
		- 20190409@Sol: Settlement Time [Redmine:#99638]
		- 20211104@Kathy: Upd RepUpdateTime [Redmine:#164184]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
		- 20221011@Kathy: Using Json [Redmine:#178694]
*/
BEGIN
	SET NOCOUNT ON

	-- CHECK SERVER BEFORE REFUND
	DECLARE @ServerName		SYSNAME 
			,@AllowRefund	BIT
			,@IsSiteDB		BIT = 0

	SET @ServerName = @@SERVERNAME

	IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL 
		SET @IsSiteDB = 1

	IF OBJECT_ID('NAP_Set_ServerAction', 'P') IS NOT NULL
	BEGIN
		EXEC [dbo].[NAP_Set_ServerAction]
			@ServerName		= @ServerName
			,@AllowRefund	= @AllowRefund	OUTPUT

		IF @AllowRefund = 0
			RETURN
	END
	-- END CHECK
	DECLARE @settlementTime DATETIME
			,@FcUpdateTime	DATETIME2
			,@rowcnt		SMALLINT
			,@transInfoJson NVARCHAR(MAX)
			
	DECLARE @tmpTransInfo TABLE (transId BIGINT
			,SettlementTime DATETIME
			,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
			,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
			,Status NVARCHAR(10),StatusID TINYINT,ruben TINYINT
			,bef_winlost MONEY ,bef_statusid TINYINT
			,FcUpdateTime DATETIME2
		)
		
	BEGIN
		WHILE 1=1
		BEGIN
			DELETE FROM @tmpTransInfo

			SET @settlementTime = GETDATE();
			SET @FcUpdateTime = SYSDATETIME()

			UPDATE TOP (10000) dbo.bettrans with (ROWLOCK, UPDLOCK)
			SET
				[status] = N'Refund',
				SettlementTime = CASE WHEN winlost <> actual_stake OR statusID <> 103 THEN @settlementTime ELSE SettlementTime END,
				statusID = 103,
				ruben = 1,
				winlost=actual_stake,
				awinlost=0,
				mwinlost=0,
				swinlost=0,
				playercomm=0,
				comm=0,
				acomm=0,
				scomm=0,
				FcUpdateTime = CASE WHEN statusId = 103 THEN FcUpdateTime ELSE @FcUpdateTime END
			OUTPUT	inserted.transid
				,inserted.Status
				,CASE WHEN inserted.SettlementTime <> ISNULL(deleted.SettlementTime,'') THEN inserted.SettlementTime ELSE NULL END
				,inserted.StatusID,inserted.ruben		
				,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
				,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm,deleted.winlost ,deleted.statusid
				,CASE WHEN inserted.FcUpdateTime <> deleted.FcUpdateTime THEN inserted.FcUpdateTime ELSE NULL END
			INTO @tmpTransInfo (
				transId
				,Status
				,SettlementTime
				,StatusID,ruben
				,WinLost,aWinLost,mWinLost,sWinLost
				,PlayerComm,Comm,aComm,sComm,bef_winlost ,bef_statusid 
				,FcUpdateTime
			)
			where
				matchid=@matchid
				--AND [status] not in (N'Void', N'Reject')
				AND statusID NOT IN (103,101,102)
				AND ruben = 0 
				--AND bettype NOT IN (14, 127) --Exclude FGLG 
				AND bettype NOT BETWEEN 1301 AND 1399 -- exclude sporting solution product
				AND bettype NOT BETWEEN 153 AND 156   -- New bettype of Tennis
				AND bettype NOT IN (10, 31, 32, 33, 1231, 1232, 1233, 1237, 1238) -- Outright, VSRacing
				AND bettype NOT BETWEEN 1501 and 1599 -- Keno
				AND bettype NOT IN (135,160,164,168,169,173,174,175,176,180,192,193,210,211,212,213,214,215,216,217)
				AND custid IN (2331, 1077687, 115770, 15523642) 
				AND SiteDBGroupID = CASE WHEN @IsSiteDB = 1 THEN SiteDBGroupID ELSE 0 END
			
			SET @rowcnt  = @@ROWCOUNT

			IF @IsSiteDB = 1 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)
			BEGIN
				SET @transInfoJson = (
					SELECT	transId AS 't'
							,SettlementTime AS 'st' 
							,WinLost AS 'w' 
							,aWinLost AS 'aw' 
							,mWinLost AS 'mw' 
							,sWinLost AS 'sw' 
							,PlayerComm AS 'pc' 
							,Comm AS 'c' 
							,aComm AS 'ac' 
							,sComm AS 'sc' 
							,Status AS 's' 
							,StatusID AS 'sid' 
							,ruben AS 'r'
							,bef_winlost AS 'bef_w' 
							,bef_statusid AS 'bef_sid' 
							,FcUpdateTime AS 'rut'
					FROM	@tmpTransInfo
					FOR JSON AUTO
				)
				EXEC dbo.SiteDB_NAP_SettlementService_CalculationLogIns 
						@SystemName = 'Settlement' 
						,@FunctionName = 'RefundBetFair'
						,@TableName = 'bettrans'
						,@MatchId = @MatchId
						,@TransInfoJson = @TransInfoJson
						,@SettlementAction = 'REFUND'
						,@TicketType = 's'	
				
			END

			IF @rowcnt < 10000 BREAK
		END
	END
END
GO