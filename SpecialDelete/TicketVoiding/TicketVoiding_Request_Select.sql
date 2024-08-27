/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
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
		- 20230908@Max: [TVS] Not Participant issue type [Redmine: #192832]
		- 20231102@Max: [TVS] Abnormal Account - Void tickets based on the differences between the losing amount and the given credit of the member [Redmine: #194140]
		- 20231211@July: [TVS] Remove SABA text of league name in case void many matches and apply new way to remove SABA text [Redmine: #196627]
		- 20231221@July: [TVS] Display player name in English for Chinese message in case there is no data on player name in Chinese [Redmine: #198687]
		- 20240102@July: [TVS] Recover Ticket issue type [Redmine: #196020]
		- 20240424@Max: [TVS] Abnormal Bet - Remove some auto void actions & Remove AB (Real Member) issue type [Redmine: #202949]
		- 20240522@Max: [TVS] Wrong Market Offered issue type [Redmine: #197051]
		- 20240813@Max: [TVS] Manage Request - Enhancements [Redmine: #208623]

	Param's explanation:	
	
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @IssueTypeId TINYINT
		,@OrgTransIds VARCHAR(MAX) = NULL
		,@PlayerIds VARCHAR(MAX) = NULL
		,@query NVARCHAR(MAX) = ''
		,@ExecuteSQL NVARCHAR(MAX) = ''
		,@PlayerName NVARCHAR(MAX)
		,@PlayerNamesChineseTraditional NVARCHAR(MAX)
		,@PlayerNamesChineseSimplified NVARCHAR(MAX)
		,@IsHasResettledTicket BIT = 0
	
	DECLARE @tmp_PlayerName AS TABLE (
			PlayerName NVARCHAR(200),
			PlayerNamesChineseTraditional NVARCHAR(200),
			PlayerNamesChineseSimplified NVARCHAR(200)
		)

	SELECT @IssueTypeId = ( SELECT TOP 1 IssueTypeId 
							FROM dbo.TicketVoiding_Request req WITH (NOLOCK) 
							WHERE RequestId = @RequestId
						  )

	IF @IssueTypeId = 22 --Check exists resettled ticket for Recover Issuetye
	BEGIN
		IF EXISTS (SELECT TOP 1 1 FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK) WHERE s.RequestId = @RequestId AND s.IsProcessed = 2)
		BEGIN
			SET @IsHasResettledTicket = 1
		END
	END
	
	SELECT	@RequestId AS RequestId
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
			,@IsHasResettledTicket AS IsHasResettledTicket
			,r.BriefInfoNote
	FROM	dbo.TicketVoiding_Request r WITH(NOLOCK)
		LEFT JOIN CustDB.dbo.Customer cr WITH (NOLOCK) ON cr.custid = r.UserId
		OUTER APPLY (SELECT TOP 1 1 AS isVoided, tv.UserId AS VoidBy, tv.RequestId
					 FROM TicketVoiding_VoidingHistory tv WITH (NOLOCK)
					 WHERE tv.RequestId = r.RequestId 
					 ORDER BY tv.CreatedDate DESC
					)AS tblVoid
		LEFT JOIN CustDB.dbo.Customer cv WITH (NOLOCK) ON cv.custid = tblVoid.VoidBy			
	WHERE	r.RequestId = @RequestId

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

	IF @IssueTypeId = 21 --Generate PlayerNames for Not Participate
	BEGIN
		SET @PlayerIds = (
		SELECT STUFF((SELECT ',' + t.PlayerIds
		FROM (
			SELECT xTrans.PlayerIds
			FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
			CROSS APPLY (
					SELECT CONVERT(XML, rd.TransIds)
				)AS t(xDATA)
			CROSS APPLY (
					SELECT STUFF((SELECT ',' + t.c.value('@PlayerId','VARCHAR(MAX)') 
					FROM t.xDATA.nodes('r') t(c)
					FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)') ,1,1,'')
				)xTrans (PlayerIds)
			WHERE rd.RequestId = @RequestId
		)t
		FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)') ,1,1,'')
		)

		SET @query = 'SELECT t.teamname
						,t.teamnamec_uni
						,t.teamnamecn
					FROM
					(	
						SELECT DISTINCT value 
						FROM string_split (@PlayerIds, '','') 
					)f
					INNER JOIN dbo.team t WITH (NOLOCK) ON t.teamid = f.value
				' 
		SET @ExecuteSQL = 'DBPRO.bodb02.dbo.sp_executesql @query, N''@PlayerIds VARCHAR(MAX)'', @PlayerIds'

		INSERT INTO @tmp_PlayerName (PlayerName, PlayerNamesChineseTraditional, PlayerNamesChineseSimplified)
		EXECUTE	sys.sp_executesql @ExecuteSQL, N'@query NVARCHAR(MAX), @PlayerIds VARCHAR(MAX)', @query, @PlayerIds

		UPDATE @tmp_PlayerName
		SET PlayerNamesChineseTraditional = CASE WHEN ISNULL(PlayerNamesChineseTraditional,'') = '' THEN PlayerName ELSE PlayerNamesChineseTraditional END
		   ,PlayerNamesChineseSimplified = CASE WHEN ISNULL(PlayerNamesChineseSimplified,'') = '' THEN PlayerName ELSE PlayerNamesChineseSimplified END

		SET @PlayerName = LTRIM((SELECT STUFF((SELECT ' & ' + PlayerName
						FROM @tmp_PlayerName
						FOR XML PATH(''),TYPE).value('(./text())[1]','NVARCHAR(MAX)') ,1,2,'')))

		SET @PlayerNamesChineseTraditional = LTRIM((SELECT STUFF((SELECT N' 和 ' + PlayerNamesChineseTraditional
						FROM @tmp_PlayerName
						FOR XML PATH(''),TYPE).value('(./text())[1]','NVARCHAR(MAX)') ,1,2,'')))

		SET @PlayerNamesChineseSimplified = LTRIM((SELECT STUFF((SELECT N' 和 ' + PlayerNamesChineseSimplified
						FROM @tmp_PlayerName
						FOR XML PATH(''),TYPE).value('(./text())[1]','NVARCHAR(MAX)') ,1,2,'')))
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
				,rd.Sporttype
				,STUFF(ts.TransIds,1,1,'') AS TransIds
				,m.hthomescore
				,m.htawayscore
				,m.finalhomescore
				,m.finalawayscore
				,m.GlobalShowTime
			 	,rd.FilterFromTransTime
				,rd.FilterToTransTime
				,rd.FilterBy
				,CASE WHEN @IssueTypeId = 20 THEN NULL ELSE rd.TransIds END AS RequestExtraInfo
				,CAST(rd.livehomescore AS VARCHAR(2)) + '-' + CAST(rd.liveawayscore AS VARCHAR(2)) AS WrongScore
				,CASE WHEN @IssueTypeId = 3 THEN SUBSTRING(rd.IssueDetail, CHARINDEX(';Act:',rd.IssueDetail) + 5, LEN(rd.IssueDetail)) ELSE NULL END AS ActualScore
				,rd.VoidFromTime
				,rd.VoidToTime
				,rd.SubIssueTypeId
				,m.IsNeutral
				,m.matchcode
				,@OrgTransIds AS OrgTransIds
				,rd.ProductIds -- Apply for issuetype Recover Ticket (22)
				,rd.AdvancedExtraInfo
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
					WHERE s.RequestId = rd.RequestId AND @IssueTypeId IN (11,17,20,22)
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

	SELECT @PlayerName AS PlayerNamesEnglish
		  ,@PlayerNamesChineseTraditional AS PlayerNamesChineseTraditional
		  ,@PlayerNamesChineseSimplified AS PlayerNamesChineseSimplified

END