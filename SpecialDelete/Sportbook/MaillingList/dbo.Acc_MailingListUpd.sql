USE [bodb_ACC]
GO
/****** Object:  StoredProcedure [dbo].[Acc_MailingListUpd]    Script Date: 3/27/2017 5:19:57 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.Acc_MailingListUpd    Script Date: 9/15/2015 5:41:32 AM ******/
/****** Object:  Stored Procedure dbo.Acc_MailingListUpd    Script Date: 9/3/2015 8:47:38 AM ******/
/****** Object:  Stored Procedure dbo.Acc_MailingListUpd    Script Date: 9/3/2015 8:46:06 AM ******/
/****** Object:  Stored Procedure dbo.Acc_MailingListUpd    Script Date: 8/21/2015 9:11:20 AM ******/
/****** Object:  Stored Procedure dbo.Acc_MailingListUpd    Script Date: 8/21/2015 9:10:03 AM ******/
ALTER PROCEDURE [dbo].[Acc_MailingListUpd]
	@Userid INT,		
	@Siteid INT = 0, 
	@FuncID INT = 287,  -- [SpecialDeleteMailing]
	@FuncName nvarchar(100) = '[SpecialDeleteMailing]',
	@ToList VARCHAR(4000), 
	@CcList VARCHAR(4000), 	
	@BccList VARCHAR(4000)=Null,
	@ErrCode INT = 0 OUTPUT,  
	@ErrMsg  VARCHAR(1000)='' OUTPUT  	
AS

/*  
Created by: Scott  
Date: 2013-01-08
Task : Update Mailing list
DB: DBACC/BODB_ACC
Original SP:   
Revisions: 
	20130301@Scott: Add more parameter @funcname and change dblink from db03 -> DBPOLICY	
	20130305@Lukas: Move SP to bodb_acc
	20130920@Kathy: Validate siteid for groups was configured on web before (12EU, IT QA, IT Support groups)
	20131101@Kathy: Add Foobet group [Redmine:#5697]
	20131113@Kathy: Add RecoverBet group [Redmine:#6647]
	20140411@Kathy: Add BetFair, OneExchange's group [Redmine:#6647]
	20150615@Dominic: Add BetTrade's group RM:#36964
	20170327@Kent: Integrate Cash-out [Redmine:#72059]
*/  

BEGIN	

SET NOCOUNT ON

--### DECLARE VARIABLE ###--
DECLARE @startRun DATETIME, @endRun DATETIME,@duration INT
DECLARE @LogData NVARCHAR(4000)
DECLARE @TrackingValue2 VARCHAR(1000)
DECLARE @ToListOld VARCHAR(4000),@CcListOld VARCHAR(4000),@BccListOld VARCHAR(4000)

--### SET VALUE FOR VARIABLE ###--
SET	@startRun = GETDATE()

SELECT	@ToListOld = Tolist,
		@CclistOld = Cclist,
		@BccListOld = BccList
FROM  Acc_MailingList WITH(NOLOCK)
WHERE Siteid = @siteid 	and funcid = @funcid

IF @Bcclist is null
	SET @Bcclist =@Bcclistold 
  
--### VALIDATE DATA AND CHECK CONDITIONAL ###--
--1. CHECK PERMISSION.
EXEC DBPOLICY.bodb02.dbo.Acc_Con_CheckPermission @custid=@UserID,@funcname=@FuncName,@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
IF @ErrCode <> 0
	RETURN

--2. VALIDATE LICENSEE.
IF @Siteid NOT IN (1000000, 1000001, 1000002, 1000003, 1000004, 1000005, 1000006, 1000007, 1000008) -- 12EU, IT QA, IT Support, Foobet, RecoverBet, BetFair, OneExchange, BetTrade, Cash-out
	IF NOT EXISTS( SELECT 1 FROM bodb02.dbo.[SITE] WITH(NOLOCK) WHERE siteid = @Siteid  and islicensee = 1 ) AND @Siteid <> 0
	BEGIN
		SELECT @ErrMsg = 'This Licensee does not exists in System.',
				@ErrCode = 101		
		RETURN
	END		

--3. CHECK DATA HAVE BEEN CHANGE.
if (@Tolist = @ToListOld and @CcList = @CclistOld and @BccList = @Bcclistold )
begin
	SELECT @ErrMsg = 'Data doesn''t change, Please check again!',
			@ErrCode = 103		
	RETURN
end

--### UPDATE DATA ###--
UPDATE 	Acc_MailingList WITH(ROWLOCK, UPDLOCK) 
SET ToList = @ToList, 
	CcList = @CcList, 
	BccList = case when @BccList is null then BccList else @BccList end
WHERE Siteid = @siteid 	and funcid = @funcid

IF @@ERROR > 0
BEGIN
	SELECT @ErrMsg = 'Update Mailing unsuccessful.',
			@ErrCode = 104
		RETURN
END

--### WRITE LOG ###--
SELECT @LogData = '<Acc_MailingListUpd> Siteid="' + COALESCE(CAST (@Siteid AS VARCHAR(10)),SPACE(1)) + '" ' 
						+ 'FuncID="' + COALESCE(CAST (@FuncID AS VARCHAR(10)),SPACE(1)) + '" '							
						+ 'ToList="' + COALESCE(@ToList, SPACE(1)) + '" '							
						+ 'CcList="' + COALESCE(@CcList, SPACE(1)) + '" '							
						+ 'BccList="' + COALESCE(@BccList, SPACE(1)) + '" '							
				+ '</Acc_MailingListUpd>'
				
SELECT @TrackingValue2 = '<Acc_MailingListUpd> Siteid="' + COALESCE(CAST (@Siteid AS VARCHAR(10)),SPACE(1)) + '" ' 
						+ 'FuncID="' + COALESCE(CAST (@FuncID AS VARCHAR(10)),SPACE(1)) + '" '							
						+ 'ToList="' + COALESCE(@ToListOld, SPACE(1)) + '" '							
						+ 'CcList="' + COALESCE(@CcListOld, SPACE(1)) + '" '							
						+ 'BccList="' + COALESCE(@BccListOLd, SPACE(1)) + '" '							
				+ '</Acc_MailingListUpd>'			
								
	
SET @endRun = GETDATE()
SET @duration  = DATEDIFF(millisecond,@startRun,@endRun)

EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
		@UserID = @UserID,
		@CustID = @UserID,
		@ActionID = 1403,
		@TrackingValue = @LogData,
		@TrackingValue2 = @TrackingValue2,
		@duration = @duration		
	
END




GRANT EXECUTE ON [dbo].[Acc_MailingListUpd] TO [bodbAdminNet]