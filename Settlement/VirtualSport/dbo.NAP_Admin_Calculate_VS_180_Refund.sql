/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_VS_180_Refund]
	@MatchId			INT
	,@IsCentral			BIT = 0
AS
/*	Creator: Kathy
	Date: 20150812
	Task: refund VS tickets (VS soccer, VS tennis)
	DB: DBTXN/BODB02
	
	Revisions:
	
	Param's Explanation:
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]    
 
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @transInfo	XML
			,@rowcnt INT = 0

	DECLARE @tmpTransInfo TABLE (transId BIGINT
			, statuswinlost TINYINT
			,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
			,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
			,Status NVARCHAR(10),StatusID TINYINT,ruben TINYINT
			,bef_winlost MONEY ,bef_statusid TINYINT
		)
	
	WHILE 1 = 1
	BEGIN
		UPDATE TOP (10000) dbo.bettrans WITH (ROWLOCK, UPDLOCK)
			SET [status] = N'Refund'
				,statusID = 103
				,winlost = actual_stake
				,awinlost = 0
				,mwinlost = 0
				,swinlost = 0
				,playercomm = 0
				,comm = 0
				,acomm = 0
				,scomm = 0
				,ruben = 1
				,statuswinlost = 0
		OUTPUT inserted.transid		
			,inserted.statuswinlost
			,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
			,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm		
			,inserted.status 			
			,inserted.statusID 	
			,inserted.ruben 
			,deleted.winlost
			,deleted.statusid
		INTO @tmpTransInfo (transId 
			, statuswinlost
			,WinLost,aWinLost,mWinLost,sWinLost 
			,PlayerComm, Comm,aComm,sComm 
			,Status ,StatusID ,ruben 
			,bef_winlost  ,bef_statusid )
		WHERE	matchid = @matchid
				AND statusID NOT IN (103, 101, 102) 
				AND bettype IN (1201, 1203, 1204, 1205, 1206, 1224, 1220, 1235, 1236)
				AND SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE SiteDBGroupID END
		
		SELECT @rowcnt = @@ROWCOUNT

		IF @IsCentral = 0	
		BEGIN
			SET @transInfo = (
				SELECT	transId AS '@t'	
						,statuswinlost AS '@statuswl' 
						,WinLost AS '@w' 
						,aWinLost AS '@aw' 
						,mWinLost AS '@mw' 
						,sWinLost AS '@sw' 
						,PlayerComm AS '@pc' 
						,Comm AS '@c' 
						,aComm AS '@ac' 
						,sComm AS '@sc' 
						,Status AS '@s' 
						,StatusID AS '@sid' 
						,ruben AS '@r' 
						,bef_winlost AS '@bef_w' 
						,bef_statusid AS '@bef_sid' 				
				FROM	@tmpTransInfo
				FOR XML PATH('r'),ROOT('root'), TYPE
			)

			INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo)
			VALUES ('Settlement', 'RefundOtherSport', 'bettrans', @MatchId, @transInfo)	
		END

		IF @rowcnt < 10000
			BREAK

	END
	
END
