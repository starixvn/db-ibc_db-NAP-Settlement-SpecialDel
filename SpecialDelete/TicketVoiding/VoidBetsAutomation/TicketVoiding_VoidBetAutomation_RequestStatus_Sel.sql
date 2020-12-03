/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_VoidBetAutomation_RequestStatus_Sel]
(
    @RequestIDs VARCHAR(MAX)
)
AS
/*	Created by: Zane
	Date 20201203
	Task: TVS - New issue type Abnormal Accounts [Redmine: #143666]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20201203@Zane: Create new SP [Redmine: #143666]	
	
	Param's explanation:	
	
*/
BEGIN
    SET NOCOUNT ON
    CREATE TABLE #tblRequestID
    (
        RequestID INT
    )


    INSERT INTO #tblRequestID (RequestID)
    SELECT tmp.val
    FROM dbo.f_SplitString(@RequestIDs, ',') tmp
    OPTION (MAXRECURSION 0)


    SELECT tvs.RequestID
		, max(tvs.SessionID) AS SessionID
		, tvs.statusID
    FROM dbo.Ticketvoiding_VoidBetAutomation_Service tvs WITH (NOLOCK)
	INNER JOIN #tblRequestID r
		ON r.RequestID = tvs.RequestID
	group by tvs.RequestID, tvs.statusID

    DROP TABLE #tblRequestID
END