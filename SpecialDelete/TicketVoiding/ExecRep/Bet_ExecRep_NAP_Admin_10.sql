/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Bet_ExecRep_NAP_Admin_10]
(
	@TransidList			VARCHAR(MAX)
	,@IsAbnormalBet			TINYINT
	,@UserID				INT = 0 
	,@MatchId				INT
)
AS
/*  Created by: 20230526@July
    Task: [TVS] Abnormal Account - Void archived tickets [Redmine:#188152]
    DB: DBTXN/bodb02
    
    Revisions: 
		- 20230526@July: Create new SP [Redmine:#188152]

    Param's explanation:
       
*/
BEGIN
	DECLARE @IsSiteDB			BIT 
			,@xml				XML = NULL
			,@transInfo			VARBINARY(MAX)
			,@transInfo3rd		VARBINARY(MAX)
			,@SiteDBGroupID		SMALLINT
			,@IsInsertTrigger	BIT = 0

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()
	IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL 
		SET @IsSiteDB = 1

	IF (OBJECT_ID('BalanceTrigger','U') IS NOT NULL AND @@SERVERNAME IN ('TESTDB053','SITDB05','SITDB05BK1','DB05','DB05BK1'))
		OR @IsSiteDB = 1
	BEGIN
		SET @IsInsertTrigger = 1
	END

	CREATE TABLE #tmpTransId (
		TransId				BIGINT
		,sporttype			SMALLINT
	)

	CREATE TABLE #BeforeTransId14(
	   matchid INT ,transid BIGINT PRIMARY KEY,betdaqid BIGINT ,sitedbgroupid SMALLINT
      ,bettype SMALLINT ,statusID TINYINT ,Status NVARCHAR(10)
	  ,winlostdate SMALLDATETIME ,SettlementTime DATETIME ,actual_stake MONEY ,modds SMALLMONEY
	  ,srecommend INT ,mrecommend INT,recommend INT ,custid INT	
	  ,winlost MONEY ,awinLost MONEY ,mwinLost MONEY ,swinLost MONEY
	  ,playercomm MONEY ,comm MONEY ,acomm MONEY ,scomm MONEY
	)

	CREATE TABLE #AfterTransId14(
	    matchid INT ,transid BIGINT PRIMARY KEY,betdaqid BIGINT ,sitedbgroupid SMALLINT
      ,bettype SMALLINT ,statusID TINYINT ,Status NVARCHAR(10)
	  ,winlostdate SMALLDATETIME ,SettlementTime DATETIME ,actual_stake MONEY ,modds SMALLMONEY
	  ,srecommend INT ,mrecommend INT,recommend INT ,custid INT	
	  ,winlost MONEY ,awinLost MONEY ,mwinLost MONEY ,swinLost MONEY
	  ,playercomm MONEY ,comm MONEY ,acomm MONEY ,scomm MONEY, ruben TINYINT, creator INT, ExtraInfo VARCHAR(1000)
	)

	SET @xml = CONVERT(XML, @TransidList)
	INSERT INTO #tmpTransId (TransId, sporttype)
	SELECT DISTINCT t.c.value('@transid','BIGINT') AS TransId
			,t.c.value('@sporttype','SMALLINT') AS sporttype
	FROM @xml.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@xml = NULL ))

	IF @IsInsertTrigger = 1 OR @IsSiteDB = 1
	BEGIN
		--capture before for balance trigger
		INSERT INTO #BeforeTransId14( 
			   matchid ,transid ,betdaqid ,sitedbgroupid
			  ,bettype ,statusID ,Status 
			  ,winlostdate ,SettlementTime ,actual_stake ,modds 
			  ,srecommend ,mrecommend ,recommend ,custid	
			  ,winlost ,awinLost ,mwinLost ,swinLost
			  ,playercomm ,comm ,acomm ,scomm
			)
		SELECT b.matchid, t.TransId, b.betdaqid, @SiteDBGroupID
			,b.bettype, b.statusID, b.status, b.winlostdate, b.SettlementTime, b.actual_stake, b.modds
			,b.srecommend, b.mrecommend, b.recommend, b.custid
			,b.winlost, b.awinlost, b.mwinlost, b.swinlost
			,b.playercomm, b.comm, b.acomm, b.scomm
		FROM #tmpTransId t
			INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON b.transid = t.TransId
	END

	UPDATE main
		SET 
			winlost = main.actual_stake
			,ruben = 1
			,creator = @UserID
			,mwinlost = 0
			,swinlost = 0
			,awinlost = 0 -- awinlost main ticket
			,playercomm = 0
			,comm = 0
			,acomm = 0
			,scomm = 0
			,statusID = 102
			,status = 'VOID'
			,ExtraInfo = dbo.f_SD_SetExtraInfoAbnormalBet(CASE WHEN @IsAbnormalBet = 1 AND @MatchId <> 29 THEN 1
																WHEN @IsAbnormalBet = 1 AND @MatchId = 29 THEN 2
																ELSE 0 END,'void',main.ExtraInfo,tmpmain.sporttype,main.bettype) 
	FROM dbo.bettrans14 AS main WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tmpTransId AS tmpmain ON main.transid = tmpmain.transid

	IF @IsInsertTrigger = 1 OR @IsSiteDB = 1
	BEGIN
		--capture after for balance trigger
		INSERT INTO #AfterTransId14( 
			   matchid ,transid ,betdaqid ,sitedbgroupid
			  ,bettype ,statusID ,Status 
			  ,winlostdate ,SettlementTime ,actual_stake ,modds 
			  ,srecommend ,mrecommend ,recommend ,custid	
			  ,winlost ,awinLost ,mwinLost ,swinLost
			  ,playercomm ,comm ,acomm ,scomm, ruben, creator, ExtraInfo
			)
		SELECT b.matchid, t.TransId, b.betdaqid, @SiteDBGroupID
			,b.bettype, b.statusID, b.status, b.winlostdate, b.SettlementTime, b.actual_stake, b.modds
			,b.srecommend, b.mrecommend, b.recommend, b.custid
			,b.winlost, b.awinlost, b.mwinlost, b.swinlost
			,b.playercomm, b.comm, b.acomm, b.scomm, b.ruben, b.creator, b.ExtraInfo
		FROM #tmpTransId t
			INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON b.transid = t.TransId
	END

	IF @IsSiteDB = 1
	BEGIN
		SET @transInfo = COMPRESS((
		SELECT	b.transId AS 't'
				, b.winlost AS 'w'
				, b.ruben AS 'r'
				, b.creator AS 'cr'
				, b.awinlost AS 'aw'
				, b.mwinlost AS 'mw'
				, b.swinlost AS 'sw'
				, b.playercomm AS 'pc'
				, b.comm AS 'c'
				, b.acomm AS 'ac'
				, b.scomm AS 'sc'
				, b.statusID AS 'sid'
				, b.status AS 's'
				, b.ExtraInfo AS 'ex'
		FROM	#AfterTransId14 b
		WHERE b.bettype NOT IN (10)
		FOR JSON PATH))

		SET @transInfo3rd = COMPRESS((
		SELECT	b.transId AS 't'
				, b.winlost AS 'w'
				, b.ruben AS 'r'
				, b.creator AS 'cr'
				, b.awinlost AS 'aw'
				, b.mwinlost AS 'mw'
				, b.swinlost AS 'sw'
				, b.playercomm AS 'pc'
				, b.comm AS 'c'
				, b.acomm AS 'ac'
				, b.scomm AS 'sc'
				, b.statusID AS 'sid'
				, b.status AS 's'
				, b.ExtraInfo AS 'ex'
		FROM	#AfterTransId14 b
		WHERE b.bettype IN (10)
		FOR JSON PATH))

		IF @transInfo IS NOT NULL
		BEGIN
			INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType)
			SELECT 'TVS', 'Void_14', 'bettrans14', 'U', @matchid, @transInfo, CASE WHEN @MatchId IN (29, 2799) THEN 'p' ELSE 's' END
		END
		IF @transInfo3rd IS NOT NULL
		BEGIN
			INSERT INTO dbo.SiteDB_SettlementService_CalculationLog_3rd (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType, EventTable)
			SELECT 'TVS', 'Void_14', 'bettrans14', 'U', @matchid, @transInfo3rd, CASE WHEN @MatchId IN (29, 2799) THEN 'p' ELSE 's' END, 2
		END
	END
	
	IF @IsInsertTrigger = 1 OR @IsSiteDB = 1
	BEGIN
		-- Insert statements for trigger here
		INSERT INTO dbo.BalanceTrigger (custid, transid, bettype, actual_stake, winlost, playercomm, ActionDate, 
			ActionID, [Action],
			BalanceChanged,
			MatchId, StatusId, SettlementType, swinlost, mwinlost, awinlost, scomm, acomm, comm, modds)
		SELECT
			-- if inserted.custid = 0, this should be VOID + Hidden
			-- if deleted.custid = 0, this may be Bet Recover
			case when i.custid = 0 then d.custid else i.custid end,
			i.transid, i.bettype, i.actual_stake, isnull(i.winlost,0) as winlost, isnull(i.playercomm,0) as playercomm, CURRENT_TIMESTAMP, 

			CASE 
				WHEN (
					i.actual_stake <> d.actual_stake 
					OR isnull(i.winlost,0) <> isnull(d.winlost,0) 
					OR isnull(i.playercomm,0) <> isnull(d.playercomm,0)
					OR isnull(i.statusid,0) <> isnull(d.statusid,0)
					OR i.custid <> d.custid
				) THEN
					CASE
					WHEN isnull(i.statusid,0) = 102 THEN 050 -- Void Bet

					WHEN i.bettype < 19001 AND isnull(d.statusid,0) = 1 THEN CASE isnull(i.statusid,0) WHEN 101 THEN 020 WHEN 0 THEN 021 ELSE 0 END -- waiting -> Reject : running : something else
					WHEN i.bettype < 19001 AND isnull(d.statusid,0) = 0 AND isnull(i.statusid,0) > 0  -- Settled : running -> Won/Lose/Draw/Refund
						THEN CASE 
								WHEN ISNULL(i.betdaqid,0) = -2 THEN 029 -- cashout ticket
								ELSE 030 -- settle ticket
							END
					WHEN i.bettype < 19001 AND isnull(d.statusid,0) = 102 AND isnull(i.statusid,0) = 0 THEN 055 -- unvoid/recover : void -> running
					WHEN i.bettype < 19001 AND isnull(d.statusid,0) > 0 
						THEN CASE isnull(i.statusid,0) 
								WHEN 0 THEN CASE WHEN ISNULL(i.betdaqid,0) = -1 AND ISNULL(d.betdaqid,0) = -2 THEN 034 ELSE 032 END
								ELSE 031 
							END -- resettle or unsettle
					WHEN i.bettype > 20000 AND i.custid = 0 THEN 130 -- cancel transfer (custid set to zero)
					WHEN i.bettype > 20000 THEN 120 -- update transfer

					--WHEN i.bettype < 19001 AND d.custid = 0 AND i.custid > 0 THEN 055 -- recover bet
					ELSE 0 END
				ELSE 001
			END,
		
			--CASE WHEN i.custid =0 THEN 'Delete ' ELSE 'Update ' END
			--	+ CASE WHEN i.bettype < 19001 then 'Bet' ELSE 'Transfer' END + 
			--CASE WHEN i.custid <> 0 THEN ', from '+ d.[status] + ' to ' + i.[status] ELSE '' END
			--[Action]--vvv
			CASE 
				WHEN ( i.winlostdate <> d.winlostdate AND i.bettype NOT IN (29, 10)	)
					OR (i.winlostdate > d.winlostdate AND i.bettype = 10 )
					OR (i.winlostdate > d.winlostdate AND i.bettype = 29 AND d.statusID NOT IN (0,1) )
					THEN 'Move WLD from ' 
							+ CASE 
								WHEN ISNULL(d.winlostdate,'') = '' THEN REPLICATE(' ', 10) 
								ELSE CONVERT(VARCHAR,d.winlostdate, 23) 
							END
							+ ' to ' 
							+ CASE 
								WHEN ISNULL(i.winlostdate,'') = '' THEN REPLICATE(' ', 10)
								ELSE CONVERT(VARCHAR,i.winlostdate, 23) 
							END						
				ELSE '' 
			END + 
			ISNULL(CASE
					WHEN i.bettype < 19001 THEN 'Bet'
					WHEN i.bettype > 20000 THEN 'Transfer'
					ELSE isnull(d.[status],'running')
				END +
				CASE
					WHEN i.custid = 0 THEN ' cancelled, ' + isnull(d.[status],'running') + ' to ' + isnull(i.[status],'running')
					WHEN i.bettype > 20000 THEN ' updated, ' + isnull(d.[status],'running') + ' to ' + isnull(i.[status],'running')
					WHEN isnull(d.statusid,0) = 1 THEN
						CASE isnull(i.statusid,0)
						WHEN 0 THEN ' accepted'
						WHEN 101 THEN ' rejected'
						ELSE ' updated, ' + isnull(d.[status],'running') + ' to ' + isnull(i.[status],'running')
						END
					WHEN isnull(d.statusid,0) = 0 THEN
						CASE 
							WHEN isnull(i.statusid,0) = 102 THEN ' voided'
							WHEN (isnull(i.statusid,0) BETWEEN 111 AND 113) OR isnull(i.statusid,0) = 103 
								THEN CASE 
										WHEN ISNULL(i.betdaqid,0) = -2 THEN ' Cash Out, ' + isnull(d.status,' running') + ' to '  + isnull(i.status,' running')
										ELSE  ' settled, ' + isnull(d.[status],'running') + ' to ' + isnull(i.[status],'running')
									END
							ELSE ' updated, ' + isnull(d.[status],'running') + ' to ' + isnull(i.[status],'running')
						END
					WHEN isnull(d.statusid,0) > 0 AND isnull(d.betdaqid,0) = -2 AND isnull(i.statusid,0) = 0 
						THEN ' Cancel Cash Out, ' + isnull(d.status,'running') + ' to ' + isnull(i.status,'running')
					ELSE ' Updated, ' + isnull(d.[status],'running') + ' to ' + isnull(i.[status],'running')
				END,'')
			--[Action]--^^^	
 			, (isnull(i.winlost,0) - ISNULL(i.actual_stake, 0) + ISNULL(i.playercomm,0))
				- (ISNULL(d.winlost,0) - ISNULL(d.actual_stake, 0) + ISNULL(d.playercomm,0))
			,i.matchid
			,isnull(i.statusID,0)
			,CASE 
				WHEN (isnull(i.statusID,0) BETWEEN 111 AND 113 OR isnull(i.statusID,0) = 103) 
					THEN CASE 
							WHEN d.SettlementTime IS NULL THEN 1 -- first settled
							WHEN i.SettlementTime <> d.SettlementTime 
								THEN CASE
										WHEN isnull(d.statusID,0) = 0 THEN 2 -- change from running to settle 
										ELSE 3 
									END -- re-settled: change from settle to settle
							WHEN isnull(d.statusID,0) BETWEEN 111 AND 113 THEN 4 -- settle to settle, no change winlost
							ELSE 0 
						END
				ELSE 0
			END -- SettlementType
			,isnull(i.swinlost,0) as swinlost
			,isnull(i.mwinlost,0) as mwinlost
			,isnull(i.awinlost,0) as awinlost
			,isnull(i.scomm,0) as scomm
			,isnull(i.acomm,0) as acomm
			,isnull(i.comm,0) as comm
			,i.modds
		FROM #AfterTransId14 i 
				INNER JOIN #BeforeTransId14 d ON i.transid = d.transid
		WHERE d.custid <> d.recommend 
			AND d.custid <> d.mrecommend 
			AND d.custid <> d.srecommend		
	END

	DROP TABLE #tmpTransId
	DROP TABLE #BeforeTransId14
	DROP TABLE #AfterTransId14
END
GO


