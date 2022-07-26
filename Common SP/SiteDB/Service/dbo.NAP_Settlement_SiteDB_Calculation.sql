/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SiteDB_Service_Calculation]
	@TransInfo XML
	,@TableName VARCHAR(128)
	,@StatusId TINYINT OUTPUT
AS
/*
	Created by: 20201123@Kathy
	Task: Settlement  
	DB: DBTRANS.BODB02
	
	Revisions:
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]

	Param's Explanation:  
		   
*/
BEGIN	
	SET NOCOUNT ON
	
	DECLARE @batchNo		INT
			,@failedId		TINYINT = 3
			,@completedId	TINYINT = 2

	DECLARE @tmpTransId TABLE (transId BIGINT
			,matchid INT, winlostdate DATETIME
			,modds MONEY, odds SMALLMONEY, oddsid INT, oddsspread MONEY, statuswinlost TINYINT,SettlementTime DATETIME
			,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
			,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
			,Status NVARCHAR(10),StatusID TINYINT,ruben TINYINT,RepUpdateTime DATETIME2
	)
	
	BEGIN TRY
		IF @tablename = 'bettrans' 
		BEGIN
			INSERT INTO @tmpTransId (TransID
					,matchid, winlostdate
					,modds, odds, oddsid, oddsspread, statuswinlost,SettlementTime,WinLost,aWinLost
					,mWinLost,sWinLost,PlayerComm,Comm,aComm,sComm,Status,StatusID,ruben,RepUpdateTime
				)
			SELECT	T.C.value('./@t', 'bigint') AS transid
					,T.C.value('./@mid', 'INT') AS matchid
					,T.C.value('./@wld', 'SMALLDATETIME') AS winlostdate
					,T.C.value('./@m', 'MONEY') AS modds
					,T.C.value('./@o', 'SMALLMONEY') AS odds
					,T.C.value('./@oid', 'INT') AS oddsid
					,T.C.value('./@os', 'MONEY') AS oddsspread
					,T.C.value('./@statuswl', 'TINYINT') AS statuswinlost
					,T.C.value('./@st', 'DATETIME') AS SettlementTime
					,T.C.value('./@w', 'MONEY') AS WinLost
					,T.C.value('./@aw', 'MONEY') AS aWinLost
					,T.C.value('./@mw', 'MONEY') AS mWinLost
					,T.C.value('./@sw', 'MONEY') AS sWinLost
					,T.C.value('./@pc', 'MONEY') AS PlayerComm
					,T.C.value('./@c', 'MONEY') AS Comm 
					,T.C.value('./@ac', 'MONEY') AS aComm
					,T.C.value('./@sc', 'MONEY') AS sComm
					,T.C.value('./@s', 'NVARCHAR(10)') AS Status
					,T.C.value('./@sid', 'TINYINT') AS StatusID
					,T.C.value('./@r', 'TINYINT') AS ruben
					,T.C.value('./@rut', 'DATETIME2') AS RepUpdateTime					
			FROM	@transInfo.nodes('/root/r') AS T(C)
			OPTION (OPTIMIZE FOR (@transInfo = NULL ))
	
			SET @batchNo = @@ROWCOUNT

			UPDATE TOP (@batchNo) b
				SET
					matchid = CASE WHEN t.matchid IS NULL THEN b.matchid ELSE t.matchid END
					,winlostdate = CASE WHEN t.winlostdate IS NULL THEN b.winlostdate ELSE t.winlostdate END
					,modds = CASE WHEN t.modds IS NULL THEN b.modds ELSE t.modds END
					,odds = CASE WHEN t.odds IS NULL THEN b.odds ELSE t.odds END
					,oddsid = CASE WHEN t.oddsid IS NULL THEN b.oddsid ELSE t.oddsid END
					,oddsspread = CASE WHEN t.oddsspread IS NULL THEN b.oddsspread ELSE t.oddsspread END  				
					,statuswinlost = CASE WHEN t.statuswinlost IS NULL THEN b.statuswinlost ELSE t.statuswinlost END
					,SettlementTime = CASE WHEN t.SettlementTime IS NULL THEN b.SettlementTime ELSE GETDATE() END						
					,WinLost = CASE WHEN t.WinLost IS NULL THEN b.winlost ELSE t.WinLost END
					,aWinLost = CASE WHEN t.aWinLost IS NULL THEN b.awinlost ELSE t.aWinLost END			
					,mWinLost = CASE WHEN t.mWinLost IS NULL THEN b.mwinlost ELSE t.mWinLost END
					,sWinLost = CASE WHEN t.sWinLost IS NULL THEN b.swinlost ELSE t.sWinLost END
					,PlayerComm = CASE WHEN t.PlayerComm IS NULL THEN b.playercomm ELSE t.PlayerComm END
					,Comm = CASE WHEN t.Comm IS NULL THEN b.comm ELSE t.Comm END					
					,aComm = CASE WHEN t.aComm IS NULL THEN b.acomm  ELSE t.aComm END					
					,sComm = CASE WHEN t.sComm IS NULL THEN b.scomm ELSE t.sComm END					
					,Status = CASE WHEN t.Status IS NULL THEN b.status ELSE t.Status END
					,StatusID = CASE WHEN t.StatusID IS NULL THEN b.statusID ELSE t.StatusID END
					,ruben= CASE WHEN t.ruben IS NULL THEN b.ruben ELSE t.ruben END
					,RepUpdateTime = CASE WHEN t.RepUpdateTime IS NULL THEN b.RepUpdateTime ELSE SYSDATETIME() END
			FROM @tmpTransId t
				INNER JOIN dbo.bettrans b  WITH (ROWLOCK, UPDLOCK) 
					ON  t.transid = b.transid 
			OPTION (OPTIMIZE FOR (@batchNo = 1), FORCE ORDER)
		END
	END TRY
	BEGIN CATCH
		SET @StatusId = @failedId

		RETURN
	END CATCH

	SET @StatusId = @completedId
END