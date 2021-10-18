/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_SubIssueType_AutoSelect]
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
	
	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @tmp_LinkMatch AS TABLE (MatchId INT)

	INSERT INTO @tmp_LinkMatch (MatchId)
	SELECT DISTINCT val AS MatchId
	FROM dbo.f_SplitString(@LinkMatchIds, ',')
	WHERE val <> ''
	OPTION (MAXRECURSION 0)

	IF @MainSubIssueTypeId = 2 --Main Corner
	BEGIN
		SELECT m.MatchId
			,CASE WHEN mr.matchid IS NOT NULL THEN 26 --Next Corner
				ELSE NULL END AS SubIssueTypeId
		FROM @tmp_LinkMatch m 
			OUTER APPLY (
					SELECT MatchId
					FROM dbo.match_remark WITH (NOLOCK)
					WHERE matchid = m.MatchId
						AND SubType BETWEEN 2100 AND 2199
			)mr
	END
	ELSE IF @MainSubIssueTypeId = 3 --Main Booking
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
	ELSE IF @MainSubIssueTypeId = 1 --Goal
	BEGIN
		SELECT m.MatchId
			,CASE WHEN mr.matchid IS NOT NULL THEN 91 --Next Goal
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