/*<info serverAlias="DBACC-BODB_ACC" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_MailingListIns]
	@Userid int,		
	@Siteid int = 0, 
	@FuncID int = 287,  -- [SpecialDeleteMailing]
	@FuncName nvarchar(100) = '[SpecialDeleteMailing]',
	@ToList varchar(4000), 
	@CcList varchar(4000), 	
	@BccList varchar(4000)='',
	@ErrCode INT = 0 OUTPUT,  
	@ErrMsg  VARCHAR(1000)='' OUTPUT  
	
AS

/*  
	Created by: Scott  
	Date: 2013-01-07
	Task : Insert Mailing list
	DB: DBACC/BODB_ACC
	Original SP:   
	
	Revisions: 
		- 20130301@Scott: Add more parameter @funcname and change dblink from db03 -> DBPOLICY
		- 20130305@Lukas: move SP to bodb_acc
		- 20130920@Kathy: Validate siteid for groups was configured on web before (12EU, IT QA, IT Support groups)
		- 20131101@Kathy: Add Foobet group [Redmine:#5697]
		- 20131113@Kathy: Add RecoverBet group [Redmine:#6647]
		- 20140411@Kathy: Add BetFair, OneExchange's group [Redmine:#6647]
		- 20150615@Dominic: Add BetTrade's group RM:#36964
		- 20170327@Kent: Integrate Cash-out [Redmine:#72059]
		- 20180808@Helen: DB05.DBPOLICY migration - Move to DBCUST [Redmine:99462]
*/  

BEGIN	

	SET NOCOUNT ON

	--### DECLARE VARIABLE ###--
	DECLARE @startRun DATETIME,	@endRun	DATETIME, @duration	INT
	DECLARE @LogData NVARCHAR(4000)


	--### SET VALUE FOR VARIABLE ###--
	SET	@startRun = GETDATE()  

	--### VALIDATE DATA AND CHECK CONDITIONAL ###--
	 --1. CHECK PERMISSION
	EXEC DBPOL.NAP_UserControl.dbo.Acc_Con_CheckPermission @custid=@UserID,@funcname=@FuncName,@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
	IF @ErrCode <> 0
		RETURN

	--2. VALIDATE SITEID. 
	IF @Siteid NOT IN (1000000, 1000001, 1000002, 1000003, 1000004, 1000005, 1000006, 1000007, 1000008) -- 12EU, IT QA, IT Support, Foobet, RecoverBet, BetFair, OneExchange, BetTrade, Cash-out
		IF NOT EXISTS( SELECT 1 FROM bodb02.dbo.[SITE] WITH(NOLOCK) WHERE siteid = @Siteid  and islicensee = 1 ) AND @Siteid <> 0
		BEGIN
			SELECT @ErrMsg = 'This Licensee does not exists in System.',
					@ErrCode = 101		
			RETURN
		END		
		

	--3. VALIDATE MAILING LIST.
	IF EXISTS( SELECT 1 FROM Acc_MailingList WITH(NOLOCK) WHERE siteid = @siteid  and FuncID = @FuncID )
	BEGIN
		SELECT @ErrMsg = 'This Mailing exists in System',
				@ErrCode = 103		
		RETURN
	END

	--### INSERT DATA ###--
	INSERT INTO Acc_MailingList (Siteid, FuncID, ToList, CcList, BccList ) 
	VALUES ( @Siteid, @FuncID, @ToList, @CcList, @BccList )
		
	IF @@ERROR > 0
	BEGIN
		SELECT @ErrMsg = 'Insert Mailing unsuccessful.',
				@ErrCode = 104
			RETURN
	END

	--### WRITE LOG ###--

	SELECT @LogData = '<Acc_MailingListIns> Siteid="' + COALESCE(CAST (@Siteid AS VARCHAR(10)),SPACE(1)) + '" ' 
							+ 'FuncID="' + COALESCE(CAST (@FuncID AS VARCHAR(10)),SPACE(1)) + '" '							
							+ 'ToList="' + COALESCE(@ToList, SPACE(1)) + '" '							
							+ 'CcList="' + COALESCE(@CcList, SPACE(1)) + '" '							
							+ 'BccList="' + COALESCE(@BccList, SPACE(1)) + '" '							
					+ '</Acc_MailingListIns>'
		
	SET @endRun = GETDATE()
	SET @duration  = DATEDIFF(millisecond,@startRun,@endRun)

	EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
		@Userid = @userid,
		@Custid = @userid,
		@ActionID = 1402,
		@TrackingValue = @LogData,
		@Duration = @duration
END
GO
/*
==========Execute sample=================
declare @errcode int, @errmsg varchar(1000)
set @errcode=0
set @errmsg = ''
exec Acc_MailingListIns  
	@Userid=8,	
	@Siteid=2,
	@FuncID=5,
	@ToList='mail.tolist@procedure.com',
	@ccList='mail.CClist@procedure.com',
	@bccList='mail.BCClist@procedure.com',	
	@errcode = @errcode output,	@errmsg = @errmsg output
select @errcode, @errmsg	
 
*/