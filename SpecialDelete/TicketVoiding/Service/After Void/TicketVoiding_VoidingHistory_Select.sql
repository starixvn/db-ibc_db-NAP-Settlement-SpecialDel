/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_VoidingHistory_Select]
	@VoidingHistoryId	INT
AS
/*	Created by: Charles
	Date 20201203
	Task: select voiddata from TicketVoiding_VoidingHistory table [Redmine: #145719]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20201203@Charles: Optimize Voiding Workflow [Redmine: #145719]
		
	Param's explanation:	
	
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @xmlVoidData  XML

	SELECT @xmlVoidData = (	SELECT VoidData
							FROM TicketVoiding_VoidingHistory WITH(NOLOCK)
							WHERE VoidingHistoryId = @VoidingHistoryId)

	SELECT 
		T.C.value('@IssueTypeId', 'INT') AS IssueTypeId
		,T.C.value('@SubIssueTypeId', 'INT') AS SubIssueTypeId
		,T.C.value('@SubIssueTypeName', 'VARCHAR(500)') AS SubIssueTypeName
		,T.C.value('@SubIssueTypeNameCS', 'NVARCHAR(256)') AS SubIssueTypeNameCS
		,T.C.value('@Reason', 'NVARCHAR(500)') AS Reason
		,T.C.value('@ReasonSC', 'NVARCHAR(500)') AS ReasonSC
		,T.C.value('@ContentChineseTraditional', 'NVARCHAR(4000)') AS ContentChineseTraditional
		,T.C.value('@ContentChineseSimplified', 'NVARCHAR(4000)') AS ContentChineseSimplified
		,T.C.value('@ContentNewChineseSimplified', 'NVARCHAR(4000)') AS ContentNewChineseSimplified
		,T.C.value('@ContentEnglish', 'NVARCHAR(4000)') AS ContentEnglish
		,T.C.value('@ContentSpanish', 'NVARCHAR(4000)') AS ContentSpanish
		,T.C.value('@ContentItalian', 'NVARCHAR(4000)') AS ContentItalian
		,T.C.value('@ContentJapanese', 'NVARCHAR(4000)') AS ContentJapanese
		,T.C.value('@ContentKorean', 'NVARCHAR(4000)') AS ContentKorean
		,T.C.value('@ContentThai', 'NVARCHAR(4000)') AS ContentThai
		,T.C.value('@CreatorId', 'INT') AS CreatorId
		,T.C.value('@CreatorName', 'NVARCHAR(50)') AS CreatorName
		,T.C.value('@DecidedBy', 'NVARCHAR(200)') AS DecidedBy
		,T.C.value('@VoidFromTime', 'NVARCHAR(50)') AS VoidFromTime
		,T.C.value('@VoidToTime', 'NVARCHAR(50)') AS VoidToTime
		,T.C.value('@VoidFromDate', 'NVARCHAR(20)') AS VoidFromDate
		,T.C.value('@VoidToDate', 'NVARCHAR(20)') AS VoidToDate
		,T.C.value('@IsHasSettledTicket', 'BIT') AS IsHasSettledTicket
	FROM	@xmlVoidData.nodes('/VoidData') AS T(C)
	OPTION (OPTIMIZE FOR (@xmlVoidData = NULL ))
END
GO