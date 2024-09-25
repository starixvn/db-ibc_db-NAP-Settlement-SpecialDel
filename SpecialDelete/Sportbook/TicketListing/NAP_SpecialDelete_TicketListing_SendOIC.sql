/*<info serverAlias="DBLIC-bodb_Licensee" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_SpecialDelete_TicketListing_SendOIC]
(
	 @MatchID				INT
	,@Globalshowtime		DATETIME --apply all sports 
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
		- 20240614@Max: [TVS] Ticket Listing - Insert data to DB053 [Redmine: #206452]
		- 20240822@Max: [TVS] Integrate new bet type of Baseball AiO - Phase 2 [Redmine: #209441]

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
		, SessionID     NVARCHAR(100)
	)
	DECLARE @tmpResultInfo TABLE (LicenseeName NVARCHAR(50), SessionID NVARCHAR(100), IsFinish BIT)
	
	INSERT INTO @tmpResultAmendment (TransID, CustID, Recommend, LicenseeName, SessionID)
	SELECT t, c, re, ln, ssid
	FROM OPENJSON(@Decompress_TransInfoSendOICJson) 
	WITH( t BIGINT, c INT, re INT, ln NVARCHAR(50), ssid NVARCHAR(100)
	) tbl

	INSERT INTO @tmpResultInfo (LicenseeName, SessionID)
	SELECT DISTINCT LicenseeName, SessionID
	FROM @tmpResultAmendment

	WHILE (1=1)
	BEGIN
		
		UPDATE TOP (1) t
		SET t.IsFinish = 1
			, @SessionID = t.SessionID
			, @LicenseeName = t.LicenseeName
		FROM @tmpResultInfo t
		WHERE IsFinish IS NULL

		IF @@ROWCOUNT = 0 BREAK;

		INSERT INTO dbo.LicenseeResultAmendment (SiteName, SessionID, MatchID, EventDate)
		SELECT @LicenseeName, @SessionID, @MatchID, @Globalshowtime

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