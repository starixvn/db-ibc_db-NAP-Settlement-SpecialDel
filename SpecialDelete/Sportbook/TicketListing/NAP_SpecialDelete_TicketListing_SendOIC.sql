/*<info serverAlias="DBLIC-bodb_Licensee" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_SpecialDelete_TicketListing_SendOIC]
(
	 @SiteName				NVARCHAR(50)
	,@MatchID				INT
	,@SessionID				VARCHAR(50)
	,@EventDate				DATETIME
	,@ResultAmendmentXML	XML
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
		@ResultAmendmentXML:  <root><r TransId="111" CustId="1112"/></root>
*/   
BEGIN
	SET NOCOUNT ON
	DECLARE  @ResultID		BIGINT

	DECLARE @tmpResultAmendment TABLE (TransID BIGINT, CustID INT)
	INSERT INTO @tmpResultAmendment (TransID, CustID)
	SELECT   T.C.value('@TransId', 'BIGINT') AS TransID
			,T.C.value('@CustId', 'INT') AS CustID
	FROM @ResultAmendmentXML.nodes('/root/r') as [T](C)

	INSERT INTO dbo.LicenseeResultAmendment (SiteName, SessionID, MatchID, EventDate)
	SELECT @SiteName, @SessionID, @MatchID, @EventDate

	SET @ResultID = SCOPE_IDENTITY()

	INSERT INTO dbo.LicenseeResultAmendmentDetails (ResultID, TransID, CustID, Recommend)
	SELECT @ResultID, t.TransID, t.CustID, c.recommend
	FROM @tmpResultAmendment t
		INNER JOIN bodb02.dbo.CustInfo c WITH(NOLOCK) ON t.CustID = c.custid 
	 
	SET NOCOUNT OFF
END