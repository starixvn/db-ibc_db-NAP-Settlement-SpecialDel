/*<info serverAlias="DBLIC-bodb_Licensee" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_SpecialDelete_TicketListing_CleanUpDataSendOIC]
AS
/*  
	Created by: July  
	Date: 20220112
	Task: SD - Result Amendment - Clean up data - Only support data within 6 months
	DB: DBLIC-bodb_Licensee   

	Revisions:  
		- 20220112@July: Create new SP [Redmine: #167306]

	Param's explanation:	
*/   
BEGIN
	SET NOCOUNT ON
	DECLARE  @ResultID		BIGINT
			,@SettingTime	DATETIME
			,@batch			INT = 1000

	CREATE TABLE #tmpResultID (ResultID BIGINT)

	SET @SettingTime = DATEADD(MONTH, -6, CAST(GETDATE() AS DATETIME))

	WHILE (1=1)
	BEGIN
		DELETE TOP(@batch) l
			OUTPUT deleted.ResultID
			INTO #tmpResultID (ResultID)
		FROM dbo.LicenseeResultAmendment l WITH(ROWLOCK)
		WHERE l.CreatedDate < @SettingTime

		IF @@ROWCOUNT = 0 BREAK;
	END

	WHILE (1=1)
	BEGIN
		DELETE TOP(@batch) d
		FROM dbo.LicenseeResultAmendmentDetails d WITH(ROWLOCK)
			INNER JOIN #tmpResultID r ON d.ResultID = r.ResultID

		IF @@ROWCOUNT = 0 BREAK;
	END

	DROP TABLE #tmpResultID
	SET NOCOUNT OFF
END
GO
