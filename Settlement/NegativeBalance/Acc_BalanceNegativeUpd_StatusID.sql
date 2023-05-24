/*<info serverAlias="DBCTG-bodb02, DBSID-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_BalanceNegativeUpd_StatusID]
  @LogIDs	VARCHAR(8000)
 ,@ErrCode	INT = 0 OUTPUT
 ,@ErrMsg	VARCHAR(1000) = '' OUTPUT  

AS
/*
	Created by: Jamie
	Date: 2013-06-26
	Task: Retrieve Negative Balance by Site 
	DB: DBTXN/bodb02 
	
	Revision: 
		- 20180103@Helen: Change Action List on Negative Balance email & Get Mailing List from OIC [Redmine:82430]
		- 20220315@Kathy: Change to use STRING_SPLIT [Redmine:#166454]
		- 20230523@Kathy: change metadata [Redmine:#188452]
	Param's Explanation:
		+ @LogIDs : '1,2,3,xxx' with xxx: LogID already notified 
	
*/
BEGIN 
	SET NOCOUNT ON 
	UPDATE	BalanceNegativeHistory WITH (UPDLOCK,ROWLOCK)
	SET		StatusID = 1
	WHERE	LogID IN (SELECT [value] FROM STRING_SPLIT(@LogIDs,','))
		
	IF @@ERROR  <> 0
	BEGIN
		SELECT	 @ErrCode	= 101
				,@ErrMsg	= 'Update Status unsuccessfully!'	
		RETURN
	END	
END 
