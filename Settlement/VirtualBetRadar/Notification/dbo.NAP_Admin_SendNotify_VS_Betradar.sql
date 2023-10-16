/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_SendNotify_VS_Betradar] 
	@MatchId			INT 
	,@notifyAction		INT
	,@IsParlay			BIT 			= 0
	,@parlayStatus		TINYINT			= 0
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			NVARCHAR(200)	= ''	OUTPUT
AS
/*	Creator: 20170712@Bobby
	Task: 79423 - Implement Email Notification when doing Refund and Re-Settle actions
	DB: DBTXN/BODB02
	
	Revisions:
		- 20170712@Bobby: Initialize
		- 20231016@Aries: Auto Send Announcement When Refund VS [Redmine:#195333]
		
	Param's Explanation:
		- @notifyAction: [@ActionId:187-RE-SETTLE;@ActionId:188-REFUND]
		- @parlayStatus: Is refer to Parlay_Calculate_Queue_VS.IsCalculating which record has singleQueueId = Single_Calculate_Queue_VS.KeyId
 
*/
BEGIN
	
	SET NOCOUNT ON	
	IF(ISNULL(@MatchId,0) <= 0 OR  ISNULL(@notifyAction,0) <= 0) RETURN
	
	DECLARE @email_body 	NVARCHAR(MAX)
		, @subject 			NVARCHAR(200)
		, @subjectAction	NVARCHAR(200)
		, @tableRow			VARCHAR(MAX)
		, @subject_Credit	NVARCHAR(200)
		, @email_Credit 	NVARCHAR(MAX)
		, @tableCredit		VARCHAR(MAX)
		, @rowCredit		VARCHAR(MAX)
		
		, @subject_Deposit	NVARCHAR(200)
		, @email_Deposit 	NVARCHAR(MAX)
		, @tableDeposit		VARCHAR(MAX)
		, @rowDeposit		VARCHAR(MAX)
		, @totalRow			INT
		, @totalTicket		INT
		, @totalRow_Deposit	INT
		, @tableMatch_Credit	VARCHAR(MAX)
		, @tableMatch_Deposit	VARCHAR(MAX)
		
	DECLARE @notifyName		VARCHAR(200)
		, @sportType		INT
		, @sportName		VARCHAR(50)
		, @eventDate		VARCHAR(50)
		, @transDateTime	VARCHAR(50)
	
	--Recipients
	
	DECLARE @Recipients 		VARCHAR(250)
		,@Credit_Recipients 	VARCHAR(250)
		,@Deposit_Recipients 	VARCHAR(250)
	
	DECLARE @betTicket		TABLE(
		transid 			BIGINT
		, custid 			INT
		, srecommend		INT
		, Username 			VARCHAR(30)
		, TransDate			DATETIME
		, IsDeposit			BIT DEFAULT(0)
		, SiteName			VARCHAR(30) DEFAULT('MBC')
		, IsParlay			BIT DEFAULT(0) -- single ticket
	)
	
	DECLARE @licModel 		TABLE (
		RowIdx				INT
		, SiteName			VARCHAR(30)
		, IsDeposit 		BIT
		, TotalRow			INT
	)
	
	BEGIN TRY
		
		SELECT @Recipients			= Recipients
			,@Credit_Recipients 	= Credit_Recipients
			,@Deposit_Recipients 	= Deposit_Recipients
		FROM [dbo].[f_Set_VS_BetRadar_EmailConfig] ()
		WHERE GroupName = 'NOTIFY'
		
		SELECT  TOP(1)
			@eventDate 			= CONVERT(VARCHAR(20), m.kickofftime, 111)  + ' ' + CONVERT(VARCHAR(5), m.kickofftime, 24)
			, @sportType		= m.sportType
			, @sportName		= s.sportName
			, @subjectAction 	= 'SportType: ' + CAST(@sportType AS VARCHAR(10)) + ' ' + @sportName + '; MatchID: ' + CAST(@matchid AS VARCHAR(10)) + '; Event Date: ' + @eventDate
			
		FROM dbo.match m WITH(NOLOCK)
			INNER JOIN dbo.sports s WITH(NOLOCK)
			ON m.sporttype = s.sporttype
			
		WHERE matchid = @matchid
		
		--CHECK VS Betradar sporttype
		IF(@sportType NOT BETWEEN 190 AND 199) RETURN;
		
		--SELECT ticket to send out notification
		;WITH CTE_ParlayRefNo AS (
			SELECT bm.custid, bm.refno
			FROM dbo.bettransm bm WITH(NOLOCK)
				OUTER APPLY (
					SELECT TOP(1) CAST(1 AS BIT) AS IsMultiple
					FROM DBPRO.BODB02.dbo.match_remark mr WITH(NOLOCK)
					WHERE mr.matchid = @matchid
						AND 1 = CASE 
								WHEN @notifyAction = 187 AND (multiple = 1 OR refund = 1) THEN 1 -- Parlay has calculated or refund completely
								WHEN @notifyAction = 188 AND (refund = 1) THEN 1 -- Parlay refund completely
								ELSE 0
							END 
				)
				AS mr
			WHERE bm.matchid 		= @matchid
				AND @IsParlay 		= 1
				AND mr.IsMultiple 	= 1
				AND @parlayStatus	= 2 --queue for CAL/REFUND parlay completely
			
		)
		INSERT INTO @betTicket ( 
			transid
			, custid
			, srecommend
			, Username
			, TransDate
			, IsParlay
		)
		--single tickets
		SELECT b.transid
			, b.custid
			, b.srecommend
			, c.Username
			, b.TransDate
			, 0 AS IsParlay
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK)
			ON b.custid		= c.custid
		WHERE matchid		= @matchid
			AND b.statusId	NOT IN (101, 102)
		
		--main parlay tickets
		UNION ALL 
		SELECT b.transid
			, b.custid
			, b.srecommend
			, c.Username
			, b.TransDate
			, 1 AS IsParlay
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN CTE_ParlayRefNo rn 
			ON b.refno = rn.refno
			INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK)
			ON b.custid = c.custid
			
		WHERE b.matchid		= 2799
			AND b.custid	= rn.custid
			AND b.bettype	= 2799
			AND b.statusId	NOT IN (101, 102)
		
		
		SET @totalTicket = @@ROWCOUNT

		IF(@totalTicket > 0)
		BEGIN
		
			UPDATE b 
			SET IsDeposit = CASE WHEN cs.custid > 0 THEN 1 ELSE 0 END
				,SiteName = CASE WHEN cs.custid > 0 THEN cs.[Site] ELSE 'MBC' END
			FROM @betTicket b
				LEFT JOIN CustDB.dbo.Dep_CustSuper cs WITH(NOLOCK)
				ON b.srecommend = cs.custid
			
			INSERT INTO @licModel (RowIdx, SiteName, IsDeposit, TotalRow)
			SELECT ROW_NUMBER() OVER (PARTITION BY IsDeposit ORDER BY SiteName ASC) AS RowIdx
				,SiteName
				, IsDeposit
				, TotalRow
			FROM (
				SELECT SiteName
					, IsDeposit
					, COUNT(1) AS TotalRow
				FROM @betTicket
				GROUP BY SiteName
					, IsDeposit

			) AS temp
			
			--SET totalRow for deposit model				
			SELECT @totalRow_Deposit = SUM(TotalRow)
			FROM @licModel 
			WHERE IsDeposit = 1 
				

			SELECT @notifyName = CASE WHEN @notifyAction = 187 THEN 'Resettle' ELSE 'Refund' END
				, @subject = '[Virtual Sports] ' + @notifyName  + ' Ticket Numbers ({<LIC_NAME>}) --' + @notifyName + ' MatchID: ' + CAST(@matchid AS VARCHAR(10)) + ' (' + @sportName + ')'
				, @email_body = N'
				<html>
					<style>
						body {font-family:tahoma;font-size:12px}
						table {border-collapse: collapse;}
						table, td, th {border: 1px solid black;text-align: center; }
						th {padding: 4px;color:white;font-family:tahoma;font-size:12px}
						td {padding: 4px;font-family:tahoma;font-size:12px}
					</style>
					<body>
					{<tableMatch>}
					{<tableRow>}
					<p>&nbsp;<p/>
					</body>
				</html>'

			SET @tableMatch_Credit = '<p><b>1. ' + @notifyName + ' Match Info:</b></p>
				<table>
					<tr style="background-color:#0095CC;">
						<th style="width:150px;">Sport Type</th>
						<th style="width:250px;">Sport Name</th>
						<th style="width:150px;">Match ID</th>
						<th style="width:250px;">Event Date</th>
					</tr>
					<tr>
						<td>' + CAST(@sportType AS VARCHAR(10)) + '</td>
						<td>' + @sportName + '</td>
						<td>' + CAST(@matchID AS VARCHAR(10)) + '</td>
						<td>' + @eventDate + '</td>
					</tr>
				</table>'
			SET @tableMatch_Deposit = '<p><b>1. ' + @notifyName + ' Match Info:</b></p>
				<table>
					<tr style="background-color:#0095CC;">
						<th style="width:150px;">Sport Type</th>
						<th style="width:250px;">Sport Name</th>
						<th style="width:150px;">Match ID</th>
						<th style="width:250px;">Event Date</th>
						<th style="width:150px;">Total Tickets</th>
					</tr>
					<tr>
						<td>' + CAST(@sportType AS VARCHAR(10)) + '</td>
						<td>' + @sportName + '</td>
						<td>' + CAST(@matchID AS VARCHAR(10)) + '</td>
						<td>' + @eventDate + '</td>
						<td>' + CAST(@totalRow_Deposit AS VARCHAR(10)) + '</td>
					</tr>
				</table>'
				
			SET @tableRow = '<p><b>2. ' + @notifyName + ' Ticket Numbers List:</b></p>
				<table>
					<tr style="background-color:#0095CC">
						<th style="width:60px">No.</th>
						<th style="width:150px">Ticket Number</th>
						<th style="width:150px">Ticket Type</th>
						<th style="width:150px">Cust ID</th>
						<th style="width:200px">User Name</th>
						<th style="width:250px">Trans Date</th>
					</tr>
					{<rowTickets>}
				</table>'
						
			--FORMAT dummy accounts 
			IF(EXISTS(SELECT 1 FROM @licModel WHERE IsDeposit = 0))
			BEGIN
				
				SET @tableCredit = @tableRow

				SELECT @totalRow = TotalRow 
				FROM @licModel 
				WHERE IsDeposit = 0
				
				;WITH CTE_Deposit AS (
					SELECT ROW_NUMBER() OVER (ORDER BY IsParlay, transid ASC) AS 'td1'
						, transid AS 'td2'
						, CASE WHEN IsParlay = 0 THEN 'Single Ticket' ELSE 'Selection of Mix Parlay' END AS 'td3'
						, custid AS 'td4'
						, Username AS 'td5'
						, CONVERT(VARCHAR(10), TransDate, 101) + ' ' + RIGHT(CONVERT(VARCHAR(20), TransDate, 22), 12) AS 'td6'
					FROM @betTicket
					WHERE IsDeposit = 0
				)
				SELECT @rowCredit = CONVERT(VARCHAR(MAX), (SELECT td1
														, td2
														, td3
														, td4
														, td5
														, td6
													FROM CTE_Deposit
													FOR XML PATH('tr'), TYPE
												  ))    
				SET @rowCredit = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@rowCredit, 'td1>', 'td>'), 'td2>', 'td>'), 'td3>','td>'), 'td4>','td>'),'td5>','td>'),'td6>','td>')
				
				SET @rowCredit += '<tr><td colspan="6" style="text-align:left;"><b>Total Tickets: ' + CAST(@totalRow AS  VARCHAR(10)) + '</b></td></tr>'

				SET @tableCredit = REPLACE(@tableCredit, '{<rowTickets>}', @rowCredit)
				
				
				SET @email_Credit = REPLACE(@email_body, '{<LIC_NAME>}', 'MBC')
				SET @email_Credit = REPLACE(@email_Credit, '{<tableMatch>}', @tableMatch_Credit)
				SET @email_Credit = REPLACE(@email_Credit, '{<tableRow>}', @tableCredit)
				
				SET @subject_Credit	= REPLACE(@subject, '{<LIC_NAME>}', 'MBC')	
				IF(LEN(ISNULL(@Credit_Recipients,'')) > 0)
				BEGIN
				    EXECUTE msdb.dbo.sp_send_dbmail @profile_name	= default
					    , @recipients			 = @Credit_Recipients
					    , @copy_recipients		 = @Recipients
					    , @blind_copy_recipients = ''
					    , @subject				 = @subject_credit
					    , @body					 = @email_credit
					    , @body_format			 = 'HTML';
				END
				
				--SELECT @email_Credit AS email_Credit
				
			END
			
			--FOR Deposit model
			IF(EXISTS(SELECT 1 FROM @licModel WHERE IsDeposit = 1))
			BEGIN
				DECLARE @rowIndx 		INT = 1
					, @licName 			VARCHAR(30)
					, @rowLic			VARCHAR(MAX)
					, @rowTitle			VARCHAR(200)
					, @rowNoCont		INT = 0
				
				SELECT @totalRow_Deposit= SUM(TotalRow)
				FROM @licModel 
				WHERE IsDeposit = 1 
				
				SET @rowDeposit			= ''
				SET @tableDeposit		= @tableRow

				WHILE (EXISTS(SELECT 1 FROM @licModel WHERE IsDeposit = 1 AND RowIdx =  @rowIndx))
				BEGIN
					
					SELECT @licName		= ''
						, @rowLic		= ''
						, @rowTitle		= ''
						, @totalRow		= 0
						
					SELECT @licName 	= SiteName
						, @totalRow		= TotalRow
						, @rowIndx 		+= 1
					FROM @licModel 
					WHERE IsDeposit = 1 AND RowIdx =  @rowIndx
					
					

					SET @rowTitle = '<tr><td colspan="6" style="text-align:center;background-color:#FFFFAA"><b>Licensee: ' + @licName + '</b></td></tr>'
					;WITH CTE_Deposit AS (
						SELECT (ROW_NUMBER() OVER (ORDER BY IsParlay, transid ASC) + @rowNoCont) AS 'td1'
							, transid AS 'td2'
							, CASE WHEN IsParlay = 0 THEN 'Single Ticket' ELSE 'Selection of Mix Parlay' END AS 'td3'
							, custid AS 'td4'
							, Username AS 'td5'
							, CONVERT(VARCHAR(10), TransDate, 101) + ' ' + RIGHT(CONVERT(VARCHAR(20), TransDate, 22), 12) AS 'td6'
						FROM @betTicket
						WHERE IsDeposit = 1
						AND SiteName = @licName
					)
					SELECT @rowLic = CONVERT(VARCHAR(MAX), (SELECT td1
															, td2
															, td3
															, td4
															, td5
															, td6
														FROM CTE_Deposit
														FOR XML PATH('tr'), TYPE
													  ))    
					SET @rowLic 		= REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@rowLic, 'td1>', 'td>'), 'td2>', 'td>'), 'td3>','td>'), 'td4>','td>'),'td5>','td>'),'td6>','td>')
					
					SET @rowLic			+= '<tr><td colspan="6" style="text-align:left;"><b>Total Tickets: ' + CAST(@totalRow AS  VARCHAR(10)) + '</td></tr>'
					SET @rowDeposit 	+= @rowTitle
					SET @rowDeposit 	+= @rowLic
					
					SET @rowNoCont		+= @totalRow
					
				END
				
				SET @tableDeposit		= REPLACE(@tableDeposit, '{<rowTickets>}', @rowDeposit)

				SET @email_Deposit = REPLACE(@email_body, '{<LIC_NAME>}', 'Licensee')	

				SET @email_Deposit = REPLACE(@email_Deposit, '{<tableMatch>}', @tableMatch_Deposit)
				SET @email_Deposit = REPLACE(@email_Deposit, '{<tableRow>}', @tableDeposit)
				
				SET @subject_Deposit		= REPLACE(@subject, '{<LIC_NAME>}', 'Licensee')	
				
				IF(LEN(ISNULL(@Deposit_Recipients,'')) > 0)
				BEGIN
					EXECUTE msdb.dbo.sp_send_dbmail @profile_name	= DEFAULT
						, @recipients			 = @Deposit_Recipients
						, @copy_recipients		 = @Recipients
						, @blind_copy_recipients = ''
						, @subject				 = @subject_Deposit
						, @body					 = @email_Deposit
						, @body_format			 = 'HTML';
				END
				--SELECT LEN(@email_Deposit), @email_Deposit AS email_deposit
			END
		END
			
		
	END TRY
	BEGIN CATCH
		SELECT @ErrCode =  ERROR_NUMBER() 
			,@ErrMsg 	=  ERROR_MESSAGE()
	END CATCH
	
END
GO