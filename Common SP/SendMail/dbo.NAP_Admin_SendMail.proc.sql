/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Admin_SendMail]
	@SoureName 			VARCHAR(100) = 'NAP-Settlement'
	, @matchid			INT
	, @message			VARCHAR(500)
	, @actionId			INT
	, @AdminId 			INT
	, @procName      	VARCHAR(100) 	= NULL
	, @severity			VARCHAR(30) 	= 'Error'
	, @remark			VARCHAR(MAX) 	= ''
	, @recipients		VARCHAR(250) 	= ''
	, @GroupName		VARCHAR(10)		= ''
	, @ErrCode			INT				= 0		OUTPUT
	, @ErrMsg			NVARCHAR(200)	= ''	OUTPUT
AS
/*
	Created:20170503@Bobby
    Task:  72789 - Implement bonus system into NAP Settlement
	DB: DBTXN/bodb02  
	
    Revisions:
		- 20160606@Bobby: Initialize
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]

		
    Parameters Explanation:   
		- @severity: [Error, Warning]
		, GroupName: ERROR...
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @email_body 	NVARCHAR(MAX)
		, @subject 			NVARCHAR(200)
		, @tableRow			VARCHAR(MAX)
		, @rowMatch			VARCHAR(MAX)
		-------------------------------
		, @actionName		VARCHAR(100)
		, @SPName			VARCHAR(100)
		--, @xmlDoc			XML
		
	IF ISNULL(@recipients,'') = ''
	BEGIN
		SELECT @recipients = Recipients
		FROM [dbo].[f_Set_VS_BetRadar_EmailConfig] ()
		WHERE GroupName = @GroupName
	END

	BEGIN TRY
	
		SELECT @actionName 	= ActionNameEn
			,@SPName		= SPName
		FROM DBLOG.bodb_CustomerLog.dbo.LogAction WITH(NOLOCK)
		WHERE ActionId = @actionId
		
		SELECT @subject	= @severity + ' on ' + @@SERVERNAME + ' - ' + @SoureName + ' - ' + ISNULL(@actionName, 'N/A')
			,@email_body = '
			<html>
				<body>
				<style>
					table {border-collapse: collapse;}
					table, td, th {border: 1px solid black;}
					th {text-align: left; padding: 8px;}
				</style>
				<h1>' + @subject + '</h1>
				<p><b>Run time: ' + convert(varchar(50), getdate(), 121) + '</p>
				<div style="background-color:red;color:white;text-align:center">Failure</div>
				<p></p>
				{<tableRow>}
				</body>
			</html>'

		SET @tableRow = '<p>Match ID List</p>
			<table with="100%">
				<tr>
				<th style="text-align:center">Match ID</th>
				<th style="text-align:center">Severity</th>
				<th style="text-align:center">Action Name</th>
				<th style="text-align:center">SP Name</th>
				<th style="text-align:center">Message</th>
				</tr>
				{<rowMatch>}
			</table>
			<p>&nbsp;<p/>
			<p>Remark:</p>'
			
			SELECT @tableRow += '<i> Source SP: ' + @procName + '</i><br/>'
			WHERE LEN(@procName) > 0
			
			SELECT @tableRow += '<i>' +  @remark + '</i>'
			WHERE LEN(@remark) > 0
			
		--FORMAT dummy accounts 
		SET @rowMatch = CONVERT(VARCHAR(MAX), (SELECT @matchid AS 'td1'
													, @severity AS 'td2'
													, @actionName AS 'td3'
													, @SPName AS 'td4'
													, @message AS 'td5'
												FOR XML PATH('tr'), TYPE
											  ))    
		SET @rowMatch = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@rowMatch, 'td1>', 'td>'), 'td2>', 'td>'), 'td3>','td>'), 'td4>','td>'),'td5>','td>')
		
		
		SET @tableRow = REPLACE(@tableRow, '{<rowMatch>}', @rowMatch)
		SET @email_body = REPLACE(@email_body, '{<tableRow>}', @tableRow)
		
		IF(LEN(ISNULL(@recipients,'')) > 0)
		BEGIN
			EXECUTE msdb.dbo.sp_send_dbmail @profile_name	= DEFAULT
				, @recipients			 = @recipients
				, @copy_recipients		 = ''
				, @blind_copy_recipients = ''
				, @subject				 = @subject
				, @body					 = @email_body
				, @body_format			 = 'HTML';
		END
		
		--SELECT @email_body AS email_body
	END TRY
	BEGIN CATCH
		SELECT @ErrCode =  ERROR_NUMBER() 
			,@ErrMsg 	=  ERROR_MESSAGE()
	END CATCH
END
GO