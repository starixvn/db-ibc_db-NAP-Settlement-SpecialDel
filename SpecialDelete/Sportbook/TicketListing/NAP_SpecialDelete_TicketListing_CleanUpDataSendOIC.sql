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
	
	DECLARE @start INT = 1, @end INT

	CREATE TABLE #tmpResultID (ID INT IDENTITY(1,1), ResultID BIGINT)

	SET @SettingTime = DATEADD(MONTH, -6, CAST(GETDATE() AS DATETIME))

	INSERT INTO #tmpResultID(ResultID)
	SELECT ResultID
	FROM dbo.LicenseeResultAmendment  WITH(NOLOCK)
	WHERE CreatedDate < @SettingTime

	SET @end = (SELECT MAX(ID) FROM #tmpResultID)

	--Delete data
	WHILE (@start <= @end)
	BEGIN
		SELECT @ResultID = ResultID
		FROM #tmpResultID
		WHERE ID = @start

		DELETE FROM LicenseeResultAmendment WITH(ROWLOCK) WHERE ResultID = @ResultID
		
		WHILE (1=1)
		BEGIN
			DELETE TOP(1000) d
			FROM dbo.LicenseeResultAmendmentDetails d WITH(ROWLOCK)
			WHERE d.ResultID = @ResultID 

			IF @@ROWCOUNT = 0 BREAK

			WAITFOR DELAY '00:00:00.020'
		END
		SET @start = @start + 1
	END

	DROP TABLE #tmpResultID
	SET NOCOUNT OFF
END
GO
