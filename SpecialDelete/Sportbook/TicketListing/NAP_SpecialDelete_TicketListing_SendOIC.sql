/*<info serverAlias="DBLIC-bodb_Licensee" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_SpecialDelete_TicketListing_SendOIC]
(
	 @SiteName				NVARCHAR(50)
	,@MatchID				INT
	,@EventDate				DATETIME
	,@ResultAmendmentXML	XML
	,@IsSent				BIT
)
AS
/*  
	Created by: July  
	Date: 20211119
	Task: SD - Send data to OIC instead of file
	DB: DBLIC-bodb_Licensee   

	Revisions:  
		- 20211119@July: Create new SP [Redmine: #159115]

	Param's explanation:	
		@ResultAmendmentXML:  <root><r TransID="111" CustID="1112"/></root>
*/   
BEGIN
	SET NOCOUNT ON
	DECLARE  @ResultID		BIGINT
			,@SessionID		UNIQUEIDENTIFIER
	SET @SessionID = NEWID()

	DECLARE @tmpResultAmendment TABLE (TransID BIGINT, CustID INT)
	INSERT INTO @tmpResultAmendment (TransID, CustID)
	SELECT   T.C.value('@TransID', 'BIGINT') AS TransID
			,T.C.value('@CustID', 'INT') AS CustID
	FROM @ResultAmendmentXML.nodes('/root/r') as [T](C)

	INSERT INTO dbo.LicenseeResultAmendment (SiteName, SessionID, MatchID, EventDate, IsSent)
	SELECT @SiteName, @SessionID, @MatchID, @EventDate, @IsSent

	SET @ResultID = SCOPE_IDENTITY()

	INSERT INTO dbo.LicenseeResultAmendmentDetails (ResultID, TransID, CustID)
	SELECT @ResultID, TransID, CustID
	FROM @tmpResultAmendment
	 
	SET NOCOUNT OFF
END