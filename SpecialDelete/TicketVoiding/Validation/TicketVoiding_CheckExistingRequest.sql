/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_CheckExistingRequest]
(
	@TransInfoJson VARBINARY(MAX) = NULL,
	@RequestId INT = 0,
	@Mode BIT = 0,
	@IssueTypeId INT = 0
)
AS
/*	
	Created by: 20250311@Max
	Task: [TVS] Enhance the Auto Void flow (Instant with Policy) of Abnormal Account  [#Redmine: #217979]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20250311@Max: Init SP [#Redmine: #217979]
		- 20250408@July: Enhance out of memory - Mode Loginfo [#Redmine: #217771]

	Param's explanation:
		@Mode		BIT = 1 --Loginfo, 0 --Others
		@IssueTypeId <> 0 --Special for Advancemode & Wrong score issuetypes
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @Decompress_TransInfoJson NVARCHAR(MAX);
	SET @Decompress_TransInfoJson = CAST(DECOMPRESS(@TransInfoJson) AS NVARCHAR(MAX));

	DECLARE @tmpTrans AS TABLE (
		matchid INT,
		transid BIGINT,
		statusID TINYINT,
		SubTransid BIGINT,
		ScoreId INT,
		Id INT
	);

	INSERT INTO @tmpTrans (
		matchid, transid, statusID, SubTransid, ScoreId, Id
	)
	SELECT 
		mid, t, sid, s_t, score, id
	FROM OPENJSON(@Decompress_TransInfoJson) 
	WITH (
		mid INT, 
		t BIGINT, 
		sid TINYINT, 
		s_t BIGINT, 
		score INT, 
		id INT
	);

	IF @Mode = 0 
	BEGIN
		SELECT DISTINCT t.transid
		FROM @tmpTrans t
		CROSS APPLY (
			SELECT rs.RequestId
			FROM dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK) 
			WHERE rs.MatchId = t.matchid AND rs.TransId = t.transid
		) rs
		CROSS APPLY (
			SELECT TOP 1 1 AS IsValid
			FROM dbo.TicketVoiding_Request r WITH (NOLOCK)
			WHERE r.RequestId = rs.RequestId
				AND r.RequestId <> @RequestId
				AND r.ActionId NOT IN (2) 
				AND r.IssueTypeId NOT IN (22)
				AND 1 = CASE 
					WHEN r.IssueTypeId = 11 AND t.StatusId NOT IN (111,112,113) THEN 1
					WHEN r.IssueTypeId <> 11 THEN 1
					ELSE 0 
				END
		) r;
	END
	ELSE -- Mode: Loginfo
	BEGIN
		CREATE TABLE #tmpTransRequest (
			TransId BIGINT, 
			RequestId INT, 
			MainTransId BIGINT, 
			MatchId INT, 
			ScoreId INT, 
			CreatedBy INT, 
			Id INT
		);

		INSERT INTO #tmpTransRequest (
			TransId, RequestId, MainTransId, MatchId, ScoreId, CreatedBy, Id
		)
		SELECT DISTINCT 
			tmp.transid,
			r.RequestId,
			tmp.MainTransId,
			t.matchid,
			t.ScoreId,
			r.UserId AS CreatedBy,
			t.Id
		FROM @tmpTrans t
		CROSS APPLY (
			SELECT rs.TransId, rs.TransId AS MainTransId, RequestId
			FROM dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK)
			WHERE rs.TransId = t.transid AND rs.MatchId = t.MatchId
			UNION ALL
			SELECT rp.TransId, rp.MainTransId, RequestId
			FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rp WITH (NOLOCK)
			WHERE rp.TransId = t.SubTransid AND rp.MatchId = t.matchid
		) tmp
		INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) 
			ON r.RequestId = tmp.RequestId
		WHERE r.RequestId <> @RequestId
			AND (r.ActionId NOT IN (2) AND r.IssueTypeId NOT IN (22));

		IF @IssueTypeId = 3
		BEGIN
			SELECT TransId, RequestId, MainTransId, MatchId, ScoreId, CreatedBy
			FROM #tmpTransRequest WITH (NOLOCK);
		END
		ELSE IF @IssueTypeId IN (12,24)	
		BEGIN
			SELECT TransId, RequestId, MainTransId, MatchId, CreatedBy, Id
			FROM #tmpTransRequest WITH (NOLOCK);
		END
		ELSE IF @IssueTypeId IN (1,10)	
		BEGIN
			SELECT TransId, RequestId, MainTransId, MatchId, CreatedBy
			FROM #tmpTransRequest WITH (NOLOCK);
		END
		ELSE
		BEGIN
			SELECT TransId, RequestId, MainTransId, MatchId
			FROM #tmpTransRequest WITH (NOLOCK);
		END

		DROP TABLE #tmpTransRequest;
	END
END
GO

