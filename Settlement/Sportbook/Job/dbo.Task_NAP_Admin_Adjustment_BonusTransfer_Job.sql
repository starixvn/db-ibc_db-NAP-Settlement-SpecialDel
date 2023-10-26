/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Task_NAP_Admin_Adjustment_BonusTransfer_Job]
	@Mode			VARCHAR(10) = 'Adjustment'
	,@CleanUpDate	DATE = NULL
AS
/*
	Created:20170503@Bobby.Nguyen
    Task:  72789 - Implement bonus system into NAP Settlement
	DB: DBTXN/bodb02  
	
    Revisions:
		- 20170503@Bobby.Nguyen: Initial
		- 20171009@Kathy: Change column name of BonusAdjustmentTransfer [Redmine:#72789]
		- 20180326@Kathy: Change bonus transfer bettypeId [Redmine:#92592]
		- 20180529@Kathy: Change email list on production [Redmine:#92592]
		- 20201012@Louisa: Update new email domain starixvn.com [Redmine:#143284]
		- 20210817@Louisa: HF-Change datatype from INT to BIGINT [Redmine:#160262]
		- 20211229@Max: Split Transfer - Adjust Negative Balance Service & Adjustment Transfer of Bonus [Redmine: #165098]
		- 20220711@Kathy: Do not use SELECT INTO [Redmine:#175276]
		- 20231026@Louisa: Update email domain from starixvn to starixsoft [Redmine:#195197]

    Parameters Explanation:   
		@Mode:	- Adjustment
				- CleanUp
		@CleanUpdate: clean data before this day
*/
BEGIN
	SET NOCOUNT ON
	
	IF @Mode = 'Adjustment'
	BEGIN
		DECLARE @execRefno 		BIGINT
			, @transCount 		INT
			, @maxExecID		BIGINT
			, @batchExec		INT
			, @batchCount		INT
			, @bettype   		SMALLINT
			
		
		DECLARE @transExecNo	TABLE (ExecID BIGINT, refno BIGINT)
		DECLARE @tempInvalidDummy TABLE ([site] VARCHAR(30), username VARCHAR(30), currencyName VARCHAR(10), isDummy BIT)
		
		DECLARE @tempTransfer 	TABLE (
			ExecID				BIGINT
			, custid			INT
			, matchid			INT
			, bonusID			INT
			, TransDesc			NVARCHAR(1000)
			, transferId		INT
			, actual_stake		MONEY 
			, winlost			MONEY
			, isValidDummy		BIT
			, username			VARCHAR(30)
			, currency			INT
			, currencyName		VARCHAR(10)
			, actualrate		FLOAT
		)

		DECLARE @tempCoupleTransfer TABLE (
			ExecID			BIGINT
			,custid			INT
			,transferId		INT
			,username		NVARCHAR(50)
			,isDummy		BIT
			,isValidDummy	BIT
		)
		
		CREATE TABLE #tempAdjustment (ExecId BIGINT, CustId INT, username VARCHAR(30), MatchId INT, BonusId INT, Amount MONEY, currency TINYINT, currencyName NVARCHAR(50), site VARCHAR(10), srecommend INT, actualrate FLOAT)
			
		SELECT @maxExecID 		= 0
			, @batchExec		= 100
			, @bettype			= 22201
			
		WHILE (1=1)
		BEGIN
			DELETE @tempTransfer
			DELETE @transExecNo
			
			--SELECT top rows to insert bonus transfer
			INSERT INTO #tempAdjustment(ExecId, CustId, username, MatchId, BonusId, Amount, currency, currencyName, site, srecommend , actualrate)
			SELECT TOP(@batchExec)
				trans.ExecID
				, trans.CustID
				, ci.username
				, trans.MatchID
				, trans.BonusID
				, trans.Amount
				, ci.currency
				, ex.currency AS currencyName
				, rec.[site]
				, ci.srecommend
				, ex.actualrate
			FROM dbo.BonusAdjustmentTransfer AS trans WITH(NOLOCK)
				INNER JOIN CustDB.dbo.Customer AS ci WITH(NOLOCK)
					ON trans.custid = ci.custid
				INNER JOIN CustDB.dbo.Customer AS rec WITH(NOLOCK)
					ON rec.custid = ci.recommend
				INNER JOIN CustDB.dbo.exchange AS ex WITH(NOLOCK)
					ON rec.currency = ex.exchangeid
					
			WHERE trans.ExecID > @maxExecID
				AND trans.isTransferred = 0
				
			ORDER BY trans.ExecID ASC
			
			SET @batchCount = @@ROWCOUNT
			
			SELECT @maxExecID = MAX(ExecID)
			FROM #tempAdjustment
			
			BEGIN--Adjustment processing
			;WITH tempDummyCust AS (
				SELECT temp.ExecID
					, temp.custid
					, temp.username
					, dummy.dummyUsername
				FROM #tempAdjustment AS temp
					OUTER APPLY (
						SELECT TOP 1 REPLACE(srec.username,'Super','Bonus02') AS dummyUsername
						FROM CustDB.dbo.Customer srec WITH(NOLOCK)
						WHERE srec.custid = temp.srecommend
					) AS dummy
			)
			INSERT INTO @tempCoupleTransfer (ExecID, custid, transferId, username, isDummy, isValidDummy)
			SELECT temp.ExecID, temp.custid
				, a.transferId, a.username, a.isDummy, a.isValidDummy
			FROM tempDummyCust AS temp
				LEFT JOIN CustDB.dbo.Customer dummy WITH(NOLOCK)
					ON temp.dummyUsername 	= dummy.username 
						AND dummy.roleid 	= 1
				OUTER APPLY (
					SELECT transferId, username, isDummy,isValidDummy
					FROM ( VALUES
						(temp.custid, temp.username, 0, CASE WHEN dummy.custid > 0 THEN 1 ELSE 0 END),
						(dummy.custid, temp.dummyUsername, 1, CASE WHEN dummy.custid > 0 THEN 1 ELSE 0 END)
				) AS t(transferId, username, isDummy, isValidDummy)) AS a
			
			INSERT INTO @tempTransfer (ExecID, custid, matchid, bonusID, TransDesc, transferId, actual_stake, winlost, isValidDummy, username, currency, currencyName, actualrate)
			SELECT temp.ExecID
				, temp.custid
				, temp.matchid
				, temp.bonusID
				, 'Bonus Adjustment - MatchID=' + CAST(temp.matchid AS VARCHAR(20)) AS TransDesc
				, trans.transferId
				, CASE 
					WHEN trans.isDummy = 0 AND temp.Amount > 0 THEN ABS(temp.Amount) 
					WHEN trans.isDummy = 1 AND temp.Amount < 0 THEN ABS(temp.Amount) 
					ELSE 0 
				END AS actual_stake
				, CASE 
					WHEN trans.isDummy = 1 AND temp.Amount > 0 THEN ABS(temp.Amount) 
					WHEN trans.isDummy = 0 AND temp.Amount < 0 THEN ABS(temp.Amount) 
					ELSE 0 
				END AS winlost
				, trans.isValidDummy
				, trans.username
				, temp.currency
				, temp.currencyName
				, temp.actualrate
			FROM #tempAdjustment AS temp
				INNER JOIN @tempCoupleTransfer AS trans
				ON temp.custid = trans.custid AND temp.ExecID = trans.ExecID
				
			--RAISE error with invalid dummy account
			INSERT INTO @tempInvalidDummy (site, username, currencyName, isDummy)
			SELECT temp.site, trans.username, temp.currencyName
				, CASE WHEN trans.transferId IS NULL THEN 1 ELSE 0 END --check dummy account
			FROM #tempAdjustment temp
				INNER JOIN @tempTransfer trans
				ON temp.ExecID = trans.ExecID
			
			WHERE trans.isValidDummy = 0
			
			--Generate refno 
			INSERT INTO @transExecNo (ExecID)
			SELECT DISTINCT ExecID
			FROM @tempTransfer
			WHERE isValidDummy = 1
			
			SELECT @transCount = @@ROWCOUNT
			
			UPDATE dbo.ref WITH (ROWLOCK)
			SET @execRefno = refno = refno  + @transCount
			WHERE  refid='refno'
			
			UPDATE	 @transExecNo
				SET	refno = (@execRefno - @transcount) + 1
					,@transcount = @transcount - 1
			--End generate refno 
			
			--INSERT batch adjustment into Transfer
			INSERT INTO [dbo].[Transfer]
				   ([custid]
				   ,[transdate]	
				   ,[stake]
				   ,[winlost]
				   ,[awinlost]
				   ,[mwinlost]
				   ,[playercomm]
				   ,[comm]
				   ,[acomm]
				   ,[creator]
				   ,[refno]
				   ,[winlostdate]
				   ,[SerialNo]
				   ,[checktime]
				   ,[actualrate]
				   ,[recommend]
				   ,[mrecommend]
				   ,[bettype]
				   ,[actual_stake]
				   ,[currency]
				   ,[ip]
				   ,[transdesc]
				   ,[scomm]
				   ,[swinlost]
				   ,[srecommend]
				   ,[Username]
				   ,[CurrencyName]
				   ,[statusID]
				   ,[balance])
			--SELECT from temp table adjustment bonus transfer
			SELECT temp.[transferId]
				   ,CURRENT_TIMESTAMP AS  [transdate]
				   ,0 AS [stake]
				   ,temp.[winlost]
				   ,0 AS [awinlost]
				   ,0 AS [mwinlost]
				   ,0 AS [playercomm]
				   ,0 AS [comm]
				   ,0 AS [acomm]
				   ,temp.transferId AS [creator]
				   ,execNo.[refno] + 100000000000 
				   ,CAST(CURRENT_TIMESTAMP AS DATE) AS [winlostdate]
				   ,0 AS [SerialNo]	
				   ,NULL AS [checktime]
				   ,temp.actualrate AS [actualrate]
				   ,ci.[recommend]
				   ,ci.[mrecommend]
				   ,@bettype AS [bettype]
				   ,temp.[actual_stake]
				   ,temp.currency
				   ,'127.0.0.1' AS [ip]
				   ,temp.[transdesc]
				   ,0 AS [scomm]
				   ,0 AS [swinlost]
				   ,ci.[srecommend]
				   ,temp.[Username]
				   ,temp.CurrencyName
				   ,131 AS [statusID]
				   ,NULL AS [balance]
					   
				FROM @tempTransfer AS temp
					INNER JOIN CustDB.dbo.custinfo AS ci WITH(NOLOCK)
						ON temp.transferId = ci.custid
					INNER JOIN @transExecNo execNo 
						ON temp.ExecID = execNo.ExecID
							
				WHERE temp.isValidDummy = 1
				ORDER BY execNo.refno
				
				--UPDATE back to BonusAdjustmentTransfer
				IF(@@ROWCOUNT > 0)
				BEGIN
					UPDATE dbo.BonusAdjustmentTransfer WITH(ROWLOCK, UPDLOCK)
					SET isTransferred 	= 1
						,ExecDate 		= CURRENT_TIMESTAMP
					WHERE ExecID IN (SELECT ExecID FROM @transExecNo)
				END
			END
			
			TRUNCATE TABLE #tempAdjustment
			
			IF(@batchCount < @batchExec) BREAK;
		END
		
		--SEND out notification
		IF(EXISTS(SELECT TOP 1 1 FROM @tempInvalidDummy))
		BEGIN
			DECLARE @email_body 	NVARCHAR(MAX)
				, @subject 			NVARCHAR(200)
				, @rowDummy			VARCHAR(MAX)
				, @rowMember		VARCHAR(MAX)
				, @tableRow			VARCHAR(MAX)
			
			SELECT @email_body = '
				<html>
					<body>
					<style>
						table {border-collapse: collapse;}
						table, td, th {border: 1px solid black;}
						/*tr:nth-child(even) {background-color: #f2f2f2}*/
						th {text-align: left; padding: 8px;}
						/*th {background-color: #4CAF50; color: white;}*/
					</style>

					<h1>Bonus Adjustment - Missing Dummy Account!</h1>
					<p><b>Run time: ' + convert(varchar(50), getdate(), 121) + '</p>
					<div style="background-color:red;color:white;text-align:center">Failure</div>
					<p></p>
					{<tableRow>}
					</body>
				</html>'
			,@subject	= N'Bonus Adjustment - Missing Dummy Account'
		
			SET @tableRow = '<p>Missing Dummy Account List</p>
				<table>
					<tr>
					<th style="text-align:center">Site</th>
					<th style="text-align:center">Dummy UserName</th>
					<th style="text-align:center">Currency</th>
					</tr>
					{<rowDummy>}
				</table>
				<p>&nbsp;<p/>
				<p>Affected Member List</p>
				<table>
					<tr>
					<th style="text-align:center">Site</th>
					<th style="text-align:center">Member UserName</th>
					<th style="text-align:center">Currency</th>
					</tr>
					{<rowMember>}
				</table>'
			--FORMAT dummy accounts 
			SET @rowDummy = CONVERT(VARCHAR(MAX), (SELECT DISTINCT site AS 'td1'
														, username AS 'td2'
														, currencyName AS 'td1'
													FROM @tempInvalidDummy
													WHERE isDummy = 1
													FOR XML PATH('tr'), TYPE
												  ))    
			SET @rowDummy = REPLACE(REPLACE(@rowDummy, 'td1>', 'td>'), 'td2>', 'td>')
			
			--FORMAT member rows
			SET @rowMember = CONVERT(VARCHAR(MAX), (SELECT DISTINCT site AS 'td1'
														, username AS 'td2'
														, currencyName AS 'td1'
													FROM @tempInvalidDummy
													WHERE isDummy = 0
													FOR XML PATH('tr'), TYPE
												  ))    
			SET @rowMember = REPLACE(REPLACE(@rowMember, 'td1>', 'td>'), 'td2>', 'td>')
			
			SET @tableRow = REPLACE(@tableRow, '{<rowDummy>}', @rowDummy)
			SET @tableRow = REPLACE(@tableRow, '{<rowMember>}', @rowMember)
			SET @email_body = REPLACE(@email_body, '{<tableRow>}', @tableRow)
			
			EXECUTE msdb.dbo.sp_send_dbmail @profile_name	= DEFAULT
				, @recipients			 = 'dbaadmin@starixsoft.com'
				--LOCAL: dba_local@starixsoft.com
				--TEST version UAT (UAT1, UAT2...): 'qa@starixsoft.com'
				--PRODUCTION: 'dbaadmin@starixsoft.com'
				, @copy_recipients		 = ''
				, @blind_copy_recipients = ''
				, @subject				 = @subject
				, @body					 = @email_body
				, @body_format			 = 'HTML';
				
			--SELECT @email_body AS email_body_bonus_adjustment
		END
	END
	ELSE IF @Mode = 'CleanUp'
	BEGIN
		WHILE 1 = 1
		BEGIN
			DELETE TOP (1000)
			FROM	dbo.BonusAdjustmentTransfer WITH (ROWLOCK, UPDLOCK)
			WHERE	isTransferred = 1
					AND LogDate < @CleanUpDate
				
			IF @@rowcount < 1000
				BREAK
		END
	END
	RETURN
END

GO
