/*<info serverAlias="DBLIC-bodb_Licensee" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_SpecialDelete_TicketListing_SendOIC]
(
	 @MatchID				INT
	,@EventDate				DATETIME
	,@TransInfoSendOICJson	VARCHAR(MAX) = NULL 
)
AS
/*  
	Created by: 20211119@July  
	Task: SD - Send data to OIC instead of file
	DB: DBLIC-bodb_Licensee   

	Revisions:  
		- 20211119@July: Create new SP [Redmine: #159115]
		- 20230623@July: Ticket listing - Enhance performance when sending data to many Licensees at a time [Redmine: #190071]

	Param's explanation:	
*/   
BEGIN
	SET NOCOUNT ON
	DECLARE  @ResultID		BIGINT
			,@SessionID     NVARCHAR(100)
			,@LicenseeName	NVARCHAR(50)
	
	DECLARE @Decompress_TransInfoSendOICJson NVARCHAR(MAX) = NULL

	SET @Decompress_TransInfoSendOICJson = CAST(DECOMPRESS(CONVERT(VARBINARY(MAX), @TransInfoSendOICJson, 1)) AS NVARCHAR(MAX))

	DECLARE @tmpResultAmendment TABLE (
		  TransID		BIGINT
		, CustID		INT
		, Recommend		INT
		, LicenseeName  NVARCHAR(50)
	)
	DECLARE @tmpResultInfo TABLE (LicenseeName NVARCHAR(50), SessionID NVARCHAR(100), IsFinish BIT)
	
	INSERT INTO @tmpResultAmendment (TransID, CustID, Recommend, LicenseeName)
	SELECT t, c, re, ln
	FROM OPENJSON(@Decompress_TransInfoSendOICJson) 
	WITH( t BIGINT, c INT, re INT, ln NVARCHAR(50)
	) tbl

	INSERT INTO @tmpResultInfo (LicenseeName)
	SELECT DISTINCT LicenseeName
	FROM @tmpResultAmendment

	WHILE (1=1)
	BEGIN
		SET @SessionID = CAST (NEWID() AS NVARCHAR(100))
		
		UPDATE TOP (1) t
		SET t.IsFinish = 1
			, t.SessionID = @SessionID
			, @LicenseeName = t.LicenseeName
		FROM @tmpResultInfo t
		WHERE IsFinish IS NULL

		IF @@ROWCOUNT = 0 BREAK;

		INSERT INTO dbo.LicenseeResultAmendment (SiteName, SessionID, MatchID, EventDate)
		SELECT @LicenseeName, @SessionID, @MatchID, @EventDate

		SET @ResultID = SCOPE_IDENTITY()

		INSERT INTO dbo.LicenseeResultAmendmentDetails (ResultID, TransID, CustID, Recommend)
		SELECT @ResultID, TransID, CustID, Recommend
		FROM @tmpResultAmendment
		WHERE LicenseeName = @LicenseeName
	END

	--RETURN DATA
	SELECT LicenseeName, SessionID
	FROM @tmpResultInfo

	SET NOCOUNT OFF
END