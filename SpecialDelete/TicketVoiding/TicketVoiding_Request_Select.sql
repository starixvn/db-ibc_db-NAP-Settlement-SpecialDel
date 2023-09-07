/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Request_Select]
(
	@RequestId		INT
)
AS
/*	Created by: 20181212@Kathy
	Task: view request [Redmine:#90155]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20190815@Raymond.Le: Return column IssueTypeId [#116617]
		- 20191111@Max: Ticket Voiding System - Abnormal Bet Issue Type [Redmine: #111541]
		- 20191219@Helen: Ticket Voiding System - hotfix [Redmine: #111541]
		- 20191220@Max: Some enhancement for TVS Abnormal Bets [Redmine: #125828]
		- 20200106@Max: Update KO Time to GlobalShowTime on General Info of Abnormal Bet [Redmine: #126623]
		- 20200215@Max: Abnormal Void Bets Automation [Redmine: #128359]
		- 20200701@Max: [TVS] Danger Accept Bets Issue Type [Redmine: #135947]
		- 20200819@Max: Issue for Abnormal Bet Request not show bettype [Redmine: #135947]
		- 20200820@Max: Action in Manage Request did not show information in TVS system [Redmine: #139933]
		- 20200901@July: [TVS] - Enhance for Danger Accept - Phase 2 [Redmine: #140785]
		- 20200910@Charles: [TVS] Enhance Void by Accept Time [Redmine: #141127]
		- 20200922@Charles: TVS - Enhance for Danger Accept Phase 3 [Redmine: #141579]
		- 20201021@Zane: TVS - Enhance for Danger Accept Phase 4 [Redmine: #143091]
		- 20201106@July: [TVS] - Abnormal Account [Redmine: #143666]
		- 20210219@July: TVS - Abnormal Bet - Exclude Customer Class - [Redmine: #147176]
		- 20210319@July: TVS - Danger Accept/Red Card Enhancement - Phase 7 [Redmine: #150459]
		- 20210420@July: TVS - New Issue Type - AB (Real Member)- [Redmine: #147175]
		- 20210428@Max: TVS - New Issue Type - Wrong Score - [Redmine: #140953]
		- 20210506@July: TVS - Danger Accept Enhancement - Phase 8 [Redmine: #152051]
		- 20210527@Max: [TVS] Danger Accept Enhancement - Phase 9 [Redmine: #153216]
		- 20210621@Max: [TVS] Wrong Score Enhancement 1 [Redmine: #156349]
		- 20210811@Max: [TVS] Wrong Score Enhancement 2 [Redmine: #157096]
		- 20211012@July: TVS - Danger Accept Enhancement - Phase 10 [Redmine: #155792]
		- 20211101@July: TVS - Abnormal Bet - Void Mix Parlay Ticket [Redmine: #161337]
		- 20211123@July: TVS - Void Archived Tickets [Redmine: #140180]
		- 20211225@Max: TVS - New issue type Wrong HDP and Wrong 1H HDP [Redmine: #146717]
		- 20220208@Max: [TVS] Wrong Score Enhancement 3 [Redmine: #164561]
		- 20220318@July: TVS - Danger Accept Enhancement - Phase 11 [Redmine: #164562]
		- 20220525@July: TVS - Notify Letstalk when void Abnormal Bets [Redmine: #172212]
		- 20220808@July: TVS - Change of TVS regarding to Scale out DBTrans [Redmine: #173229]
		- 20221026@July: TVS - VAR message [Redmine: #178088]
		- 20230717@Max: [TVS] Duplicate Ticket - New Issue Type [Redmine: #187835]
		- 20230814@Max: [TVS] Reduced Over - Update rule for action "auto void" [Redmine: #191762]

	Param's explanation:	
	
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @IssueTypeId TINYINT
		,@OrgTransIds VARCHAR(MAX) = NULL

	SELECT	r.Sporttype
			,r.IssueTypeId
			,r.ActionId
			,r.MistakenBy
			,r.DecidedBy
			,(SELECT	o.OperatorId AS '@OperatorId', o.OperatorTypeId AS '@TypeId'
				FROM	dbo.TicketVoiding_OperatorInfo o WITH(NOLOCK)
				WHERE	o.RequestId = @RequestId
				FOR XML PATH ('r'), ROOT('root')) AS OperatorInfo
			,r.Provider
			,r.Source
			,r.Remark
			,r.IsTest
			,ISNULL(isVoided,0) AS isVoided
			,cr.username AS RequestedBy
			,cv.username AS VoidedBy
			,r.UserId
			,CASE WHEN r.ActionId = 1 THEN 'AddRequest' 
				  WHEN r.ActionId = 4 THEN 'VoidInstant'
				  WHEN r.ActionId = 6 THEN 'VoidInstant5m'
				  WHEN r.ActionId = 7 THEN 'VoidInstant10m' 
				  WHEN r.ActionId = 8 THEN 'VoidInstantNopolicy'
				  WHEN r.ActionId = 9 THEN 'VoidResultKeyed'
				ELSE '' END AS ActionName
	FROM	dbo.TicketVoiding_Request r WITH(NOLOCK)
		LEFT JOIN CustDB.dbo.Customer cr WITH (NOLOCK) ON cr.custid = r.UserId
		OUTER APPLY (SELECT TOP 1 1 AS isVoided, tv.UserId AS VoidBy, tv.RequestId
					 FROM TicketVoiding_VoidingHistory tv WITH (NOLOCK)
					 WHERE tv.RequestId = r.RequestId 
					 ORDER BY tv.CreatedDate DESC
					)AS tblVoid
		LEFT JOIN CustDB.dbo.Customer cv WITH (NOLOCK) ON cv.custid = tblVoid.VoidBy			
	WHERE	r.RequestId = @RequestId

	SELECT @IssueTypeId = ( SELECT TOP 1 IssueTypeId 
							FROM dbo.TicketVoiding_Request req WITH (NOLOCK) 
							WHERE RequestId = @RequestId
						  )

	IF @IssueTypeId = 20 --Generate OrgTransIds for Duplicate Tickets
	BEGIN
		SET @OrgTransIds = (
				SELECT xTrans.OrgTransIds
				FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
				CROSS APPLY (
						SELECT CONVERT(XML, rd.TransIds)
					)AS t(xDATA)
				CROSS APPLY (
						SELECT STUFF((SELECT ',' + t.c.value('@OrgTransIds','VARCHAR(MAX)') 
						FROM t.xDATA.nodes('root/r') t(c)
						FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)') ,1,1,'')
					)xTrans (OrgTransIds)
				WHERE rd.RequestId = @RequestId
		)
	END

	IF @IssueTypeId <> 13 -- Except for AC 
	BEGIN
		SELECT	rd.MatchId
				,m.eventdate
				,m.ParentID
				,rd.LeagueId
				,rd.HomeId
				,rd.AwayId
				,rd.KickOffTime
				,STUFF(ts.TransIds,1,1,'') AS TransIds
				,m.hthomescore
				,m.htawayscore
				,m.finalhomescore
				,m.finalawayscore
				,m.GlobalShowTime
				,rd.FilterFromTransTime
				,rd.FilterToTransTime
				,rd.FilterBy
				,rd.TransIds AS RequestExtraInfo
				,CAST(rd.livehomescore AS VARCHAR(2)) + '-' + CAST(rd.liveawayscore AS VARCHAR(2)) AS WrongScore
				,CASE WHEN @IssueTypeId = 3 THEN SUBSTRING(rd.IssueDetail, CHARINDEX(';Act:',rd.IssueDetail) + 5, LEN(rd.IssueDetail)) ELSE NULL END AS ActualScore
				,rd.VoidFromTime
				,rd.VoidToTime
				,rd.SubIssueTypeId
				,m.IsNeutral
				,m.matchcode
				,@OrgTransIds AS OrgTransIds
		FROM	dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
			OUTER APPLY (
				SELECT	m.eventdate, m.ParentID, m.hthomescore, m.htawayscore, m.finalhomescore, m.finalawayscore, m.GlobalShowTime, m.matchcode, ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
				FROM	dbo.match m WITH(NOLOCK)
				WHERE	m.matchid = rd.matchid
				UNION
				SELECT	m.eventdate, m.ParentID, m.hthomescore, m.htawayscore, m.finalhomescore, m.finalawayscore, m.globalshowtime, m.matchcode, ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
				FROM	dbo.match14 m WITH(NOLOCK)
				WHERE	m.matchid = rd.matchid
			) m
			OUTER APPLY (SELECT ',' + CAST(TransId AS VARCHAR(MAX)) 
					FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
					WHERE s.RequestId = rd.RequestId AND @IssueTypeId IN (11,15,17,20)
					FOR XML PATH('')
				)ts	 (TransIds)
		WHERE	rd.RequestId = @RequestId
		ORDER BY CASE WHEN @IssueTypeId = 1 THEN m.matchcode ELSE NULL END
			, CASE WHEN @IssueTypeId = 3 THEN CAST(rd.livehomescore AS VARCHAR(2)) + '-' + CAST(rd.liveawayscore AS VARCHAR(2)) ELSE NULL END
	END
	ELSE IF @IssueTypeId = 13 -- apply for Abnormal Account
	BEGIN
		SELECT	TOP 1
				 rd.Usernames AS UserNames
				,rd.ProductIds AS ProductIds
				,rd.TicketStatusIds AS StatusIds 
				,rd.FromWinlostDate AS FromDate 
				,rd.ToWinlostDate AS ToDate
				,rd.SubIssueTypeId
		FROM	dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
		WHERE	rd.RequestId = @RequestId
	END

	SELECT TOP 1 tv.MessageId
			,msg.Content_en AS ContentEnglish
			,msg.Content_ch AS ContentChineseTraditional
			,msg.Content_cs AS ContentChineseSimplified
	FROM TicketVoiding_VoidingHistory tv WITH (NOLOCK)
		CROSS APPLY (
				SELECT m.Content_en, m.Content_ch, m.Content_cs
				FROM DBMSG.bodb_Message.dbo.Msg m WITH (NOLOCK)
				WHERE m.MessageId = tv.MessageId
			) msg
	WHERE tv.RequestId = @RequestId AND tv.StatusId = 2
	ORDER BY tv.CreatedDate DESC

END