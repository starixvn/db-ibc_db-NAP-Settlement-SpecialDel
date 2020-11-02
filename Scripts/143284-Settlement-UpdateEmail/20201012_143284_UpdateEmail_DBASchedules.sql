/*<info serverAlias="DBTP-bodb_consistency" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created:20201012@Louisa
    Task:  Update new email domain starixvn.com [Redmine:#143284]
    DB: DBTP/bodb_consistency
	
	Revisions:
		- 20201012@Louisa: Update new email domain starixvn.com [Redmine:#143284]
*/

USE bodb_consistency
GO

BEGIN
	BEGIN TRY

		UPDATE dbo.DBA_Schedules WITH(ROWLOCK, UPDLOCK)
		SET Emails =  REPLACE(Emails,'starixsoft','starixvn')
		WHERE ISNULL(Emails,'') <> ''

		SELECT  ERROR_MESSAGE()

	END TRY

	BEGIN CATCH
		SELECT	ERROR_MESSAGE()
	END CATCH
	
END
