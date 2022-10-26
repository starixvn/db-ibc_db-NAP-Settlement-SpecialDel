/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_SubIssueType_AutoSelect]
(	
	@MainSubIssueTypeId		TINYINT
	,@LinkMatchIds			VARCHAR(MAX)
)
AS
/*	
	Created by: Max
	Date 20211013
	Task: [TVS] Danger Accept Enhancement - Phase 10 [Redmine: #155792]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20211013@Max: Create new SP [Redmine: #155792]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20221025@July: TVS - VAR message [Redmine: #178088]

	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @tmp_LinkMatch AS TABLE (MatchId INT)

	INSERT INTO @tmp_LinkMatch (MatchId)
	SELECT DISTINCT value AS MatchId
	FROM STRING_SPLIT(@LinkMatchIds, ',')
	WHERE value <> ''

	IF @MainSubIssueTypeId IN (2, 68, 69) --Main Corner Home/Away
	BEGIN
		SELECT m.MatchId
			,CASE WHEN mr.matchid IS NOT NULL THEN 
						CASE WHEN @MainSubIssueTypeId = 2 THEN 26 --Next Corner
							 WHEN @MainSubIssueTypeId = 68 THEN 70 --Next Corner Home
							 WHEN @MainSubIssueTypeId = 69 THEN 71 --Next Corner Away
							 END
				ELSE NULL END AS SubIssueTypeId
		FROM @tmp_LinkMatch m 
			OUTER APPLY (
					SELECT MatchId
					FROM dbo.match_remark WITH (NOLOCK)
					WHERE matchid = m.MatchId
						AND SubType BETWEEN 2100 AND 2199
			)mr
	END
	ELSE IF @MainSubIssueTypeId IN (3,111) --Main Booking Home/Away
	BEGIN
		SELECT m.MatchId
			,CASE WHEN mr.matchid IS NOT NULL THEN 72 --Next Booking
				ELSE NULL END AS SubIssueTypeId
		FROM @tmp_LinkMatch m 
			OUTER APPLY (
					SELECT MatchId
					FROM dbo.match_remark WITH (NOLOCK)
					WHERE matchid = m.MatchId
						AND SubType BETWEEN 2900 AND 2999
			)mr
	END
	ELSE IF @MainSubIssueTypeId = 73 --Main Goal Kick
	BEGIN
		SELECT m.MatchId
			,CASE WHEN mr.matchid IS NOT NULL THEN 74 --Next Goal Kick
				ELSE NULL END AS SubIssueTypeId
		FROM @tmp_LinkMatch m 
			OUTER APPLY (
					SELECT MatchId
					FROM dbo.match_remark WITH (NOLOCK)
					WHERE matchid = m.MatchId
						AND SubType BETWEEN 3900 AND 3999
			)mr
	END
	ELSE IF @MainSubIssueTypeId IN (1, 55, 56) --Goal Home/Away
	BEGIN
		SELECT m.MatchId
			,CASE WHEN mr.matchid IS NOT NULL THEN 
						CASE WHEN @MainSubIssueTypeId = 1 THEN 91 --Next Goal
							 WHEN @MainSubIssueTypeId = 55 THEN 89 --Next Goal Home
							 WHEN @MainSubIssueTypeId = 56 THEN 90 --Next Goal Away
							 END
				ELSE NULL END AS SubIssueTypeId
		FROM @tmp_LinkMatch m 
			OUTER APPLY (
					SELECT MatchId
					FROM dbo.match_remark WITH (NOLOCK)
					WHERE matchid = m.MatchId
						AND SubType BETWEEN  400 AND 499
			)mr
	END

END
GO