/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_LogInfo_Select]
(	
	 @RequestId			  INT = 0
	,@UserID			  INT
	,@IssueTypeId		  INT = 1
	,@ActionId			  INT = 5
	,@IsShowLogOnly		  BIT = 0
	,@SubIssueTypeId	  INT = NULL
	,@KickOffInfo		  VARCHAR(MAX) = NULL
	,@WrongScoreInfo	  VARCHAR(MAX) = NULL
	,@DangerAcceptedInfo  VARCHAR(MAX) = NULL
	,@RedCardInfo		  VARCHAR(MAX) = NULL
	,@WrongHDPInfo		  VARCHAR(MAX) = NULL
	,@Wrong1stHDPInfo	  VARCHAR(MAX) = NULL
	,@WrongOUInfo		  VARCHAR(MAX) = NULL
	,@Wrong1stOUInfo	  VARCHAR(MAX) = NULL	
	,@WrongOddsInfo		  VARCHAR(MAX) = NULL
	,@ReducedOverInfo	  VARCHAR(MAX) = NULL
	,@NotParticipateInfo  VARCHAR(MAX) = NULL
	,@TransInfoJson		  VARCHAR(MAX) = NULL
)
AS
/*	
	Created by: 20200701@Max
	Task: [TVS] Danger Accept Bets Issue Type [Redmine: #111573]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20200701@Max: Create new SP [Redmine: #135947]
		- 20200825@Max: [TVS] HotFix - Danger Accept [Redmine: #140164]
		- 20200901@July: [TVS] - Enhance for Danger Accept - Phase 2 [Redmine: #140785]
		- 20200910@Charles: [TVS] Enhance Void by Accept Time [Redmine: #141127]
		- 20201002@Max: [TVS] - Modify bet type list on Home/Away Team filter of Danger Accept [Redmine: #142883]
		- 20200918@Charles: TVS - Enhance for Danger Accept Phase 3 [Redmine: #141579]
		- 20201015@Max: [TVS] - HotFix - Danger accept add by accept time can add ticket super live [Redmine: #143308]
		- 20201021@July: [TVS] - Wrong Red Card [Redmine: #140951]
		- 20201102@Max: TVS - Enhance for Danger Accept - Phase 4 - Show LogInfo when voided [Redmine: #143091]
		- 20201130@July: TVS - Check lock match before add request [Redmine: #143666]
		- 20210322@July: TVS - Danger Accept/Red Card Enhancement - Phase 7 [Redmine: #150459]
		- 20210510@Max: [TVS] Danger Accept/Red Card Enhancement - Search and save not same log info [Redmine: #154772]
		- 20210511@Max: TVS - Wrong Score [Redmine: #140953]
		- 20210524@Max: [TVS] Wrong Score - Void 2H tickets in range time [Redmine: #155598]
		- 20210528@Max: Exclude some group bettypes [Redmine: #155598]
		- 20210531@July: TVS - Danger Accept Enhancement - Phase 8 [Redmine: #152051]
		- 20210526@Max: [TVS] Danger Accept Enhancement - Phase 9 [Redmine: #153216]
		- 20210611@Max: [TVS] Hotfix Highlight Min TransId [Redmine: #156832]
		- 20210617@Max: [TVS] Wrong Score Enhancement 1 [Redmine: #156349]
		- 20210619@Helen: SP Tuning [Redmine: #157249]
		- 20210621@Max: [TVS] EKO & Wrong Kick Off Time - Warning tickets existed on other request not show Transid [Redmine: #156728]
		- 20210803@July: TVS - Apply new way to lock parlay tickets [Redmine: #157970]
		- 20210811@Max: [TVS] Wrong Score Enhancement 2 [Redmine: #157096]
		- 20210817@July: TVS - Red Card Enhancement - Phase 1 [Redmine: #157097]
		- 20211012@July: TVS - Danger Accept Enhancement - Phase 10 [Redmine: #155792]
		- 20211210@July: Implement New Cash Out Model [Redmine: #165097]
		- 20220110@July: TVS - New issue type Wrong HDP and Wrong 1H HDP [Redmine: #146717]
		- 20220208@Max: [TVS] Wrong Score Enhancement 3 [Redmine: #164561]
		- 20220311@July: TVS - Wrong count settled tickets at log info [Redmine: #169763]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220321@July: TVS - Danger Accept Enhancement - Phase 11 [Redmine: #164562]
		- 20220401@July: TVS - New issue type Wrong OU and Wrong 1H OU [Redmine: #170220]
		- 20220510@Max: Issue Performance Add/Edit Request issue type Wrong OU & Wrong 1st OU [Redmine: #172281]
		- 20220517@Max: TVS - Wrong Score: Add/Edit Request COUNT single ticket NOT RIGHT at log info [Redmine: #172851]
		- 20220620@July: TVS - Support FT Instant Settlement on HT Calculation [Redmine: #174122]
		- 20220627@July: TVS - Remove invalid column [Redmine: #174122]
		- 20220808@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20221124@July: [TVS] Increase data size when sending data between web and DB [Redmine: #180863]
		- 20230103@Max: Change JSON input [Redmine: #180625]
		- 20230419@Max: [TVS] New issue type Wrong Odds [Redmine: #179934]
		- 20230608@Max: [TVS] Support void Cricket when reducing over [Redmine: #185833]
		- 20230908@Max: [TVS] Not Participant issue type [Redmine: #192832]

	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON 

	-- Write useraction log 
	DECLARE @sqlCommand NVARCHAR(MAX), @ID UNIQUEIDENTIFIER
			, @SubmittedDate DATETIME = GETDATE()
			, @spName VARCHAR(500) = OBJECT_NAME(@@PROCID)
	SET @ID =  NEWID()
	BEGIN TRY
		IF OBJECT_ID (N'TVS_UserActionLog') IS NOT NULL 
		BEGIN	
			SET @sqlCommand = 'EXEC dbo.TicketVoiding_LogInfo_Select '
					+ CASE WHEN @RequestId IS NULL THEN '' ELSE '@RequestId = ' + CONVERT(NVARCHAR(50), @RequestId) END
					+ CASE WHEN @UserID IS NULL THEN '' ELSE ',@UserID = ' + CONVERT(NVARCHAR(50), @UserID) END
					+ CASE WHEN @IssueTypeId IS NULL THEN '' ELSE ',@IssueTypeId = ' + CONVERT(NVARCHAR(50), @IssueTypeId) END
					+ CASE WHEN @ActionId IS NULL THEN '' ELSE ',@ActionId = ' + CONVERT(NVARCHAR(50), @ActionId) END
					+ CASE WHEN @IsShowLogOnly IS NULL THEN '' ELSE ',@IsShowLogOnly = ' + CONVERT(NVARCHAR(50), @IsShowLogOnly) END
					+ CASE WHEN @SubIssueTypeId IS NULL THEN '' ELSE ',@SubIssueTypeId = ' + CONVERT(NVARCHAR(50), @SubIssueTypeId) END
					+ CASE WHEN @KickOffInfo IS NULL THEN '' ELSE ',@KickOffInfo = ''' + CONVERT(NVARCHAR(MAX), @KickOffInfo) + '''' END
					+ CASE WHEN @WrongScoreInfo IS NULL THEN '' ELSE ',@WrongScoreInfo = ''' + CONVERT(NVARCHAR(MAX), @WrongScoreInfo) + '''' END
					+ CASE WHEN @DangerAcceptedInfo IS NULL THEN '' ELSE ',@DangerAcceptedInfo = ''' + CONVERT(NVARCHAR(MAX), @DangerAcceptedInfo) + '''' END
					+ CASE WHEN @RedCardInfo IS NULL THEN '' ELSE ',@RedCardInfo = ''' + CONVERT(NVARCHAR(MAX), @RedCardInfo) + '''' END	
					+ CASE WHEN @WrongHDPInfo IS NULL THEN '' ELSE ',@WrongHDPInfo = ''' + CONVERT(NVARCHAR(MAX), @WrongHDPInfo) + '''' END
					+ CASE WHEN @Wrong1stHDPInfo IS NULL THEN '' ELSE ',@Wrong1stHDPInfo = ''' + CONVERT(NVARCHAR(MAX), @Wrong1stHDPInfo) + '''' END
					+ CASE WHEN @WrongOUInfo IS NULL THEN '' ELSE ',@WrongOUInfo = ''' + CONVERT(NVARCHAR(MAX), @WrongOUInfo) + '''' END
					+ CASE WHEN @Wrong1stOUInfo IS NULL THEN '' ELSE ',@Wrong1stOUInfo = ''' + CONVERT(NVARCHAR(MAX), @Wrong1stOUInfo) + '''' END
					+ CASE WHEN @WrongOddsInfo IS NULL THEN '' ELSE ',@WrongOddsInfo = ''' + CONVERT(NVARCHAR(MAX), @WrongOddsInfo) + '''' END
					+ CASE WHEN @ReducedOverInfo IS NULL THEN '' ELSE ',@ReducedOverInfo = ''' + CONVERT(NVARCHAR(MAX), @ReducedOverInfo) + '''' END
					+ CASE WHEN @NotParticipateInfo IS NULL THEN '' ELSE ',@NotParticipateInfo = ''' + CONVERT(NVARCHAR(MAX), @NotParticipateInfo) + '''' END
					+ CASE WHEN @TransInfoJson IS NULL THEN '' ELSE ',@TransInfoJson = ''' + CONVERT(NVARCHAR(MAX), @TransInfoJson) + '''' END

			INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
			VALUES (@ID, @spName, @sqlCommand, @UserID, NULL, GETDATE(),@SubmittedDate)
		END	
	END TRY
	BEGIN CATCH
	END CATCH 

	IF @IssueTypeId = 1 --Danger Accept
	BEGIN
		EXEC dbo.TicketVoiding_LogInfo_DARC_Select
			 @RequestId			   = @RequestId
			,@ActionId			   = @ActionId
			,@IsShowLogOnly		   = @IsShowLogOnly
			,@IssueTypeId		   = @IssueTypeId
			,@DARCInfo			   = @DangerAcceptedInfo
			,@TransInfoJson		   = @TransInfoJson
	END

	IF @IssueTypeId = 2 --WrongOdds
	BEGIN
		EXEC dbo.TicketVoiding_LogInfo_WO_Select
			 @RequestId			   = @RequestId
			,@ActionId			   = @ActionId
			,@IsShowLogOnly		   = @IsShowLogOnly
			,@IssueTypeId		   = @IssueTypeId
			,@WrongOddsInfo		   = @WrongOddsInfo
			,@TransInfoJson		   = @TransInfoJson
	END
	ELSE IF @IssueTypeId = 3 --Wrong score
	BEGIN
		EXEC dbo.TicketVoiding_LogInfo_WC_Select
			 @RequestId			   = @RequestId
			,@ActionId			   = @ActionId
			,@IsShowLogOnly		   = @IsShowLogOnly
			,@IssueTypeId		   = @IssueTypeId
			,@WrongScoreInfo	   = @WrongScoreInfo
			,@TransInfoJson		   = @TransInfoJson
	END
	ELSE IF @IssueTypeId = 4 --Wrong HDP
	BEGIN
		EXEC dbo.TicketVoiding_LogInfo_HDP_Select
			 @RequestId			   = @RequestId
			,@ActionId			   = @ActionId
			,@IsShowLogOnly		   = @IsShowLogOnly
			,@IssueTypeId		   = @IssueTypeId
			,@WrongHDPInfo		   = @WrongHDPInfo
			,@TransInfoJson		   = @TransInfoJson
	END
	ELSE IF @IssueTypeId = 5 --Wrong 1st HDP
	BEGIN
		EXEC dbo.TicketVoiding_LogInfo_HDP_Select
			 @RequestId			   = @RequestId
			,@ActionId			   = @ActionId
			,@IsShowLogOnly		   = @IsShowLogOnly
			,@IssueTypeId		   = @IssueTypeId
			,@WrongHDPInfo		   = @Wrong1stHDPInfo
			,@TransInfoJson		   = @TransInfoJson
	END
	ELSE IF @IssueTypeId = 6 --Wrong OU
	BEGIN
		EXEC dbo.TicketVoiding_LogInfo_OU_Select
			 @RequestId			   = @RequestId
			,@IssueTypeId		   = @IssueTypeId
			,@ActionId			   = @ActionId
			,@IsShowLogOnly		   = @IsShowLogOnly
			,@WrongOUInfo		   = @WrongOUInfo
			,@TransInfoJson		   = @TransInfoJson
	END
	ELSE IF @IssueTypeId = 7 --Wrong 1st OU
	BEGIN
		EXEC dbo.TicketVoiding_LogInfo_OU_Select
			 @RequestId			   = @RequestId
			,@ActionId			   = @ActionId
			,@IsShowLogOnly		   = @IsShowLogOnly
			,@IssueTypeId		   = @IssueTypeId
			,@WrongOUInfo		   = @Wrong1stOUInfo
			,@TransInfoJson		   = @TransInfoJson
	END
	ELSE IF @IssueTypeId IN (8,9) --EKO,WKO
	BEGIN
		EXEC dbo.TicketVoiding_LogInfo_KO_Select
			 @RequestId			   = @RequestId
			,@ActionId			   = @ActionId
			,@IsShowLogOnly		   = @IsShowLogOnly
			,@KickOffInfo		   = @KickOffInfo
			,@TransInfoJson		   = @TransInfoJson
	END
	ELSE IF @IssueTypeId = 10 --Red card
	BEGIN
		EXEC dbo.TicketVoiding_LogInfo_DARC_Select
			 @RequestId			   = @RequestId
			,@ActionId			   = @ActionId
			,@IsShowLogOnly		   = @IsShowLogOnly
			,@IssueTypeId		   = @IssueTypeId
			,@DARCInfo			   = @RedCardInfo
			,@TransInfoJson		   = @TransInfoJson
	END
	ELSE IF @IssueTypeId = 19 --ReducedOver
	BEGIN
		EXEC dbo.TicketVoiding_LogInfo_RO_Select
			 @RequestId			   = @RequestId
			,@ActionId			   = @ActionId
			,@IsShowLogOnly		   = @IsShowLogOnly
			,@IssueTypeId		   = @IssueTypeId
			,@ReducedOverInfo	   = @ReducedOverInfo
			,@TransInfoJson		   = @TransInfoJson
	END
	ELSE IF @IssueTypeId = 21 --Not Participate (Use same SP with Reduced Over)
	BEGIN
		EXEC dbo.TicketVoiding_LogInfo_RO_Select
			 @RequestId			   = @RequestId
			,@ActionId			   = @ActionId
			,@IsShowLogOnly		   = @IsShowLogOnly
			,@IssueTypeId		   = @IssueTypeId
			,@ReducedOverInfo	   = @NotParticipateInfo
			,@TransInfoJson		   = @TransInfoJson
	END

	-- Write useraction log	
	BEGIN TRY
		IF OBJECT_ID (N'TVS_UserActionLog') IS NOT NULL 
		BEGIN	       
			INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
			VALUES (@ID, @spName, NULL, @UserID, NULL, GETDATE(),@SubmittedDate)
		END        
	END TRY
	BEGIN CATCH
	END CATCH

END
GO

