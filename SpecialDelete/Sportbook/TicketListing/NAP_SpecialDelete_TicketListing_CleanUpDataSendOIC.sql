/*<info serverAlias="DBLIC-bodb_Licensee" executers="wsv_nap" isFunction="0"></info>*/
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

	DECLARE  @SettingTime	DATETIME
	SET @SettingTime = DATEADD(MONTH, -6, CAST(GETDATE() AS DATE))

	CREATE TABLE #tmpResultID (ResultID BIGINT PRIMARY KEY)
	DECLARE @tmpResultID_Batch AS TABLE (ResultID BIGINT PRIMARY KEY)

	INSERT INTO #tmpResultID(ResultID)
	SELECT ResultID
	FROM dbo.LicenseeResultAmendment  WITH(NOLOCK)
	WHERE CreatedDate < @SettingTime

	--Delete data
	WHILE (1=1)
	BEGIN
		DELETE TOP (300) R
			OUTPUT DELETED.ResultID
			INTO @tmpResultID_Batch (ResultID)		
		FROM #tmpResultID R

		IF @@ROWCOUNT = 0 BREAK;

		DELETE r
		FROM LicenseeResultAmendment r WITH(ROWLOCK) 
			INNER JOIN @tmpResultID_Batch b ON r.ResultID = b.ResultID
		
		WHILE (1=1)
		BEGIN
			DELETE TOP(2000) d
			FROM dbo.LicenseeResultAmendmentDetails d WITH(ROWLOCK)
				INNER JOIN @tmpResultID_Batch b ON d.ResultID = b.ResultID

			IF @@ROWCOUNT = 0 BREAK
			
			WAITFOR DELAY '00:00:00.020'
		END

		DELETE @tmpResultID_Batch
	END

	DROP TABLE #tmpResultID
	SET NOCOUNT OFF
END
GO
