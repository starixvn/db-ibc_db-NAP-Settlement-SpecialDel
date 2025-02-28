/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_SubIssueType_AutoSelect]
(	
	@MainSubIssueTypeId		TINYINT
	,@LinkMatchIds			VARCHAR(MAX)
)
AS
/*	
	Created by: 20211013@Max
	Task: [TVS] Danger Accept Enhancement - Phase 10 [Redmine: #155792]
	DB: DBPRO/bodb02
	
	Revisions: 
		- 20211013@Max: Create new SP [Redmine: #155792]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20221025@July: TVS - VAR message [Redmine: #178088]
		- 20241216@July: [TVS] Danger Accepted - Auto fill number of booking/goal kick/goal to the message template [Redmine: #214377]
		- 20250228@Lani: [TVS] Wrong Score - Add new sub type and related event function [Redmine: #216151]

	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @tmp_LinkMatch AS TABLE (MatchId INT)

	INSERT INTO @tmp_LinkMatch (MatchId)
	SELECT DISTINCT value AS MatchId
	FROM STRING_SPLIT(@LinkMatchIds, ',')
	WHERE value <> ''

	IF @MainSubIssueTypeId IN (2, 68, 69, 132, 133, 134, 135) --Main Corner Home/Away - No Indication Home/Away Corner (No Onwards/Onwards)
	BEGIN
		SELECT m.MatchId
			,CASE WHEN mr.matchid IS NOT NULL THEN 
						CASE WHEN @MainSubIssueTypeId = 2 THEN 26 --Next Corner
							 WHEN @MainSubIssueTypeId = 68 THEN 70 --Next Corner Home
							 WHEN @MainSubIssueTypeId = 69 THEN 71 --Next Corner Away
							 WHEN @MainSubIssueTypeId IN (132, 133) THEN 142 --Next Corner Home
							 WHEN @MainSubIssueTypeId IN (134, 135) THEN 143 --Next Corner Away
							 END
				ELSE NULL END AS SubIssueTypeId
		FROM @tmp_LinkMatch m 
			OUTER APPLY (
					SELECT MatchId
					FROM dbo.match_remark WITH (NOLOCK)
					WHERE matchid = m.MatchId
						AND (SubType LIKE '21__' OR SubType LIKE '26__') --2100+N/2600+N
			)mr
	END
	ELSE IF @MainSubIssueTypeId IN (3,111, 112, 113, 114, 115) --Main Booking Home/Away - No Indication Home/Away Booking (No Onwards/Onwards)
	BEGIN
		SELECT m.MatchId
			,CASE WHEN mr.matchid IS NOT NULL THEN
						CASE WHEN @MainSubIssueTypeId IN (3,111) THEN 72 --Next Booking
							 WHEN @MainSubIssueTypeId IN (112, 113, 114, 115) THEN 144 
						END
				ELSE NULL END AS SubIssueTypeId
		FROM @tmp_LinkMatch m 
			OUTER APPLY (
					SELECT MatchId
					FROM dbo.match_remark WITH (NOLOCK)
					WHERE matchid = m.MatchId
						AND (SubType LIKE '29__' OR SubType LIKE '34__') --2900+N/3400+N
			)mr
	END
	ELSE IF @MainSubIssueTypeId IN (73, 136, 137, 138, 139) --Main Goal Kick - No Indication Home/Away Goal Kick (No Onwards/Onwards)
	BEGIN
		SELECT m.MatchId
			,CASE WHEN mr.matchid IS NOT NULL THEN
						CASE WHEN @MainSubIssueTypeId = 73 THEN 74 --Next Goal Kick
						     WHEN @MainSubIssueTypeId IN (136, 137, 138, 139) THEN 146
						END
				ELSE NULL END AS SubIssueTypeId
		FROM @tmp_LinkMatch m 
			OUTER APPLY (
					SELECT MatchId
					FROM dbo.match_remark WITH (NOLOCK)
					WHERE matchid = m.MatchId
						AND (SubType LIKE '39__' OR SubType LIKE '43__') --3900+N/4300+N

			)mr
	END
	ELSE IF @MainSubIssueTypeId IN (1, 55, 56, 7, 35, 94, 95) --Goal Home/Away - No Indication Home/Away Goal (No Onwards/Onwards)
	BEGIN
		SELECT m.MatchId
			,CASE WHEN mr.matchid IS NOT NULL THEN 
						CASE WHEN @MainSubIssueTypeId = 1 THEN 91 --Next Goal
							 WHEN @MainSubIssueTypeId = 55 THEN 89 --Next Goal Home
							 WHEN @MainSubIssueTypeId = 56 THEN 90 --Next Goal Away
							 WHEN @MainSubIssueTypeId IN (7,35) THEN 140 --Next Goal Home
							 WHEN @MainSubIssueTypeId IN (94,95) THEN 141 --Next Goal Away
							 END
				ELSE NULL END AS SubIssueTypeId
		FROM @tmp_LinkMatch m 
			OUTER APPLY (
					SELECT MatchId
					FROM dbo.match_remark WITH (NOLOCK)
					WHERE matchid = m.MatchId
						AND (SubType LIKE '4__' OR SubType LIKE '5__')  --400+N/500+N
			)mr
	END

END
GO